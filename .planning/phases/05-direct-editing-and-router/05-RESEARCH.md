# Phase 5: Direct Editing and Router - Research

**Researched:** 2026-03-12
**Domain:** Claude skill system / PBIP file editing / plain-language routing
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Edit input style**
- Prompt-then-describe pattern: command responds "Describe the change you want to make:" and waits — consistent with /pbi:explain and /pbi:comment
- Accepts any model change (rename, expression update, format string, display folder, description, relationships, table properties — anything the analyst can describe in plain language)
- If the analyst's change involves updating a measure expression, the command asks them to paste the new DAX — same paste-in pattern as other pbi commands
- PBIP project required: if no `.SemanticModel/` found, output "No PBIP project found. Run /pbi:edit from a directory containing .SemanticModel/." and stop — no paste-in fallback mode

**Ambiguity resolution**
- When target matches multiple entities (e.g., [Revenue] in Sales, Products, Finance): show all candidates and ask which one. "Found [Revenue] in: Sales, Products, Finance. Which table?"
- When target doesn't exist: suggest close fuzzy matches. "No measure named [Revnue] found. Did you mean: [Revenue] (Sales), [Revenue YTD] (Sales)?"
- When analyst describes a creation (e.g., "add measure [Revenue YTD] to Sales"): treat creation as a valid edit operation — scaffold the entity in the right table file and proceed through the normal preview/confirm flow

**Change preview format**
- Human-readable Before/After in labelled code blocks (not raw `+/-` diff)
- Always show the target file path as a header: `File: .SemanticModel/definition/tables/Sales.tmdl`
- Format:
  ```
  File: .SemanticModel/definition/tables/Sales.tmdl

  **Before**
  [code block with original TMDL snippet]

  **After**
  [code block with modified TMDL snippet]

  Write this change? (y/N)
  ```
- Default is N (capital N) — pressing Enter = cancel. On N: "Change discarded. No files modified." Consistent with pbi-error confirm-before-write pattern

**Pre-write checklist (EDIT-02)**
- Desktop-closed confirmation (same guard as pbi-comment/pbi-error)
- `unappliedChanges.json` check: if file exists in `.SemanticModel/`, warn "unappliedChanges.json detected — Desktop may have unsaved changes. Proceed anyway? (y/N)"
- TMDL indentation preservation: when writing TMDL, read the existing file first, match exact indentation style (spaces vs tabs, indent depth) before writing back

**Auto-commit (EDIT-04 / GIT-06)**
- After successful write: silent commit + one confirmation line: `Auto-committed: chore: update [MeasureName] in TableName`
- Carries forward Phase 4 established pattern exactly — conventional commit `chore:` prefix for metadata edits, `feat:` for additions
- If no git repo: skip commit, show hint "No git repo — run /pbi:commit to initialise one." File write still succeeds

**Router — bare /pbi**
- Free-form routing: if analyst types `/pbi [intent]` (with inline text), Claude reads intent and routes directly to the right subcommand without showing a menu
- Bare `/pbi` with no inline text: show a category-based menu (not individual command list)
- Category menu groups: "Work on a DAX measure", "Audit the model", "See or commit changes", "Edit a model file"
- After category selection: one follow-up question to narrow to exact command (e.g., "Which DAX command: explain, format, optimise, comment?") before launching

### Claude's Discretion
- Exact fuzzy match algorithm for close-match suggestions (edit distance, prefix match, etc.)
- How to parse free-form analyst intent into a target command in the router
- Exact wording of routing follow-up questions

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INFRA-02 | Bare `/pbi` command asks what the analyst needs and routes to the appropriate subcommand | New skill at `.claude/skills/pbi/SKILL.md`; `$ARGUMENTS` pattern distinguishes inline intent from bare invocation; category menu with two-step routing |
| EDIT-01 | User can run `/pbi:edit` with a description of what to change and Claude reads the relevant PBIP files, applies the change, and writes back to disk | New skill at `.claude/skills/pbi-edit/SKILL.md`; uses same three-block startup, Read tool to locate and read target file, Write tool to write back |
| EDIT-02 | Edit command performs pre-write checklist: Desktop-closed confirmation, `unappliedChanges.json` check, TMDL indentation preservation | Desktop guard reused from pbi-comment; `unappliedChanges.json` check via bash stat; indentation-read-then-match rule in skill instructions |
| EDIT-03 | Edit command shows a preview of the change before writing (diff of before/after) and requires confirmation | Human-readable Before/After in labelled code blocks with explicit `File:` header; capital-N default confirm prompt |
| EDIT-04 | After a successful edit, an automatic local git commit is created (satisfies GIT-06) | Auto-commit bash block copied from pbi-comment/pbi-error; `chore:` prefix for metadata, `feat:` for additions |
</phase_requirements>

