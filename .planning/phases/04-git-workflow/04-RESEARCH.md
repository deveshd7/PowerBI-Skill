# Phase 4: Git Workflow - Research

**Researched:** 2026-03-12
**Domain:** Claude skill system / git CLI / PBIP file diffing / conventional commits
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Diff output depth**
- Count summary format: "3 measures modified in Sales, 1 relationship removed" — not full before/after DAX diff
- Covers all four change categories: measures (added/modified/removed), relationships, tables and columns, model properties (format strings, display folders, descriptions)
- Scope: diffs against last commit (standard `git diff HEAD` against PBIP model files)
- Filters to PBIP model files only — .tmdl / model.bim / relationships / tables files; ignores cache, settings, and lock files entirely

**Gitignore handling**
- `/pbi:diff` checks `.gitignore` for noise file entries before presenting output
- If entries are missing: auto-fix silently — add the missing entries to `.gitignore` then proceed with the diff (no warning prompt)
- If no `.gitignore` at all: created as part of `git init` (see below)
- Standard noise file entries always included: `cache.abf`, `localSettings.json`, `.pbi-context.md`, `SecurityBindings`

**Auto-commit trigger (GIT-06)**
- Auto-commit logic lives inside each writing skill (pbi-comment, pbi-error) — self-contained, no shared utility skill
- Surface to analyst: silent commit + one confirmation line at end of output: `Auto-committed: chore: update [MeasureName] comment in TableName`
- If no git repo when auto-commit triggers: skip the commit, show hint: "No git repo — run /pbi:commit to initialise one." File write still succeeds.

**Commit message format**
- Conventional commits format: `feat:` / `fix:` / `chore:` prefix
- Subject line: one concise summary of the primary change
- Body: one bullet per changed item (measure, relationship, table) — e.g. `- add [Revenue YTD] to Sales` / `- modify [Total Cost] in Products`
- Auto-commits from file writes always use `chore:` prefix — e.g. `chore: update [Revenue YTD] comment in Sales`
- `/pbi:commit` infers prefix from change type: `feat` for adds, `fix` for corrections, `chore` for metadata updates

**Git init (GIT-08)**
- `/pbi:commit` initialises a git repo if none exists — `git init` + creates `.gitignore` with standard PBIP noise file entries + initial commit
- Push to remote is always manual — no command auto-pushes under any circumstances

### Claude's Discretion
- Exact `git diff` command construction to scope to PBIP model files only
- How to parse raw git diff output into business-language change categories
- `.gitignore` creation template formatting and ordering
- Handling of edge cases: empty repo (no commits yet), detached HEAD

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GIT-01 | User can run `/pbi:diff` to get a human-readable summary of what changed since the last commit (measures added/modified/removed, relationships changed) — not raw JSON diff | `git diff HEAD` scoped to PBIP files; parse +/- lines in measure/relationship blocks |
| GIT-02 | Diff summary uses business language (table and measure names, not JSON key paths) | Parse TMDL measure declarations and TMSL JSON measure name fields to extract human names |
| GIT-03 | Diff command verifies `.gitignore` is guarding noise files before presenting output | Read `.gitignore`, grep for required entries, silently append if missing |
| GIT-04 | User can run `/pbi:commit` to stage PBIP changes and commit locally with an auto-generated business-language commit message | `git add` PBIP files only, then `git commit -m` with generated message |
| GIT-05 | Commit message summarises the actual model changes (tables, measures, relationships) | Same diff parse logic as GIT-01/02; infer conventional commit prefix from change type |
| GIT-06 | After every successful PBIP file write (from any command), an automatic local git commit is created | Add auto-commit bash block inside pbi-comment and pbi-error after their write steps |
| GIT-07 | Push to remote is always manual — no command auto-pushes | Confirmed: no `git push` in any skill |
| GIT-08 | If no git repo exists, `/pbi:commit` initialises one and creates an initial commit | `git rev-parse --is-inside-work-tree` check; `git init` + `.gitignore` creation + initial commit |
</phase_requirements>

---

## Summary

Phase 4 introduces two new skills (`pbi-diff` and `pbi-commit`) plus targeted modifications to two existing skills (`pbi-comment` and `pbi-error`). The domain is entirely within git CLI and PBIP file parsing — no external APIs, no new third-party libraries.

