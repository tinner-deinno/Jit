#!/usr/bin/env python3
"""
multi-proxy.py — Unified AI Backend Proxy for Claude Code
===========================================================
แปลง Anthropic Messages API ↔ หลาย backend:
  1. OpenAI / Codex   (OPENAI_API_KEY)
  2. GitHub Copilot   (COPILOT_TOKEN หรือ auto-detect จาก apps.json)
  3. MDES Ollama      (OLLAMA_TOKEN)

Auto-rotate เมื่อ token หมด (429/402/403)
รองรับ tool-calling + streaming (fake SSE)

Port: 4322  (Ollama proxy ยังอยู่ที่ 4321)

Usage:
    python3 scripts/multi-proxy.py

Claude Code:
    export ANTHROPIC_BASE_URL=http://127.0.0.1:4322
    export ANTHROPIC_API_KEY=multi-proxy
    claude --dangerously-skip-permissions
"""

import os, json, time, re, threading, urllib.request, urllib.error, glob
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

# ─── Config ───────────────────────────────────────────────────────────
PROXY_PORT = int(os.environ.get("MULTI_PROXY_PORT", "4322"))
PROXY_HOST = os.environ.get("PROXY_HOST", "127.0.0.1")

OPENAI_API_KEY     = os.environ.get("OPENAI_API_KEY", "")
OPENAI_BASE_URL    = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com")
OPENAI_MODEL       = os.environ.get("OPENAI_MODEL", "gpt-4o")

COPILOT_TOKEN      = os.environ.get("COPILOT_TOKEN", "") or os.environ.get("GITHUB_COPILOT_TOKEN", "")
COPILOT_BASE_URL   = "https://api.githubcopilot.com"
COPILOT_MODEL      = os.environ.get("COPILOT_MODEL", "gpt-4o")

OLLAMA_TOKEN       = os.environ.get("OLLAMA_TOKEN", "")
OLLAMA_BASE_URL    = os.environ.get("OLLAMA_BASE_URL", "https://ollama.mdes-innova.online")
OLLAMA_MODEL       = os.environ.get("OLLAMA_MODEL", "gemma4:26b")

GITHUB_TOKEN       = os.environ.get("GITHUB_TOKEN", "") or os.environ.get("GH_TOKEN", "")

# ThaiLLM — Typhoon (SCB10X), OpenThaiGPT (AIEAT), Pathumma (NECTEC), THaLLE (KBTG)
THAILLM_TOKEN    = os.environ.get("THAILLM_TOKEN", "")
THAILLM_BASE_URL = os.environ.get("THAILLM_BASE_URL", "https://api.opentyphoon.ai")
THAILLM_MODEL    = os.environ.get("THAILLM_MODEL", "typhoon-v2-8b-instruct")

# Local Ollama (localhost)
OLLAMA_LOCAL_URL   = os.environ.get("OLLAMA_LOCAL_URL", "http://127.0.0.1:11434")
OLLAMA_LOCAL_MODEL = os.environ.get("OLLAMA_LOCAL_MODEL", "qwen2.5-coder:7b")
OLLAMA_LOCAL_TOKEN = os.environ.get("OLLAMA_LOCAL_TOKEN", "")

# CommandCode (http://api.commandcode.ai)
COMMANDCODE_API_KEY  = os.environ.get("COMMANDCODE_API_KEY", "") or os.environ.get("CC_KEY", "")
COMMANDCODE_BASE_URL = os.environ.get("COMMANDCODE_BASE_URL", "https://api.commandcode.ai/provider/v1")
COMMANDCODE_MODEL    = os.environ.get("COMMANDCODE_MODEL", "deepseek/deepseek-v4-pro")

# Backend order — first available wins, rotates on quota error
_BACKEND_ORDER_ENV = os.environ.get("MULTI_BACKEND_ORDER", "ollama,commandcode,copilot,thaillm,local,openai")
BACKEND_ORDER = [b.strip() for b in _BACKEND_ORDER_ENV.split(",") if b.strip()]

# ─── Copilot token auto-detect ────────────────────────────────────────
def _find_copilot_apps_json():
    """Find GitHub Copilot apps.json on Windows or Linux"""
    candidates = [
        os.path.join(os.environ.get("LOCALAPPDATA",""), "github-copilot", "apps.json"),
        os.path.join(os.environ.get("LOCALAPPDATA",""), "GitHub Copilot", "apps.json"),
        os.path.join(os.environ.get("APPDATA",""), "GitHub Copilot", "hosts.json"),
        os.path.expanduser("~/.config/github-copilot/hosts.json"),
        os.path.expanduser("~/.config/github-copilot/apps.json"),
    ]
    for p in candidates:
        if p and os.path.exists(p):
            return p
    return None