---

## Summary

Phase 5 introduces two new SKILL.md files and no other new tooling. `pbi-edit` is a general-purpose model editor that follows the same architecture as `pbi-comment` and `pbi-error` but accepts any describable change (not just expression comments or error fixes). The bare `pbi` router is a lightweight orchestrator that reads `$ARGUMENTS` to distinguish inline intent from a bare invocation and either routes immediately or presents a two-step category menu.

The central technical challenge in `pbi-edit` is entity resolution: the skill must map a natural-language change description (e.g., "rename measure [Revenue] to [Total Revenue]") to the exact target file and block, handle ambiguity (multiple tables), handle near-miss names (fuzzy match), and handle creation requests (scaffold new entity). All of these resolution patterns build directly on mechanisms that already exist in `pbi-comment` and `pbi-error` — the `grep -rl "measure.*[MeasureName]"` bash lookup, the before/after preview with capital-N default, and the auto-commit block. None need to be invented from scratch.

The router (`pbi` bare skill) has no file I/O of its own. Its only job is reading `$ARGUMENTS`, deciding whether to route directly or show a menu, and — when a menu is shown — waiting for the analyst to select a category before asking one follow-up question. The existing skill descriptions in each SKILL.md frontmatter provide all the source material needed to write the menu copy.

**Primary recommendation:** Build both skills as new SKILL.md files following the exact header pattern of `pbi-commit`/`pbi-diff`. `pbi-edit` copies the startup three-block pattern verbatim. The router (`pbi`) is the simplest skill in the suite — no bash injections, no file reads, just conditional routing logic in plain instructions.

---

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Claude SKILL.md system | current | Skill definition and execution | All nine existing pbi skills use this format |
| Bash `!` injection blocks | system | PBIP detection, desktop check, session context, git operations | Established in all writing skills (pbi-comment, pbi-error) |
| `grep -rl` | system | Locate target entity in TMDL file tree | Already in pbi-comment and pbi-error for measure lookup |
| Read / Write tools | current | File read and write-back | Same tools used by every existing writing skill |

### No New Libraries Required
Phase 5 introduces no new external dependencies. All tools are already present in the project: bash for detection and git, Read/Write tools for file I/O, and Claude's natural language capability for entity resolution and fuzzy matching.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Claude doing fuzzy match inline | Levenshtein distance via bash/python script | Claude handles the fuzzy match as a reasoning step — consistent with how all other skill logic works; a shell script adds a file and a dependency with no benefit at this scope |
| Two-step category menu for router | Full command list | Locked decision: category groups reduce cognitive load for analysts unfamiliar with the full command suite |

---

## Architecture Patterns

### Recommended Project Structure
```
.claude/skills/
├── pbi/
│   └── SKILL.md          # new: bare /pbi router
├── pbi-edit/
│   └── SKILL.md          # new: /pbi:edit command
├── pbi-comment/
│   └── SKILL.md          # no changes required
├── pbi-error/
│   └── SKILL.md          # no changes required
└── [all other skills unchanged]
```

No changes to any existing skill are required for Phase 5. Both auto-commit (GIT-06) and the Desktop guard (INFRA-06) are already in pbi-comment and pbi-error from Phase 4. Phase 5 reuses those patterns unchanged in the new `pbi-edit` skill.

### Pattern 1: pbi-edit Startup Block (Three Bash Injections)
**What:** Identical to all writing skills — PBIP detection, Desktop check, session context.
**When to use:** Top of `pbi-edit/SKILL.md`, before any instructions.

```yaml
---
name: pbi-edit
description: Describe any model change in plain language and have Claude apply it directly to PBIP files. Use when an analyst wants to rename a measure, update an expression, change a format string, update a display folder, modify a description, or make any other model property change.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Write, Bash
---

## PBIP Detection
!`PBIP_RESULT=""; if [ -d ".SemanticModel" ]; then PBISM=$(cat ".SemanticModel/definition.pbism" 2>/dev/null); if echo "$PBISM" | grep -q '"version": "1.0"'; then PBIP_RESULT="PBIP_MODE=file PBIP_FORMAT=tmsl"; else PBIP_RESULT="PBIP_MODE=file PBIP_FORMAT=tmdl"; fi; else PBIP_RESULT="PBIP_MODE=paste"; fi; echo "$PBIP_RESULT"`

## Desktop Check
!`tasklist /fi "imagename eq PBIDesktop.exe" 2>/dev/null | findstr /i "PBIDesktop.exe" >nul 2>&1 && echo "DESKTOP=open" || echo "DESKTOP=closed"`

## Session Context
!`cat .pbi-context.md 2>/dev/null | tail -80 || echo "No prior context found."`
```

