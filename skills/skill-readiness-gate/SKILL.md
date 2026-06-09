---
name: skill-readiness-gate
description: "Validate and gate skills before integration — verify SKILL.md frontmatter integrity, check for syntax errors, and report integration readiness. Use when developing new skills (especially in parallel fleet development like /spawn_skill_agents), when user says 'is this skill ready', 'verify skill syntax', 'check skill format', 'gate this skill', 'integration ready?', or wants to validate multiple skills for production. Do NOT trigger for general skill creation (use /skill-creator), skill performance metrics (use /skill-metrics), or non-skill YAML validation."
argument-hint: "[<skill-name> | --batch <dir>] [--fix | --report] [--strict]"
---

# /skill-readiness-gate — Skill Integration Validator

> "A skill ready for integration is a skill that integrates without surprises."

Automated gatekeeper that verifies SKILL.md frontmatter, syntax, completeness, and structural integrity before promoting skills from staging (`./skills/`) into production (`~/.claude/skills/`).

## Usage

```
/skill-readiness-gate skill-name              # Validate single skill
/skill-readiness-gate skill-name --fix        # Auto-fix detected issues
/skill-readiness-gate --batch ./skills        # Validate all skills in directory
/skill-readiness-gate --batch ./skills --fix  # Batch fix all
/skill-readiness-gate skill-name --strict     # Strict validation (includes warnings)
/skill-readiness-gate skill-name --report     # Generate integration readiness report
```

---

## Validation Gates

### Gate 1: Frontmatter Structure (REQUIRED)

Check YAML frontmatter format:

```yaml
---
name: <string>                    # Must be present, lowercase, hyphen-separated
description: <string>             # Must be present, non-empty
argument-hint: <string or null>   # Optional but recommended
---
```

**Checks:**
- ✓ Frontmatter enclosed in `---` at start and after metadata
- ✓ `name` field exists, is lowercase, matches filename pattern
- ✓ `description` field exists, non-empty, includes usage triggers ("Use when...") and anti-triggers ("Do NOT trigger...")
- ✓ Valid YAML syntax (can parse with `yaml` library or equivalent)
- ✓ No BOM, no mixed line endings (LF only)

**Failure mode**: Skill cannot be registered. Returns: `FAIL — Frontmatter`

---

### Gate 2: Content Structure (REQUIRED)

Check that SKILL.md body has essential sections:

