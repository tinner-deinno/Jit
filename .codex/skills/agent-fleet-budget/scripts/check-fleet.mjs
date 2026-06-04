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

function isErrorReply(text) {
  const t = String(text || "").trim();
  if (!t) return true;
  return /(system override|query failed|unavailable|not available|backend (failed|error)|i (cannot|can't|am unable)|^error\b|:\s*error|\bnot ok\b)/i.test(t);
}

function isUsableProbeReply(text, backend) {
  const t = String(text || "").trim();
  if (isErrorReply(t)) return false;
  const name = String(backend || "").replace(/[_-]/g, "[_-]?");
  return /\bok\b/i.test(t) || (name && new RegExp(name, "i").test(t));
}

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
            let parsedJson = null;
            try {
              parsedJson = JSON.parse(body);
            } catch {}
            resolve({
              ok: response.statusCode >= 200 && response.statusCode < 300,
              status: response.statusCode ?? 0,
              body: body.slice(0, 400),
              json: parsedJson,
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

function requestPostJson(targetUrl, headers = {}, body = {}, timeoutMs = 15000) {
  return new Promise((resolve) => {
    try {
      const parsed = new URL(targetUrl);
      const transport = parsed.protocol === "https:" ? https : http;
      const bodyText = JSON.stringify(body);
      const request = transport.request(
        parsed,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Content-Length": Buffer.byteLength(bodyText),
            ...headers,
          },
          timeout: timeoutMs,
        },
        (response) => {
          let responseBody = "";
          response.on("data", (chunk) => {
            responseBody += chunk;
          });
          response.on("end", () => {
            let parsedJson = null;
            try {
              parsedJson = JSON.parse(responseBody);
            } catch {}
            resolve({
              ok: response.statusCode >= 200 && response.statusCode < 300,
              status: response.statusCode ?? 0,
              body: responseBody.slice(0, 400),
              json: parsedJson,
            });
          });
        }
      );
      request.on("error", (error) => resolve({ ok: false, status: 0, error: error.message }));
      request.on("timeout", () => {
        request.destroy(new Error("timeout"));
      });
      request.write(bodyText);
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
  if (!url) return { ok: false, status: 0, error: "missing url" };
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  const probe = await requestJson(`${url.replace(/\/$/, "")}/api/tags`, headers);
  const models = Array.isArray(probe.json?.models)
    ? probe.json.models.map((model) => String(model.name || model.model || "")).filter(Boolean)
    : [];
  delete probe.json;
  if (models.length) probe.models = models.slice(0, 80);
  return probe;
}

function normalizeThaiLLMBaseUrl(url) {
  const value = String(url || "").trim().replace(/\/+$/, "");
  return (value || "http://thaillm.or.th/api")
    .replace(/\/v1\/chat\/completions$/i, "")
    .replace(/\/chat\/completions$/i, "");
}

async function probeThaiLLM(url, token, model) {
  const baseUrl = normalizeThaiLLMBaseUrl(url);
  if (!token) return { ok: false, status: 0, error: "missing token", baseUrl };
  const headers = { Authorization: `Bearer ${token}` };
  const modelsProbe = await requestJson(`${baseUrl}/v1/models`, headers, 8000);
  const models = Array.isArray(modelsProbe.json?.data)
    ? modelsProbe.json.data.map((item) => String(item.id || item.model || "")).filter(Boolean)
    : [];
  if (modelsProbe.ok) {
    const out = { ...modelsProbe, baseUrl };
    delete out.json;
    if (models.length) out.models = models.slice(0, 80);
    return out;
  }

  const chatProbe = await requestPostJson(
    `${baseUrl}/v1/chat/completions`,
    headers,
    {
      model: model || "openthaigpt-thaillm-8b-instruct-v7.2",
      messages: [{ role: "user", content: "Reply exactly: OK thaillm" }],
      max_tokens: 32,
      temperature: 0.1,
    },
    20000
  );
  const out = { ...chatProbe, baseUrl };
  delete out.json;
  return out;
}

async function probeFirstStatus(urls, headers = {}, timeoutMs = 5000) {
  let last = null;
  for (const targetUrl of urls.filter(Boolean)) {
    const probe = await requestStatus(targetUrl, headers, timeoutMs);
    const withUrl = { ...probe, url: targetUrl };
    if (probe.ok) return withUrl;
    last = withUrl;
  }
  return last || { ok: false, status: 0, error: "no urls" };
}

function cloudModelAliases(model) {
  const value = String(model || "").trim();
  const aliases = new Set([value]);
  if (value.endsWith("-cloud")) aliases.add(value.slice(0, -"-cloud".length));
  return Array.from(aliases).filter(Boolean);
}

async function main() {
  const status = modelRouter.status();
  const backends = status.backends || {};
  const targetCloudModel = process.env.JIT_CLOUD_MODEL || backends.ollama_cloud?.targetModel || backends.ollama_cloud?.model || "gemma4:31b-cloud";
  const innovaSseUrls = Array.from(
    new Set([process.env.INNOVA_BOT_SSE_URL || "http://127.0.0.1:7010/sse", "http://127.0.0.1:7012/sse"])
  );

  const probes = {
    ollama_mdes: await probeOllama(backends.ollama_mdes?.url, process.env.OLLAMA_MDES_TOKEN || process.env.OLLAMA_TOKEN || ""),
    thaillm: await probeThaiLLM(backends.thaillm?.url, process.env.THAILLM_TOKEN || "", backends.thaillm?.model),
    ollama_local: await probeOllama(backends.ollama_local?.url, process.env.OLLAMA_LOCAL_TOKEN || ""),
    ollama_cloud: await probeOllama(backends.ollama_cloud?.url, process.env.OLLAMA_CLOUD_TOKEN || ""),
    openclaude: await requestStatus(
      backends.openclaude?.healthEndpoint || `http://${backends.openclaude?.host || "localhost"}:${Number(backends.openclaude?.port || 8000)}/health`
    ),
    innova_bot_sse: await probeFirstStatus(innovaSseUrls),
  };
  if (Array.isArray(probes.ollama_cloud.models)) {
    const aliases = cloudModelAliases(targetCloudModel);
    probes.ollama_cloud.targetModel = targetCloudModel;
    probes.ollama_cloud.targetModelAliases = aliases;
    probes.ollama_cloud.targetModelPresent = probes.ollama_cloud.models.some((model) => aliases.includes(model));
  } else {
    probes.ollama_cloud.targetModel = targetCloudModel;
    probes.ollama_cloud.targetModelAliases = cloudModelAliases(targetCloudModel);
    probes.ollama_cloud.targetModelPresent = null;
  }

  const summarize = (name, configured, probe, options = {}) => {
    const targetModelMissing = Boolean(options.requireTargetModel && probe?.targetModelPresent === false);
    const state = !configured
      ? "offline"
      : probe?.ok && !targetModelMissing
      ? "ready"
      : probe?.status === 401 || probe?.status === 403 || probe?.status === 429
      ? "degraded"
      : "degraded";
    return {
      state,
      probe,
      configured,
      reachable: Boolean(probe?.ok),
      usable: state === "ready",
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
      ollama_cloud: summarize("ollama_cloud", Boolean(backends.ollama_cloud?.available), probes.ollama_cloud, { requireTargetModel: true }),
      copilot: {
        state: backends.copilot?.available ? "configured" : "offline",
        details: backends.copilot,
      },
      openai: {
        state: backends.openai?.available ? "configured" : "offline",
        details: backends.openai,
      },
      openclaude: summarize("openclaude", Boolean(backends.openclaude?.configured ?? backends.openclaude?.available), probes.openclaude),
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
          ok: isUsableProbeReply(result.reply, backend),
          usedBackend: result.backend,
          latencyMs: Date.now() - startedAt,
          reply: String(result.reply || "").slice(0, 120),
          contentUsable: isUsableProbeReply(result.reply, backend),
          ...(isUsableProbeReply(result.reply, backend) ? {} : { error: "non-usable probe reply" }),
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
    for (const model of backends.thaillm?.models || []) {
      const startedAt = Date.now();
      try {
        const result = await modelRouter.callModelPromise(
          [{ role: "user", content: `Reply with exactly: OK thaillm ${model}` }],
          { preferBackend: "thaillm", model, noRotate: true }
        );
        smokeResults.push({
          backend: "thaillm",
          model,
          ok: isUsableProbeReply(result.reply, "thaillm"),
          usedBackend: result.backend,
          latencyMs: Date.now() - startedAt,
          reply: String(result.reply || "").slice(0, 120),
          contentUsable: isUsableProbeReply(result.reply, "thaillm"),
          ...(isUsableProbeReply(result.reply, "thaillm") ? {} : { error: "non-usable probe reply" }),
        });
      } catch (error) {
        smokeResults.push({
          backend: "thaillm",
          model,
          ok: false,
          latencyMs: Date.now() - startedAt,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
    report.smoke = smokeResults;
    report.contentUsableBackends = Array.from(
      new Set(smokeResults.filter((item) => item.contentUsable && item.usedBackend === item.backend).map((item) => item.backend))
    );
  }

  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error instanceof Error ? error.message : String(error) }, null, 2));
  process.exit(1);
});
