# Phase 2: Context-Aware DAX - Research

**Researched:** 2026-03-14
**Domain:** Claude Code skill markdown instruction patterns — `.pbi-context.md` schema extension, multi-step branching logic in command `.md` files
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Context intake on fast path**
- When any DAX command runs and `.pbi-context.md` has no model context, ask: "Which table, and which columns are relevant to this measure?" — targeted ask, not a full schema dump
- Applies to ALL DAX subcommands (explain, format, optimise, comment, error, new), not just `/pbi new`
- Answer is stored in `.pbi-context.md` and reused for subsequent measures in the same session (no re-asking)
- If context is already present from a prior `/pbi load` or previous session, skip the ask

**Duplication check**
- Every `/pbi new` asks "Does a similar measure already exist in the model?" before generating — always-on, not conditional on context state
- Simple yes/no question format
- If user answers yes: ask "What's the existing measure?" then generate a new measure that extends or wraps the existing one (e.g., `CALCULATE([ExistingMeasure], filter)`) rather than duplicating the logic

**Filter-sensitive DAX trigger**
- Trigger pattern list: time intelligence (DATEYTD, SAMEPERIODLASTYEAR, TOTALYTD, DATESYTD) + ratio/rank (DIVIDE, RANKX, TOPN, PERCENTILEX)
- When a filter-sensitive pattern is detected, ask BEFORE generating: "Where will this be placed and what date/filter slicers are active?"
- Generate DAX only after the user answers — output is informed by visual context from the start
- Visual placement context (visual type + active slicers) is saved to `.pbi-context.md` and reused for subsequent filter-sensitive measures in the session

**Measures gate in deep mode**
- Triggered at the end of a deep mode session (Phase 2 scope: measures = end of session)
- Gate shows a summary of all measures generated in the session (measure names + target tables)
- Gate asks two things before closing:
  1. Restates the business question from `.pbi-context.md` and asks: "Do these measures answer it?"
  2. "All measures complete — confirm to close the deep mode session"
- Full business question verification flow (VERF-02) is Phase 3; this is a lightweight check only

### Claude's Discretion
- Exact phrasing of the context intake question per subcommand (explain vs new have different natural phrasing)
- How to detect the filter-sensitive pattern from the user's request text (keyword matching on function names vs intent reading)
- Whether to surface the "visual context saved" acknowledgment or silently store it

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INTR-04 | Before writing filter-sensitive DAX (ratios, time intelligence, ranking), skill asks about visual consumption context (where measure will be placed, active slicers) | Filter-sensitive detection section; `## Visual Context` schema extension |
| DAX-01 | Generated measures reference actual tables/columns described by user, not assumed generic schema | Context intake step pattern; Model Context reuse from `.pbi-context.md` |
| DAX-02 | Duplication check — skill asks if a similar measure already exists before writing a new one | Duplication check gate pattern in `new.md`; wrap-existing pattern |
| DAX-03 | Filter context warning surfaced when generating CALCULATE-heavy patterns without knowing visual placement | Filter-sensitive trigger list; pre-generation gate pattern |
| PHASE-02 | Measures phase — context-aware DAX generation, explicit gate before advancing to next phase | Measures gate in `deep.md`; session summary + confirmation pattern |
</phase_requirements>

---

## Summary

Phase 2 extends six existing DAX command files (`explain`, `format`, `optimise`, `comment`, `error`, `new`) and the `deep.md` session controller. All changes are instruction-text additions to markdown files — no new libraries, no new tooling, no new build steps. The entire implementation surface is:

1. A new context intake step prepended to each DAX command file (check `.pbi-context.md` for `## Model Context`, ask if absent, write if answered).
2. A duplication check gate added to `new.md` between requirement collection and generation.
3. A filter-sensitive pattern detection step added to `new.md` and the solve-first default handler, triggering a pre-generation visual context ask.
4. A `## Visual Context` section added to the `.pbi-context.md` schema to store visual placement + slicer data across the session.
5. A measures gate step appended to `deep.md` that summarises generated measures and requires user confirmation before the session closes.