**Confidence:** HIGH — verbatim copy of pbi-comment and pbi-error startup.

### Pattern 2: PBIP-Only Guard (No Paste-In Fallback)
**What:** Unlike other skills, `pbi-edit` stops immediately on `PBIP_MODE=paste` with a specific message. There is no paste-in mode.
**When to use:** First branch check after startup blocks in pbi-edit instructions.

```
If PBIP Detection output contains PBIP_MODE=paste:
  Output: "No PBIP project found. Run /pbi:edit from a directory containing .SemanticModel/."
  Stop. Do not proceed.
```

**Confidence:** HIGH — locked decision in CONTEXT.md.

### Pattern 3: unappliedChanges.json Check
**What:** Additional pre-write guard unique to pbi-edit. Check for presence of `unappliedChanges.json` in `.SemanticModel/` before writing.
**When to use:** In pbi-edit pre-write checklist (Step: Pre-Write Checks), after Desktop guard passes.

```bash
ls ".SemanticModel/unappliedChanges.json" 2>/dev/null && echo "UNAPPLIED=yes" || echo "UNAPPLIED=no"
```

If `UNAPPLIED=yes`: output warning and prompt:
```
unappliedChanges.json detected — Desktop may have unsaved changes. Proceed anyway? (y/N)
```
Default N — on N: "Write cancelled. No files modified." On Y: proceed to write.

**What is unappliedChanges.json?** Power BI Desktop writes this file to `.SemanticModel/` when it has in-memory model changes that have not yet been saved back to the PBIP files. If this file is present, the PBIP files on disk do not reflect the current state of the model — writing over them risks discarding unsaved Desktop changes. This check is new to Phase 5 (not present in pbi-comment or pbi-error).

**Confidence:** HIGH — file behavior confirmed by PBIP format documentation and established project knowledge. The file path and existence check are straightforward bash.

### Pattern 4: Entity Resolution Flow
**What:** Map a natural-language change description to a specific file and block. This is the core of pbi-edit and the most complex part of the skill.
**When to use:** After analyst describes the change, before preview generation.

**Resolution steps (TMDL):**

1. **Parse the description** — extract: entity type (measure / column / table / relationship), entity name, table name (if given), and change type (rename / update expression / update formatString / update displayFolder / update description / add / remove).

2. **Locate the file:**
   ```bash
   grep -rl "measure.*[EntityName]" ".SemanticModel/definition/tables/" 2>/dev/null
   ```
   - Zero results → fuzzy match suggestion (see Pattern 5)
   - One result → proceed
   - Multiple results → ambiguity prompt: "Found [EntityName] in: Table1, Table2. Which table?"

3. **Read the file** (Read tool) — extract the target block (measure block, column block, table header, or relationships.tmdl for relationship edits).

4. **Apply the change in memory** — compute the modified block content without writing yet.

5. **Show Before/After preview** (see Pattern 6).

6. **On confirmation, write back** — Write tool with full file content (not partial write). Preserve all other content exactly.

**Resolution steps (TMSL):**

1. Read `.SemanticModel/model.bim`.
2. Find the target measure/column/table in the JSON structure by name.
3. Zero results → fuzzy match suggestion; multiple → ambiguity prompt (same as TMDL).
4. Apply change in memory to the JSON object.
5. Before/After preview shows the JSON snippet containing the changed fields.
6. On confirmation, write back the entire `model.bim`.

**Confidence:** HIGH — this is a direct extension of the grep-locate → Read → modify → Write pattern already in pbi-comment (TMDL) and pbi-error (both formats).

### Pattern 5: Fuzzy Match for Near-Miss Names
**What:** When entity resolution returns zero results, suggest close matches instead of failing hard.
**When to use:** In pbi-edit entity resolution when grep returns no match.

Claude performs the fuzzy match as a reasoning step:
1. Run `grep -r "measure " ".SemanticModel/definition/tables/" 2>/dev/null` to list all measure names in the project.
2. Compare the requested name to the list using edit-distance reasoning (common typos: transposed letters, dropped letters, incorrect capitalisation).
3. Output up to 3 candidates: "No measure named [RequestedName] found. Did you mean: [Candidate1] (Table1), [Candidate2] (Table1)?"
4. Wait for analyst to clarify or confirm.

For TMSL, extract all measure names from the `"name"` fields in the `"measures"` arrays of `model.bim`.

**Confidence:** HIGH for the overall pattern. The fuzzy matching itself is Claude's discretion (CONTEXT.md) — the implementation is Claude's natural language reasoning, not a fixed algorithm. This is appropriate and consistent with how all other reasoning tasks are handled in the skill suite.

