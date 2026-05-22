#!/usr/bin/env bun
// voice/server.ts — Bun HTTP server: Jit voice + command bridge
//
// GET  /          → serve voice/public/index.html (Jit Command Center UI)
// POST /command   → voice AI pipeline: text → minds/jit-voice.sh → {action, response_th}
// GET  /monitor   → SSE stream of life-loop synthesized blood status (every 5s)
// POST /speak     → (legacy) inject text into tmux Claude pane
// GET  /status    → server info + JIT_ROOT
//
// Voice flow:
//   Browser mic → Web Speech API → POST /command → jit-voice.sh → TTS response

import { join } from "path"

const PORT = parseInt(process.env.VOICE_PORT || "3333")
// Resolve JIT_ROOT: env var → parent of this file's directory (voice/ → Jit/)
const JIT_ROOT = process.env.JIT_ROOT
  || join(import.meta.dir, "..")
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

    // POST /command → voice AI pipeline (minds/jit-voice.sh)
    if (req.method === "POST" && url.pathname === "/command") {
      let body: { text?: string }
      try {
        body = await req.json()
      } catch {
        return Response.json({ ok: false, error: "invalid JSON" }, { status: 400, headers: CORS_HEADERS })
      }

      const text = body?.text?.trim()
      if (!text) {
        return Response.json({ ok: false, error: "text required" }, { status: 400, headers: CORS_HEADERS })
      }

      const scriptPath = join(JIT_ROOT, "minds", "jit-voice.sh")
      // Verify script exists before spawning (use .exists() — .size is a property, not a method)
      let scriptExists = false
      try { scriptExists = await Bun.file(scriptPath).exists() } catch { scriptExists = false }
      if (!scriptExists) {
        console.error(`[cmd] script not found: ${scriptPath}`)
        return Response.json(
          { ok: false, error: `jit-voice.sh not found at ${scriptPath}. Check JIT_ROOT env var.` },
          { status: 500, headers: CORS_HEADERS }
        )
      }

      const proc = Bun.spawnSync(
        ["bash", scriptPath, "process", text],
        { timeout: 80_000, env: { ...process.env, JIT_ROOT } }  // 80s: mdes 20s + local 15s + overhead
      )
      const stdout = proc.stdout ? new TextDecoder().decode(proc.stdout).trim() : ""
      const stderr = proc.stderr ? new TextDecoder().decode(proc.stderr).trim() : ""

      // Surface real errors (exit code check)
      if (proc.exitCode !== 0 && !stdout) {
        console.error(`[cmd] script failed (exit ${proc.exitCode}) | ${stderr.substring(0, 200)}`)
        return Response.json(
          { ok: false, error: `voice processor failed (exit ${proc.exitCode}): ${stderr.substring(0, 120)}` },
          { status: 500, headers: CORS_HEADERS }
        )
      }

      try {
        const data = JSON.parse(stdout)
        console.log(`[cmd] "${text.substring(0, 40)}" → ${data.action} "${(data.response_th || "").substring(0, 50)}"`)
        return Response.json({ ok: true, ...data }, { headers: CORS_HEADERS })
      } catch {
        console.error(`[cmd] JSON parse error | exitCode=${proc.exitCode} | stderr: ${stderr.substring(0, 120)} | stdout: ${stdout.substring(0, 120)}`)
        return Response.json(
          { ok: false, error: `voice processor output not valid JSON. stderr: ${stderr.substring(0, 100)}` },
          { status: 500, headers: CORS_HEADERS }
        )
      }
    }

    // GET /monitor → SSE stream of life-loop synthesized status (every 5s)
    if (req.method === "GET" && url.pathname === "/monitor") {
      const synthesizedPath = "/tmp/manusat-blood/synthesized.json"
      let closed = false
      const encoder = new TextEncoder()

      const stream = new ReadableStream({
        async start(controller) {
          const send = (data: unknown): void => {
            if (closed) return
            try {
              controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`))
            } catch {
              closed = true
            }
          }

          // Initial handshake
          send({ status: "connected", ts: new Date().toISOString() })

          while (!closed) {
            await Bun.sleep(5000)
            if (closed) break
            try {
              const content = await Bun.file(synthesizedPath).text()
              const data = JSON.parse(content)
              send({ status: "ok", ...data })
            } catch {
              send({ status: "waiting", ts: new Date().toISOString() })
            }
          }
        },
        cancel() {
          closed = true
        },
      })

      return new Response(stream, {
        headers: {
          ...CORS_HEADERS,
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          Connection: "keep-alive",
        },
      })
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
  console.log(`   Routes:   GET / | POST /speak | GET /status | POST /command | GET /monitor`)
  console.log(`   Voice AI: ${JIT_ROOT}/minds/jit-voice.sh`)
  console.log(``)
  console.log(`   Open browser at: http://localhost:${server.port}`)
  console.log(`   (Codespace: forward port ${server.port} then open PORTS tab URL)`)
})()
