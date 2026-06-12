<!-- cc-team deliverable
 group: SEC (Secrets overhaul tooling + docs (gitleaks, hooks, CI, sanitizer, playbook, README, hardened compose))
 member: S3 role=dev model=moonshotai/Kimi-K2.6
 finish_reason: length | tokens: {"prompt_tokens":241,"completion_tokens":7000,"total_tokens":7241,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":0,"image_tokens":0},"cache_creation_input_tokens":0} | 68s
 generated: 2026-06-12T19:15:46.633Z -->
The user wants a raw YAML output for a GitHub Actions workflow file. No markdown fences, no prose. Just the raw YAML.

Requirements:
- name: secret-scan
- Triggers: on push to branch main, and on pull_request
- Top-level permissions: contents read, id-token write, pull-requests write
- Job gitleaks:
  - runs-on: ubuntu-latest
  - steps:
    - actions/checkout@v4 with fetch-depth 0
    - gitleaks/gitleaks-action@v2 with env GITLEAKS_CONFIG set to .gitleaks.toml and a commented GITLEAKS_LICENSE placeholder
- Job verify-artifacts:
  - runs-on: ubuntu-latest
  - a bash step that greps the PR/commit diff for referenced file paths (in backticks or quotes, ending .ts/.js/.md) and prints a non-failing warning if a referenced path does not exist on disk (guards against hallucinated-artifact references from bulk generation)
- Job block-env-files:
  - a bash step that fails if git ls-files lists a real .env file (not .env.example)
- Add concise hash comments
- Valid YAML, correct two-space indentation

Let's construct the YAML carefully.

Structure:
```yaml
name: secret-scan

on:
  push:
    branches:
      - main
  pull_request:

permissions:
  contents: read
  id-token: write
  pull-requests: write

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITLEAKS_CONFIG: .gitleaks.toml
          # GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}

  verify-artifacts:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Verify referenced artifacts exist
        shell: bash
        run: |
          # Extract quoted/backticked paths ending in .ts/.js/.md from the diff
          git diff ${{ github.event.pull_request.base.sha || 'HEAD~1' }}..HEAD \
            | grep -oE '["`'\''][^"'\''`]+[.](ts|js|md)["`'\'']' \
            | sed 's/^["`'\'']//; s/["`'\'']$//' \
            | sort -u \
            | while read -r path; do
                if [[ ! -e "$path" ]]; then
                  echo "::warning::Referenced path does not exist: $path"
                fi
              done

Wait, need to be careful with the grep and sed in YAML. Also, for pull_request, the diff is between base and head. For push, maybe we can use HEAD~1..HEAD or similar. The user said "PR/commit diff". So we need to handle both cases.

Actually, for `pull_request`, `github.event.pull_request.base.sha` is available. For `push`, we can use `github.event.before`. But if it's the first commit on a new branch, `github.event.before` might be all zeros. Let's think.

Simpler approach: use `git diff HEAD~1..HEAD` for push? But if multiple commits are pushed, HEAD~1 might not be the previous state. `github.event.before` is better. But if it's 0000000, we can fallback.

Alternatively, just use `git diff ${{ github.event.before || 'HEAD~1' }}..HEAD`? But for pull_request, `github.event.before` is not the base, it's the previous commit on the branch? Actually for pull_request event, `github.event.before` is not standard. Better to use `github.event.pull_request.base.sha` for PR and `github.event.before` for push.

Let's write:
```
git diff ${{ github.event.pull_request.base.sha || github.event.before || 'HEAD~1' }}..HEAD
```
But if `github.event.before` is all zeros (0000000000000000000000000000000000000000), git diff will fail. We could handle that, but maybe it's overkill. The user wants a non-failing warning step. Let's keep it relatively simple but functional.

Actually, for `pull_request`, the checkout by default checks out a merge commit. `github.event.pull_request.base.sha` is available. For `push`, `github.event.before` is available. So:

```
git diff ${{ github.event.pull_request.base.sha || github.event.before }}..HEAD
```

But if `github.event.before` is not defined (e.g., workflow_dispatch, though not in triggers), fallback to HEAD~1.

Wait, the triggers are only push and pull_request. So this should be fine.

Now for the grep pattern. The user wants referenced file paths in backticks or quotes, ending .ts/.js/.md.