### Pattern 6: Before/After Preview with Confirm
**What:** Human-readable change preview before any write. Reuses the confirmed pbi-error pattern with a new `File:` header.
**When to use:** After entity resolution and change computation, before write.

```
File: .SemanticModel/definition/tables/Sales.tmdl

**Before**
```tmdl
measure Revenue =
		SUM(Sales[Amount])
	formatString: #,##0
	displayFolder: "Base Measures"
```

**After**
```tmdl
measure 'Total Revenue' =
		SUM(Sales[Amount])
	formatString: #,##0
	displayFolder: "Base Measures"
```

Write this change? (y/N)
```

- "y" or "Y": proceed to write
- "n", "N", or Enter: "Change discarded. No files modified."

**Key difference from pbi-error:** The `File:` header is always shown (locked decision). The pbi-error preview did not include a file path header — pbi-edit adds it.

**Confidence:** HIGH — directly extends the pbi-error confirm-before-write pattern. The format is locked in CONTEXT.md.

### Pattern 7: Creation / Scaffold Flow
**What:** When the analyst describes adding a new entity (e.g., "add measure [New Calc] to Sales"), treat it as an edit operation — scaffold the new entity and run through the normal preview/confirm flow.
**When to use:** When entity resolution detects a "create" intent (keywords: "add", "create", "new") and the entity does not yet exist.

**TMDL scaffold for a new measure in Sales.tmdl:**
```tmdl
	measure 'New Calc' =
			[expression]
		formatString: 0
```
- Insert after the last existing measure block in the target table file, before the trailing blank line.
- Ask for the expression: "Paste the DAX expression for [New Calc]:"
- Then proceed through the normal Before/After preview (Before shows the current end of the file; After shows the new measure appended).

**Auto-commit prefix for creation:** `feat:` (per Phase 4 convention — additions use `feat:`).

**Confidence:** HIGH — creation is explicitly a valid operation (locked in CONTEXT.md). The TMDL structure is known from fixtures; the scaffold pattern follows the existing indentation style (tab-indented, same as Sales.tmdl).

### Pattern 8: Auto-Commit Block (copied from pbi-comment/pbi-error)
**What:** After successful write, run a git commit with conventional commit message.
**When to use:** In pbi-edit, inside the `y` confirmation branch, after Write tool completes.

```bash
GIT_STATUS=$(git rev-parse --is-inside-work-tree 2>/dev/null && echo "yes" || echo "no")
if [ "$GIT_STATUS" = "yes" ]; then
  git add '.SemanticModel/' 2>/dev/null
  git commit -m "[PREFIX]: [VERB] [ENTITY_NAME] in [TABLE_NAME]" 2>/dev/null && echo "AUTO_COMMIT=ok" || echo "AUTO_COMMIT=fail"
else
  echo "AUTO_COMMIT=skip_no_repo"
fi
```

Commit message prefix selection:
- Metadata change (rename, formatString, displayFolder, description): `chore:`
- Expression update: `chore:`
- Entity creation: `feat:`
- Entity removal: `fix:`

Output:
- `AUTO_COMMIT=ok`: `Auto-committed: [full commit message]`
- `AUTO_COMMIT=skip_no_repo`: `No git repo — run /pbi:commit to initialise one.`
- `AUTO_COMMIT=fail`: silent (non-fatal)

**Confidence:** HIGH — verbatim from pbi-comment and pbi-error Phase 4 patterns.

### Pattern 9: pbi Router (bare /pbi) Skill
**What:** A minimal routing skill that reads `$ARGUMENTS`. No bash injections, no file reads.
**When to use:** New skill at `.claude/skills/pbi/SKILL.md`.

**Frontmatter:**
```yaml
---
name: pbi
description: Power BI skill suite entry point. Routes to the appropriate /pbi subcommand based on analyst intent. Use when an analyst types /pbi with or without a description of what they need.
disable-model-invocation: true
model: sonnet
allowed-tools: []
---
```

**Routing logic:**

