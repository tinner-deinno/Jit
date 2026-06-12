<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: C03 role=dev model=commandcode/deepseek/deepseek-v4-flash
 finish_reason: end_turn | tokens: {"prompt_tokens":196,"completion_tokens":1117,"total_tokens":1313} | 12s
 generated: 2026-06-12T19:33:21.153Z -->
#!/bin/bash
# Claude Code Stop hook: batch type-check edited .ts/.tsx files
# Place in .claude/hooks/stop-format-typecheck.sh
# Configure in settings.json: "hooks": { "Stop": ".claude/hooks/stop-format-typecheck.sh" }
# Reads accumulated paths from $TMPDIR/jit-edited-files (written by post-edit step)
# Runs tsc --noEmit in each package directory containing edited files; exits 2 on failure.

# Cross-platform temp directory
TMPDIR="${TMPDIR:-${TEMP:-/tmp}}"
EDITED_FILE="$TMPDIR/jit-edited-files"

# Skip if no edited files recorded
if [ ! -s "$EDITED_FILE" ]; then
    exit 0
fi

# Collect unique directories from .ts/.tsx files
declare -A dirs
while IFS= read -r file; do
    case "${file,,}" in
        *.ts|*.tsx)
            dir=$(dirname "$file")
            dirs["$dir"]=1
            ;;
    esac
done < "$EDITED_FILE"

if [ ${#dirs[@]} -eq 0 ]; then
    exit 0
fi

# Clear edited file to avoid re-processing (post-edit will recreate on next change)
> "$EDITED_FILE"

# Run tsc in each directory
failure=0
for dir in "${!dirs[@]}"; do
    # Skip if no tsconfig.json in directory or any parent (simple check: require in dir)
    if [ ! -f "$dir/tsconfig.json" ]; then
        continue
    fi

    if ! (cd "$dir" && tsc --noEmit); then
        echo "TypeScript errors in $dir"
        failure=1
    fi
done

if [ "$failure" -eq 1 ]; then
    exit 2
fi
exit 0