Regex: `[\"\'\`][^\"\'\`]+[.](ts|js|md)[\"\'\`]`

In bash single quotes, we need to be careful. Let's use double quotes for the grep pattern or escape properly.

In YAML, a multiline script with `|` preserves newlines.

```
run: |
  # Diff against base for PR or previous commit for push
  base="${{ github.event.pull_request.base.sha || github.event.before || 'HEAD~1' }}"
  git diff "$base"..HEAD \
    | grep -oE '[\"`'\''][^\"`'\'']+[.](ts|js|md)[\"`'\'']' \
    | sed 's/^[\"`'\'']//; s/[\"`'\'']$//' \
    | sort -u \
    | while IFS= read -r path; do
        if [[ ! -e "$path" ]]; then
          echo "::warning::Referenced path does not exist: $path"
        fi
      done
```

Wait, the quoting inside the YAML script is tricky. Let's think about how to write this cleanly.

Actually, we can avoid complex quoting by using a different delimiter or just writing the regex in a way that doesn't conflict.

In bash heredoc or just using double quotes for grep pattern:
```
grep -oE '["`'\''][^"'\''`]+[.](ts|js|md)["`'\'']'
```
This is messy.

Alternative: use `git diff ... | grep -oE '\b[^[:space:]]+[.](ts|js|md)\b'`? No, user specifically wants backticks or quotes.

Maybe we can use perl or python? But user asked for a bash step.

Let's try:
```
git diff "$base"..HEAD \
  | grep -oE '[\"`'"'"'][^\"`'"'"']+[.](ts|js|md)[\"`'"'"']' \
  | sed 's/^[\"`'"'"']//; s/[\"`'"'"']$//' \
  | sort -u \
  | while IFS= read -r path; do
      if [[ ! -e "$path" ]]; then
        echo "::warning::Referenced path does not exist: $path"
      fi
    done
```

This is still messy. Let's think of a simpler regex. We can match backtick, single quote, or double quote using character class. In bash single quotes, we can't easily include a single quote. But the YAML `run:` block is interpreted by bash, not by YAML quotes necessarily. If we use `run: |`, the content is literal.

So we can write:
```
run: |
  base="${{ github.event.pull_request.base.sha || github.event.before || 'HEAD~1' }}"
  git diff "$base"..HEAD \
    | grep -oE '["`'"'"'][^"`'"'"']+[.](ts|js|md)["`'"'"']' \
    | sed 's/^["`'"'"']//; s/["`'"'"']$//' \
    | sort -u \
    | while IFS= read -r path; do
        if [[ ! -e "$path" ]]; then
          echo "::warning::Referenced path does not exist: $path"
        fi
      done
```

Wait, inside `run: |`, the shell will see the text after YAML parsing. The YAML parser will pass the literal characters. So we can just write the bash script. The challenge is embedding single quotes inside a bash script that isn't itself quoted by YAML (because `|` means literal block).

So the bash script lines are just raw strings. If I write:
```
    | grep -oE '["`'"'"'][^"`'"'"']+[.](ts|js|md)["`'"'"']' \
```
Bash sees: `grep -oE '["`'"'"'][^"`'"'"']+[.](ts|js|md)["`'"'"']'`

Let's parse that bash quoting:
- `'["`'` -> literal `["`
- `"'"` -> literal `'`
- `'"']` -> wait, let's break it down carefully.

Actually, the sequence `'["`'"'"']` is:
- `'["`'` -> starts with single quote, contains `["`, then closes with `'`. So literal is `["`.
- `"'"` -> double-quoted string containing `'`. So literal is `'`.
- `'"']` -> double-quoted string containing `"]`. Wait, no.

Let's write it out: `'["`'"'"']`
- `'` opens single quote.
- `["` is literal.
- `'` closes single quote.
- `"'"` is double-quoted string containing `'`.
- `'` opens single quote.
- `"]` is literal? No, after `"'"` we have `'"']`.
  - `"'"` yields `'`.
  - Then `'"']` -> double quote opens, then `']`? No.

This is getting too confusing. Let's use a different approach: write the regex in a variable using a here-document or just use `grep` with a file? Or use `perl` which can use different delimiters?

Actually, we can use `grep -oP` (perl regex) and use a regex that doesn't require shell quoting of single quotes? No, we still need to pass the pattern to grep.

Simpler: use `python3` or `node` if available? The user said "a bash step". But we can call python from bash. However, maybe better to stick to pure bash but use a temporary file for the regex? Overkill.

Alternative: use `git diff ... | grep -oE '\`[^`]+[.](ts|js|md)\`|"[^"]+[.](ts|js|md)"|'"'"'[^'"'"']+[.](ts|js|md)'"'"''`? That's also messy.

Wait, we can use `grep -oE '(\`[^`]+\.(ts|js|md)\`|"[^"]+\.(ts|js|md)"|'"'"'[^'"'"']+\.(ts|js|md)'"'"')'`? Still messy.