```
If $ARGUMENTS is non-empty:
  Read the inline text as analyst intent.
  Map intent to the most relevant subcommand:
    - "explain" / "what does" / "understand" → /pbi:explain
    - "format" / "clean up" / "prettify" → /pbi:format
    - "optimise" / "optimize" / "performance" / "speed up" → /pbi:optimise
    - "comment" / "annotate" / "document" → /pbi:comment
    - "audit" / "health check" / "review model" → /pbi:audit
    - "diff" / "what changed" / "changes" → /pbi:diff
    - "commit" / "save" / "snapshot" → /pbi:commit
    - "error" / "fix" / "diagnose" → /pbi:error
    - "edit" / "rename" / "update" / "change" / "modify" → /pbi:edit
    - "load" / "context" / "model context" → /pbi:load
  Output: "Routing to /pbi:[subcommand] — [brief description of what it does]."
  Then immediately execute the behaviour of that subcommand (or instruct the analyst to run /pbi:[subcommand] if execution requires a separate invocation).

If $ARGUMENTS is empty (bare /pbi):
  Output the category menu:

  > What would you like to do?
  >
  > **A — Work on a DAX measure**
  >    explain, format, optimise, comment
  >
  > **B — Audit the model**
  >    audit
  >
  > **C — See or commit changes**
  >    diff, commit
  >
  > **D — Edit a model file**
  >    edit
  >
  > Type A, B, C, or D — or describe what you need and I'll route you directly.

  On selection:
  - A: "Which DAX command? explain · format · optimise · comment"
  - B: Route directly to /pbi:audit (only one command in category)
  - C: "Which command? diff — see what changed · commit — save a snapshot"
  - D: Route directly to /pbi:edit (only one command in category)

  On free-text response: apply the intent mapping above and route directly.
```

**Note on `allowed-tools: []`:** The router has no file I/O and no bash calls. It is pure conversational routing. Setting `allowed-tools` to empty (or omitting it) is consistent with the router's purpose. Check whether the Claude skill system supports empty `allowed-tools` — if not, set `allowed-tools: Read` as a safe default (Read will never be called but satisfies any schema requirement).

**Confidence:** HIGH for the routing logic. MEDIUM for `allowed-tools: []` syntax — verify against existing skills if empty array causes a parse error; fallback is `allowed-tools: Read`.

### Pattern 10: Context Update (pbi-edit)
**What:** After each successful edit, update `.pbi-context.md` using Read-then-Write.
**When to use:** At the end of pbi-edit, after write confirmation and auto-commit.

Updates:
- `## Last Command`: Command = `/pbi:edit`, Timestamp = UTC ISO 8601, Measure = `[EntityName] in [TableName]`, Outcome = `[Change type] applied`
- `## Command History`: Append row, keep to 20 rows max.
- Do NOT modify `## Analyst-Reported Failures`.

**Confidence:** HIGH — identical pattern to all existing writing skills.

### Anti-Patterns to Avoid
- **Partial file writes:** Never write only the changed block back. Always read the full file, modify the target block in memory, then write the entire file back. Partial writes corrupt TMDL structure.
- **Assuming tab vs space indentation:** The fixture uses tab indentation (`\t`). Other PBIP projects may use spaces. Always read the existing file and match its indentation style before writing.
- **Skipping the unappliedChanges.json check:** This check is unique to pbi-edit (pbi-comment and pbi-error do not have it). It must be added to pbi-edit's pre-write flow; do not omit it for simplicity.
- **Auto-selecting when ambiguous:** When the same measure name exists in multiple tables, always ask the analyst — never guess the table.
- **Writing on capital-N or Enter default:** The confirm prompt default is N. Pressing Enter or typing N must result in "Change discarded. No files modified." Never write on ambiguous input.
- **Router showing the full command list:** The router menu shows category groups (4 categories), not individual commands (9+ commands). Showing individual commands defeats the purpose of the router.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PBIP format detection | Custom parser | Reuse pbi-comment/pbi-error PBIP detection bash block verbatim | Already tested across 4 phases; any deviation risks regression |
| Desktop process check | Custom OS process check | Reuse `tasklist /fi "imagename eq PBIDesktop.exe"` verbatim | Windows-specific, already validated in prior skills |
| Entity name lookup in TMDL | File walker + regex engine | `grep -rl "measure.*[Name]"` bash | Single line, sufficient for the project's file tree depth |
| Auto-commit logic | New git helper | Copy auto-commit bash block verbatim from pbi-comment | Idempotent; tested in Phase 4; no variation needed |
| Fuzzy match scoring | Levenshtein distance library | Claude inline reasoning over the names list | Consistent with how all other reasoning is done in skills; no extra files |

**Key insight:** pbi-edit is an orchestration skill, not a new technology. Every non-trivial pattern it needs already exists in the codebase. The only genuinely new element is the `unappliedChanges.json` check and the broader "any change" entity resolution scope.

---

## Common Pitfalls

### Pitfall 1: TMDL Indentation Corruption
**What goes wrong:** TMDL uses tab indentation. If pbi-edit writes the modified file with spaces (the default in many text outputs), Power BI Desktop will fail to parse the file.
**Why it happens:** Claude's text generation defaults to spaces in code blocks. The Write tool writes exactly what it is given — it does not re-indent.
**How to avoid:** The skill instructions must explicitly state: "Read the existing file first, observe whether it uses tabs or spaces and the indent depth. When writing the modified file back, preserve the exact indentation character and depth." The TMDL fixture uses a single tab (`\t`) per indent level — verify this is consistent across all fixture files.
**Warning signs:** Power BI Desktop reports a parse error on the .tmdl file immediately after an edit.