- ✓ H1 title matching skill name (e.g., `# /skill-name — ...)
- ✓ Quote/epigraph section (> "...")
- ✓ Usage section with examples (## Usage)
- ✓ At least one instructional section (## ..., ## Step X, ## Overview, etc.)

**Failure mode**: Skill structure incomplete. Returns: `FAIL — Content`

---

### Gate 3: Syntax Validation (REQUIRED)

Check that referenced commands, scripts, or code blocks are syntactically sound:

- ✓ Bash blocks (```bash```) parse without syntax errors
- ✓ Code examples are properly fenced
- ✓ File paths referenced are reasonable (no `C:\Users\...\temp\...` singletons)
- ✓ Environment variable references ($VAR) are documented
- ✓ No embedded secrets (API keys, tokens, passwords) in examples

**Checks**:
```bash
# If bash block exists, validate:
bash -n <script> 2>&1

# If TypeScript/JS block exists, check for:
# - Valid function signatures
# - Proper bracket/paren balancing
# - No undefined symbol references (light check)
```

**Failure mode**: Syntax errors present. Returns: `FAIL — Syntax`

---

### Gate 4: Completeness Check (RECOMMENDED)

Warn if optional but best-practice elements are missing:

- ⚠️ `argument-hint` not provided (metadata clarity)
- ⚠️ No examples or usage shown
- ⚠️ Description shorter than 50 chars (too brief)
- ⚠️ Anti-trigger section ("Do NOT trigger...") missing from description
- ⚠️ No section describing when/why skill should be used

**Failure mode**: Warnings only. Returns: `WARN — Completeness` (skill still passes)

---

### Gate 5: Integration Readiness (OPTIONAL)

If `--strict` flag used, additionally check:

- ⚠️ Skill name doesn't collide with existing global skills
- ⚠️ Skill works with declared supported shells (bash, zsh, fish, powershell)
- ⚠️ No hardcoded absolute paths (except well-known: `~/.claude/`, `/tmp/`, `$HOME/`)
- ⚠️ Documentation language is consistent (all Thai, all English, or marked as mixed)

**Failure mode**: Integration concerns. Returns: `WARN — Integration` (skill still passes but noted)

---

## Output Format

### Summary (all modes)

```
╔════════════════════════════════════════════════════════════╗
║ Skill Readiness Gate Report                               ║
╠════════════════════════════════════════════════════════════╣
║ Skill:        [name]                                       ║
║ Status:       ✓ READY / ⚠️ WARN / ❌ FAIL                 ║
║ Path:         [absolute path]                              ║
║ Size:         [bytes], [lines] lines                       ║
║ Frontmatter:  ✓ Valid                                      ║
║ Content:      ✓ Valid                                      ║
║ Syntax:       ✓ Valid                                      ║
║ Completeness: ⚠️ Missing argument-hint                     ║
║ Integration:  ⚠️ Collides with existing skill-creator      ║
╚════════════════════════════════════════════════════════════╝

Ready for integration? YES ✓
  Promote with: skill-readiness-gate skill-name --promote

Issues found:
  1. [WARN] Argument-hint missing — add to frontmatter
  2. [WARN] Name collision with global skill-creator
     (Local skill takes precedence if installed first)

Recommendations:
  - Add argument-hint to frontmatter for clarity
  - Consider renaming to avoid collision, or document override
```

### Detailed Check Results

```
Gate 1: Frontmatter Structure ✓
  ✓ YAML syntax valid
  ✓ name: "skill-readiness-gate" (lowercase, hyphen-separated)
  ✓ description: non-empty (178 chars)
  ✓ argument-hint: provided

Gate 2: Content Structure ✓
  ✓ H1 title present: "# /skill-readiness-gate — Skill Integration Validator"
  ✓ Quote section: "> "A skill ready...""
  ✓ Usage section: ## Usage (4 examples)
  ✓ Instructional sections: 5 gate descriptions

Gate 3: Syntax Validation ✓
  ✓ No bash blocks (clean)
  ✓ No embedded secrets detected
  ✓ All file paths are relative or well-known

Gate 4: Completeness ✓
  ✓ argument-hint provided
  ✓ 8 usage examples shown
  ✓ Description > 50 chars (178)
  ✓ Anti-triggers documented
  ✓ Clear purpose statement

Gate 5: Integration (--strict)
  ✓ No name collision
  ✓ Works with: bash, zsh, fish, powershell
  ✓ No hardcoded absolute paths
  ✓ English documentation (consistent)
```

### Batch Report (`--batch` mode)

```
╔═════════════════════════════════════════════════════════╗
║ Batch Skill Readiness Report                           ║
║ Directory: /Users/nat/Jit/skills/                       ║
║ Timestamp: 2026-06-09 14:23:45 UTC                     ║
╠═════════════════════════════════════════════════════════╣
║ Total skills scanned: 12                                ║
║ Ready for integration: 10 ✓                             ║
║ Warnings: 2 ⚠️                                           ║
║ Failed: 0 ❌                                             ║
╠═════════════════════════════════════════════════════════╣
║ Results:                                                 ║
║                                                          ║
║  1. skill-1          ✓ READY                            ║
║  2. skill-2          ⚠️ WARN (missing argument-hint)     ║
║  3. skill-3          ✓ READY                            ║
║  4. skill-4          ⚠️ WARN (syntax: trailing space)    ║
║  5. skill-5          ✓ READY                            ║
║  6. skill-6          ✓ READY                            ║
║  7. skill-7          ✓ READY                            ║
║  8. skill-8          ✓ READY                            ║
║  9. skill-9          ✓ READY                            ║
║ 10. skill-10         ✓ READY                            ║
║ 11. skill-11         ✓ READY                            ║
║ 12. skill-12         ✓ READY                            ║
║                                                          ║
╚═════════════════════════════════════════════════════════╝

Next steps:
  - Fix 2 warnings: skill-readiness-gate --batch ./skills --fix
  - Promote ready skills: skill-readiness-gate skill-1 --promote
  - View detailed report: skill-readiness-gate skill-2 --report
```

---

## Mode: Single Skill Validation

### Example: Validate a new skill

```bash
/skill-readiness-gate skill-name
```

Output: Summary + detailed checks (see above format)

Return codes:
- `0` — READY (no issues, can integrate)
- `1` — WARN (issues detected, review before promoting)
- `2` — FAIL (blocking issues, cannot integrate)

---

## Mode: Batch Validation (`--batch`)

### Example: Validate all skills in staging directory

```bash
/skill-readiness-gate --batch ./skills/
/skill-readiness-gate --batch /Users/nat/Jit/skills/ --strict
```

**Steps:**
1. Find all `<dir>/*/SKILL.md` files
2. Run validation on each
3. Collect results
4. Display batch summary (see "Batch Report" format above)
5. If `--fix` flag provided, auto-correct all non-critical issues
6. If `--report` flag provided, generate markdown report file

---

## Mode: Auto-Fix (`--fix`)

When `--fix` flag is used, automatically correct non-critical issues:

**Auto-fixable:**
- Trailing whitespace in frontmatter
- Missing BOM (remove if present)
- Inconsistent line endings (normalize to LF)
- Missing blank line after frontmatter
- Extra/missing spaces around `---` fences
- Bash syntax errors (indentation, missing quotes — light fixes only)

**Non-fixable (requires human review):**
- Missing required fields (name, description)
- Content structure incomplete
- Syntax errors in complex scripts
- Collisions with existing skills

---

## Mode: Strict Validation (`--strict`)

Enables all additional gates (Integration Readiness) and treats warnings as blockers:

```bash
/skill-readiness-gate skill-name --strict
```

Returns FAIL if:
- Any WARN condition detected (not just errors)
- Skill name collides with global skill
- Syntax validation has warnings

---

## Mode: Report Generation (`--report`)

Generate a human-readable markdown report for documentation:

```bash
/skill-readiness-gate skill-name --report
```

Output file: `./skills/skill-name/READINESS_REPORT.md`

Contents:
- Summary table (gates, pass/fail status)
- Detailed findings per gate
- Recommendations
- Integration steps
- Timestamp

---

## Integration Workflow (Recommended)

For parallel skill fleet development (like `/spawn_skill_agents`):

```bash
# 1. Each agent develops its skill in ./skills/<name>/
#    Agent 1 → ./skills/skill-1/SKILL.md
#    Agent 2 → ./skills/skill-2/SKILL.md
#    ... etc

# 2. Gate everything before integration
/skill-readiness-gate --batch ./skills/ --strict

# 3. Fix any warnings
/skill-readiness-gate --batch ./skills/ --fix

# 4. Verify all passed
/skill-readiness-gate --batch ./skills/

# 5. Promote to ~/.claude/skills/ (manual or scripted)
# (Not handled by this skill — requires human/admin approval)
```

---

## Implementation Notes

### Language Support

- **Bash validation**: Use `bash -n` for syntax checking
- **YAML validation**: Use YAML parser (e.g., `yaml` npm, or built-in)
- **File path normalization**: Handle Windows/Unix path differences
- **Character encoding**: Detect and normalize UTF-8 (remove BOM if present)

### Error Messages

All errors should be **actionable**:

```
❌ FAIL — Frontmatter
  Line 3: name field missing
  Fix: Add 'name: skill-name' after '---'

❌ FAIL — Syntax
  Line 47: bash script has unmatched ')' bracket
  Fix: Review lines 45-50 and balance parentheses
  Context:
    45:     for file in *.md; do
    46:       echo "Processing $file"
    47:     done)  ← extra ')'
```

---

## Exit Codes & Return Values

| Code | Meaning | Action |
|------|---------|--------|
| 0 | READY | Skill is production-ready |
| 1 | WARN | Issues found, review before promoting |
| 2 | FAIL | Blocking issues, cannot integrate |

---

## Flags Reference

| Flag | Argument | Effect |
|------|----------|--------|
| `--fix` | none | Auto-correct non-critical issues |
| `--strict` | none | Treat warnings as blockers |
| `--report` | none | Generate markdown report |
| `--batch` | <dir> | Validate all skills in directory |

---

## Rules

- **Never modify a skill without user approval** (even with `--fix`, require confirmation)
- **All checks are read-only by default** — use `--fix` to enable modifications
- **Batch mode shows summary; single-skill mode shows details**
- **Report files are created alongside SKILL.md** (same directory)
- **Skill name must match directory name** (lowercase, hyphen-separated)

---

*Integration readiness gate — ensuring skills integrate cleanly. Built for parallel skill fleet development.*

---

ARGUMENTS: $ARGUMENTS