The central technical challenge is parsing raw `git diff HEAD` output into business-language change counts. PBIP model files come in two formats: TMDL (plaintext, easy to parse with line patterns) and TMSL (JSON model.bim, requiring key-path identification). Diff parsing must handle both. TMDL diffs are line-oriented and map naturally to measure/column/relationship block boundaries. TMSL diffs are JSON patches where `+` / `-` lines appear inside measure objects — the parsing approach must extract measure names from the surrounding object context, not just flag raw key paths.

The `.gitignore` hygiene check is a simple read-and-fix flow with no user prompt (locked decision: auto-fix silently). The auto-commit block in pbi-comment and pbi-error is a self-contained bash snippet that runs after a confirmed write, checks for a git repo, and falls back gracefully if none exists.

**Primary recommendation:** Build `pbi-diff` and `pbi-commit` as standalone SKILL.md files following the exact same startup pattern as existing skills (PBIP detection, session context injection, `allowed-tools: Read, Write, Bash`). The diff-parsing logic is the only non-trivial piece — design it as explicit category detection rules, one pass per change category, not a generic diff walker.

---

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| git CLI | system | All VCS operations | Already on analyst machine; PBIP projects are git-tracked by default |
| bash (skill startup blocks) | system | `git diff`, `git add`, `git commit`, `git init`, `git rev-parse` | Consistent with all existing skills using `!` bash injection blocks |

### No New Libraries Required
All git operations run via bash commands inside `!` blocks in SKILL.md files. No npm packages, no Python scripts, no external tooling.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bash `!` blocks for git | A separate shell script | Bash blocks are the established pattern — shell scripts add file management complexity |
| Inline diff parsing by Claude | jq / grep pipeline | Claude parses the diff text directly — consistent with how other skills handle file content; simpler than a shell pipeline for business-language output |

---

## Architecture Patterns

### Recommended Project Structure
```
.claude/skills/
├── pbi-diff/
│   └── SKILL.md          # new: /pbi:diff command
├── pbi-commit/
│   └── SKILL.md          # new: /pbi:commit command
├── pbi-comment/
│   └── SKILL.md          # modified: add auto-commit block after write step
├── pbi-error/
│   └── SKILL.md          # modified: add auto-commit block after write step (after y confirm)
└── [existing skills unchanged]
```

### Pattern 1: PBIP-Scoped Git Diff
**What:** Run `git diff HEAD` filtered to PBIP model file paths only, capturing both staged and unstaged changes.
**When to use:** In `pbi-diff` Step 1 and in `pbi-commit` Step 1 (to build commit message).

**TMDL scope command:**
```bash
git diff HEAD -- '.SemanticModel/definition/tables/*.tmdl' '.SemanticModel/definition/relationships.tmdl' 2>/dev/null
```

**TMSL scope command:**
```bash
git diff HEAD -- '.SemanticModel/model.bim' 2>/dev/null
```

**Empty repo edge case (no commits yet — `HEAD` does not exist):**
```bash
git diff HEAD 2>&1 | grep -q "unknown revision" && git diff --cached -- '.SemanticModel/' 2>/dev/null || git diff HEAD -- '.SemanticModel/' 2>/dev/null
```

**Confidence:** HIGH — `git diff HEAD` is standard git; `--` path scoping is documented behavior.

### Pattern 2: Repo Existence Check
**What:** Determine if the current directory is inside a git repo before attempting any git operation.
**When to use:** `pbi-commit` Step 0; auto-commit blocks in `pbi-comment` and `pbi-error`.

```bash
git rev-parse --is-inside-work-tree 2>/dev/null && echo "GIT=yes" || echo "GIT=no"
```

**Also check for empty repo (no commits yet):**
```bash
git rev-parse HEAD 2>/dev/null && echo "HAS_COMMITS=yes" || echo "HAS_COMMITS=no"
```

**Confidence:** HIGH — `git rev-parse --is-inside-work-tree` is the canonical idiom for this check.

### Pattern 3: TMDL Diff Parsing Rules
**What:** Translate raw TMDL diff lines into business-language change categories.
**When to use:** In `pbi-diff` Step 2 and `pbi-commit` Step 2 (message generation).

Claude reads the diff text and applies these rules:

**Measures:**
- A measure is ADDED if a `+ measure Name =` line appears without a corresponding `- measure Name =` line in the same file's diff hunk.
- A measure is REMOVED if a `- measure Name =` line appears without a `+ measure Name =` line.
- A measure is MODIFIED if both `- measure Name =` and `+ measure Name =` lines appear, OR if only lines inside an existing measure block changed (i.e., expression body, formatString, description, displayFolder lines changed but the declaration line is unchanged).
- Extract measure name: from text after `measure ` up to ` =`, stripping single quotes.
- Extract table name: from the file path — `tables/TableName.tmdl` → `TableName`.

**Relationships:**
- A relationship is ADDED if `+ relationship` line appears.
- A relationship is REMOVED if `- relationship` line appears.
- A relationship is MODIFIED if a property line inside a relationship block changed (e.g., crossFilteringBehavior).
- Extract relationship name from `+ relationship Name` or `- relationship Name`.

**Tables and columns:**
- A table is ADDED if `+ table Name` appears.
- A table is REMOVED if `- table Name` appears.
- A column is ADDED if `+ column Name` appears.
- A column is REMOVED if `- column Name` appears.

**Model properties (metadata-only changes):**
- If only `formatString`, `displayFolder`, `description` (`///` lines in TMDL) lines changed inside a measure block — classify as "model property update" for that measure.

### Pattern 4: TMSL Diff Parsing Rules
**What:** Translate raw JSON diff lines from model.bim into business-language changes.

For TMSL, Claude reads the diff and:
- Identifies measure object boundaries: a `+` or `-` block containing `"name":` inside a `"measures":` array context.
- If an entire measure object (all lines) is added/removed → measure added/removed.
- If only `"expression"` or `"description"` or `"formatString"` lines changed inside an existing named measure → measure modified.
- For relationships: `"relationships":` array additions/removals.
- Extract name from `"name": "MeasureName"` line in context.

### Pattern 5: Auto-Commit Block (for pbi-comment and pbi-error)
**What:** Self-contained git commit block added after the Write step in writing skills.
**When to use:** After a confirmed successful file write (after Write tool call succeeds).

The block lives in SKILL.md instructions, executed as a bash `!` block at runtime:

```bash
# Auto-commit check (runs after Write tool confirms success)
GIT_STATUS=$(git rev-parse --is-inside-work-tree 2>/dev/null && echo "yes" || echo "no")
if [ "$GIT_STATUS" = "yes" ]; then
  git add '.SemanticModel/' 2>/dev/null
  git commit -m "chore: update [MeasureName] comment in [TableName]" 2>/dev/null && echo "AUTO_COMMIT=ok" || echo "AUTO_COMMIT=fail"
else
  echo "AUTO_COMMIT=skip_no_repo"
fi
```

The skill then outputs:
- `AUTO_COMMIT=ok` → append line: `Auto-committed: chore: update [MeasureName] comment in [TableName]`
- `AUTO_COMMIT=skip_no_repo` → append line: `No git repo — run /pbi:commit to initialise one.`
- `AUTO_COMMIT=fail` → silent (file write still succeeded; git error is non-fatal)

**Note for pbi-error:** Auto-commit block runs only after the analyst confirms `y` to the write prompt and the Write tool completes. If the analyst responds `n`, no commit.

### Pattern 6: Git Init Flow (pbi-commit, GIT-08)
**What:** Initialize a git repo, create `.gitignore`, and create initial commit if no repo exists.

```bash
git init && echo "INIT=ok" || echo "INIT=fail"
```

Then create `.gitignore` with Write tool (content template below).

Then stage everything and create initial commit:
```bash
git add '.SemanticModel/' && git commit -m "chore: initial PBIP model commit"
```

### .gitignore Template (standard PBIP noise entries)
```
# Power BI noise files
*.abf
localSettings.json
.pbi-context.md
SecurityBindings
*.pbids
cache/
```

### Conventional Commit Prefix Inference Rules (pbi-commit)
| Change detected | Prefix |
|----------------|--------|
| Any measure or table ADDED | `feat:` |
| Any measure REMOVED | `fix:` (treat as corrective removal) |
| Only expression or description changes | `chore:` |
| Only formatString / displayFolder changes | `chore:` |
| Relationship added or removed | `feat:` / `fix:` respectively |
| Mixed adds and changes | `feat:` (most significant wins) |