### Pitfall 2: Expression Ask Timing for DAX Changes
**What goes wrong:** If the analyst describes "update the expression of [Revenue YTD]", the skill needs the new DAX expression before it can generate the Before/After preview. If the skill generates a preview with a placeholder expression, the analyst confirms something they haven't seen yet.
**Why it happens:** The before/after preview requires the final After state, which requires the new expression.
**How to avoid:** When the change type is "update expression", ask for the DAX paste-in BEFORE generating the preview: "Paste the new DAX expression for [MeasureName]:" — then show the preview with the actual new expression, then ask for confirmation.

### Pitfall 3: unappliedChanges.json False Alarm
**What goes wrong:** The analyst has Power BI Desktop closed and there is no unappliedChanges.json, but the skill reports a warning anyway due to a stale file from a previous session.
**Why it happens:** Power BI Desktop does not always clean up `unappliedChanges.json` on close. The file may persist after Desktop exits.
**How to avoid:** The skill cannot distinguish a stale file from a live one. The locked decision is to warn and ask — this is correct behaviour. The analyst can confirm with `y` if they know the file is stale. Document this in the skill as expected behaviour, not a bug.
**Warning signs:** Analyst sees the warning even though they know Desktop is closed — they should respond `y` to proceed.

### Pitfall 4: TMSL Expression Array vs String Form
**What goes wrong:** In model.bim, a measure expression may be a JSON string (`"expression": "SUM(Sales[Amount])"`) or a JSON array (`"expression": ["line1", "line2"]`). If pbi-edit converts a string to an array (or vice versa) during write, Power BI Desktop may parse it differently or reject it.
**Why it happens:** Multi-line expressions use the array form. The pbi-comment skill already handles this — but a new developer writing pbi-edit may not know to check.
**How to avoid:** The skill must explicitly say: "Preserve the original expression form. If the original was a string, write back as a string. If it was an array, write back as an array. Only convert to array if the new expression contains line breaks and the original was a string." This rule is identical to the pbi-comment and pbi-error rule for TMSL.
**Warning signs:** model.bim becomes malformed JSON or Power BI shows a parse error after an expression update.

### Pitfall 5: Creation Scaffold Missing Required TMDL Properties
**What goes wrong:** When scaffolding a new measure, the skill omits required or strongly-recommended TMDL properties (formatString, displayFolder), producing a minimal measure block that triggers audit warnings.
**Why it happens:** The minimum valid TMDL measure is just `measure Name =\n\t\t[expression]` — but best practice (enforced by pbi-audit) requires formatString and displayFolder.
**How to avoid:** When creating a new measure, ask the analyst for the formatString and displayFolder, or default to sensible values (`formatString: 0` for numeric, `displayFolder: ""` for no folder). Document the defaults in the skill.

### Pitfall 6: Router allowed-tools Schema
**What goes wrong:** Setting `allowed-tools: []` in the router SKILL.md may cause a Claude skill system parse error if the schema requires at least one tool.
**Why it happens:** The skill system schema may validate that `allowed-tools` is a non-empty list.
**How to avoid:** Default to `allowed-tools: Read` in the router. The Read tool will never be called by the router, but it satisfies any non-empty list requirement without granting write or bash access.
**Warning signs:** `/pbi` fails to load at startup with a skill schema error.

---

## Code Examples

Verified patterns from existing project skills:

### unappliedChanges.json Check (bash)
```bash
# Run in pbi-edit pre-write checklist
ls ".SemanticModel/unappliedChanges.json" 2>/dev/null && echo "UNAPPLIED=yes" || echo "UNAPPLIED=no"
```

### PBIP-Only Guard
```
If PBIP_MODE=paste:
  Output: "No PBIP project found. Run /pbi:edit from a directory containing .SemanticModel/."
  Stop.
```

### Entity Lookup (TMDL)
```bash
# Locate measure file — same pattern as pbi-comment
grep -rl "measure.*Revenue" ".SemanticModel/definition/tables/" 2>/dev/null
```

### All Measure Names Dump (for fuzzy match)
```bash
# List all measure declarations across all TMDL tables
grep -r "measure " ".SemanticModel/definition/tables/" 2>/dev/null
```

### Before/After Preview Format (locked)
```
File: .SemanticModel/definition/tables/Sales.tmdl

**Before**
```tmdl
	measure Revenue =
			SUM(Sales[Amount])
		formatString: #,##0
		displayFolder: "Base Measures"