The skill's execution model — markdown instructions interpreted by Claude Code at runtime — means "implementation" is prose and step specifications, not code. Correctness is validated by manual acceptance testing against defined scenarios. The existing test infrastructure (`tests/acceptance-scenarios.md`) is the right pattern for Phase 2 test coverage; the planner should add a Phase 2 acceptance scenario file in the same format.

**Primary recommendation:** Implement changes file-by-file. Each of the six DAX command files and `deep.md` can be planned and executed as an independent task, with one additional task for `.pbi-context.md` schema documentation. Tests are a final task producing a new acceptance scenarios file.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Markdown instruction files | — | Skill command implementation | This project's entire implementation surface; all Phase 1 delivered this way |
| `.pbi-context.md` | — | Cross-command session persistence | Established in Phase 1 as the canonical state store; all commands read/write it |
| Read + Write tools | — | File I/O within command instructions | Required for context persistence pattern; no bash alternatives used for context |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Bash tool (in skill) | — | Git auto-commit in `new.md`, `comment.md`, `error.md` | Only for git operations; never for `.pbi-context.md` writes |
| `grep -rlF` | — | Measure name search in TMDL files | Fixed-string flag essential — measure names contain special chars |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Markdown step-based context check | Separate routing file | Step-based is self-contained per command; separate routing adds cross-file dependency and complexity |
| Keyword matching for filter-sensitive detection | Intent reading | Keyword matching (exact function names) is deterministic; intent reading risks false positives on "what's the rate?" type questions |

**Installation:** None required. This phase modifies existing markdown files only.

---

## Architecture Patterns

### Current `.pbi-context.md` Schema

```markdown
# PBI Context

## Last Command
- Command: [command]
- Timestamp: [ISO 8601]
- Measure: [measure name]
- Outcome: [outcome]

## Command History
| Timestamp | Command | Measure Name | Outcome |
|-----------|---------|--------------|---------|

## Analyst-Reported Failures
| Timestamp | Command | Measure Name | What Failed | Notes |
|-----------|---------|--------------|-------------|-------|

## Model Context
[written by /pbi load OR by the new context intake step]

## Business Question
[written by /pbi deep]

## Existing Measures
[written by /pbi deep]

## Escalation State
[written by solve-first handler during escalation]
```

### Required Schema Addition: `## Visual Context`

```markdown
## Visual Context
- Visual type: [card | table | matrix | chart | slicer | unknown]
- Active slicers: [e.g., Date[Year], Product[Category]]
- Noted: [ISO 8601 timestamp]
```

This section is written when a filter-sensitive question is answered and reused for subsequent filter-sensitive measures in the same session.

### Pattern 1: Context Intake Step (all 6 DAX command files)

**What:** A new step prepended to each command's execution flow that checks whether `## Model Context` is present in Session Context. If absent, asks one targeted question and writes the answer before proceeding.

**When to use:** Every DAX command invocation. The check is lightweight — if context exists, it is a no-op. The step only blocks if context is genuinely absent.

**Step text template:**
```markdown
### Step 0.5 — Model Context Check

Read Session Context for `## Model Context` section.

- If `## Model Context` is present and non-empty: proceed to next step. Use table/column names from Model Context when generating DAX.
- If `## Model Context` is absent or empty:
  - Ask: "[Command-specific context question — see per-command phrasing below]"
  - Wait for the analyst's answer.
  - Read `.pbi-context.md` with Read tool. Add or update `## Model Context` with the analyst's answer. Write back with Write tool.
  - Proceed to next step using the newly stored context.
