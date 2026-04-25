#!/usr/bin/env bun
// voice/server.ts — Bun HTTP server: voice bridge between browser and Claude TUI
//
// GET  /         → serve voice/public/index.html
// POST /speak    → inject transcript text into Claude pane via tmux (no Enter)
// GET  /status   → return current claude pane target
//
// Voice flow:
//   Browser mic → Web Speech API → POST /speak → tmux send-keys → Claude TUI

import { join } from "path"

const PORT = parseInt(process.env.VOICE_PORT || "3333")
const JIT_ROOT = process.env.JIT_ROOT || "/workspaces/Jit"
const PUBLIC_DIR = join(JIT_ROOT, "voice", "public")
const PANE_FILE = "/tmp/claude-pane.txt"

// ─── Read claude pane target ────────────────────────────────────────────
async function readPane(): Promise<string | null> {
  try {
    const content = await Bun.file(PANE_FILE).text()
    const pane = content.trim()
    return pane || null
  } catch {
    return null
  }
}

// ─── Inject text into tmux pane (no Enter key) ─────────────────────────
function injectToPane(pane: string, text: string): { ok: boolean; error?: string } {
  const result = Bun.spawnSync(["tmux", "send-keys", "-t", pane, text, ""])
  if (result.exitCode === 0) {
    return { ok: true }
  }
  const stderr = result.stderr ? new TextDecoder().decode(result.stderr) : "unknown error"
  return { ok: false, error: stderr.trim() }
}

// ─── CORS headers for Codespace browser access ──────────────────────────
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
}

// ─── Server ─────────────────────────────────────────────────────────────
const server = Bun.serve({
  port: PORT,
  hostname: "0.0.0.0",

  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url)

    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS })
    }

    // GET / → serve index.html
    if (req.method === "GET" && url.pathname === "/") {
      try {
        const file = Bun.file(join(PUBLIC_DIR, "index.html"))
        return new Response(file, {
          headers: {
            "Content-Type": "text/html; charset=utf-8",
            ...CORS_HEADERS,
          },
        })
      } catch {
        return new Response("index.html not found", { status: 404, headers: CORS_HEADERS })
      }
    }

    // GET /status → current pane info
    if (req.method === "GET" && url.pathname === "/status") {
      const pane = await readPane()
      return Response.json(
        {
          ok: true,
          pane,
          paneFile: PANE_FILE,
          server: "innova-voice",
          port: PORT,
          jitRoot: JIT_ROOT,
        },
        { headers: CORS_HEADERS }
      )
    }

    // POST /speak → inject into claude pane
    if (req.method === "POST" && url.pathname === "/speak") {
      let body: { text?: string }
      try {
        body = await req.json()
      } catch {
        return Response.json(
          { ok: false, error: "invalid JSON" },
          { status: 400, headers: CORS_HEADERS }
        )
      }

      const text = body?.text?.trim()
      if (!text) {
        return Response.json(
          { ok: false, error: "text is required and must not be empty" },
          { status: 400, headers: CORS_HEADERS }
        )
      }

      const pane = await readPane()
      if (!pane) {
        return Response.json(
          {
            ok: false,
            error: `claude pane target not found. Run innova-startup.sh first. (looking in ${PANE_FILE})`,
          },
          { status: 503, headers: CORS_HEADERS }
        )
      }

      const result = injectToPane(pane, text)
      if (result.ok) {
        console.log(`[voice] injected ${text.length} chars → pane ${pane}: "${text.substring(0, 60)}${text.length > 60 ? "..." : ""}"`)
        return Response.json(
          { ok: true, pane, injected: text, length: text.length },
          { headers: CORS_HEADERS }
        )
      } else {
        console.error(`[voice] tmux error: ${result.error}`)
        return Response.json(
          { ok: false, error: result.error },
          { status: 500, headers: CORS_HEADERS }
        )
      }
    }

    return new Response("Not Found", { status: 404, headers: CORS_HEADERS })
  },

  error(err: Error): Response {
    console.error("[voice] server error:", err)
    return new Response("Internal Server Error", { status: 500, headers: CORS_HEADERS })
  },
})

;(async () => {
  const pane = await readPane()
  console.log(`🎤 innova Voice Server`)
  console.log(`   Port:     ${server.port}`)
  console.log(`   Public:   ${PUBLIC_DIR}`)
  console.log(`   Pane:     ${pane || "(not set — run innova-startup.sh)"}`)
  console.log(`   Routes:   GET / | POST /speak | GET /status`)
  console.log(``)
  console.log(`   Open browser at: http://localhost:${server.port}`)
  console.log(`   (Codespace: forward port ${server.port} then open PORTS tab URL)`)
})()