```

**After**
```tmdl
	measure 'Total Revenue' =
			SUM(Sales[Amount])
		formatString: #,##0
		displayFolder: "Base Measures"
```

Write this change? (y/N)
```

### Auto-Commit Block (pbi-edit variant)
```bash
GIT_STATUS=$(git rev-parse --is-inside-work-tree 2>/dev/null && echo "yes" || echo "no")
if [ "$GIT_STATUS" = "yes" ]; then
  git add '.SemanticModel/' 2>/dev/null
  git commit -m "chore: rename [Revenue] to [Total Revenue] in Sales" 2>/dev/null && echo "AUTO_COMMIT=ok" || echo "AUTO_COMMIT=fail"
else
  echo "AUTO_COMMIT=skip_no_repo"
fi
```

### Context Update After Edit (pbi-edit, Read-then-Write)
```
Last Command section:
  Command: /pbi:edit
  Timestamp: [current UTC ISO 8601]
  Measure: Revenue → Total Revenue in Sales
  Outcome: Rename applied
```

### TMDL Rename Pattern (in-memory, before Write)
Original Sales.tmdl block:
```
	measure Revenue =
			SUM(Sales[Amount])
		formatString: #,##0
		displayFolder: "Base Measures"
```

After rename to "Total Revenue":
```
	measure 'Total Revenue' =
			SUM(Sales[Amount])
		formatString: #,##0
		displayFolder: "Base Measures"
```
Note: Single-word measure names use no quotes; multi-word names use single quotes (e.g., `'Total Revenue'`). This matches the pattern already established in Sales.tmdl (`measure 'Revenue YTD'` vs `measure Revenue`).

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|-----------------|--------|
| Analyst edits TMDL/model.bim files directly in a text editor | `/pbi:edit` describes the change in plain language and Claude applies it | Eliminates manual JSON/TMDL syntax manipulation errors |
| Analyst must know which file contains a specific measure | Entity resolution via grep + ambiguity prompt | Analysts work by measure name, not file path |
| No confirmation before file changes | Before/After preview with capital-N default | Prevents accidental writes |

No deprecated patterns in scope. The patterns used (PBIP bash detection, grep-based lookup, Read/Write tools, auto-commit block) are all established in Phase 2-4 and remain current.

---

## Open Questions

1. **`allowed-tools: []` syntax validity in Claude skill system**
   - What we know: All existing skills have at least one tool in `allowed-tools`. No skill has an empty list.
   - What's unclear: Whether the SKILL.md schema permits an empty `allowed-tools` array.
   - Recommendation: Default to `allowed-tools: Read` for the router. The Read tool will never be called in practice, but it avoids any schema risk. Flag for validation in Wave 0 by testing bare `/pbi` invocation.
   - Confidence: MEDIUM

2. **TMDL measure quote rule: when are single quotes required?**
   - What we know: The fixture shows `measure 'Revenue YTD' =` (multi-word, quoted) and `measure Revenue =` (single-word, unquoted). This matches standard TMDL behaviour.
   - What's unclear: Whether there is a character set rule beyond "multi-word" (e.g., do names with special characters also require quotes? Do names starting with a digit?).
   - Recommendation: Apply the rule "if the measure name contains a space or special character, wrap in single quotes; otherwise unquoted" — consistent with what the fixture already demonstrates. Verify with a rename test in Wave 0.
   - Confidence: HIGH for the space rule; MEDIUM for special characters.

3. **Router $ARGUMENTS availability**
   - What we know: The Claude skill system passes inline text after the command name as `$ARGUMENTS`. All existing skills use this variable (e.g., `--table TableName` in pbi-comment).
   - What's unclear: Whether `$ARGUMENTS` is empty vs undefined vs absent when no text follows the command. The router's routing logic depends on this distinction.
   - Recommendation: Check for `$ARGUMENTS` being empty string or absent using the same pattern as the existing skills. If the variable is always defined (just empty when no text), the check `if [ -z "$ARGUMENTS" ]` works. Flag for manual test in Wave 0.
   - Confidence: HIGH — all prior skills use `$ARGUMENTS`; empty vs non-empty is a standard bash test.

---

## Validation Architecture

