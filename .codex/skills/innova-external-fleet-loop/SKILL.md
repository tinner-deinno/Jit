# innova-external-fleet-loop

Run the Jit Mother loop as an external-first, budget-aware fleet with visual proof and innova-bot coordination.

Use this when:
- `innomcp` or `innova-bot` work needs a long-running Mother loop
- you want `80+` honest worker identities without making GPT-5.5 the main worker lane
- you need progress packets to `innova-bot` plus browser-based proof from Playwright and chrome-tools

## Default posture

- Parent controller stays in Codex/Jit.
- Worker lanes prefer `ollama_mdes` and `thaillm`.
- `ollama_cloud`, `copilot`, and `openai` stay fallback/advisor lanes.
- `innova-bot` is a coordination bridge by default, not a main worker lane.

## Command flow

1. Refresh live fleet health:

```powershell
node .codex/skills/agent-fleet-budget/scripts/check-fleet.mjs --smoke
```

2. Verify the GUI eye is alive:

```powershell
node eval/visual-probe.js --url http://127.0.0.1:7010/gui --run-id visual-smoke
```

3. Run a one-shot proof cycle:

```powershell
node eval/innova-loop-controller.js --once --interval-ms 240000 --count 84 --concurrency 8 --advisor-threshold 8 --fleet-attempts 1 --fleet-worker-timeout-ms 45000 --visual-every 1
```

4. Start the long-running loop:

```powershell
powershell -File scripts/start-innova-loop.ps1 -IntervalSeconds 240 -Count 84 -Concurrency 8 -AdvisorThreshold 8 -MaxHours 5
powershell -File scripts/start-innova-talk-loop.ps1 -IntervalSeconds 240 -MaxHours 5
```

## Evidence to check

- `network/loop/latest-report.json`
- `network/loop/latest-fleet-progress.json`
- `network/loop/latest-visual.json`
- `network/artifacts/fleet-batch-*/`
- `network/artifacts/visual-cycle-*/`

## Pass criteria

- `84/84` workers complete with at least `75%` OK; target is `100%`
- partial progress messages reach `innova-bot`
- visual probe returns HTTP `200` with screenshot and devtools analysis
- provider mix stays external-first unless a cheaper lane is degraded
