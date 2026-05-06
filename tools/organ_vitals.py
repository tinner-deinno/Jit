#!/usr/bin/env python3
"""
organ_vitals — MCP tool for มนุษย์ Agent system.
Reports system vitals: CPU, RAM, disk. Usable as an MCP tool via stdin/stdout JSON-RPC.

Usage:
  python tools/organ_vitals.py                  # MCP server mode (stdin/stdout)
  python tools/organ_vitals.py --snapshot        # Print snapshot and exit
"""

import json
import sys
import os
import shutil
from datetime import datetime, timezone


def _vitals_snapshot() -> dict:
    """Collect current system vitals without external dependencies."""
    # CPU — use /proc/stat for a 0-cost single-sample estimate (Linux only)
    cpu_percent: float | None = None
    try:
        with open("/proc/stat") as f:
            line = f.readline()
        parts = line.split()
        idle = int(parts[4])
        total = sum(int(p) for p in parts[1:])
        # Store in a temp file to compute delta on next call
        state_path = "/tmp/_organ_vitals_cpu_state"
        if os.path.exists(state_path):
            with open(state_path) as f:
                prev_total, prev_idle = map(int, f.read().split())
            d_total = total - prev_total
            d_idle  = idle  - prev_idle
            cpu_percent = round(100 * (d_total - d_idle) / d_total, 1) if d_total else 0.0
        with open(state_path, "w") as f:
            f.write(f"{total} {idle}")
    except Exception:
        pass

    # RAM — /proc/meminfo
    ram: dict = {}
    try:
        mem = {}
        with open("/proc/meminfo") as f:
            for line in f:
                k, v = line.split(":", 1)
                mem[k.strip()] = int(v.split()[0])
        total_kb  = mem.get("MemTotal", 0)
        avail_kb  = mem.get("MemAvailable", 0)
        used_kb   = total_kb - avail_kb
        ram = {
            "total_mb":  round(total_kb / 1024, 1),
            "used_mb":   round(used_kb  / 1024, 1),
            "free_mb":   round(avail_kb / 1024, 1),
            "percent":   round(100 * used_kb / total_kb, 1) if total_kb else 0.0,
        }
    except Exception:
        pass

    # Disk — shutil works everywhere
    disk: dict = {}
    try:
        usage = shutil.disk_usage("/workspaces")
        disk = {
            "total_gb": round(usage.total / 1e9, 2),
            "used_gb":  round(usage.used  / 1e9, 2),
            "free_gb":  round(usage.free  / 1e9, 2),
            "percent":  round(100 * usage.used / usage.total, 1),
        }
    except Exception:
        pass

    return {
        "agent":     "netra",
        "organ":     "eye",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "cpu_percent":  cpu_percent,
        "ram":  ram,
        "disk": disk,
        "node": os.environ.get("INNOVA_NODE_ID", "unknown"),
    }


# ── MCP JSON-RPC 2.0 server (stdio transport) ─────────────────────

def _send(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def _handle(req: dict) -> dict | None:
    rpc_id = req.get("id")
    method = req.get("method", "")

    if method == "initialize":
        return {
            "jsonrpc": "2.0", "id": rpc_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "organ_vitals", "version": "1.0.0"},
            },
        }

    if method == "tools/list":
        return {
            "jsonrpc": "2.0", "id": rpc_id,
            "result": {
                "tools": [{
                    "name": "get_vitals",
                    "description": "Returns current CPU, RAM, and disk usage for this Jit node.",
                    "inputSchema": {
                        "type": "object",
                        "properties": {},
                        "required": [],
                    },
                }],
            },
        }

    if method == "tools/call":
        tool_name = (req.get("params") or {}).get("name", "")
        if tool_name == "get_vitals":
            snapshot = _vitals_snapshot()
            return {
                "jsonrpc": "2.0", "id": rpc_id,
                "result": {
                    "content": [{
                        "type": "text",
                        "text": json.dumps(snapshot, ensure_ascii=False, indent=2),
                    }],
                    "isError": False,
                },
            }
        return {
            "jsonrpc": "2.0", "id": rpc_id,
            "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"},
        }

    if method == "notifications/initialized":
        return None  # notification, no response

    return {
        "jsonrpc": "2.0", "id": rpc_id,
        "error": {"code": -32601, "message": f"Method not found: {method}"},
    }


def run_mcp_server() -> None:
    """MCP stdio server loop."""
    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        try:
            req = json.loads(raw)
        except json.JSONDecodeError as e:
            _send({"jsonrpc": "2.0", "id": None,
                   "error": {"code": -32700, "message": f"Parse error: {e}"}})
            continue
        resp = _handle(req)
        if resp is not None:
            _send(resp)


if __name__ == "__main__":
    if "--snapshot" in sys.argv:
        print(json.dumps(_vitals_snapshot(), ensure_ascii=False, indent=2))
    else:
        run_mcp_server()
