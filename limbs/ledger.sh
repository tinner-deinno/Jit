#!/bin/bash

# Jit Versioned State Ledger
# Implements an immutable, versioned ledger for shared state.
# Path: /workspaces/Jit/limbs/ledger.sh

set -e

LEDGER_ROOT="/workspaces/Jit/memory/ledger"
SNAPSHOTS_DIR="$LEDGER_ROOT/snapshots"
META_DIR="$LEDGER_ROOT/meta"
HEAD_FILE="$META_DIR/HEAD"
LOCK_FILE="$META_DIR/ledger.lock"

# --- Internal Helpers ---

acquire_lock() {
    local timeout=5
    local start_time=$(date +%s)
    while [ ! -f "$LOCK_FILE" ]; do
        # Lock exists
        sleep 0.1
        if [ $(( $(date +%s) - start_time )) -gt $timeout ]; then
            echo "Error: Could not acquire lock after ${timeout}s" >&2
            exit 1
        fi
    done
    # This is a simple lock; for true production we'd use flock,
    # but in this environment we'll use a lock file.
    touch "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# --- Commands ---

commit() {
    local content="$1"
    if [ -z "$content" ]; then
        echo "Usage: ledger commit '<json_content>'"
        exit 1
    fi

    acquire_lock

    # Generate Version ID: timestamp + short random hash
    local timestamp=$(date +%Y%m%d%H%M%S)
    local rand_hash=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)
    local version_id="${timestamp}_${rand_hash}"
    local snapshot_path="$SNAPSHOTS_DIR/$version_id.json"

    # Atomic write: write to tmp then move
    local tmp_file="${snapshot_path}.tmp"
    echo "$content" > "$tmp_file"
    mv "$tmp_file" "$snapshot_path"

    # Update HEAD
    echo "$version_id" > "$HEAD_FILE"

    release_lock
    echo "Committed version: $version_id"
}

checkout() {
    local version_id="$1"
    if [ -z "$version_id" ]; then
        echo "Usage: ledger checkout <version_id>"
        echo "If no version provided, showing HEAD"
        version_id=$(cat "$HEAD_FILE" 2>/dev/null || echo "")
    fi

    if [ -z "$version_id" ]; then
        echo "Error: No versions available."
        exit 1
    fi

    local snapshot_path="$SNAPSHOTS_DIR/$version_id.json"
    if [ ! -f "$snapshot_path" ]; then
        echo "Error: Version $version_id not found."
        exit 1
    fi

    cat "$snapshot_path"
}

log() {
    echo "Version ID | Timestamp | Size"
    echo "--------------------------------------"
    # List files in snapshots dir, sort by date
    ls -1 "$SNAPSHOTS_DIR" | sort -r | while read -r file; do
        local vid="${file%.json}"
        local size=$(stat -c%s "$SNAPSHOTS_DIR/$file")
        local ts=$(stat -c%y "$SNAPSHOTS_DIR/$file" | cut -d' ' -f1)
        echo "$vid | $ts | ${size}B"
    done
}

diff_versions() {
    local v_a="$1"
    local v_b="$2"

    if [ -z "$v_a" ] || [ -z "$v_b" ]; then
        echo "Usage: ledger diff <version_a> <version_b>"
        exit 1
    fi

    local path_a="$SNAPSHOTS_DIR/$v_a.json"
    local path_b="$SNAPSHOTS_DIR/$v_b.json"

    if [ ! -f "$path_a" ] || [ ! -f "$path_b" ]; then
        echo "Error: One or both versions not found."
        exit 1
    fi

    # Use diff for structural comparison
    diff -u "$path_a" "$path_b" || true
}

# --- Router ---

case "$1" in
    commit)
        shift
        commit "$1"
        ;;
    checkout)
        shift
        checkout "$1"
        ;;
    log)
        log
        ;;
    diff)
        shift
        diff_versions "$1" "$2"
        ;;
    *)
        echo "Jit State Ledger"
        echo "Usage: $0 {commit|checkout|log|diff}"
        echo "  commit <json>    - Create a new versioned snapshot"
        echo "  checkout <id>    - Retrieve content of a specific version"
        echo "  log               - List all version history"
        echo "  diff <id1> <id2> - Show changes between two versions"
        exit 1
        ;;
esac
