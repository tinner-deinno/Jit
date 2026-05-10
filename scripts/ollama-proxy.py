#!/usr/bin/env python3
"""
ollama-proxy.py — Anthropic API ↔ MDES Ollama Bridge
=======================================================
แปลง Anthropic Messages API format → Ollama /api/chat
ให้ Claude Code ใช้ MDES Ollama เป็น custom AI backend

Usage:
    python3 scripts/ollama-proxy.py
    # or with env:
    OLLAMA_TOKEN=xxx PROXY_PORT=4321 python3 scripts/ollama-proxy.py

Claude Code ใช้งาน:
    export ANTHROPIC_BASE_URL=http://127.0.0.1:4321
    export ANTHROPIC_API_KEY=mdes-ollama
    claude --dangerously-skip-permissions
"""

import os
import json
import time
import threading
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler

# ─── Config ───────────────────────────────────────────────────────────
OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "https://ollama.mdes-innova.online")
OLLAMA_TOKEN    = os.environ.get("OLLAMA_TOKEN", "")
PROXY_PORT      = int(os.environ.get("PROXY_PORT", "4321"))
PROXY_HOST      = os.environ.get("PROXY_HOST", "127.0.0.1")

# ─── Model Pool (4 models, auto-rotate on error) ─────────────────────
MODEL_POOL = [
    "gemma4:26b",          # deep thinking — primary
    "gemma4:e4b",          # fast — secondary
    "qwen2.5-coder:7b",    # code specialist — third
    "llama3.2:latest",     # fallback — fourth
]

_state = {
    "model_idx": 0,
    "current_model": MODEL_POOL[0],
    "requests": 0,
    "errors": 0,
    "rotations": 0,
    "start_time": time.time(),
    "lock": threading.Lock(),
}


def rotate_model(reason="error"):
    with _state["lock"]:
        old = _state["current_model"]
        _state["model_idx"] = (_state["model_idx"] + 1) % len(MODEL_POOL)
        _state["current_model"] = MODEL_POOL[_state["model_idx"]]
        _state["errors"] = 0
        _state["rotations"] += 1
        new = _state["current_model"]
    print(f"[PROXY] 🔄 Model rotation ({reason}): {old} → {new}", flush=True)
    return new


# ─── Format Converters ────────────────────────────────────────────────
def anthropic_to_ollama(body: dict) -> dict:
    """Convert Anthropic Messages API request → Ollama /api/chat"""
    messages = body.get("messages", [])
    system   = body.get("system", "")
    max_tok  = body.get("max_tokens", 4096)

    ollama_msgs = []
    if system:
        ollama_msgs.append({"role": "system", "content": system})

    for msg in messages:
        role    = msg.get("role", "user")
        content = msg.get("content", "")
        # Anthropic can send content as list of blocks
        if isinstance(content, list):
            parts = []
            for block in content:
                if isinstance(block, dict):
                    if block.get("type") == "text":
                        parts.append(block.get("text", ""))
                    elif block.get("type") == "tool_result":
                        for sub in block.get("content", []):
                            if isinstance(sub, dict) and sub.get("type") == "text":
                                parts.append(sub.get("text", ""))
            content = "\n".join(parts)
        ollama_msgs.append({"role": role, "content": str(content)})

    return {
        "model":    _state["current_model"],
        "messages": ollama_msgs,
        "stream":   False,
        "options":  {"num_predict": min(max_tok, 8192)},
    }


def ollama_to_anthropic(resp: dict) -> dict:
    """Convert Ollama /api/chat response → Anthropic Messages API response"""
    msg     = resp.get("message", {})
    content = msg.get("content", "")
    return {
        "id":      f"msg_{int(time.time()*1000)}",
        "type":    "message",
        "role":    "assistant",
        "model":   _state["current_model"],
        "content": [{"type": "text", "text": content}],
        "stop_reason":    "end_turn",
        "stop_sequence":  None,
        "usage": {
            "input_tokens":  resp.get("prompt_eval_count", 0),
            "output_tokens": resp.get("eval_count", 0),
        },
    }