**Subject line construction:** "[prefix] [primary verb] [primary item] in [table/model]"
- e.g. `feat: add [Revenue YTD] measure to Sales`
- e.g. `chore: update display folder for 3 measures in Products`
- e.g. `fix: remove bidirectional filter on Sales → Date relationship`

**Body construction:** one bullet per changed item:
```
- add [Revenue YTD] to Sales
- modify [Total Cost] expression in Products
- remove [Obsolete Calc] from Inventory
```

### Anti-Patterns to Avoid
- **Running `git diff` without path scoping:** Will include all project files (report JSON, theme files, etc.) creating irrelevant noise in the diff output. Always scope with `-- '.SemanticModel/'` or specific file paths.
- **Using `git add .` or `git add -A`:** Will stage non-model files (audit-report.md, any local config). Always use `git add '.SemanticModel/'` to stage only PBIP model files.
- **Attempting `git diff HEAD` on an empty repo:** `HEAD` does not exist before the first commit. Check `HAS_COMMITS` before using `HEAD` reference; fall back to `git diff --cached` for staged content on a fresh repo.
- **Detached HEAD state:** `git diff HEAD` still works in detached HEAD; `git commit` works too. No special handling needed — detached HEAD is rare in this analyst context.
- **Blocking on git failures:** git operations are non-fatal for file write commands. If `git commit` fails in the auto-commit block, the file write still succeeded. Never block output delivery on git errors.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Repo existence check | Custom file-system check (look for `.git/` directory) | `git rev-parse --is-inside-work-tree` | The canonical idiom; handles submodules and worktrees correctly |
| Conventional commit prefix logic | Complex rule engine | Simple if/else table in SKILL.md instructions | The rules are fixed and small; a table of 6 rules is the correct abstraction level |
| .gitignore parsing | Custom parser | `grep -q "cache.abf" .gitignore` | Standard grep; no edge cases for this fixed list of patterns |
| Commit message length enforcement | Character counter | Claude's natural language generation | Subject lines from this skill are always short (model names, table names); length is not a practical problem |

**Key insight:** This phase is almost entirely git CLI orchestration + text parsing by Claude. The only "library" is git itself. No new packages are needed or appropriate.

---

## Common Pitfalls

### Pitfall 1: `git diff HEAD` Fails on Empty Repository
**What goes wrong:** If the analyst runs `/pbi:commit` on a fresh PBIP project with no git history, `git diff HEAD` exits with error "fatal: ambiguous argument 'HEAD': unknown revision or path not in the working tree."
**Why it happens:** `HEAD` is a symbolic ref that requires at least one commit to resolve.
**How to avoid:** Always run `git rev-parse HEAD` before using `HEAD` as a diff ref. If it fails, treat all PBIP files as new (initial commit scenario). Use `git status --porcelain '.SemanticModel/'` to enumerate untracked/new files instead of `git diff HEAD`.
**Warning signs:** The bash `!` block output contains "unknown revision" or "fatal: ambiguous".

### Pitfall 2: Scoping `git add` Too Broadly
**What goes wrong:** `git add .` or `git add -A` stages `audit-report.md`, `.pbi-context.md`, `.planning/` files, and any other project artifacts alongside model files.
**Why it happens:** Convenience habit from general git workflows.
**How to avoid:** All `git add` commands in these skills must be scoped: `git add '.SemanticModel/'`. Note: `.pbi-context.md` is in `.gitignore` (locked decision) so it won't be staged even if `git add .` is used — but `audit-report.md` would be, so explicit scoping is still required.
**Warning signs:** `git status` shows non-model files staged.

### Pitfall 3: TMDL Diff Hunk Context Lines Misread as Changes
**What goes wrong:** Git diff includes unchanged context lines (lines without `+` or `-` prefix) to show surrounding code. If the parser treats these as changes, it produces false positives.
**Why it happens:** Diff output has three types of lines: `+` (added), `-` (removed), space (context). Context lines look like model content.
**How to avoid:** When parsing diff output, only count lines that start with `+` (not `+++`) or `-` (not `---`). Filter out the hunk headers (`@@ ... @@`) and file headers (`--- a/...`, `+++ b/...`).
**Warning signs:** Diff summary reports changes to measures that the analyst knows were not touched.

