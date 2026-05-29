#!/usr/bin/env node

import http from "node:http";
import https from "node:https";
import net from "node:net";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const jitRoot = path.resolve(__dirname, "../../../..");
const modelRouter = await import(pathToFileURL(path.join(jitRoot, "hermes-discord", "model-router.js")).href);
const smokeMode = process.argv.includes("--smoke");

function requestJson(targetUrl, headers = {}, timeoutMs = 5000) {
  return new Promise((resolve) => {
    try {
      const parsed = new URL(targetUrl);
      const transport = parsed.protocol === "https:" ? https : http;
      const request = transport.request(
        parsed,
        {
          method: "GET",
          headers,
          timeout: timeoutMs,
        },
        (response) => {
          let body = "";
          response.on("data", (chunk) => {
            body += chunk;
          });
          response.on("end", () => {
            resolve({
              ok: response.statusCode >= 200 && response.statusCode < 300,
              status: response.statusCode ?? 0,
              body: body.slice(0, 400),
            });
          });
        }
      );
      request.on("error", (error) => resolve({ ok: false, status: 0, error: error.message }));
      request.on("timeout", () => {
        request.destroy(new Error("timeout"));
      });
      request.end();
    } catch (error) {
      resolve({ ok: false, status: 0, error: error instanceof Error ? error.message : String(error) });
    }
  });
}

function requestStatus(targetUrl, headers = {}, timeoutMs = 5000) {
  return new Promise((resolve) => {
    try {
      const parsed = new URL(targetUrl);
      const transport = parsed.protocol === "https:" ? https : http;
      const request = transport.request(
        parsed,
        {
          method: "GET",
          headers,
          timeout: timeoutMs,
        },
        (response) => {
          resolve({
            ok: (response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300,
            status: response.statusCode ?? 0,
            contentType: response.headers["content-type"] ?? "",
          });
          response.destroy();
        }
      );
      request.on("error", (error) => resolve({ ok: false, status: 0, error: error.message }));
      request.on("timeout", () => {
        request.destroy(new Error("timeout"));
      });
      request.end();
    } catch (error) {
      resolve({ ok: false, status: 0, error: error instanceof Error ? error.message : String(error) });
    }
  });
}

function checkTcp(host, port, timeoutMs = 2500) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    let done = false;

    const finish = (result) => {
      if (done) return;
      done = true;
      socket.destroy();
      resolve(result);
    };

    socket.setTimeout(timeoutMs);
    socket.once("connect", () => finish({ ok: true }));
    socket.once("timeout", () => finish({ ok: false, error: "timeout" }));
    socket.once("error", (error) => finish({ ok: false, error: error.message }));
    socket.connect(port, host);
  });
}

async function probeOllama(url, token) {
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  return requestJson(`${url.replace(/\/$/, "")}/api/tags`, headers);
}

async function main() {
  const status = modelRouter.status();
  const backends = status.backends || {};

  const probes = {
    ollama_mdes: await probeOllama(backends.ollama_mdes?.url, process.env.OLLAMA_MDES_TOKEN || process.env.OLLAMA_TOKEN || ""),
    thaillm: await probeOllama(backends.thaillm?.url, process.env.THAILLM_TOKEN || process.env.OLLAMA_TOKEN || ""),
    ollama_local: await probeOllama(backends.ollama_local?.url, process.env.OLLAMA_LOCAL_TOKEN || ""),
    ollama_cloud: await probeOllama(backends.ollama_cloud?.url, process.env.OLLAMA_CLOUD_TOKEN || ""),
    openclaude: await checkTcp(backends.openclaude?.host || "localhost", Number(backends.openclaude?.port || 8000)),
    innova_bot_sse: await requestStatus("http://127.0.0.1:7010/sse"),
  };

  const summarize = (name, configured, probe) => {
    const state = !configured
      ? "offline"
      : probe?.ok
      ? "ready"
      : probe?.status === 401 || probe?.status === 403 || probe?.status === 429
      ? "degraded"
      : "degraded";
    return {
      state,
      probe,
      configured,
    };
  };

  const report = {
    generatedAt: new Date().toISOString(),
    primary: status.primary,
    order: status.order,
    lanes: {
      ollama_mdes: summarize("ollama_mdes", Boolean(backends.ollama_mdes?.available), probes.ollama_mdes),
      thaillm: summarize("thaillm", Boolean(backends.thaillm?.available), probes.thaillm),
      ollama_local: summarize("ollama_local", Boolean(backends.ollama_local?.available), probes.ollama_local),
      ollama_cloud: summarize("ollama_cloud", Boolean(backends.ollama_cloud?.available), probes.ollama_cloud),
      copilot: {
        state: backends.copilot?.available ? "configured" : "offline",
        details: backends.copilot,
      },
      openai: {
        state: backends.openai?.available ? "configured" : "offline",
        details: backends.openai,
      },
      openclaude: summarize("openclaude", Boolean(backends.openclaude?.available), probes.openclaude),
      innova_bot_sse: summarize("innova_bot_sse", true, probes.innova_bot_sse),
    },
  };

  if (smokeMode) {
    const smokeBackends = ["ollama_mdes", "thaillm", "ollama_local", "ollama_cloud", "copilot", "openai", "openclaude"];
    const smokeResults = [];
    for (const backend of smokeBackends) {
      const startedAt = Date.now();
      try {
        const result = await modelRouter.callModelPromise(
          [{ role: "user", content: `Reply with exactly: OK ${backend}` }],
          { preferBackend: backend, noRotate: true }
        );
        smokeResults.push({
          backend,
          ok: true,
          usedBackend: result.backend,
          latencyMs: Date.now() - startedAt,
          reply: String(result.reply || "").slice(0, 120),
        });
      } catch (error) {
        smokeResults.push({
          backend,
          ok: false,
          latencyMs: Date.now() - startedAt,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
    report.smoke = smokeResults;
  }

  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error instanceof Error ? error.message : String(error) }, null, 2));
  process.exit(1);
});