Let's think about the simplest correct YAML. Maybe we can avoid the complex quoting by using `sed` or `awk` to strip quotes after a broader match.

For example, match any token ending in .ts/.js/.md that might be surrounded by quotes or backticks. But the user specifically wants backticks or quotes.

Actually, we can just use three separate grep commands and combine:
```
git diff ... | grep -oE '\`[^`]+\.(ts|js|md)\`' | tr -d '`'
git diff ... | grep -oE '"[^"]+\.(ts|js|md)"' | tr -d '"'
git diff ... | grep -oE "'[^']+\.(ts|js|md)'" | tr -d "'"
```
Then pipe all to sort -u.

In bash inside YAML, single quotes are fine if we wrap the whole command in double quotes? No, because `run: |` is literal.

Let's write the script lines:
```
  git diff "$base"..HEAD \
    | grep -oE '\`[^`]+\.(ts|js|md)\`' \
    | tr -d '`' \
    | grep -oE '"[^"]+\.(ts|js|md)"' \
    | tr -d '"' \
    | grep -oE "'[^']+\.(ts|js|md)'" \
    | tr -d "'" \
    | sort -u \
    | while IFS= read -r path; do
        if [[ ! -e "$path" ]]; then
          echo "::warning::Referenced path does not exist: $path"
        fi
      done
```
Wait, piping grep to grep doesn't concatenate outputs. We need to group them. Use `{ git diff ... | grep ... | tr ...; git diff ... | grep ... | tr ...; git diff ... | grep ... | tr ...; } | sort -u`.

But running git diff three times is inefficient but acceptable. Or save to a variable/file.

```
run: |
  base="${{ github.event.pull_request.base.sha || github.event.before || 'HEAD~1' }}"
  diff_output=$(git diff "$base"..HEAD)
  printf '%s\n' "$diff_output" \
    | grep -oE '\`[^`]+\.(ts|js|md)\`' \
    | tr -d '`' > /tmp/refs.txt
  printf '%s\n' "$diff_output" \
    | grep -oE '"[^"]+\.(ts|js|md)"' \
    | tr -d '"' >> /tmp/refs.txt
  printf '%s\n' "$diff_output" \
    | grep -oE "'[^']+\.(ts|js|md)'" \
    | tr -d "'" >> /tmp/refs.txt
  sort -u /tmp/refs.txt | while IFS= read -r path; do
    if [[ ! -e "$path" ]]; then
      echo "::warning::Referenced path does not exist: $path"
    fi
  done
```

This is much cleaner and avoids quoting hell. The single quote in the grep pattern `grep -oE "'[^']+\.(ts|js|md)'"` is inside double quotes in YAML? No, in `run: |` it's literal bash. The bash line is:
```
    | grep -oE "'[^']+\.(ts|js|md)'" \
```
Bash sees: `grep -oE "'[^']+\.(ts|js|md)'"`. The outer double quotes allow the single quote inside. Perfect.

Similarly for backtick:
```
    | grep -oE '\`[^`]+\.(ts|js|md)\`' \
```
Bash sees: `grep -oE '\`[^`]+\.(ts|js|md)\`'`. Inside single quotes, backtick is literal. Perfect.

And for double quotes:
```
    | grep -oE '"[^"]+\.(ts|js|md)"' \
```
Bash sees: `grep -oE '"[^"]+\.(ts|js|md)"'`. Inside single quotes, double quote is literal. Perfect.

So this works beautifully.

Now for the `block-env-files` job:
- runs-on: ubuntu-latest
- a bash step that fails if git ls-files lists a real .env file (not .env.example)

```
  block-env-files:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Block real .env files
        shell: bash
        run: |
          # Fail if any tracked file is named exactly .env
          if git ls-files | grep -q '^\.env$'; then
            echo "::error::Real .env file detected in repository. Use .env.example instead."
            exit 1
          fi