```

**Per-command phrasing (Claude's discretion items with recommended defaults):**

| Command | Context Question Phrasing |
|---------|--------------------------|
| `new` | "Which table should this measure go in, and which columns are relevant?" |
| `explain` | "Which table does this measure belong to?" (columns visible in the DAX itself) |
| `format` | "Which table does this measure belong to?" (format is structural, table helps with display folder inference) |
| `optimise` | "Which table does this measure belong to, and are there any related tables involved?" |
| `comment` | "Which table does this measure belong to?" |
| `error` | "Which table is this measure in, and what are the involved columns or tables?" |

### Pattern 2: Duplication Check Gate (`new.md` only)

**What:** A yes/no gate inserted between Step 1 (collect requirements) and Step 3 (generate measure components) in `new.md`.

**When to use:** Every `/pbi new` invocation, unconditionally.

**Step text:**
```markdown
### Step 2 — Duplication Check

Before generating, ask:

> "Does a similar measure already exist in the model?"

Wait for the analyst's answer.

- If **no**: proceed to Step 3 (generate).
- If **yes**: ask "What's the existing measure? (paste its DAX or name it)"
  - Wait for answer.
  - In Step 3, generate a measure that wraps or extends the existing one using CALCULATE or a similar wrapper pattern (e.g., `CALCULATE([ExistingMeasure], filter)`). Do NOT duplicate the base logic.
  - Note in the Step 4 output under Assumptions: "Wraps existing measure [Name] — extends rather than duplicates logic."
```

Note: This replaces the current Step 2 (Model Context Check) which moves to Step 0.5 (Context Intake). The current `new.md` Step 2 only fires in file mode; the new pattern applies universally.

### Pattern 3: Filter-Sensitive Detection Gate (`new.md` and solve-first handler)

**What:** A detection step that inspects the analyst's stated business intent or pasted DAX for filter-sensitive function keywords. If detected, it asks about visual placement BEFORE generating.

**When to use:** In `new.md`, after requirements are collected (before generation). In the solve-first handler, after understanding the request (before generating a solution).

**Trigger keyword list (exact strings, case-insensitive):**
- Time intelligence: `DATEYTD`, `SAMEPERIODLASTYEAR`, `TOTALYTD`, `DATESYTD`, `DATEADD`, `PARALLELPERIOD`, `DATESBETWEEN`
- Ratio/rank: `DIVIDE`, `RANKX`, `TOPN`, `PERCENTILEX`

**Detection source:** The analyst's request description text (not a generated DAX string). Look for function name mentions or intent phrases like "year to date", "same period last year", "ratio", "rank", "top N", "percentage of".

**Step text:**
```markdown
### Step 2.5 — Filter-Sensitive Pattern Check

Scan the analyst's stated business intent for these patterns:
- Time intelligence: DATEYTD, SAMEPERIODLASTYEAR, TOTALYTD, DATESYTD, DATEADD, PARALLELPERIOD; or phrases "year to date", "same period last year", "prior year", "month-to-date"
- Ratio/rank: DIVIDE, RANKX, TOPN, PERCENTILEX; or phrases "as a percentage", "ratio", "rank", "top N", "share of"

If **no pattern detected**: proceed to Step 3 (generate).

If **pattern detected**:
1. Check Session Context for `## Visual Context` section.
   - If present and non-empty: use stored visual placement context. Note it in the output: "Using saved visual context: [type] with [slicers]." Proceed to Step 3.
   - If absent or empty: ask before generating:
     > "This measure is filter-sensitive — where will it be placed (e.g., card, table, matrix) and what slicers or date filters are active?"
   - Wait for the analyst's answer.
   - Read `.pbi-context.md`. Add or update `## Visual Context` with the answer. Write back.
   - Proceed to Step 3, incorporating the visual context into the DAX design.
```

### Pattern 4: Measures Gate (`deep.md` session close)

**What:** A new terminal step in `deep.md` that activates when the analyst signals they are done with measures. Shows a session summary and requires explicit confirmation before the session closes.

**When to use:** At the end of a deep mode session, when the analyst indicates they are finished generating measures for the session.

**Trigger:** Analyst says something like "done", "that's all the measures", "I think we're good", "finished", "complete" after at least one measure has been generated in the session.

**Step text:**
```markdown
### Step 4 — Measures Gate (end of session)

When the analyst signals completion of the measures phase:

1. Collect all measures generated in this deep mode session from `## Command History` (filter for `/pbi new` rows in this session's timeframe) and/or from `## Model Context` if it lists newly added measures.

2. Output a session summary:
   ```
   **Measures session summary:**
   [List each measure generated: "- [Measure Name] → [Table]"]

   **Business question on file:** [Restate from ## Business Question in .pbi-context.md]

   Do these measures answer the stated business question? (yes/no — if no, describe what's missing)
   ```

3. Wait for the analyst's answer to the business question check.
   - If **yes**: proceed to step 4.
   - If **no**: acknowledge the gap, offer to continue generating. Do NOT close the gate. Resume from Step 3 of the deep mode flow.

4. Output confirmation prompt:
   ```
   All measures complete — confirm to close the deep mode session. (confirm/cancel)
   ```

5. On "confirm": output "Deep mode session closed. Use /pbi diff or /pbi commit to review and save your changes."
   On "cancel": resume from Step 3.
```

### Recommended File Change Order

The planner should sequence tasks in this order to minimize dependency conflicts:

1. **`.pbi-context.md` schema** — add `## Visual Context` section definition (documentation task, no runtime dependency)
2. **`commands/new.md`** — most changes land here (Step 0.5 + Step 2 duplication + Step 2.5 filter check)
3. **`commands/explain.md`** — Step 0.5 only (lightest change; good second task)
4. **`commands/format.md`** — Step 0.5 only
5. **`commands/optimise.md`** — Step 0.5 only
6. **`commands/comment.md`** — Step 0.5 only
7. **`commands/error.md`** — Step 0.5 only
8. **`commands/deep.md`** — Step 4 measures gate (most complex new logic)
9. **Acceptance test scenarios** — new file `tests/phase2-acceptance-scenarios.md`

### Anti-Patterns to Avoid

- **Re-asking for context already in session:** Every context intake step MUST check `.pbi-context.md` first. Asking again when context exists breaks the "no re-asking" contract.
- **Blocking on context for paste-in tasks:** `format` and `optimise` have no file write path — the context question for these should be lightweight and skippable if the analyst only wants formatting, not generation. Consider whether these two commands need the full context intake gate or just an optional hint.
- **Writing the attempt counter to disk:** The solve-first failure counter is in-session memory only (established in Phase 1). Do NOT add filter-sensitive detection counter persistence to `.pbi-context.md`.
- **Mixing the duplication check and filter check in one step:** These are sequential gates with different conditions. Keep them as separate named steps in `new.md` so they are independently modifiable.
- **Deep mode gate firing too early:** The measures gate should only fire when the analyst signals completion, not after every measure. The step should be triggered by completion language, not by a fixed count.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Context persistence across commands | Custom file format or bash state | `.pbi-context.md` Read-then-Write pattern | Already established and battle-tested in Phase 1 across all commands |
| Keyword detection for filter-sensitive patterns | Regex engine in bash | Plain keyword scan in Claude's text analysis step | Claude Code instructions execute in LLM context — direct string recognition is reliable and maintainable |
| Session measure tracking for gate | Database / additional tracking file | `## Command History` table filtered by `/pbi new` | The history table already records every command; no new state store needed |
| Visual context storage | Separate `.pbi-visual-context.md` | New `## Visual Context` section in `.pbi-context.md` | Keeps all session state co-located; existing Read-then-Write pattern applies |

**Key insight:** This is a prompt engineering project, not a software engineering project. The "library" is the `.pbi-context.md` file and the markdown instruction format. Don't reach for bash or external tools to solve problems that the LLM's instruction execution handles natively.

---

## Common Pitfalls

### Pitfall 1: Context Check Placement Breaks Existing Step Numbers

**What goes wrong:** Adding Step 0.5 between Step 0 (Mode Detection) and Step 1 disrupts references to existing step numbers within command files. If Step 1 is referenced elsewhere ("Skip to Step 6"), those references still work — but inserting a step between two numbered steps requires renumbering or awkward fractional naming.

**Why it happens:** The existing command files use integer step numbers and have cross-references (e.g., "Skip to Step 6").

**How to avoid:** Use the "Step 0.5" fractional naming convention explicitly in the instruction text, labelled as "Model Context Check." Do NOT renumber existing steps. This is the pattern specified in CONTEXT.md's code context.

**Warning signs:** A command file whose Step 1 says "If PBIP_MODE=file, skip to Step 5" — the Step 0.5 insert must not change what "Step 5" means.

### Pitfall 2: Filter-Sensitive Check Applied to Paste Commands That Don't Generate

**What goes wrong:** `format` and `optimise` are paste-in commands that transform existing DAX, not generate new DAX. Adding a filter-sensitive gate before transformation makes no sense — the filter context is already embedded in the pasted expression.

**Why it happens:** The CONTEXT.md says the context intake applies to "all DAX subcommands" but the filter-sensitive detection trigger is specifically about generation. These are two different mechanisms.

**How to avoid:** Apply Step 0.5 (model context) to all 6 commands. Apply Step 2.5 (filter-sensitive gate) ONLY to `new.md` and the solve-first handler where DAX is being generated. Do NOT add filter-sensitive detection to `format`, `optimise`, `comment`, `explain`, or `error`.

**Warning signs:** A plan task that says "add filter-sensitive check to optimise.md" — this is incorrect scope.

### Pitfall 3: Duplication Check Becomes Verbose

**What goes wrong:** The duplication check in `new.md` grows into a multi-step validation flow rather than staying as a single yes/no question.

**Why it happens:** It is tempting to add "scan the model for similar names" logic or to enumerate existing measures from the context file.

**How to avoid:** The CONTEXT.md is explicit: "Does a similar measure already exist?" is a one-liner before generation, not a separate step. The analyst knows their model. Trust the answer.

### Pitfall 4: Deep Mode Gate Fires on Every Measure

**What goes wrong:** The measures gate logic in `deep.md` is triggered after each `/pbi new` call rather than at session completion.

**Why it happens:** A naive implementation checks "was a measure just generated?" after Step 3 context output.

**How to avoid:** The gate fires on ANALYST SIGNAL of completion ("done", "that's all", "finished"), not on a count or after each generation. The `deep.md` session is conversational — the gate is a terminal step, not a per-measure step.

### Pitfall 5: Visual Context Reuse Misses the `## Visual Context` Check

**What goes wrong:** Each filter-sensitive check asks the visual context question again even when the analyst already answered it for a prior measure in the same session.

**Why it happens:** The check condition forgets to read `.pbi-context.md` before asking.

**How to avoid:** Step 2.5 must read Session Context FIRST and check for `## Visual Context`. If present and non-empty, reuse it. Only ask when the section is absent or explicitly noted as "unknown".

### Pitfall 6: Model Context Write Overwrites Existing Context

**What goes wrong:** The context intake step writes to `## Model Context` and accidentally erases context previously loaded by `/pbi load`.

**Why it happens:** The Write tool replaces the whole file — if the write logic reconstructs `## Model Context` from only the current answer, it drops the richer load context.

**How to avoid:** Step 0.5 must check for existing `## Model Context` first and SKIP the write entirely if it already exists. Only write when the section was absent. Explicitly test the "load then explain" scenario in acceptance tests.

---

## Code Examples

### Example 1: Step 0.5 — Model Context Check (for `explain.md`)

```markdown
### Step 0.5 — Model Context Check

Read Session Context for `## Model Context` section.

- If `## Model Context` is present and non-empty: note the table context in your explanation. Proceed to Step 1.
- If `## Model Context` is absent or empty:
  - Ask: "Which table does this measure belong to?"
  - Wait for the analyst's answer.
  - Read `.pbi-context.md` with Read tool. Add `## Model Context` section with the analyst's answer. Write back with Write tool.
  - Proceed to Step 1 using the noted table context.
```

### Example 2: Step 2 — Duplication Check (for `new.md`)

```markdown
### Step 2 — Duplication Check

Ask:

> "Does a similar measure already exist in the model?"

Wait for answer.

- **No**: proceed to Step 2.5.
- **Yes**: ask "What's the existing measure? (paste its DAX or name it)"
  - Wait for answer.
  - In Step 3, generate a measure that wraps the existing one. Example pattern:
    ```dax
    Revenue YTD (Filtered) =
    CALCULATE(
        [Revenue YTD],
        Product[Category] = "Electronics"
    )
    ```
  - Add to Step 4 Assumptions: "Wraps existing measure [Name] — extends rather than duplicates logic."
  - Proceed to Step 2.5.
```

### Example 3: Step 2.5 — Filter-Sensitive Check (for `new.md`)

```markdown
### Step 2.5 — Filter-Sensitive Pattern Check

Scan the analyst's stated business intent from Step 1 for these patterns (case-insensitive):
- Keywords: DATEYTD, SAMEPERIODLASTYEAR, TOTALYTD, DATESYTD, DATEADD, PARALLELPERIOD, DIVIDE, RANKX, TOPN, PERCENTILEX
- Phrases: "year to date", "same period last year", "prior year", "month-to-date", "as a percentage", "ratio", "rank", "top N", "share of"

If **no pattern detected**: proceed to Step 3.

If **pattern detected**:
1. Check Session Context for `## Visual Context` section.
   - If present and non-empty:
     Output: "Using saved visual context: [visual type] with slicers [slicer list]."
     Proceed to Step 3 using this context.
   - If absent or empty:
     Ask: "This measure is filter-sensitive — where will it be placed (e.g., card, table, matrix) and what slicers or date filters will be active?"
     Wait for answer.
     Read `.pbi-context.md`. Add `## Visual Context` section:
     ```
     ## Visual Context
     - Visual type: [from analyst's answer]
     - Active slicers: [from analyst's answer]
     - Noted: [current ISO 8601 timestamp]
     ```
     Write back with Write tool.
     Proceed to Step 3, incorporating visual context into the DAX design.
```

### Example 4: `.pbi-context.md` with Visual Context Section

```markdown
# PBI Context

## Last Command
- Command: /pbi new
- Timestamp: 2026-03-14T09:00:00Z
- Measure: Revenue YTD
- Outcome: New measure scaffolded

## Command History
| Timestamp | Command | Measure Name | Outcome |
|-----------|---------|--------------|---------|
| 2026-03-14T09:00:00Z | /pbi new | Revenue YTD | New measure scaffolded |

## Model Context
Sales table: columns Amount, OrderDate, CustomerID, ProductID
Date table: columns Date, Year, Month, Quarter — related to Sales[OrderDate]

## Visual Context
- Visual type: card
- Active slicers: Date[Year], Product[Category]
- Noted: 2026-03-14T09:00:00Z

## Business Question
Compare regional sales performance month-over-month

## Analyst-Reported Failures
| Timestamp | Command | Measure Name | What Failed | Notes |
|-----------|---------|--------------|-------------|-------|
```

### Example 5: Measures Gate Step (for `deep.md`)

```markdown
### Step 4 — Measures Gate

When the analyst signals they are done with measures for this session (e.g., "done", "that's all the measures", "finished", "I think we're good"):

1. Review `## Command History` in `.pbi-context.md` for rows with Command = `/pbi new` from this session.

2. Output a session summary:

   > **Measures session summary:**
   > [For each /pbi new in Command History: "- [Measure Name] → [Table]"]
   >
   > **Business question on file:** [Content of ## Business Question]
   >
   > Do these measures answer the stated business question? (yes / no — if no, describe what's missing)

3. Wait for the analyst's answer.
   - **Yes**: proceed to step 4.
   - **No**: acknowledge the gap and offer to continue. Do NOT close the session. Resume generating.

4. Output:
   > All measures complete — confirm to close the deep mode session. (confirm / cancel)

5. On "confirm": output "Deep mode session closed. Use /pbi diff or /pbi commit to review and save your changes."
   On "cancel": resume from Step 3 context summary.

### Anti-Patterns
- NEVER trigger the gate after each individual measure — it fires only on analyst completion signal
- NEVER advance past the gate if the business question check returns "no"
- NEVER impose visual or polish phases (Phase 3 scope)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `/pbi new` asks "Which table?" only | Step 0.5 asks table + relevant columns across all DAX commands | Phase 2 | All DAX generation grounded in actual model from first request |
| No duplication awareness | Always-on duplication check gate in `/pbi new` | Phase 2 | Prevents measure proliferation; reuse via wrapping pattern |
| Filter-sensitive patterns generated without visual context | Pre-generation visual context gate for time intel + ratio patterns | Phase 2 | CALCULATE-heavy measures informed by slicer state before writing |
| Deep mode ends informally | Explicit measures gate with business question check | Phase 2 | Hard checkpoint before session closes; lightweight VERF gate |
| `.pbi-context.md` has no visual placement data | `## Visual Context` section added | Phase 2 | Reuse of visual context across multiple filter-sensitive measures |

**Deprecated/outdated:**
- `new.md` Step 2 (PBIP_MODE=file-only model context check): replaced by Step 0.5 (universal context intake) + Step 2 (duplication check)
- Deep mode "ends at Step 3 context output": extended with terminal Step 4 measures gate

---

## Open Questions

1. **Should `format` and `optimise` have a context intake step?**
   - What we know: CONTEXT.md says context intake applies to "all DAX subcommands." But format and optimise transform existing DAX — they don't generate from model context.
   - What's unclear: Whether asking "which table?" before formatting a pasted measure adds genuine value or just adds friction.
   - Recommendation: Include Step 0.5 in `format` and `optimise` but make it truly lightweight — if model context is absent, do NOT block execution; instead note "context not available — using pasted measure as-is." This honors the locked decision without blocking paste-in transforms.

2. **What if the analyst doesn't answer the duplication check question clearly?**
   - What we know: The check is "Does a similar measure already exist?" — a yes/no question. Ambiguous answers ("maybe", "not sure") are possible.
   - What's unclear: Whether "not sure" should be treated as no (proceed with generation) or should prompt for more information.
   - Recommendation: Treat "not sure" as no — generate the measure. The progressive friction principle says don't interrogate upfront. The analyst can always run the duplication check again if they later discover a conflict.

3. **Measures gate in deep mode: how does the skill know the session started from deep mode?**
   - What we know: The gate is in `deep.md`. Subsequent `/pbi new` calls execute `new.md` directly, not `deep.md`. The deep.md session context output (Step 3) sets up the session but doesn't own subsequent commands.
   - What's unclear: Whether the gate logic lives in `deep.md` as a step the analyst manually triggers ("type 'done' to close the session") or whether it is embedded in `new.md` as a check for "was this invoked from deep mode."
   - Recommendation: Keep the gate in `deep.md` as an explicit terminal step. Instruct the analyst in Step 3's output: "When you've finished generating measures, type `/pbi deep done` or just say 'done' and I'll close the session." This makes the gate activation explicit rather than implicit.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual acceptance testing (no automated test runner — skill is markdown instructions for an LLM) |
| Config file | None — test scenarios are human-readable `.md` files |
| Quick run command | Open project in Claude Code, run specified `/pbi` commands, compare output to pass criteria |
| Full suite command | Run all scenarios in `tests/phase2-acceptance-scenarios.md` sequentially |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DAX-01 | Context intake step asks for table/column when absent | manual | Run `/pbi new` with empty `.pbi-context.md`, verify question asked | ❌ Wave 0 |
| DAX-01 | Context reused — no re-asking when `## Model Context` exists | manual | Run `/pbi new` twice, verify second run skips question | ❌ Wave 0 |
| DAX-01 | Context intake applies to explain/format/optimise/comment/error | manual | Run each command with empty context, verify question asked | ❌ Wave 0 |
| DAX-01 | Model context NOT overwritten when `/pbi load` context present | manual | Run `/pbi load` then `/pbi new`, verify no context re-ask | ❌ Wave 0 |
| DAX-02 | Duplication check fires on every `/pbi new` | manual | Run `/pbi new`, verify "Does a similar measure already exist?" appears | ❌ Wave 0 |
| DAX-02 | "Yes" answer produces a wrapping measure | manual | Answer yes with existing measure name, verify CALCULATE wrapper pattern | ❌ Wave 0 |
| DAX-03 | Filter-sensitive keyword triggers visual context ask | manual | Request a DATESYTD measure, verify "where will this be placed?" fires before DAX | ❌ Wave 0 |
| DAX-03 | Visual context reused on second filter-sensitive measure | manual | Generate two time-intel measures, verify second skips the question | ❌ Wave 0 |
| INTR-04 | Visual context ask fires before generation (not after) | manual | Request RANKX measure, verify question before DAX output | ❌ Wave 0 |
| INTR-04 | Non-filter-sensitive measures proceed without visual context ask | manual | Request `SUM(Sales[Amount])`, verify no visual context question | ❌ Wave 0 |
| PHASE-02 | Deep mode measures gate shows session summary | manual | Complete deep mode session, say "done", verify measure list displayed | ❌ Wave 0 |
| PHASE-02 | Gate restates business question | manual | Verify business question from `.pbi-context.md` appears in gate output | ❌ Wave 0 |
| PHASE-02 | Gate blocks advance if business question answer is "no" | manual | Answer "no" to business question check, verify session continues | ❌ Wave 0 |
| PHASE-02 | Gate closes session on "confirm" | manual | Answer "confirm", verify session closed message | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Smoke test — run the single changed command with a representative request, verify no regression on existing behavior
- **Per wave merge:** Run all Phase 2 scenarios plus Group 4 (existing behavior preservation) from Phase 1 scenarios
- **Phase gate:** All Phase 2 scenarios green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/phase2-acceptance-scenarios.md` — covers all 14 test rows above (DAX-01 through PHASE-02)

*(Note: No test framework install needed — all testing is manual execution by a human following the scenario script. The file is the only Wave 0 gap.)*

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection of `.claude/skills/pbi/SKILL.md` — routing table, solve-first handler, shared rules
- Direct code inspection of `.claude/skills/pbi/commands/new.md` — existing steps, context check pattern (Step 2), auto-commit pattern
- Direct code inspection of `.claude/skills/pbi/commands/explain.md`, `format.md`, `optimise.md`, `comment.md`, `error.md` — current step structure, context update patterns
- Direct code inspection of `.claude/skills/pbi/commands/deep.md` — current session flow, existing anti-patterns
- `.planning/phases/02-context-aware-dax/02-CONTEXT.md` — locked decisions, integration points, reusable assets
- `tests/fixtures/context-20-rows.md` — confirmed `.pbi-context.md` schema (sections, column names, format)
- `tests/acceptance-scenarios.md` — Phase 1 test pattern for Phase 2 test design

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` — requirement definitions (INTR-04, DAX-01-03, PHASE-02)
- `.planning/STATE.md` — phase completion status, Phase 1 delivered items
- `.planning/phases/01-skill-core-escalation/01-02-SUMMARY.md` — Phase 1 delivery record confirming what was actually built

### Tertiary (LOW confidence)
- None. All findings derived from direct code inspection and CONTEXT.md locked decisions.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all implementation is markdown instruction files; stack is fully observable from existing codebase
- Architecture patterns: HIGH — patterns derived from existing Phase 1 command files and locked decisions in CONTEXT.md
- Pitfalls: HIGH — identified from direct inspection of step cross-references, mode branching logic, and the "no re-asking" contract stated in CONTEXT.md
- Validation approach: HIGH — manual acceptance testing confirmed as the right pattern by Phase 1 practice

**Research date:** 2026-03-14
**Valid until:** Until any command file's step structure changes (stable — these are markdown documents)
