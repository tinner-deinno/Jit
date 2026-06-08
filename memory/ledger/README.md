# Versioned State Ledger

The Versioned State Ledger replaces simple shared JSON files with an immutable, version-controlled history of the system state.

## Architecture

- **Snapshots**: Every state change is saved as a unique JSON file in `/workspaces/Jit/memory/ledger/snapshots/`.
- **HEAD**: The current active version is tracked in `/workspaces/Jit/memory/ledger/meta/HEAD`.
- **Immutability**: Once a snapshot is written, it is never modified.

## Usage

The ledger is managed via the CLI tool at `/workspaces/Jit/limbs/ledger.sh`.

### 1. Commit State
Saves the current state as a new version.
```bash
bash /workspaces/Jit/limbs/ledger.sh commit '{"key": "value", "status": "active"}'
```

### 2. Log History
Lists all recorded snapshots in reverse chronological order.
```bash
bash /workspaces/Jit/limbs/ledger.sh log
```

### 3. Checkout Version
Retrieves the content of a specific version. If no ID is provided, it retrieves the latest (HEAD).
```bash
bash /workspaces/Jit/limbs/ledger.sh checkout <version_id>
```

### 4. Diff Versions
Shows the differences between two snapshots.
```bash
bash /workspaces/Jit/limbs/ledger.sh diff <version_id_a> <version_id_b>
```

## Safety Measures
- **Atomic Moves**: New snapshots are written to a temporary file and moved to their final location to prevent partial writes.
- **Locking**: A lock file is used during commit operations to prevent race conditions between agents.
