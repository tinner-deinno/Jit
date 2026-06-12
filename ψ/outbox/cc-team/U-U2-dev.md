<!-- cc-team deliverable
 group: U (innomcp UI debug wave — central backend URL helper, fix broken fetches, hide test creds, VQA regression spec)
 member: U2 role=dev model=Qwen/Qwen3.7-Max
 finish_reason: stop | tokens: {"prompt_tokens":416,"completion_tokens":1915,"total_tokens":2331,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":1742,"image_tokens":0},"cache_creation_input_tokens":0} | 38s
 generated: 2026-06-12T08:54:13.596Z -->
IMPORT:
import { BACKEND } from "../../lib/backendUrl";
BLOCK-A-NEW:
      const response = await fetch(`${BACKEND}/api/projects`, {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: trimmed }),
      }).catch(() => null);
BLOCK-B-NEW:
    fetch(`${BACKEND}/api/projects`, { credentials: "include" })
      .then((response) => (response.ok ? response.json() : null))
BLOCK-C-NEW:
    fetch(`${BACKEND}/api/tasks?limit=8`, { credentials: "include" })
      .then((r) => (r.ok ? r.json() : null))