### Pitfall 4: TMSL JSON Diff Is Non-Trivial to Attribute
**What goes wrong:** In model.bim diffs, a single changed measure may produce many `+`/`-` lines (the whole expression array). The parser must attribute all those lines to ONE measure, not count each line as a separate measure change.
**Why it happens:** TMSL stores expressions as JSON arrays of strings, so a 5-line DAX expression becomes 5+ diff lines.
**How to avoid:** Parse TMSL diffs by tracking measure object boundaries: scan for the nearest `"name": "..."` field above a block of changed lines within the `"measures": [...]` array context. Group all changed lines between two `"name":` fields as one measure change.
**Warning signs:** Diff reports 10 measures modified when only 1 was changed.

### Pitfall 5: `.gitignore` Check Uses Wrong Entry Format
**What goes wrong:** The `.gitignore` check looks for `cache.abf` but the file contains `*.abf` — the check incorrectly reports it as missing and adds a duplicate entry.
**Why it happens:** `.gitignore` supports glob patterns; a check for the literal string misses broader patterns.
**How to avoid:** Check for any of: the literal file name (`cache.abf`) OR a covering glob pattern (`*.abf`). If either is present, consider it guarded. When adding entries, prefer glob patterns for file extensions (`*.abf`) and exact matches for specific file names (`localSettings.json`, `.pbi-context.md`).
**Warning signs:** `.gitignore` accumulates duplicate entries on repeated `/pbi:diff` runs.

### Pitfall 6: Auto-Commit Races With Ongoing TMDL Writes
**What goes wrong:** In theory, if a write is interrupted mid-file, `git commit` could capture an incomplete TMDL file.
**Why it happens:** The bash auto-commit block runs after the Write tool confirms — in practice the Write tool is atomic from Claude's perspective, so this is not a real risk in the skill execution model. The Write tool completes fully before the next instruction executes.
**How to avoid:** The current sequential instruction model (Write tool → then bash auto-commit) is safe. Document this assumption in the skill.
**Warning signs:** (Not expected to occur — noted for completeness.)

---

## Code Examples

Verified patterns from git documentation and project conventions:

### Repo Existence and Commit History Check
```bash
# Run as single bash injection in SKILL.md startup
GIT_CHECK=$(git rev-parse --is-inside-work-tree 2>/dev/null && echo "GIT=yes" || echo "GIT=no")
HAS_COMMITS=$(git rev-parse HEAD 2>/dev/null && echo "HAS_COMMITS=yes" || echo "HAS_COMMITS=no")
echo "$GIT_CHECK $HAS_COMMITS"
```

### PBIP-Scoped Diff (TMDL project)
```bash
# Staged + unstaged changes against last commit, scoped to model files only
git diff HEAD -- '.SemanticModel/definition/tables/' '.SemanticModel/definition/relationships.tmdl' 2>/dev/null
# Fallback for empty repo (no HEAD):
git status --porcelain '.SemanticModel/' 2>/dev/null
```

### PBIP-Scoped Diff (TMSL project)
```bash
git diff HEAD -- '.SemanticModel/model.bim' 2>/dev/null
```

### Stage PBIP Files Only
```bash
git add '.SemanticModel/' 2>/dev/null
```

### Commit With Multi-Line Message
```bash
git commit -m "feat: add [Revenue YTD] measure to Sales

- add [Revenue YTD] to Sales
- modify [Total Cost] expression in Products" 2>/dev/null
```

### .gitignore Noise Entry Check (bash)
```bash
# Check for cache.abf guard (literal OR glob)
if grep -qE '^(cache\.abf|\*\.abf)' .gitignore 2>/dev/null; then
  echo "ABF_GUARDED=yes"
else
  echo "ABF_GUARDED=no"
fi
```

### .gitignore Auto-Fix (append missing entries)
```bash
# Append only if not already present
grep -q "localSettings.json" .gitignore 2>/dev/null || echo "localSettings.json" >> .gitignore
grep -q ".pbi-context.md" .gitignore 2>/dev/null || echo ".pbi-context.md" >> .gitignore
grep -qE '^(\*\.abf|cache\.abf)' .gitignore 2>/dev/null || echo "*.abf" >> .gitignore
grep -q "SecurityBindings" .gitignore 2>/dev/null || echo "SecurityBindings" >> .gitignore
```

