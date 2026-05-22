#!/usr/bin/env python3
"""
scripts/heartbeat-win.py — Jit Heartbeat for Windows
No Bash needed — pure Python 3.x

Every 15 minutes:
1. Update memory/state/heartbeat.log
2. Update memory/state/innova.state.json vitality
3. Check Oracle health (port 47778)
4. Check local Ollama health (port 11434)
5. git commit + push state

Usage:
    python scripts/heartbeat-win.py           # One heartbeat
    python scripts/heartbeat-win.py --daemon  # Every 15 min
    python scripts/heartbeat-win.py --status  # Show last heartbeat
"""
import argparse
import json
import os
import platform
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from urllib.request import urlopen
from urllib.error import URLError

JIT_ROOT = Path(__file__).parent.parent.resolve()
STATE_DIR = JIT_ROOT / "memory" / "state"
HEARTBEAT_LOG = STATE_DIR / "heartbeat.log"
INNOVA_STATE = STATE_DIR / "innova.state.json"


def log(msg: str, level="INFO"):
    ts = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    prefix = {"INFO": "✅", "WARN": "⚠️ ", "ERROR": "❌"}.get(level, "•")
    print(f"{prefix} [{ts}] {msg}")


def check_url(url: str, timeout: int = 3) -> bool:
    try:
        urlopen(url, timeout=timeout)
        return True
    except (URLError, Exception):
        return False


def beat():
    now = datetime.now()
    ts = now.strftime("%Y-%m-%dT%H:%M:%S")
    date_str = now.strftime("%Y-%m-%d")

    # Check services
    oracle_ok = check_url("http://127.0.0.1:47778/api/health")
    ollama_ok = check_url("http://127.0.0.1:11434/api/tags")

    log(f"Oracle: {'ONLINE' if oracle_ok else 'offline'}", "INFO" if oracle_ok else "WARN")
    log(f"Ollama: {'ONLINE' if ollama_ok else 'offline'}", "INFO" if ollama_ok else "WARN")

    vitality = 42
    if oracle_ok:
        vitality += 20
    if ollama_ok:
        vitality += 15
    if (JIT_ROOT / ".github" / "skills" / "mind-body-bridge" / "SKILL.md").exists():
        vitality += 10
    if (JIT_ROOT / "ψ" / "contacts.json").exists():
        vitality += 5
    if (JIT_ROOT / ".github" / "skills" / "recap" / "SKILL.md").exists():
        vitality += 8

    log(f"Vitality: {vitality}%")

    # Update heartbeat.log
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    beat_line = f"[{ts}] host=PC0-Windows-Jit oracle={'yes' if oracle_ok else 'no'} ollama={'yes' if ollama_ok else 'no'} vitality={vitality}%\n"
    with open(HEARTBEAT_LOG, "a", encoding="utf-8") as f:
        f.write(beat_line)
    log("Heartbeat log updated")

    # Update innova.state.json
    if INNOVA_STATE.exists():
        with open(INNOVA_STATE, encoding="utf-8") as f:
            state = json.load(f)
        state.setdefault("vitality", {})["last_heartbeat"] = ts
        state["vitality"]["oracle_online"] = oracle_ok
        state["vitality"]["ollama_online"] = ollama_ok
        state["vitality"]["vitality_pct"] = vitality
        state["vitality"]["host"] = "PC0-Windows-Jit"
        # Increment pulse count
        count = state["vitality"].get("pulse_count", 0)
        state["vitality"]["pulse_count"] = count + 1
        with open(INNOVA_STATE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2, ensure_ascii=False)
        log("innova.state.json updated")

    # Git commit + push
    try:
        subprocess.run(
            ["git", "add", "memory/state/"],
            cwd=JIT_ROOT, capture_output=True, check=True
        )
        subprocess.run(
            ["git", "commit", "-m", f"💓 heartbeat {ts} vitality={vitality}% [auto]"],
            cwd=JIT_ROOT, capture_output=True, check=False  # may fail if nothing to commit
        )
        subprocess.run(
            ["git", "push", "--quiet"],
            cwd=JIT_ROOT, capture_output=True, check=False
        )
        log("Git state pushed")
    except Exception as e:
        log(f"Git push skipped: {e}", "WARN")

    return vitality


def status():
    if HEARTBEAT_LOG.exists():
        lines = HEARTBEAT_LOG.read_text(encoding="utf-8").strip().split("\n")
        last = lines[-1] if lines else "(no entries)"
        print(f"Last heartbeat: {last}")
    else:
        print("No heartbeat log found")
    if INNOVA_STATE.exists():
        state = json.load(open(INNOVA_STATE, encoding="utf-8"))
        v = state.get("vitality", {})
        print(f"Vitality: {v.get('vitality_pct', '?')}%  Oracle: {v.get('oracle_online')}  Ollama: {v.get('ollama_online')}")


def main():
    parser = argparse.ArgumentParser(description="Jit Heartbeat (Windows)")
    parser.add_argument("--daemon", action="store_true", help="Run every 15 minutes")
    parser.add_argument("--status", action="store_true", help="Show last heartbeat")
    parser.add_argument("--interval", type=int, default=900, help="Interval in seconds (default 900)")
    args = parser.parse_args()

    if args.status:
        status()
        return

    if args.daemon:
        log("Starting heartbeat daemon (every 15 min). Ctrl+C to stop.")
        while True:
            try:
                beat()
            except Exception as e:
                log(f"Heartbeat error: {e}", "ERROR")
            time.sleep(args.interval)
    else:
        beat()


if __name__ == "__main__":
    main()