```

Wait, `git ls-files` lists tracked files. If someone commits a `.env` file, it will be listed. The requirement says "fails if git ls-files lists a real .env file (not .env.example)". So `grep -q '^\.env$'` is correct. Or `grep -Fx '.env'`. Let's use `grep -Fx '.env'` for exact match.

Also need to consider `.env` anywhere? The requirement says "a real .env file". Usually that means exactly `.env`. But maybe also `.env.local`, `.env.production`? The requirement explicitly says "not .env.example" and "a real .env file". I think exact `.env` is what they mean. But to be safe, maybe `grep -E '^\.env$'`? The user said "a real .env file (not .env.example)". So exact `.env` is correct.

Let's write it as:
```
          # Reject tracked files named exactly .env
          if git ls-files | grep -Fx '.env' >/dev/null; then
            echo "::error::Committed .env file detected. Use .env.example instead."
            exit 1
          fi
```

Now, let's assemble the full YAML.

Need to ensure two-space indentation.

Top level:
```
name: secret-scan

on:
  push:
    branches:
      - main
  pull_request:

permissions:
  contents: read
  id-token: write
  pull-requests: write

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITLEAKS_CONFIG: .gitleaks.toml
          # GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}

  verify-artifacts:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Verify referenced artifacts exist
        shell: bash
        run: |
          # Determine base ref for PR or previous commit for push
          base="${{ github.event.pull_request.base.sha || github.event.before || 'HEAD~1' }}"
          diff_output=$(git diff "$base"..HEAD)
          printf '%s\n' "$diff_output" \
            | grep -oE '\`[^`]+\.(ts|js|md)\`' \
            | tr -d '`' > /tmp/refs.txt
          printf '%s\n' "$diff_output" \
            | grep -oE '"[^"]+\.(ts|js|md)"' \
            | tr -d '"' >> /tmp/refs.txt
          printf '%s\n' "$diff_output" \
            | grep -oE "'[^']+\.(ts|js|md)'" \
            | tr -d "'" >> /tmp/refs.txt
          sort -u /tmp/refs.txt | while IFS= read -r path; do
            if [[ ! -e "$path" ]]; then
              echo "::warning::Referenced path does not exist: $path"
            fi
          done

  block-env-files:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Block real .env files
        shell: bash
        run: |
          # Fail if a tracked .env file exists (allow .env.example)
          if git ls-files | grep -Fx '.env' >/dev/null; then
            echo "::error::Committed .env file detected. Use .env.example instead."
            exit 1
          fi
```

Wait, I need to check if `github.event.before` is available for push. Yes. For pull_request, `github.event.pull_request.base.sha` is available. The `||` logic in GitHub expressions works.

One issue: `github.event.before` might be `0000000000000000000000000000000000000000` for new branches. `git diff` with that will fail. But since the trigger is `push` to `main`, and `main` is usually not a new branch in a way that `before` is zero? Actually if someone force-pushes or creates main, it could be. But for this exercise, it's probably acceptable. The fallback `|| 'HEAD~1'` handles if both are empty, but not if `before` is zeros. We could add a check:
```
base="${{ github.event.pull_request.base.sha || github.event.before || 'HEAD~1' }}"
if [[ "$base" == "0000000000000000000000000000000000000000" ]]; then
  base="HEAD~1"
fi
```
But the user asked for concise hash comments, not necessarily exhaustive error handling. I'll keep it simple but maybe add a comment.

Also, the `verify-artifacts` job: the user said "a bash step that greps the PR/commit diff for referenced file paths... and prints a non-failing warning if a referenced path does not exist". So the step itself should not fail. My script uses `echo "::warning::..."` and doesn't exit 1, so it's non-failing. Good.

The `block-env-files` job: "a bash step that fails if git ls-files lists a real .env file". My script exits 1. Good.

Now, check indentation. Two spaces.

```
name: secret-scan

on:
  push:
    branches:
      - main
  pull_request:

permissions:
  contents: read
  id-token: write
  pull-requests: write

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITLEAKS_CONFIG: .gitleaks.toml
          # GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}

  verify-artifacts:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Verify referenced artifacts exist
        shell: bash
        run: |
          # Determine base ref for PR or previous commit for push
          base="${{ github.event.pull_request.base.sha || github.event.before || 'HEAD~1' }}"
          diff_output=$(git diff "$base"..HEAD)
          printf '%s\n' "$diff_output" \
            | grep -oE '\`[^`]+\.(ts|js|md)\`' \
            | tr -d '`' > /tmp/refs.txt
          printf '%s\n' "$diff_output" \
            | grep -oE '"[^"]+\.(ts|js|md)"' \
            | tr -d '"' >> /tmp/refs.txt
          printf '%s\n' "$diff_output" \
            | grep -oE "'[^']+\.(ts|js|md)'" \
            | tr -d "'" >> /tmp/refs.txt
          sort -u /tmp/refs.txt | while IFS= read -r path; do
            if [[ ! -e "$path" ]]; then
              echo "::warning::Referenced path does not exist: $path"
            fi
          done

  block-env-files:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Block real .env files
        shell: bash
        run: |
          # Fail if a tracked .env file exists (allow .env.example)
          if git ls-files | grep -Fx '.env' >/dev/null; then
            echo "::error::Committed .env file detected. Use .env.example instead."
            exit 1
          fi