### Git Init + Initial Commit Flow
```bash
git init 2>/dev/null && echo "INIT=ok" || echo "INIT=fail"
# (then Write .gitignore with Write tool)
git add '.SemanticModel/' '.gitignore' 2>/dev/null
git commit -m "chore: initial PBIP model commit" 2>/dev/null && echo "COMMIT=ok" || echo "COMMIT=fail"
```

---

## Skill SKILL.md Header Patterns (for new skills)

Both new skills follow the exact same header pattern as pbi-audit (the most recent comparable skill):

```yaml
---
name: pbi-diff
description: Show a human-readable summary of PBIP model changes since the last git commit. Use when an analyst asks what changed, wants a diff, or wants to review model changes before committing.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Write, Bash
---
```

```yaml
---
name: pbi-commit
description: Stage PBIP model changes and create a local git commit with an auto-generated business-language message. Use when an analyst wants to commit changes or save a snapshot of the model.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Write, Bash
---
```

**Key difference from pbi-comment and pbi-error:** Both new skills need `Bash` in `allowed-tools` (git CLI calls). Existing writing skills currently only have `Read, Write` — the auto-commit block additions to pbi-comment and pbi-error will require adding `Bash` to their `allowed-tools` frontmatter.

---

## Existing Skill Modification Scope

### pbi-comment changes required
1. **Frontmatter:** Add `Bash` to `allowed-tools` (currently `Read, Write`).
2. **After Step 6 write confirmation line:** Add auto-commit bash block (see Pattern 5 above).
3. **Output:** Append auto-commit confirmation line (or no-repo hint) after "Written to:" line.
4. **Context update (Step 7):** No change needed — auto-commit is already recorded in the write confirmation line.

### pbi-error changes required
1. **Frontmatter:** Add `Bash` to `allowed-tools` (currently `Read, Write`).
2. **After step 6 "Written to:" line** (inside File Fix Preview section, after `y` confirmation and write): Add auto-commit bash block.
3. **Output:** Append auto-commit confirmation line (or no-repo hint) after "Written to:" line.
4. **Step 6 context update:** No change needed.

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|-----------------|--------|
| Manual git staging and commit with generic messages | Auto-generated conventional commit messages with model-aware content | Analysts get meaningful git history without knowing git message conventions |
| No `.gitignore` guard | Proactive auto-fix before diff output | Prevents Power BI cache files and local settings from polluting git history silently |

**No deprecated patterns in scope** — git CLI behavior used here (`git diff HEAD`, `git add`, `git commit`, `git init`, `git rev-parse`) is stable across all modern git versions.

---

## Open Questions

1. **Windows path quoting for git on Windows**
   - What we know: The project runs on Windows 11 (shell: bash). Git bash on Windows accepts forward-slash paths. Single-quoted glob patterns in `git diff HEAD -- '...'` work in git bash.
   - What's unclear: Whether `find` or `ls` pattern expansions differ between git bash on Windows vs Linux; however, we do not use `find` in these skills — git handles the path matching directly.
   - Recommendation: Use forward slashes in all git path arguments; single-quote glob patterns to prevent shell expansion. Test `git diff HEAD -- '.SemanticModel/'` early in Wave 0 manual validation.
   - Confidence: MEDIUM — git bash on Windows is well-documented but path quoting edge cases occasionally appear.

2. **TMDL measure block boundary detection in diff output**
   - What we know: TMDL uses tab-indented blocks. A measure block starts at `measure Name =` and ends at the next `measure`, `column`, `table`, or EOF. In a diff, context lines blur boundaries.
   - What's unclear: Whether there are edge cases where measure names contain characters that break simple `measure Name =` regex matching (e.g., measures with spaces in names use single quotes: `measure 'Revenue YTD' =`).
   - Recommendation: The parsing instructions in the SKILL.md must handle both `measure Name =` and `measure 'Name' =` forms — identical to the existing pbi-load and pbi-comment skill patterns that already handle both forms.
   - Confidence: HIGH — both name forms are documented and handled in prior skills.

---

## Validation Architecture

nyquist_validation is enabled (config.json: `"nyquist_validation": true`).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual / bash fixture-based (no automated test runner detected) |
| Config file | none — tests are manual inspection against fixtures in `tests/fixtures/` |
| Quick run command | `cd tests/fixtures/pbip-tmdl && git diff HEAD -- '.SemanticModel/' 2>/dev/null` |
| Full suite command | Manual walkthrough of all scenarios against both fixture types |