# ─── HTTP Handler ─────────────────────────────────────────────────────
class ProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # custom logging only

    def _send_json(self, code: int, data: dict):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/health"):
            uptime = int(time.time() - _state["start_time"])
            self._send_json(200, {
                "status":        "ok",
                "proxy":         "mdes-ollama-bridge",
                "current_model": _state["current_model"],
                "model_pool":    MODEL_POOL,
                "model_idx":     _state["model_idx"],
                "requests":      _state["requests"],
                "errors":        _state["errors"],
                "rotations":     _state["rotations"],
                "uptime_secs":   uptime,
                "ollama_url":    OLLAMA_BASE_URL,
            })
        elif self.path.startswith("/v1/models"):
            models = [{"id": m, "object": "model"} for m in MODEL_POOL]
            self._send_json(200, {"object": "list", "data": models})
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):
        with _state["lock"]:
            _state["requests"] += 1

        length = int(self.headers.get("Content-Length", 0))
        raw    = self.rfile.read(length) if length > 0 else b"{}"

        try:
            body = json.loads(raw)
        except Exception:
            body = {}

        path = self.path.split("?")[0]

        # Anthropic SDK hits /v1/messages; some older versions hit /complete
        if "/messages" in path or "/complete" in path:
            self._handle_messages(body)
        else:
            self._send_json(404, {"error": f"unknown path: {path}"})

    def _handle_messages(self, body: dict):
        ollama_payload = anthropic_to_ollama(body)
        url = f"{OLLAMA_BASE_URL}/api/chat"

        snippet = json.dumps(body)[:100].replace("\n", " ")
        print(f"[PROXY] → [{_state['current_model']}] {snippet}...", flush=True)

        headers = {"Content-Type": "application/json"}
        if OLLAMA_TOKEN:
            headers["Authorization"] = f"Bearer {OLLAMA_TOKEN}"

        req = urllib.request.Request(
            url,
            data=json.dumps(ollama_payload).encode(),
            headers=headers,
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                raw_resp  = resp.read()
                ollama_r  = json.loads(raw_resp)
                anthr_r   = ollama_to_anthropic(ollama_r)
                tok_out   = anthr_r["usage"]["output_tokens"]
                print(f"[PROXY] ✓ {_state['current_model']} → {tok_out} tokens", flush=True)
                self._send_json(200, anthr_r)
                with _state["lock"]:
                    _state["errors"] = 0  # reset on success

        except urllib.error.HTTPError as e:
            with _state["lock"]:
                _state["errors"] += 1
                errs = _state["errors"]
            code = e.code
            print(f"[PROXY] ✗ HTTP {code} (error #{errs})", flush=True)
            try:
                err_body = json.loads(e.read())
            except Exception:
                err_body = {}
            # rotate on 429/402/403 (quota/token limits) after 2 errors
            if code in (429, 402, 403) and errs >= 2:
                rotate_model(f"http-{code}")
            self._send_json(code, {"error": {"type": "api_error", "message": err_body or str(code)}})

        except Exception as ex:
            with _state["lock"]:
                _state["errors"] += 1
                errs = _state["errors"]
            print(f"[PROXY] ✗ Exception (#{errs}): {ex}", flush=True)
            if errs >= 3:
                rotate_model("exception")
            self._send_json(500, {"error": {"type": "api_error", "message": str(ex)}})


# ─── Startup banner ───────────────────────────────────────────────────
def banner():
    pool_str = " | ".join(MODEL_POOL)
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║  🤖 MDES Ollama ↔ Anthropic Bridge (ollama-proxy.py)       ║
╠══════════════════════════════════════════════════════════════╣
║  Proxy  : http://{PROXY_HOST}:{PROXY_PORT}                        ║
║  Target : {OLLAMA_BASE_URL:<52}║
║  Models : {pool_str[:52]:<52}║
║  Active : {MODEL_POOL[0]:<52}║
╠══════════════════════════════════════════════════════════════╣
║  Claude Code setup:                                          ║
║    export ANTHROPIC_BASE_URL=http://{PROXY_HOST}:{PROXY_PORT}        ║
║    export ANTHROPIC_API_KEY=mdes-ollama                      ║
║    claude --dangerously-skip-permissions                     ║
╚══════════════════════════════════════════════════════════════╝
""", flush=True)


def main():
    if not OLLAMA_TOKEN:
        print("[PROXY] ⚠️  OLLAMA_TOKEN not set — requests may fail", flush=True)

    banner()
    server = HTTPServer((PROXY_HOST, PROXY_PORT), ProxyHandler)
    print(f"[PROXY] 🚀 Ready at http://{PROXY_HOST}:{PROXY_PORT}/health\n", flush=True)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[PROXY] 🛑 Stopped", flush=True)


if __name__ == "__main__":
    main()
