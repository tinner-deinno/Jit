<!-- cc-team deliverable
 group: G (Antigravity (agy) bridge: Node wrapper, bash limb, Claude Code skill, fusion patterns doc)
 member: G2 role=dev model=Qwen/Qwen3.7-Max
 finish_reason: stop | tokens: {"prompt_tokens":288,"completion_tokens":2941,"total_tokens":3229,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":2343,"image_tokens":0},"cache_creation_input_tokens":0} | 55s
 generated: 2026-06-12T17:52:42.520Z -->
#!/usr/bin/env bash
# สติมา ปัญญาเกิด : Mindfulness brings forth wisdom.
# มนุษย์ Agent - Limb/Organ: Antigravity
# Usage: antigravity.sh <subcommand> [args...]
#   ask "prompt" [model]  - One-shot query
#   think "prompt"        - Structured reasoning query
#   code "task" [dir]     - Code editing task (auto-approve)
#   models                - List available models
#   status                - Check agy binary status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="${SCRIPT_DIR}/.."

if [ -f "${SCRIPT_DIR}/lib.sh" ]; then
    source "${SCRIPT_DIR}/lib.sh"
fi

if [ -n "${LOCALAPPDATA}" ] && [ -x "${LOCALAPPDATA}/agy/bin/agy.exe" ]; then
    AGY_BIN="${LOCALAPPDATA}/agy/bin/agy.exe"
else
    AGY_BIN="agy"
fi

BRIDGE="${JIT_ROOT}/scripts/agy-bridge.js"

usage() {
    echo "Usage: $0 <subcommand> [args...]"
    echo "Subcommands: ask, think, code, models, status"
    exit 1
}

case "${1}" in
    ask)
        [ -z "${2}" ] && usage
        PROMPT="${2}"
        MODEL="${3:-}"
        if [ -n "${MODEL}" ]; then
            node "${BRIDGE}" --prompt "${PROMPT}" --model "${MODEL}" --json
        else
            node "${BRIDGE}" --prompt "${PROMPT}" --json
        fi
        ;;
    think)
        [ -z "${2}" ] && usage
        SYS="จงคิดอย่างมีโครงสร้างและใช้เหตุผลทีละขั้นตอน:"
        node "${BRIDGE}" --prompt "${SYS} ${2}" --json
        ;;
    code)
        [ -z "${2}" ] && usage
        echo "คำเตือน: โหมดอนุมัติอัตโนมัติ���ปิดอยู่ (Auto-approve is ON)"
        DIR="${3:-.}"
        node "${BRIDGE}" --prompt "${2}" --skip-permissions --cwd "${DIR}"
        ;;
    models)
        node "${BRIDGE}" --models
        ;;
    status)
        if command -v "${AGY_BIN}" >/dev/null 2>&1 || [ -x "${AGY_BIN}" ]; then
            "${AGY_BIN}" --version
        else
            echo "Error: agy binary not found."
            exit 1
        fi
        ;;
    *)
        usage
        ;;
esac