def _load_github_oauth_token():
    """Load GitHub OAuth token from Copilot apps.json"""
    p = _find_copilot_apps_json()
    if not p:
        return ""
    try:
        d = json.load(open(p, encoding="utf-8"))
        # apps.json: {"github.com": {"oauth_token": "ghu_..."}}
        # hosts.json: {"github.com": {"oauth_token": "ghu_..."}}
        gh = d.get("github.com", d)
        return gh.get("oauth_token", gh.get("token", ""))
    except Exception:
        return ""


def _exchange_copilot_token(oauth_token: str) -> str:
    """Exchange GitHub OAuth token for Copilot API token"""
    if not oauth_token:
        return ""
    try:
        req = urllib.request.Request(
            "https://api.github.com/copilot_internal/v2/token",
            headers={
                "Authorization": f"Bearer {oauth_token}",
                "Accept": "application/json",
                "User-Agent": "claude-code-multi-proxy/1.0",
            },
            method="GET",
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            return data.get("token", "")
    except Exception as ex:
        print(f"[MULTI] Copilot token exchange failed: {ex}", flush=True)
        return ""


def _resolve_copilot_token() -> str:
    """Resolve Copilot bearer token by any available method"""
    # 1. Direct env var
    if COPILOT_TOKEN:
        return COPILOT_TOKEN
    # 2. GitHub token env → exchange
    if GITHUB_TOKEN:
        tok = _exchange_copilot_token(GITHUB_TOKEN)
        if tok:
            print("[MULTI] ✓ Copilot token via GITHUB_TOKEN exchange", flush=True)
            return tok
    # 3. Auto-detect from apps.json
    oauth = _load_github_oauth_token()
    if oauth:
        tok = _exchange_copilot_token(oauth)
        if tok:
            print("[MULTI] ✓ Copilot token via apps.json", flush=True)
            return tok
    return ""


# ─── State ────────────────────────────────────────────────────────────
_copilot_bearer  = ""        # resolved at startup
_copilot_expires = 0.0       # unix timestamp

_state = {
    "backend_idx": 0,
    "current_backend": None,
    "requests": 0,
    "errors": 0,
    "rotations": 0,
    "start_time": time.time(),
    "backend_errors": {b: 0 for b in BACKEND_ORDER},
    "lock": threading.Lock(),
}


def _init_backends():
    """Determine which backends are available and set starting backend"""
    global _copilot_bearer, _copilot_expires
    available = []

    if OPENAI_API_KEY:
        available.append("openai")
        print(f"[MULTI] ✓ OpenAI backend (model: {OPENAI_MODEL})", flush=True)
    else:
        print("[MULTI] ○ OpenAI: no OPENAI_API_KEY", flush=True)

    _copilot_bearer = _resolve_copilot_token()
    _copilot_expires = time.time() + 1700  # ~28 min, typical copilot token lifetime
    if _copilot_bearer:
        available.append("copilot")
        print(f"[MULTI] ✓ Copilot backend (model: {COPILOT_MODEL})", flush=True)
    else:
        print("[MULTI] ○ Copilot: no token found", flush=True)

    if OLLAMA_TOKEN:
        available.append("ollama")
        print(f"[MULTI] ✓ Ollama/MDES backend (model: {OLLAMA_MODEL})", flush=True)
    else:
        print("[MULTI] ○ Ollama/MDES: no OLLAMA_TOKEN", flush=True)

    if THAILLM_TOKEN:
        available.append("thaillm")
        print(f"[MULTI] ✓ ThaiLLM backend (model: {THAILLM_MODEL})", flush=True)
    else:
        print("[MULTI] ○ ThaiLLM: no THAILLM_TOKEN", flush=True)

    # Local Ollama — ping /api/tags to detect
    try:
        req = urllib.request.Request(f"{OLLAMA_LOCAL_URL}/api/tags", method="GET")
        with urllib.request.urlopen(req, timeout=3) as resp:
            tags_raw = json.loads(resp.read())
        local_models = [m["name"] for m in tags_raw.get("models", [])]
        if local_models:
            available.append("local")
            print(f"[MULTI] ✓ Local Ollama backend ({len(local_models)} models: {', '.join(local_models[:3])}...)", flush=True)
        else:
            print("[MULTI] ○ Local Ollama: running but no models installed", flush=True)
    except Exception:
        print("[MULTI] ○ Local Ollama: not reachable", flush=True)

    if COMMANDCODE_API_KEY:
        available.append("commandcode")
        print(f"[MULTI] ✓ CommandCode backend (model: {COMMANDCODE_MODEL})", flush=True)
    else:
        print("[MULTI] ○ CommandCode: no COMMANDCODE_API_KEY", flush=True)

    ordered = [b for b in BACKEND_ORDER if b in available]
    if not ordered:
        print("[MULTI] ⚠️  No backends configured! Claude Code will get errors.", flush=True)
        ordered = BACKEND_ORDER  # try anyway
    return ordered


# ─── Anthropic → OpenAI format conversion ────────────────────────────

def _content_to_str(content) -> str:
    """Convert Anthropic content (str or list of blocks) to plain string"""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get("type", "")
            if btype == "text":
                parts.append(block.get("text", ""))
            elif btype == "tool_result":
                sub_content = block.get("content", "")
                parts.append(_content_to_str(sub_content))
        return "\n".join(p for p in parts if p)
    return str(content)


def anthropic_to_openai(body: dict, model: str) -> dict:
    """Convert Anthropic Messages API request → OpenAI Chat Completions"""
    messages = body.get("messages", [])
    system   = body.get("system", "")
    max_tok  = body.get("max_tokens", 4096)

    oai_msgs = []
    if system:
        oai_msgs.append({"role": "system", "content": _content_to_str(system)})

    for msg in messages:
        role    = msg.get("role", "user")
        content = msg.get("content", "")

        # Handle assistant messages with tool_use blocks
        if role == "assistant" and isinstance(content, list):
            text_parts = []
            tool_calls = []
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "text":
                    text_parts.append(block.get("text", ""))
                elif block.get("type") == "tool_use":
                    tool_calls.append({
                        "id": block.get("id", f"call_{int(time.time()*1000)}"),
                        "type": "function",
                        "function": {
                            "name": block.get("name", ""),
                            "arguments": json.dumps(block.get("input", {})),
                        },
                    })
            oai_msg = {"role": "assistant", "content": " ".join(text_parts) or None}
            if tool_calls:
                oai_msg["tool_calls"] = tool_calls
            oai_msgs.append(oai_msg)
            continue

        # Handle user messages with tool_result blocks
        if role == "user" and isinstance(content, list):
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_result":
                    tool_id = block.get("tool_use_id", "")
                    result_text = _content_to_str(block.get("content", ""))
                    oai_msgs.append({
                        "role": "tool",
                        "tool_call_id": tool_id,
                        "content": result_text,
                    })
                elif block.get("type") == "text":
                    oai_msgs.append({"role": "user", "content": block.get("text", "")})
            continue

        oai_msgs.append({"role": role, "content": _content_to_str(content)})

    tok_limit = min(int(max_tok), 16384)
    result = {
        "model": model,
        "messages": oai_msgs,
    }
    # GPT-5.4 / GPT-5.5 require max_completion_tokens instead of max_tokens
    if re.match(r"^gpt-5\.[45]", model):
        result["max_completion_tokens"] = tok_limit
    else:
        result["max_tokens"] = tok_limit

    # Convert Anthropic tools → OpenAI tools
    if "tools" in body and body["tools"]:
        result["tools"] = [
            {
                "type": "function",
                "function": {
                    "name": t.get("name", ""),
                    "description": t.get("description", ""),
                    "parameters": t.get("input_schema", {}),
                },
            }
            for t in body["tools"]
        ]
        choice = body.get("tool_choice", {})
        if isinstance(choice, dict) and choice.get("type") == "any":
            result["tool_choice"] = "required"
        elif isinstance(choice, dict) and choice.get("type") == "auto":
            result["tool_choice"] = "auto"

    return result


def openai_to_anthropic(resp: dict, model_used: str) -> dict:
    """Convert OpenAI Chat Completions response → Anthropic Messages API"""
    choices    = resp.get("choices", [{}])
    choice     = choices[0] if choices else {}
    message    = choice.get("message", {})
    finish     = choice.get("finish_reason", "stop")
    text       = message.get("content") or ""
    usage      = resp.get("usage", {})

    content_blocks = []

    # Handle tool_calls in response
    tool_calls = message.get("tool_calls", [])
    for tc in tool_calls:
        fn = tc.get("function", {})
        try:
            args = json.loads(fn.get("arguments", "{}"))
        except Exception:
            args = {"_raw": fn.get("arguments", "")}
        content_blocks.append({
            "type": "tool_use",
            "id": tc.get("id", f"toolu_{int(time.time()*1000)}"),
            "name": fn.get("name", ""),
            "input": args,
        })

    if text:
        content_blocks.append({"type": "text", "text": text})

    stop_reason = "tool_use" if tool_calls else "end_turn"
    if finish == "length":
        stop_reason = "max_tokens"

    return {
        "id":    f"msg_{int(time.time()*1000)}",
        "type":  "message",
        "role":  "assistant",
        "model": model_used,
        "content": content_blocks,
        "stop_reason":    stop_reason,
        "stop_sequence":  None,
        "usage": {
            "input_tokens":  usage.get("prompt_tokens", 0),
            "output_tokens": usage.get("completion_tokens", 0),
        },
    }


# ─── Anthropic → Ollama format conversion (reused from ollama-proxy) ──

def anthropic_to_ollama(body: dict, model: str) -> dict:
    messages = body.get("messages", [])
    system   = body.get("system", "")
    max_tok  = body.get("max_tokens", 4096)

    ollama_msgs = []
    if system:
        ollama_msgs.append({"role": "system", "content": _content_to_str(system)})

    for msg in messages:
        role    = msg.get("role", "user")
        content = msg.get("content", "")
        ollama_msgs.append({"role": role, "content": _content_to_str(content)})

    return {
        "model":    model,
        "messages": ollama_msgs,
        "stream":   False,
        "options":  {"num_predict": min(int(max_tok), 8192)},
    }


def ollama_to_anthropic(resp: dict, model_used: str) -> dict:
    msg     = resp.get("message", {})
    content = msg.get("content", "")
    return {
        "id":      f"msg_{int(time.time()*1000)}",
        "type":    "message",
        "role":    "assistant",
        "model":   model_used,
        "content": [{"type": "text", "text": content}],
        "stop_reason":    "end_turn",
        "stop_sequence":  None,
        "usage": {
            "input_tokens":  resp.get("prompt_eval_count", 0),
            "output_tokens": resp.get("eval_count", 0),
        },
    }


# ─── Streaming helpers ────────────────────────────────────────────────

def _build_sse_events(anthr_resp: dict) -> bytes:
    """Build complete SSE byte stream from Anthropic response dict"""
    msg_id = anthr_resp["id"]
    model  = anthr_resp["model"]
    usage  = anthr_resp.get("usage", {})
    in_tok = usage.get("input_tokens", 0)
    out_tok= usage.get("output_tokens", 0)
    stop   = anthr_resp.get("stop_reason", "end_turn")

    content_blocks = anthr_resp.get("content", [])
    # gather text
    text = ""
    for b in content_blocks:
        if isinstance(b, dict) and b.get("type") == "text":
            text += b.get("text", "")

    lines = []

    def emit(event, data):
        lines.append(f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n")

    emit("message_start", {
        "type": "message_start",
        "message": {
            "id": msg_id, "type": "message", "role": "assistant",
            "content": [], "model": model,
            "stop_reason": None, "stop_sequence": None,
            "usage": {"input_tokens": in_tok, "output_tokens": 0},
        },
    })
    emit("content_block_start", {"type": "content_block_start", "index": 0,
                                   "content_block": {"type": "text", "text": ""}})
    emit("ping", {"type": "ping"})
    if text:
        emit("content_block_delta", {"type": "content_block_delta", "index": 0,
                                      "delta": {"type": "text_delta", "text": text}})
    emit("content_block_stop", {"type": "content_block_stop", "index": 0})
    emit("message_delta", {"type": "message_delta",
                            "delta": {"stop_reason": stop, "stop_sequence": None},
                            "usage": {"output_tokens": out_tok}})
    emit("message_stop", {"type": "message_stop"})

    return "\n".join(lines).encode("utf-8") + b"\n"


# ─── Backend callers ──────────────────────────────────────────────────

def _call_openai(body: dict, model_override: str = None) -> dict:
    """Call OpenAI Chat Completions API"""
    model    = model_override or OPENAI_MODEL
    oai_body = anthropic_to_openai(body, model)
    payload  = json.dumps(oai_body).encode()
    req = urllib.request.Request(
        f"{OPENAI_BASE_URL}/v1/chat/completions",
        data=payload,
        headers={
            "Content-Type":  "application/json",
            "Authorization": f"Bearer {OPENAI_API_KEY}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        raw  = json.loads(resp.read())
        return openai_to_anthropic(raw, f"openai/{model}")


def _get_copilot_token() -> str:
    """Return valid Copilot token, re-exchange if near expiry"""
    global _copilot_bearer, _copilot_expires
    if time.time() > _copilot_expires - 60:
        # Token near expiry — re-exchange
        oauth = _load_github_oauth_token() or GITHUB_TOKEN
        new_tok = _exchange_copilot_token(oauth) if oauth else ""
        if new_tok:
            _copilot_bearer  = new_tok
            _copilot_expires = time.time() + 1700
    return _copilot_bearer


def _call_copilot(body: dict, model_override: str = None) -> dict:
    """Call GitHub Copilot Chat Completions API"""
    token = _get_copilot_token()
    if not token:
        raise RuntimeError("No Copilot token available")

    model    = model_override or COPILOT_MODEL
    oai_body = anthropic_to_openai(body, model)
    payload  = json.dumps(oai_body).encode()
    req = urllib.request.Request(
        f"{COPILOT_BASE_URL}/chat/completions",
        data=payload,
        headers={
            "Content-Type":          "application/json",
            "Authorization":         f"Bearer {token}",
            "Copilot-Integration-Id":"vscode-chat",
            "Editor-Version":        "vscode/1.89.0",
            "Editor-Plugin-Version": "copilot-chat/0.16.0",
            "User-Agent":            "GitHubCopilotChat/0.16.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        raw = json.loads(resp.read())
        return openai_to_anthropic(raw, f"copilot/{model}")


def _call_ollama(body: dict, model_override: str = None) -> dict:
    """Call MDES Ollama /api/chat"""
    model       = model_override or OLLAMA_MODEL
    ollama_body = anthropic_to_ollama(body, model)
    payload     = json.dumps(ollama_body).encode()
    req = urllib.request.Request(
        f"{OLLAMA_BASE_URL}/api/chat",
        data=payload,
        headers={
            "Content-Type":  "application/json",
            "Authorization": f"Bearer {OLLAMA_TOKEN}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        raw = json.loads(resp.read())
        return ollama_to_anthropic(raw, f"mdes/{model}")


def _call_thaillm(body: dict, model_override: str = None) -> dict:
    """Call ThaiLLM OpenAI-compatible API (Typhoon, OpenThaiGPT, Pathumma, THaLLE)"""
    if not THAILLM_TOKEN:
        raise RuntimeError("No THAILLM_TOKEN set")
    model    = model_override or THAILLM_MODEL
    oai_body = anthropic_to_openai(body, model)
    payload  = json.dumps(oai_body).encode()
    req = urllib.request.Request(
        f"{THAILLM_BASE_URL}/v1/chat/completions",
        data=payload,
        headers={
            "Content-Type":  "application/json",
            "Authorization": f"Bearer {THAILLM_TOKEN}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        raw = json.loads(resp.read())
        return openai_to_anthropic(raw, f"thaillm/{model}")


def _call_local(body: dict, model_override: str = None) -> dict:
    """Call Local Ollama /api/chat"""
    model       = model_override or OLLAMA_LOCAL_MODEL
    ollama_body = anthropic_to_ollama(body, model)
    payload     = json.dumps(ollama_body).encode()
    headers = {"Content-Type": "application/json"}
    if OLLAMA_LOCAL_TOKEN:
        headers["Authorization"] = f"Bearer {OLLAMA_LOCAL_TOKEN}"
    req = urllib.request.Request(
        f"{OLLAMA_LOCAL_URL}/api/chat",
        data=payload,
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        raw = json.loads(resp.read())
        return ollama_to_anthropic(raw, f"local/{model}")


def _call_commandcode(body: dict, model_override: str = None) -> dict:
    """Call CommandCode API — dual-format hub.
    claude-* models → native Anthropic /messages (pass-through);
    everything else → OpenAI /chat/completions (translated)."""
    model = model_override or COMMANDCODE_MODEL

    if model.lower().startswith("claude"):
        # Native Anthropic wire format — pass body through unchanged
        cc_body = {k: v for k, v in body.items() if k != "stream"}
        cc_body["model"] = model
        cc_body.setdefault("max_tokens", 4096)
        payload = json.dumps(cc_body).encode()
        req = urllib.request.Request(
            f"{COMMANDCODE_BASE_URL}/messages",
            data=payload,
            headers={
                "Content-Type":  "application/json",
                "Authorization": f"Bearer {COMMANDCODE_API_KEY}",
                # Cloudflare blocks the default Python-urllib UA with 403
                "User-Agent":    "claude-multi-proxy/1.0",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=180) as resp:
            raw = json.loads(resp.read())
            raw["model"] = f"commandcode/{model}"
            return raw

    oai_body = anthropic_to_openai(body, model)
    payload  = json.dumps(oai_body).encode()
    req = urllib.request.Request(
        f"{COMMANDCODE_BASE_URL}/chat/completions",
        data=payload,
        headers={
            "Content-Type":  "application/json",
            "Authorization": f"Bearer {COMMANDCODE_API_KEY}",
            # Cloudflare blocks the default Python-urllib UA with 403
            "User-Agent":    "claude-multi-proxy/1.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        raw = json.loads(resp.read())
        return openai_to_anthropic(raw, f"commandcode/{model}")


_BACKEND_CALLERS = {
    "openai":      _call_openai,
    "copilot":     _call_copilot,
    "ollama":      _call_ollama,
    "thaillm":     _call_thaillm,
    "local":       _call_local,
    "commandcode": _call_commandcode,
}

# ─── Backend rotation ─────────────────────────────────────────────────

_available_backends: list = []


def _rotate_backend(reason="error"):
    with _state["lock"]:
        old = _available_backends[_state["backend_idx"] % len(_available_backends)]
        _state["backend_idx"] = (_state["backend_idx"] + 1) % len(_available_backends)
        new = _available_backends[_state["backend_idx"] % len(_available_backends)]
        _state["backend_errors"][old] = 0
        _state["rotations"] += 1
    print(f"[MULTI] 🔄 Backend rotation ({reason}): {old} → {new}", flush=True)
    return new


def _current_backend() -> str:
    if not _available_backends:
        return BACKEND_ORDER[0]
    return _available_backends[_state["backend_idx"] % len(_available_backends)]


def _parse_model_prefix(raw_model: str):
    """
    Returns (backend, clean_model).
    Prefixes: copilot/, mdes/, thaillm/, local/, openai/, commandcode/, cc/
    """
    for prefix, backend in (
        ("copilot/",     "copilot"),
        ("mdes/",        "ollama"),
        ("thaillm/",     "thaillm"),
        ("local/",       "local"),
        ("openai/",      "openai"),
        ("commandcode/", "commandcode"),
        ("cc/",          "commandcode"),
    ):
        if raw_model.lower().startswith(prefix):
            return backend, raw_model[len(prefix):]
    return None, raw_model


def call_with_rotation(body: dict) -> dict:
    """Call backend. If model has a prefix (e.g. copilot/...) pin that backend.
    Otherwise rotate across available backends."""
    raw_model = body.get("model", "")
    pinned_backend, clean_model = _parse_model_prefix(raw_model)

    if pinned_backend:
        body = {**body, "model": clean_model}
        caller = _BACKEND_CALLERS.get(pinned_backend)
        if not caller:
            raise RuntimeError(f"No caller for pinned backend: {pinned_backend}")
        snippet = json.dumps(body)[:80].replace("\n", " ")
        print(f"[MULTI] → [{pinned_backend}:{clean_model}] {snippet}...", flush=True)
        result = caller(body, clean_model)
        out_tok = result.get("usage", {}).get("output_tokens", 0)
        print(f"[MULTI] ✓ {pinned_backend} → {out_tok} tokens", flush=True)
        return result

    # No prefix — rotate across available backends
    tries = max(len(_available_backends), 1)

    for attempt in range(tries):
        backend = _current_backend()
        caller  = _BACKEND_CALLERS.get(backend)
        if not caller:
            _rotate_backend(f"no-caller-{backend}")
            continue

        snippet = json.dumps(body)[:80].replace("\n", " ")
        print(f"[MULTI] → [{backend}] {snippet}...", flush=True)

        try:
            result = caller(body)
            with _state["lock"]:
                _state["backend_errors"][backend] = 0
                _state["errors"] = 0
            return result

        except urllib.error.HTTPError as e:
            code = e.code
            with _state["lock"]:
                _state["backend_errors"][backend] += 1
                errs = _state["backend_errors"][backend]
                _state["errors"] += 1
            print(f"[MULTI] ✗ {backend} HTTP {code} (#{errs})", flush=True)
            if code in (429, 402, 403, 401) and errs >= 2:
                _rotate_backend(f"{backend}-http{code}")
                continue
            raise

        except Exception as ex:
            with _state["lock"]:
                _state["backend_errors"][backend] += 1
                errs = _state["backend_errors"][backend]
                _state["errors"] += 1
            print(f"[MULTI] ✗ {backend} error #{errs}: {ex}", flush=True)
            if errs >= 2:
                _rotate_backend(f"{backend}-exception")
                continue
            raise

    raise RuntimeError("All backends exhausted")


# ─── HTTP Handler ─────────────────────────────────────────────────────

class ProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def _send_json(self, code: int, data: dict):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_sse(self, data: bytes):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if "/health" in self.path:
            uptime = int(time.time() - _state["start_time"])
            self._send_json(200, {
                "status":           "ok",
                "proxy":            "multi-backend",
                "current_backend":  _current_backend(),
                "available":        _available_backends,
                "backend_order":    BACKEND_ORDER,
                "requests":         _state["requests"],
                "errors":           _state["errors"],
                "rotations":        _state["rotations"],
                "uptime_secs":      uptime,
                "backends": {
                    "openai":   bool(OPENAI_API_KEY),
                    "copilot":  bool(_copilot_bearer),
                    "ollama":   bool(OLLAMA_TOKEN),
                    "thaillm":  bool(THAILLM_TOKEN),
                    "local":    "local" in _available_backends,
                    "commandcode": bool(COMMANDCODE_API_KEY),
                },
            })
        elif "/v1/models" in self.path:
            models = [
                # CommandCode
                {"id": "commandcode/deepseek/deepseek-v4-pro",   "object": "model"},
                {"id": "commandcode/deepseek/deepseek-v4-flash", "object": "model"},
                {"id": "commandcode/qwen/qwen3.7-max",          "object": "model"},
                {"id": "commandcode/minimax/minimax-m3",        "object": "model"},
                {"id": "cc/deepseek/deepseek-v4-pro",           "object": "model"},
                {"id": "cc/deepseek/deepseek-v4-flash",         "object": "model"},
                # MDES Ollama
                {"id": "mdes/gemma4:26b",           "object": "model"},
                {"id": "mdes/qwen3.5:9b",            "object": "model"},
                {"id": "mdes/qwen3.5:27b",           "object": "model"},
                {"id": "mdes/qwen2.5-coder:32b",     "object": "model"},
                {"id": "mdes/gemma4:e4b",            "object": "model"},
                {"id": "mdes/gemma3:12b",            "object": "model"},
                # Copilot Claude (bridged)
                {"id": "copilot/claude-sonnet-4.6",  "object": "model"},
                {"id": "copilot/claude-sonnet-4.5",  "object": "model"},
                {"id": "copilot/claude-haiku-4.5",   "object": "model"},
                {"id": "copilot/claude-opus-4.5",    "object": "model"},
                {"id": "copilot/claude-opus-4.7",    "object": "model"},
                # Copilot GPT-5
                {"id": "copilot/gpt-5.5",            "object": "model"},
                {"id": "copilot/gpt-5.4",            "object": "model"},
                {"id": "copilot/gpt-5.3-codex",      "object": "model"},
                {"id": "copilot/gpt-5.2",            "object": "model"},
                {"id": "copilot/gpt-5.2-codex",      "object": "model"},
                {"id": "copilot/gpt-5-mini",         "object": "model"},
                # Copilot GPT-4
                {"id": "copilot/gpt-4.1",            "object": "model"},
                {"id": "copilot/gpt-4o",             "object": "model"},
                {"id": "copilot/gpt-4o-mini",        "object": "model"},
                # Copilot Gemini
                {"id": "copilot/gemini-2.5-pro",     "object": "model"},
                # ThaiLLM
                {"id": "thaillm/typhoon-v2-70b-instruct",         "object": "model"},
                {"id": "thaillm/typhoon-v2-8b-instruct",          "object": "model"},
                {"id": "thaillm/typhoon-v2-r1-70b",               "object": "model"},
                {"id": "thaillm/typhoon-v1.5x-70b-instruct",      "object": "model"},
                {"id": "thaillm/Typhoon-S-ThaiLLM-8B-Instruct",   "object": "model"},
                {"id": "thaillm/OpenThaiGPT-ThaiLLM-8B-Instruct-v7.2", "object": "model"},
                {"id": "thaillm/Pathumma-ThaiLLM-qwen3-8b-think-3.0.0", "object": "model"},
                {"id": "thaillm/THaLLE-0.2-ThaiLLM-8B-fa",       "object": "model"},
                # Local Ollama
                {"id": "local/qwen2.5-coder:7b",    "object": "model"},
                {"id": "local/qwen3:8b",             "object": "model"},
                {"id": "local/llama3.2",             "object": "model"},
            ]
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

        path   = self.path.split("?")[0]
        is_stream = body.get("stream", False)

        if "/count_tokens" in path:
            # Claude Code token-counting stub — rough estimate (chars/4)
            try:
                est = max(1, len(json.dumps(body.get("messages", []), ensure_ascii=False)) // 4)
            except Exception:
                est = 1
            self._send_json(200, {"input_tokens": est})
            return

        if "/messages" in path or "/complete" in path:
            # Anthropic format — pass through to call_with_rotation
            pass
        elif "/chat/completions" in path:
            # OpenAI format — convert to Anthropic body for call_with_rotation
            raw_model = body.get("model", "")
            pinned_backend, clean_model = _parse_model_prefix(raw_model)
            # Build a minimal Anthropic-style body so call_with_rotation can handle it
            msgs = body.get("messages", [])
            anthropic_body = {
                "model": body.get("model", ""),
                "max_tokens": body.get("max_tokens") or body.get("max_completion_tokens") or 4096,
                "messages": [],
                "stream": False,
            }
            system_parts = []
            for m in msgs:
                role = m.get("role", "user")
                content = m.get("content", "")
                if role == "system":
                    system_parts.append(content)
                else:
                    anthropic_body["messages"].append({"role": role, "content": content})
            if system_parts:
                anthropic_body["system"] = "\n".join(system_parts)

            try:
                result = call_with_rotation(anthropic_body)
                out_tok = result.get("usage", {}).get("output_tokens", 0)
                print(f"[MULTI] ✓ OAI path → {out_tok} tokens", flush=True)
                # Convert back to OpenAI format for the caller
                text = ""
                for block in result.get("content", []):
                    if block.get("type") == "text":
                        text += block.get("text", "")
                oai_resp = {
                    "id": result.get("id", "chatcmpl-proxy"),
                    "object": "chat.completion",
                    "model": result.get("model", raw_model),
                    "choices": [{"index": 0, "message": {"role": "assistant", "content": text},
                                 "finish_reason": result.get("stop_reason", "stop")}],
                    "usage": {
                        "prompt_tokens":     result.get("usage", {}).get("input_tokens", 0),
                        "completion_tokens": result.get("usage", {}).get("output_tokens", 0),
                        "total_tokens":      result.get("usage", {}).get("input_tokens", 0) +
                                             result.get("usage", {}).get("output_tokens", 0),
                    },
                }
                self._send_json(200, oai_resp)
            except urllib.error.HTTPError as e:
                code = e.code
                try:   err_body = json.loads(e.read())
                except Exception: err_body = {}
                print(f"[MULTI] ✗ OAI path HTTP {code}", flush=True)
                self._send_json(code, {"error": {"type": "api_error", "message": str(err_body or code)}})
            except Exception as ex:
                print(f"[MULTI] ✗ OAI path error: {ex}", flush=True)
                self._send_json(500, {"error": {"type": "api_error", "message": str(ex)}})
            return
        else:
            self._send_json(404, {"error": f"unknown path: {path}"})
            return

        try:
            # Force non-stream for backend calls; we fake SSE
            body_nostream = {**body, "stream": False}
            result = call_with_rotation(body_nostream)
            out_tok = result.get("usage", {}).get("output_tokens", 0)
            backend = _current_backend()
            print(f"[MULTI] ✓ {backend} → {out_tok} tokens", flush=True)

            if is_stream:
                sse = _build_sse_events(result)
                self._send_sse(sse)
            else:
                self._send_json(200, result)

        except urllib.error.HTTPError as e:
            code = e.code
            try:
                err_body = json.loads(e.read())
            except Exception:
                err_body = {}
            print(f"[MULTI] ✗ final HTTP {code}", flush=True)
            self._send_json(code, {"error": {"type": "api_error",
                                              "message": str(err_body or code)}})

        except Exception as ex:
            print(f"[MULTI] ✗ final error: {ex}", flush=True)
            self._send_json(500, {"error": {"type": "api_error", "message": str(ex)}})


# ─── Banner ───────────────────────────────────────────────────────────

def banner():
    avail = " + ".join(_available_backends) if _available_backends else "NONE"
    thaillm_stat = ("✓ " + THAILLM_MODEL) if THAILLM_TOKEN else "✗ no THAILLM_TOKEN"
    local_stat   = "✓ local Ollama" if "local" in _available_backends else "✗ not reachable"
    cc_stat      = ("✓ " + COMMANDCODE_MODEL) if COMMANDCODE_API_KEY else "✗ no key"
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║  🤖 Multi-Backend Proxy (multi-proxy.py)                    ║
╠══════════════════════════════════════════════════════════════╣
║  Port         : {PROXY_HOST}:{PROXY_PORT:<40} ║
║  Active       : {avail:<46} ║
╠══════════════════════════════════════════════════════════════╣
║  MDES/Ollama  : {"✓ " + OLLAMA_MODEL if OLLAMA_TOKEN else "✗ no OLLAMA_TOKEN":<44} ║
║  CommandCode  : {cc_stat:<44} ║
║  Copilot      : {"✓ " + COPILOT_MODEL if _copilot_bearer else "✗ no token":<44} ║
║  ThaiLLM      : {thaillm_stat:<44} ║
║  Local Ollama : {local_stat:<44} ║
║  OpenAI       : {"✓ " + OPENAI_MODEL if OPENAI_API_KEY else "✗ no OPENAI_API_KEY":<44} ║
╠══════════════════════════════════════════════════════════════╣
║  set ANTHROPIC_BASE_URL=http://{PROXY_HOST}:{PROXY_PORT}             ║
║  set OPENAI_BASE_URL=http://{PROXY_HOST}:{PROXY_PORT}                ║
║  set ANTHROPIC_API_KEY=multi-proxy                           ║
║  set OPENAI_API_KEY=multi-proxy                              ║
╚══════════════════════════════════════════════════════════════╝
""", flush=True)


def main():
    global _available_backends
    _available_backends = _init_backends()
    banner()
    server = ThreadingHTTPServer((PROXY_HOST, PROXY_PORT), ProxyHandler)
    print(f"[MULTI] 🚀 Ready at http://{PROXY_HOST}:{PROXY_PORT}/health\n", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[MULTI] 🛑 Stopped", flush=True)


if __name__ == "__main__":
    main()