**Note:** No automated test runner (pytest, jest, vitest) exists in this project. Validation is manual testing against the fixture directories at `tests/fixtures/pbip-tmdl/` and `tests/fixtures/pbip-tmsl/`. This is consistent with all prior phases.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Validation Method | Fixture Exists? |
|--------|----------|-----------|-------------------|----------------|
| GIT-01 | `/pbi:diff` shows count summary in business language | manual | Run `/pbi:diff` in pbip-tmdl fixture after modifying Sales.tmdl; verify output says "1 measure modified in Sales" | ✅ `tests/fixtures/pbip-tmdl` |
| GIT-02 | Diff uses measure/table names, not JSON key paths | manual | Inspect `/pbi:diff` output; confirm no `model.tables[0]` style text appears | ✅ same fixture |
| GIT-03 | `.gitignore` guard check before diff output | manual | Run `/pbi:diff` with missing `.gitignore` entries; verify entries added silently, diff proceeds | ❌ Wave 0: create `.gitignore` test variant |
| GIT-04 | `/pbi:commit` stages and commits PBIP files | manual | Run `/pbi:commit` in fixture; verify `git log` shows new commit with only `.SemanticModel/` files | ✅ same fixture |
| GIT-05 | Commit message names actual model changes | manual | Inspect `git log --oneline` after `/pbi:commit`; verify subject line names measure/table | ✅ same fixture |
| GIT-06 | Auto-commit after pbi-comment write | manual | Run `/pbi:comment` in PBIP file mode with Desktop closed; verify auto-commit confirmation line appears and `git log` shows new commit | ✅ `tests/fixtures/pbip-tmdl` |
| GIT-07 | No auto-push ever occurs | manual | Verify no `git push` command appears in any skill output or SKILL.md file content | ✅ (inspection only) |
| GIT-08 | `/pbi:commit` inits repo if none exists | manual | Run `/pbi:commit` in a directory with PBIP files but no `.git/`; verify repo created, `.gitignore` written, initial commit created | ❌ Wave 0: create no-repo test directory |

### Sampling Rate
- **Per task:** Manual inspection of bash block output and git log after each skill execution
- **Per wave merge:** Run all manual scenarios against both TMDL and TMSL fixtures
- **Phase gate:** All 8 GIT requirements manually verified before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/fixtures/pbip-tmdl-no-gitignore/` — copy of TMDL fixture with no `.gitignore` file, to test GIT-03 auto-fix
- [ ] `tests/fixtures/pbip-no-repo/` — PBIP model directory with no `.git/` folder, to test GIT-08 init flow
- [ ] Git history in TMDL fixture — the existing fixture has no git history; Wave 0 must run `git init` and make an initial commit in `tests/fixtures/pbip-tmdl/` to enable `git diff HEAD` testing

---

## Sources

### Primary (HIGH confidence)
- Git documentation (man pages / git-scm.com): `git diff`, `git add`, `git commit`, `git init`, `git rev-parse` — all behavior described is standard documented git
- Project SKILL.md files (pbi-comment, pbi-error, pbi-audit, pbi-load): all startup patterns, frontmatter conventions, allowed-tools patterns, and write-back flows verified by direct file reading

### Secondary (MEDIUM confidence)
- Conventional Commits specification (conventionalcommits.org v1.0.0): `feat:`, `fix:`, `chore:` prefix semantics — widely adopted, locked in CONTEXT.md decisions
- TMDL format structure: inferred from `tests/fixtures/pbip-tmdl/` fixture files which demonstrate the actual on-disk format used in this project

### Tertiary (LOW confidence)
- Windows git bash path quoting behavior: general knowledge; not verified with specific Windows + git bash test. Flag for manual validation in Wave 0.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — git CLI only; no new libraries
- Architecture patterns: HIGH — git commands are documented; SKILL.md patterns match established project conventions directly observed in existing skills
- Diff parsing rules: MEDIUM — TMDL parsing is straightforward; TMSL JSON diff attribution requires careful implementation attention
- Pitfalls: HIGH — identified from direct analysis of git behavior and existing project file formats
- Windows path handling: MEDIUM — functional in git bash but warrants early validation

**Research date:** 2026-03-12
**Valid until:** 2026-09-12 (git CLI behavior is highly stable; PBIP format changes are the main risk)