nyquist_validation is enabled (config.json: `"nyquist_validation": true`).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual / bash fixture-based (no automated test runner) |
| Config file | none — tests are manual inspection against fixtures in `tests/fixtures/` |
| Quick run command | Run `/pbi:edit` in `tests/fixtures/pbip-tmdl/` with a rename description; verify Sales.tmdl is updated correctly |
| Full suite command | Manual walkthrough of all scenarios for EDIT-01 through EDIT-04 and INFRA-02 against both TMDL and TMSL fixtures |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Validation Method | Fixture Exists? |
|--------|----------|-----------|-------------------|----------------|
| INFRA-02 | Bare `/pbi` shows category menu and routes to correct subcommand | manual | Run bare `/pbi` — verify category menu appears; select A → verify DAX question appears; then run `/pbi explain a measure` — verify direct route to /pbi:explain | ✅ No fixture needed (conversational only) |
| EDIT-01 | `/pbi:edit` reads PBIP files, applies change, writes back to disk | manual | Run `/pbi:edit` with "rename measure [Revenue] to [Total Revenue] in Sales" in `tests/fixtures/pbip-tmdl/`; verify Sales.tmdl shows `measure 'Total Revenue'` | ✅ `tests/fixtures/pbip-tmdl` |
| EDIT-02 | Pre-write checklist: Desktop check, unappliedChanges.json, TMDL indentation | manual | (a) Run with Desktop open → verify write blocked; (b) Create `tests/fixtures/pbip-tmdl/.SemanticModel/unappliedChanges.json` → verify warning prompt appears; (c) Inspect written file → verify tab indentation preserved | ✅ `tests/fixtures/pbip-tmdl` (needs unappliedChanges.json test variant — see Wave 0) |
| EDIT-03 | Before/After preview shown before write; confirmation required; capital-N default | manual | Run `/pbi:edit` with any change; verify `File:` header appears, Before/After blocks shown, `Write this change? (y/N)` prompt appears; press Enter → verify "Change discarded. No files modified." | ✅ `tests/fixtures/pbip-tmdl` |
| EDIT-04 | Auto-commit created after successful edit | manual | Run `/pbi:edit` through full y-confirm flow; verify `git log --oneline` shows new commit with correct message and `.SemanticModel/` files staged | ✅ `tests/fixtures/pbip-tmdl` (requires git history — same Wave 0 setup as Phase 4) |

### Sampling Rate
- **Per task:** Manual inspection of the modified fixture file and git log after each skill test
- **Per wave merge:** Run all 5 requirement scenarios against both TMDL and TMSL fixtures
- **Phase gate:** All EDIT-01 through EDIT-04 and INFRA-02 manually verified before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/fixtures/pbip-tmdl/.SemanticModel/unappliedChanges.json` (test file, to be created and deleted per test) — covers EDIT-02 unappliedChanges check
- [ ] Git history in `tests/fixtures/pbip-tmdl/` — if not already initialised from Phase 4 execution, Wave 0 must run `git init` and create an initial commit to enable EDIT-04 auto-commit verification
- [ ] `tests/fixtures/pbip-tmsl/` edit scenario — TMSL rename test: update `"name"` field in `model.bim` measures array; verify JSON integrity preserved

---

## Sources

### Primary (HIGH confidence)
- Existing project SKILL.md files (pbi-comment, pbi-error, pbi-load, pbi-commit, pbi-diff) — all startup patterns, entity lookup patterns, auto-commit blocks, and confirm-before-write flows verified by direct file reading
- `tests/fixtures/pbip-tmdl/` and `tests/fixtures/pbip-tmsl/` — TMDL and TMSL on-disk formats verified by direct file reading; indentation style, measure block structure, and TMSL JSON structure all confirmed
- `.planning/phases/05-direct-editing-and-router/05-CONTEXT.md` — all locked decisions and discretion areas read directly

### Secondary (MEDIUM confidence)
- `unappliedChanges.json` behaviour: established project knowledge in CONTEXT.md and STATE.md; the file's purpose (Desktop unsaved changes marker) is consistent with PBIP format documentation patterns
- Router `$ARGUMENTS` handling: inferred from how existing skills use `$ARGUMENTS` (e.g., `--table TableName` in pbi-comment); empty/non-empty distinction is standard bash behaviour

### Tertiary (LOW confidence)
- TMDL special-character quoting rules beyond the space rule: confirmed only by fixture observation, not by official Microsoft TMDL specification directly

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new libraries; all tooling already in project
- Architecture patterns: HIGH — both new skills are direct extensions of verified Phase 2-4 patterns
- Entity resolution / fuzzy match: HIGH for the flow; LOW for edge cases in special character quoting
- unappliedChanges.json check: HIGH for existence check logic; MEDIUM for stale-file behaviour documentation
- Router: HIGH for routing logic; MEDIUM for `allowed-tools: []` schema edge case

**Research date:** 2026-03-12
**Valid until:** 2026-09-12 (PBIP format and Claude skill system are stable; main risk is Power BI Desktop updates changing unappliedChanges.json semantics)
