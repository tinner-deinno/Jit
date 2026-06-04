# Jit Mother Fleet Batch - 2026-06-04

## Result

Final hardened run:

- Artifact: `network/artifacts/fleet-batch-2026-06-03T19-28-50-993Z/summary.json`
- Count: 56 workers
- Completed: 56
- OK: 56
- Failed: 0
- Pending: 0
- Duration: 264810 ms

Provider split:

- `ollama_mdes`: 16/16 OK, model `gemma4:26b`, average 16659 ms
- `thaillm`: 15/15 OK, four ThaiLLM models, average 10501 ms
- `ollama_cloud`: 15/15 OK, models `gemma4:31b-cloud` and `nemotron-3-super:cloud`, average 9947 ms
- `copilot`: 10/10 OK, models `claude-sonnet-4.6` and default, average 48873 ms

## Retry Evidence

The hardened run recovered a real transient ThaiLLM failure:

- Worker id: 6
- Backend: `thaillm`
- Model: `pathumma-thaillm-qwen3-8b-think-3.0.0`
- Attempt 1: failed with `HTTP 502`
- Attempt 2: succeeded on `thaillm`

## Latest Probe After Run

`node mother.js probe --timeout 45000` after the full run produced:

- Usable: `ollama_mdes`, `ollama_cloud`, `thaillm`
- Degraded: `ollama_local` timeout, `copilot` quota exhausted, `openai` CLI error, `openclaude` refused, `innova_bot` in-band fallback error

`node mother.js doctor` still returned `OK with warnings` and no hard blockers.

## Discord Status

The fleet harness now sends Discord status directly through Node HTTP/HTTPS and no longer depends on the CRLF-sensitive Bash reporter.

Current `.env` has `DISCORD_TOKEN` set, but no `JIT_REPORT_CHANNEL_ID`, `DISCORD_CHANNEL_ID`, or `DISCORD_WEBHOOK_URL`, so fleet runs report `discordSent: false`. Add one report channel or webhook to enable the requested 10-minute Discord updates.

## Codex Proof Addendum - 2026-06-04T07:24Z

Command-level guardrails were added to `eval/fleet-batch.js`:

- `--lanes` selects explicit provider lanes.
- `--require-min-count` fails before provider calls if the built batch is too small.
- `--require-min-ok` fails the run unless enough workers return usable replies.
- Every run now writes `proof-manifest.json` and `proof-manifest.md` with command, git state, requirement verdict, lane split, and SHA-256 hashes for `summary.json` / `summary.md`.

Fresh proof run:

- Command: `node eval/fleet-batch.js --count 51 --concurrency 6 --attempts 2 --lanes ollama_mdes,thaillm,ollama_cloud --require-min-count 51 --require-min-ok 51`
- Artifact: `network/artifacts/fleet-batch-2026-06-04T07-19-36-869Z/proof-manifest.json`
- Log: `network/artifacts/fleet-proof-20260604-141936.log`
- Result: `51/51 OK`, `0` failed, `0` pending, duration `295963 ms`
- Requirement verdict: `count >= 51` pass, `ok >= 51` pass

Provider split:

- `ollama_mdes`: `19/19 OK`, model `gemma4:26b`, average `29422 ms`
- `thaillm`: `16/16 OK`, all four ThaiLLM models, average `8722 ms`
- `ollama_cloud`: `16/16 OK`, models `gemma4:31b-cloud` and `nemotron-3-super:cloud`, average `4238 ms`

Current live lane notes:

- `check-fleet --smoke` passed content calls for `ollama_mdes`, `thaillm`, `ollama_cloud`, and `openai`.
- `copilot` is currently configured but not content-usable: router smoke saw GitHub API `404`, and direct `gh copilot -p` returned `402 quota_exceeded`.
- `ollama_local` is reachable by tag list but content-smoke timed out.
- `openclaude` is configured but refused connection.

Coordination probes:

- `node eval/innova-bot-talk.js` passed: `mother.task -> innova` via File Fallback in `1645 ms`.
- `maw workspace status` ran and reported no configured workspaces.
- `maw ui status` no longer crashes after the UI plugin import fix; it now reports `maw-ui not installed`.
- `maw team status` remains blocked by CLI dispatch mismatch (`unknown command: team`) in this MAW install.

Discord note:

- The fleet harness attempted Discord reporting path but `discordSent: false` because no channel ID or webhook is configured.
