<!-- cc-team deliverable
 group: U (innomcp UI debug wave — central backend URL helper, fix broken fetches, hide test creds, VQA regression spec)
 member: U1 role=dev model=deepseek/deepseek-v4-pro
 finish_reason: stop | tokens: {"prompt_tokens":286,"completion_tokens":2123,"total_tokens":2409,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":1866,"image_tokens":0},"cache_creation_input_tokens":0} | 44s
 generated: 2026-06-12T08:54:18.913Z -->
// Centralized backend URL resolution replacing scattered hardcoded 'http://localhost:3011' fallbacks.
export const BACKEND: string = (() => {
  const envUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  if (envUrl && envUrl.trim() !== "") return envUrl.trim();
  if (typeof window !== "undefined" && window.location.port === "3000") return "http://localhost:3015";
  return "";
})();

export const WS_BACKEND: string = (() => {
  const wsUrl = process.env.NEXT_PUBLIC_WS_URL;
  if (wsUrl && wsUrl.trim() !== "") return wsUrl.trim();
  if (!BACKEND) return "";
  return BACKEND.replace(/^http(s)?:\/\//, (_, s) => `ws${s ? "s" : ""}://`);
})();

export function backendFetch(path: string, init?: RequestInit): Promise<Response> {
  const headers = new Headers(init?.headers);
  const fetchInit: RequestInit = {
    ...init,
    credentials: "include",
    headers,
  };
  return fetch(BACKEND + path, fetchInit);
}