```

Wait, the user said "Add concise hash comments." I have some. Maybe add a couple more.

Also, check if `uses: actions/checkout@v4` is needed in every job. Yes, jobs run in parallel and don't share workspace (unless using artifacts). So each job needs its own checkout. Good.

One more thing: the `gitleaks` job env. The user said "with env GITLEAKS_CONFIG set to .gitleaks.toml and a commented GITLEAKS_LICENSE placeholder". I have that.

Let's double-check the YAML syntax.
- `on:` is valid.
- `permissions:` at top level is valid.
- `jobs:` block is valid.
- `run: |` with proper indentation.

The expression `${{ github.event.pull_request.base.sha || github.event.before || 'HEAD~1' }}` is inside a double-quoted string in bash. This is fine because GitHub will substitute it before bash runs. The resulting string might be empty if none match, but then `'HEAD~1'` is the fallback. Actually, the expression evaluates to a string. If `github.event.pull_request.base.sha` is undefined, it moves to `github.event.before`. If that's undefined (e.g., not a push event?), then `'HEAD~1'`. For `pull_request`, `github.event.before` is not defined, but `github.event.pull_request.base.sha` is. For `push`, `github.event.pull_request.base.sha` is not defined, but `github.event.before` is. So it works.

One subtlety: in `pull_request` events, the checkout action checks out the merge commit by default. `git diff` between `base.sha` and `HEAD` (which is the merge commit) will show the combined diff. That's acceptable.

Also, for `push` to main, `HEAD` is the new commit. `git diff "$base"..HEAD` works.

Is there any issue with `grep -oE '\`[^`]+\.(ts|js|md)\`' `? In bash single quotes inside YAML literal block, the backtick is just a character. So the pattern is: backtick, then `[^`]` (character class excluding backtick), then `\.(ts|js|md)`, then backtick. This is correct.

Similarly `grep -oE "'[^']+\.(ts|js|md)'"` is inside double quotes in bash, so single quotes are fine.

And `grep -oE '"[^"]+\.(ts|js|md)"'` is inside single quotes in bash, so double quotes are fine.

Everything looks good.

Wait, the user said "Output ONLY raw YAML (no markdown fences, no prose)." So I must not wrap it in ```yaml. Just output the raw text.

I should also ensure there is no trailing whitespace or extra blank lines at the end? Usually a final newline is fine.

Let me review the exact wording again:
- "name is secret-scan" -> done
- "Triggers: on push to branch main, and on pull_request" -> done
- "Top-level permissions: contents read, id-token write (for OIDC), pull-requests write" -> done
- "Job gitleaks: runs-on ubuntu-latest; steps: actions/checkout@v4 with fetch-depth 0 for full history, then gitleaks/gitleaks-action@v2 with env GITLEAKS_CONFIG set to .gitleaks.toml and a commented GITLEAKS_LICENSE placeholder." -> done
- "Job verify-artifacts: runs-on ubuntu-latest, a bash step that greps the PR/commit diff for referenced file paths (in backticks or quotes, ending .ts/.js/.md) and prints a non-failing warning if a referenced path does not exist on disk (guards against hallucinated-artifact references from bulk generation)." -> done
- "Job block-env-files: a bash step that fails if git ls-files lists a real .env file (not .env.example)." -> done
- "Add concise hash comments." -> done
- "Valid YAML, correct two-space indentation." -> done

One final check: the `verify-artifacts` job uses `git diff` which might fail if the base is not available (e.g., shallow clone). But we do `actions/checkout@v4` without specifying fetch-depth, which defaults to 1. For `pull_request`, the default checkout fetches the base and head to create a merge commit, so `base.sha` should be available. For `push`, the default checkout with fetch-depth 1 only fetches the current commit. `github.event.before` might not be present in the local git history if it's a shallow clone. To be safe, we should add `fetch-depth: 0` to the checkout in `verify-artifacts` and `block-env-files` as well? The user didn't explicitly say that, but for `git diff` and `git ls-files`, `git ls-files` works with shallow clone, but `git diff "$base"..HEAD` might fail if `$base` is not fetched.

However, for `push` events, `actions/checkout@v4` with default fetch-depth 1 does fetch the commit itself, but not the history before it. `github.event.before` is a SHA that might not be in the local repo if it's a shallow clone. Actually, for push events, GitHub provides `before` and `after`. The checkout action fetches the `after` commit. Does it fetch `before`? Not necessarily with fetch-depth 1. But `git diff` can still work if it has the commit? No, it needs both commits in the object database.

To make it robust, I should add `fetch-depth: 0` to all checkouts. The user only explicitly required it for gitleaks, but it's good practice. However, the user might be strict about requirements. Let me see: "steps: actions/checkout@v4 with fetch-depth 0 for full history" - this was only mentioned for gitleaks. But for verify-artifacts, we need history too. I'll add fetch-depth: 0 to verify-artifacts checkout to ensure git diff works. For block-env-files, `git ls-files` doesn't need history, just the tree. Default fetch-depth 1 is enough. But for consistency, maybe add it? The user didn't ask. I'll add it to verify-artifacts to ensure the diff step works. Actually, for PR, the default checkout fetches enough for diff against base? The checkout action docs say for pull_request events, it checks out the merge commit. The base commit should be available. For push, fetch-depth 1 might not include `before`. So to be safe, I'll add `fetch-depth: 0` to verify-artifacts.

Wait, but if I add it without being asked, is that okay? The user wants a functional workflow. A non-functional workflow would be bad. I'll add `fetch-depth: 0` to verify-artifacts checkout. Actually, `git ls-files` in block-env-files works fine with shallow checkout.

Let me reconsider the verify-artifacts diff base. Another approach: for pull_request, use `github.base_ref` (the branch name) and fetch it. But with `fetch-depth: 0`, everything is fetched.

Let's add `fetch-depth: 0` to verify-artifacts checkout. I'll keep block-env-files as default.

Actually, looking at the requirements again: "steps: actions/checkout@v4 with fetch-depth 0 for full history" was explicitly under gitleaks. It doesn't say the other jobs need it. But if I don't add it, the workflow might fail for push events. However, the user might not care about that edge case, or maybe they assume `github.event.before` is available. I'll add a comment and keep fetch-depth 0 for verify-artifacts to be safe. No, I'll just add it. It's harmless.

Wait, the user said "correct two-space indentation". Let me count.

```
name: secret-scan
```
0 spaces.

```
on:
  push:
    branches:
      - main
  pull_request:
```
2, 4, 6, 4.

```
permissions:
  contents: read
  id-token: write
  pull-requests: write
```
2, 4.

```
jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITLEAKS_CONFIG: .gitleaks.toml
          # GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
```
2, 4, 6, 8, 10, 8, 10, 8, 10, 12. Looks correct.

```
  verify-artifacts:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Verify referenced artifacts exist
        shell: bash
        run: |
          # Determine base ref for PR or previous commit for push
          base="${{ github.event.pull_request.base.sha || github.event.before || 'HEAD~1' }}"
          diff_output=$(git diff "$base"..HEAD)
          printf '%s\n' "$diff_output"
