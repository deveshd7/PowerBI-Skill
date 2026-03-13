# Phase 1: Paste-in DAX Commands - Research

**Researched:** 2026-03-12
**Domain:** Claude Code Skill System / DAX / DAX Formatter API
**Confidence:** HIGH (skill system), MEDIUM (DAX Formatter API endpoint), HIGH (DAX patterns)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Command Invocation UX**
- All four commands use the same prompt-then-paste pattern: command runs, responds with "Paste your DAX measure below:", analyst pastes the full measure
- Full DAX assignment expected (`MeasureName = expression`) — commands extract the name themselves
- Invalid or partial DAX: attempt it anyway, flag the syntax issue as part of the output (no rejection/re-prompt)
- Optional `--table TableName` flag accepted by any command to provide table context; not required
- After every command output, always show the full menu of related commands as next steps (not context-selective — always show all)

**Architecture — Haiku/Sonnet Split**
- `/pbi:load` is an explicit command the analyst runs before DAX commands when file context is needed; Phase 1 establishes the slot but its full value (reading PBIP model) arrives in Phase 2
- DAX commands in Phase 1 work fine without a prior `/pbi:load` run — paste-in mode needs no prior context load
- Haiku subagents handle all data retrieval and file reading; Sonnet handles all reasoning and output generation
- When Haiku reads model context (Phase 2+), pass only targeted extraction (relevant measure + dependencies), not a full model dump — keeps Sonnet context lean

**Output Structure — /pbi:explain**
- Sections with headers: plain English summary at top, then labelled sections: Filter Context, Row Context, Context Transitions, Performance Notes
- Complexity tag shown at top: `_Complexity: Intermediate_` (inferred, not analyst-declared)
- Complex DAX terms used naturally with brief parenthetical: e.g. "triggers a context transition (row context converted to filter context)"

**Output Structure — /pbi:optimise**
- Side-by-side layout: Original code block, then Optimised code block, then bulleted list of changes with rationale per change
- Rationale depth scales with complexity: simple rewrites get brief rationale; complex rewrites (context transitions, iterator restructuring) get full explanation
- Measures containing iterators over measure references: flagged as "requires manual verification — context transition present", not auto-rewritten

**Output Structure — /pbi:comment**
- Two labelled blocks: (1) commented DAX code block with inline `//` comments, (2) Description Field value as a plain text block ready to paste into Power BI measure Description property

**Output Structure — /pbi:format**
- DAX Formatter API attempted first
- On API failure: quiet note at top of output — `_DAX Formatter API unavailable — formatted inline by Claude_` — then formatted block follows
- No prominent warning, no silent suppression — one line acknowledgement only

**Session Context — .pbi-context.md**
- Purpose in Phase 1: track command history (command run, measure pasted, output summary) and analyst-reported failures
- Failures are analyst-reported only — not auto-detected by Claude
- When a prior failure is found on re-run: flagged at top of output before results: "Previous attempt at this measure used [approach X] and failed. Using [approach Y] instead."
- File lives in project root, visible and readable/editable by the analyst — not hidden, not tucked in a subdirectory

**Skill Level Adaptation**
- Complexity inferred from measure patterns: simple measures (SUM, DIVIDE, basic CALCULATE) → simpler explanation; complex patterns (context transitions, EARLIER, ALLEXCEPT, nested iterators) → technical depth
- No analyst declaration required — no one-time setup, no --level flag
- Same complexity-based approach applies to /pbi:optimise rationale depth

### Claude's Discretion
- Exact DAX Formatter API endpoint and request format (needs empirical verification — STATE.md flags this as medium-confidence)
- Specific section headers within /pbi:explain output (Filter Context, Row Context wording)
- .pbi-context.md schema/structure (as long as it tracks command, measure, output, and failures)
- Follow-up command menu layout and ordering

### Deferred Ideas (OUT OF SCOPE)
- `/pbi:load` reading actual PBIP model files — Phase 2 (INFRA-03, INFRA-04, INFRA-05, INFRA-06)
- Error recovery writing fixes back to PBIP files — Phase 2 (ERR-03)
- Comment write-back to PBIP files (`/pbi:comment` in file mode) — Phase 2 (DAX-13)
- Batch commenting across all measures in a table — v2 backlog (DAX-V2-02)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INFRA-01 | Skill suite is invocable via `/pbi` prefix commands | Skill system: each command = one SKILL.md in `.claude/skills/pbi-{name}/` |
| CTX-01 | `.pbi-context.md` maintained in project root tracking: last command, changes, failures, open issues | Markdown file schema pattern documented below |
| CTX-02 | Each command reads `.pbi-context.md` at startup and uses it to avoid repeating failed approaches | `!` bash injection in SKILL.md reads file at invocation time |
| CTX-03 | Each command updates `.pbi-context.md` after execution with a summary | Write tool call inside skill instructions; or Bash append |
| CTX-04 | If a previous approach failed (logged in context), command flags this and suggests alternative | Conditional logic inside skill instructions referencing context file contents |
| DAX-01 | User pastes DAX measure and receives plain-English explanation | Sonnet model in skill; prompt includes output structure |
| DAX-02 | Explanation identifies filter context, row context, context transitions | Prompt template in SKILL.md; DAX pattern list documented below |
| DAX-03 | Explanation adapts register to inferred analyst skill level | Complexity inference rules documented below; embedded in skill prompt |
| DAX-04 | User pastes DAX measure and receives SQLBI-style formatted output | DAX Formatter API call + inline fallback |
| DAX-05 | Formatted output returned as copy-paste ready code block | Skill instructions specify fenced code block wrapping |
| DAX-06 | Format command attempts DAX Formatter API first; falls back to Claude inline formatting if unreachable | `!` bash injection runs curl; skill instructions handle both branches |
| DAX-07 | User pastes DAX and receives performance-optimised rewrite with rationale | Sonnet skill with optimisation rules from SQLBI patterns |
| DAX-08 | Optimiser detects and rewrites common slow patterns: unnecessary FILTER on table, SUMX over single column where SUM suffices, redundant CALCULATE wrappers | Pattern list documented below; embedded as rules in skill prompt |
| DAX-09 | Measures with iterators over measure references flagged as "requires manual verification" | Detection pattern documented below; guard rule in skill prompt |
| DAX-10 | Optimiser suggests alternatives with trade-off explanations where multiple valid rewrites exist | Skill instructions specify when to show alternatives |
| DAX-11 | User pastes DAX and receives version with `//` inline comments explaining business logic | Sonnet skill with comment placement rules |
| DAX-12 | Command outputs a `description` field value suitable for pasting into Power BI measure Description property | Two-block output format specified in skill instructions |
| ERR-01 | User pastes a Power BI error log or error message and receives a diagnosis of the root cause | Sonnet skill; common PBI error patterns documented below |
| ERR-02 | Error recovery reads `.pbi-context.md` to understand what was last changed and correlates to recent edits | `!` bash injection reads context file at startup |
| ERR-04 | If the same error has been seen before (logged in context), command skips failed approaches and leads with correct method | Context file query logic in skill instructions |
</phase_requirements>

---

## Summary

Phase 1 is implemented entirely as Claude Code skills — Markdown files with YAML frontmatter stored in `.claude/skills/`. No npm packages, no compiled code, no external runtimes are needed. Each `/pbi:*` command is one skill directory containing a `SKILL.md` file with instructions Claude follows when you type that slash command.

The Claude Code skill system (as of 2026) is the correct and current mechanism. The older `.claude/commands/` approach still works but skills are the recommended path because they support supporting files, frontmatter-controlled invocation, and `context: fork` for subagent delegation. The `model:` frontmatter field enables the Haiku/Sonnet architectural split: each skill explicitly sets which model handles its work.

The one genuinely uncertain element is the DAX Formatter API endpoint. The old web interface uses `POST https://www.daxformatter.com` with a `fx` form parameter; the newer .NET client library uses a JSON API whose exact path is not publicly documented and needs a live `curl` test to confirm. The fallback strategy (Claude inline formatting) is robust and the CONTEXT.md decision locks in a quiet one-line acknowledgement when the API is unreachable — this is already the correct approach regardless of which API path works.

**Primary recommendation:** Build each `/pbi:*` command as a project-scoped skill in `.claude/skills/pbi-{name}/SKILL.md`. Use `disable-model-invocation: true` on all of them (analyst controls when to run DAX commands). Use the `model:` field to pin Sonnet for reasoning-heavy skills. Run a live `curl` test against daxformatter.com before wiring the API into `/pbi:format`.

---

## Standard Stack

### Core

| Component | Version / Location | Purpose | Why Standard |
|-----------|-------------------|---------|--------------|
| Claude Code Skill System | Current (2026) | Each `/pbi:*` command as a `SKILL.md` | Official mechanism; replaces `.claude/commands/` with richer features |
| SKILL.md YAML frontmatter | Current spec | Frontmatter controls model, invocation, tool access | Official Claude Code feature; documented at code.claude.com |
| `model: haiku` / `model: sonnet` | Frontmatter field | Pins model per skill | Directly supports the locked Haiku/Sonnet split decision |
| `disable-model-invocation: true` | Frontmatter field | Prevents Claude auto-triggering DAX commands | Required — analyst must deliberately invoke these commands |
| `!``bash command``` syntax | Skill dynamic context | Reads `.pbi-context.md` at invocation time; runs curl for DAX Formatter | Official dynamic context injection; runs before Claude sees the prompt |
| `.pbi-context.md` | Project root Markdown file | Session state: command history, failures, last measure | Analyst-readable; written by Write tool or Bash in skill |

### Supporting

| Component | Version / Location | Purpose | When to Use |
|-----------|-------------------|---------|-------------|
| `context: fork` + `agent:` | Frontmatter field | Run a skill in an isolated subagent | Phase 2+ for Haiku retrieval subagent; NOT needed for Phase 1 paste-in mode |
| `allowed-tools:` | Frontmatter field | Restrict which tools run without approval | Use on `/pbi:format` to allow Bash (for curl) without per-use prompt |
| `$ARGUMENTS` substitution | Skill variable | Passes `--table TableName` flag to skill | Enables the optional table context flag |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.claude/skills/` SKILL.md | `.claude/commands/` `.md` files | Commands still work but lack supporting files, model pinning via frontmatter is the same, skills are forward-compatible |
| Inline Claude formatting (fallback) | Local DAX formatter CLI | No external tool dependency; Claude's SQLBI-style output is high quality; avoids asking user to install anything |

**Installation:** No packages to install. Create skill directories:

```bash
mkdir -p .claude/skills/pbi-explain
mkdir -p .claude/skills/pbi-format
mkdir -p .claude/skills/pbi-optimise
mkdir -p .claude/skills/pbi-comment
mkdir -p .claude/skills/pbi-load
mkdir -p .claude/skills/pbi-error
```

---

## Architecture Patterns

### Recommended Project Structure

```
.claude/
└── skills/
    ├── pbi-explain/
    │   └── SKILL.md          # /pbi:explain command
    ├── pbi-format/
    │   └── SKILL.md          # /pbi:format command
    ├── pbi-optimise/
    │   └── SKILL.md          # /pbi:optimise command
    ├── pbi-comment/
    │   └── SKILL.md          # /pbi:comment command
    ├── pbi-load/
    │   └── SKILL.md          # /pbi:load command slot (Phase 1: stub)
    └── pbi-error/
        └── SKILL.md          # /pbi:error command (ERR-01, ERR-02, ERR-04)
.pbi-context.md               # Session state file (project root)
```

### Pattern 1: Standard DAX Command Skill Structure

**What:** Every `/pbi:*` command follows the same SKILL.md structure — read context, prompt for DAX, do reasoning, update context.

**When to use:** All DAX commands in Phase 1.

```yaml
# Source: code.claude.com/docs/en/slash-commands (official skill docs)
---
name: pbi-explain
description: Explain a DAX measure in plain English. Use when an analyst asks to explain, understand, or break down a DAX measure.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Write, Bash(cat *)
---

## Prior Session Context
!`cat .pbi-context.md 2>/dev/null || echo "No prior context."`

## Your Task

Respond: "Paste your DAX measure below:"

Wait for the analyst to paste a full DAX measure assignment (e.g. `MeasureName = expression`).
Extract the measure name from the assignment. If `--table TableName` was passed in $ARGUMENTS, note the table context.

[... output structure instructions ...]

After output, update .pbi-context.md with a summary of this run.
```

### Pattern 2: DAX Formatter API Call with Fallback

**What:** `!` bash injection runs a `curl` call at skill startup. Skill instructions reference a variable containing the result.

**When to use:** `/pbi:format` only.

```yaml
---
name: pbi-format
disable-model-invocation: true
model: sonnet
allowed-tools: Bash(curl *), Read, Write
---

## Format API Check
!`curl -s -X POST "https://www.daxformatter.com/api/daxformatter/dax" \
  -H "Content-Type: application/json" \
  -d '{"Dax":"1+1","ListSeparator":",","DecimalSeparator":"."}' \
  --max-time 5 2>/dev/null && echo "API_OK" || echo "API_FAIL"`

[Instructions reference API_OK/API_FAIL to select branch]
```

**Note:** The `curl` probe above is a best-guess at the JSON endpoint path — this MUST be verified with a live test before the skill is considered working. See Open Questions.

### Pattern 3: .pbi-context.md Schema

**What:** A structured Markdown file written and read by all commands.

**When to use:** Created on first command run; updated after every command.

```markdown
# PBI Context

## Last Command
- Command: /pbi:explain
- Timestamp: 2026-03-12T10:00:00Z
- Measure: Revenue YTD = CALCULATE([Total Revenue], DATESYTD('Date'[Date]))
- Outcome: Success — explained DATESYTD with time intelligence context

## Command History
| Timestamp | Command | Measure Name | Outcome |
|-----------|---------|--------------|---------|
| 2026-03-12T10:00:00Z | /pbi:explain | Revenue YTD | Success |

## Analyst-Reported Failures
| Timestamp | Command | Measure Name | What Failed | Notes |
|-----------|---------|--------------|-------------|-------|
| (empty) | | | | |
```

### Pattern 4: Haiku/Sonnet Split via `model:` Frontmatter

**What:** Use `model: haiku` for file-read/retrieval skills, `model: sonnet` for all reasoning skills.

**When to use:** All Phase 1 skills use `model: sonnet`. `/pbi:load` stub uses `model: haiku` (cheap; no reasoning needed in Phase 1).

```yaml
# Sonnet for reasoning (explain, format, optimise, comment, error)
model: sonnet

# Haiku for data retrieval (load — Phase 1 stub, full value in Phase 2)
model: haiku
```

Source: code.claude.com official docs — `model:` field accepts `sonnet`, `haiku`, `opus`, or `inherit`.

### Anti-Patterns to Avoid

- **Using `context: fork` in Phase 1:** Fork creates an isolated subagent that cannot access the main conversation. For paste-in mode, the DAX content arrives via the conversation — inline execution is correct. Reserve `context: fork` for Phase 2+ Haiku file-reading subagents.
- **Auto-invocation enabled on DAX commands:** Never omit `disable-model-invocation: true` from DAX commands. Without it, Claude might auto-trigger `/pbi:optimise` mid-conversation when the analyst mentions a slow measure.
- **Writing `.pbi-context.md` with absolute paths:** Always use relative path `./pbi-context.md` or just `.pbi-context.md` in bash calls — the skill runs from the project working directory.
- **Silently suppressing the DAX Formatter fallback:** The CONTEXT.md decision is explicit: one quiet line, not silence. Never omit the acknowledgement line.
- **Parsing DAX with regex for complex cases:** Simple extraction of measure name (everything before the first `=`) is fine; do not attempt to fully parse DAX expressions with bash/regex.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DAX formatting / indentation | Custom regex/indent rules | DAX Formatter API (primary), Claude inline (fallback) | SQLBI's formatter encodes years of community conventions; Claude's training on DAX covers the same conventions as fallback |
| Session state persistence | Custom database, JSON store | `.pbi-context.md` Markdown file | Markdown is analyst-readable and editable; no parse library needed; fits the skill's Read/Write tool access |
| Skill routing / dispatch | Custom router skill | Native Claude Code skill system (`/skill-name` invocation) | The platform handles discovery, menu display, and invocation — no routing code needed |
| DAX pattern detection | Custom AST parser | String-pattern matching in skill prompt instructions | DAX patterns for optimisation (FILTER on table, SUMX over column) are identifiable via text pattern matching given Claude's DAX knowledge; full parse is overkill for Phase 1 |

**Key insight:** This entire phase is prompt-and-instruction work, not code. The skill system, Claude's DAX training, and a single curl call to DAX Formatter cover all requirements without writing any executable code files.

---

## Common Pitfalls

### Pitfall 1: DAX Formatter API Endpoint Not Publicly Documented

**What goes wrong:** The newer JSON endpoint (used by the .NET NuGet client) is not clearly documented in any public URL. Using the old HTML form endpoint (`POST https://www.daxformatter.com` with `fx=` parameter) works but returns formatted HTML, not clean text.

**Why it happens:** SQLBI's primary distribution channel is the .NET NuGet package; the raw REST endpoint is an implementation detail they haven't prominently documented.

**How to avoid:** Before wiring the API call into the skill, run a test `curl` against `https://www.daxformatter.com/api/daxformatter/dax` with a trivial DAX expression and inspect the response. If it returns a JSON object with a formatted DAX string, that is the correct endpoint. If it 404s, try `https://www.daxformatter.com/api/daxformatter` or check browser network tab on daxformatter.com.

**Warning signs:** `curl` returns HTML instead of JSON; response contains full page markup; HTTP 404 or 405 status.

### Pitfall 2: `!` Bash Injection Output Polluting the Skill Prompt

**What goes wrong:** If the `!` bash command that reads `.pbi-context.md` outputs a very large file (hundreds of entries), it bloats the skill's initial context and can confuse Claude about what it's supposed to do next.

**Why it happens:** `.pbi-context.md` grows with every command run. No truncation by default.

**How to avoid:** In the skill's bash injection, pipe through `tail -100` or use a structured schema where the History table is capped (e.g., keep last 20 entries). Alternatively, read only specific sections with `grep -A 5 "Last Command"`.

**Warning signs:** Skill responses reference stale history; slow skill startup; Claude confuses old measure with new one.

### Pitfall 3: Analyst Pastes Measure Expression Without Assignment

**What goes wrong:** Analyst pastes `CALCULATE([Sales], 'Date'[Year] = 2024)` without the `MeasureName =` prefix. The locked decision says "attempt it anyway, flag the syntax issue."

**Why it happens:** Analysts often copy from the formula bar (which shows only the expression) rather than the measure editor (which shows the full assignment).

**How to avoid:** Skill instructions must check whether the pasted content contains `=` early. If no `=` found, treat the whole paste as the expression, use a placeholder name like `[Measure]`, and add a note: "Note: No measure name detected — treating entire input as the expression."

**Warning signs:** Claude errors on "extract measure name" step; output lacks a measure name in the heading.

### Pitfall 4: Context Transition False Positive in Optimise

**What goes wrong:** The locked decision says measures with iterators over measure references must be flagged, not auto-rewritten. Without a clear rule in the skill instructions, Claude may attempt to optimise these and produce incorrect rewrites.

**Why it happens:** Context transitions are subtle — `SUMX(Table, [Measure])` causes a context transition because `[Measure]` implicitly calls `CALCULATE`, which transforms row context to filter context. An optimiser that does not detect this will produce wrong output.

**How to avoid:** Skill instructions must include the detection rule explicitly: "If the measure body contains a reference to another measure name (identified as `[Name]` not preceded by a column reference like `Table[Col]`) inside an iterator (SUMX, AVERAGEX, MAXX, etc.), add the manual verification flag and do not rewrite that portion."

**Warning signs:** Optimised measure references `[SomeMeasure]` inside `SUMX` with no flag; analyst reports incorrect totals after applying optimised version.

### Pitfall 5: `.pbi-context.md` Write Race / Missing File on First Run

**What goes wrong:** On first invocation, `.pbi-context.md` does not exist. If the skill's write logic assumes the file exists (e.g., `echo "..." >> .pbi-context.md`), it creates a file without the expected headers, breaking future reads.

**Why it happens:** Fresh project, no prior `/pbi` command run.

**How to avoid:** Skill instructions must handle the "file does not exist" case by creating it with the full schema on first write. The bash injection already handles this: `cat .pbi-context.md 2>/dev/null || echo "No prior context."`. The write step must do the equivalent: either check for file existence or always overwrite with the full updated content (Read → modify in memory → Write).

---

## Code Examples

### SKILL.md Skeleton — All DAX Commands

```yaml
# Source: code.claude.com/docs/en/slash-commands (official skill documentation)
---
name: pbi-explain
description: Explain a DAX measure. Use when asked to explain, understand, or analyse a DAX formula.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Write
---

## Session Context
!`cat .pbi-context.md 2>/dev/null || echo "No prior context found."`

## Instructions

Respond to the analyst with exactly: "Paste your DAX measure below:"

Once the analyst pastes the measure:

1. Extract the measure name (everything before the first `=` sign, trimmed).
   - If no `=` found, use placeholder name `[Measure]` and note: "No measure name detected."
2. If `$ARGUMENTS` contains `--table TableName`, note TableName as context.
3. Check session context above for any prior failures on this measure name. If found, flag at top of output.
4. Generate output in the required structure (see Output Structure below).
5. Update .pbi-context.md with this run's summary.

## Output Structure

_Complexity: [Simple/Intermediate/Advanced]_ (infer from measure patterns)

**[Measure Name]**

[One paragraph plain-English summary of what the measure calculates]

### Filter Context
[What filters are applied, from where]

### Row Context
[Whether any row context exists; if so, from which iterator]

### Context Transitions
[Whether CALCULATE triggers a context transition; explain if present]

### Performance Notes
[Brief note on any performance implications]

---
**Next steps:** `/pbi:format` · `/pbi:optimise` · `/pbi:comment` · `/pbi:error`

## After Output

Write to .pbi-context.md:
- Last Command: /pbi:explain
- Measure name extracted
- One-line outcome summary
- Append to Command History table
```

### Complexity Inference Rules (embed in explain and optimise skills)

```
# Embed these rules in the skill prompt under "Complexity Inference"

Simple (use plain language, avoid jargon):
- Measure body contains only: SUM, COUNT, AVERAGE, MIN, MAX, DIVIDE, IF, BLANK
- Single CALCULATE with one filter argument
- No iterators (no SUMX, AVERAGEX, MAXX, etc.)
- No time intelligence functions

Intermediate (explain concepts with brief parentheticals):
- CALCULATE with multiple filter arguments
- Single iterator (SUMX, AVERAGEX) over a physical table column
- Time intelligence functions (DATESYTD, DATEADD, SAMEPERIODLASTYEAR)
- FILTER used as CALCULATE argument
- RELATED or RELATEDTABLE

Advanced (use full technical depth, name patterns explicitly):
- Iterators over measure references (context transition present)
- EARLIER or EARLIERNOD
- ALLEXCEPT, ALLSELECTED, REMOVEFILTERS with multiple columns
- Nested iterators (SUMX inside SUMX)
- RANKX, TOPN with complex expressions
- Variables (VAR/RETURN) that themselves contain iterators
```

### DAX Optimisation Rules (embed in optimise skill)

```
# Source: SQLBI articles on DAX performance — verified patterns
# Embed these as the rule set in /pbi:optimise

Rule 1 — FILTER on entire table:
  DETECT: FILTER(TableName, condition) as CALCULATE argument where condition
          tests a single column
  REWRITE: Replace with column filter: CALCULATE([M], TableName[Col] = value)
  RATIONALE: Column filter uses xmatch internally; avoids full table scan

Rule 2 — SUMX over single column:
  DETECT: SUMX(TableName, TableName[Column]) with no expression complexity
  REWRITE: SUM(TableName[Column])
  RATIONALE: SUM is a native aggregation; SUMX iterates row-by-row unnecessarily

Rule 3 — Redundant CALCULATE wrapper:
  DETECT: CALCULATE([SimpleMeasure]) with no filter arguments
  REWRITE: [SimpleMeasure] directly
  RATIONALE: CALCULATE with no filters adds overhead with no benefit

Rule 4 — Iterator over measure reference (DO NOT REWRITE):
  DETECT: SUMX/AVERAGEX/MAXX/etc.(Table, [MeasureName]) where [MeasureName]
          is a measure (not a column reference like Table[Col])
  ACTION: Flag as "requires manual verification — context transition present"
          Explain: "This iterator calls [MeasureName] in a row context,
          which triggers an implicit CALCULATE, converting row context to
          filter context. Rewriting this requires verifying the measure
          behaves correctly under row-context-to-filter-context conversion."
  DO NOT auto-rewrite.

Rule 5 — Nested iterators:
  DETECT: Iterator function directly inside another iterator function
  ACTION: Flag with explanation of the Cartesian product risk
  REWRITE: Only if the inner iteration is trivially collapsible (e.g., inner
           is just a column reference, not a full expression)
```

### DAX Formatter API — curl Probe (to verify endpoint before use)

```bash
# Run this manually to verify the endpoint before wiring it into the skill
# This is the BEST-GUESS endpoint path — must be confirmed empirically
curl -s -X POST "https://www.daxformatter.com/api/daxformatter/dax" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"Dax":"Sales = SUM(Sales[Amount])","ListSeparator":",","DecimalSeparator":".","MaxLineLength":120}' \
  --max-time 10

# Alternative legacy endpoint (old form-POST, returns HTML):
curl -s -X POST "https://www.daxformatter.com" \
  -d "fx=Sales%20%3D%20SUM%28Sales%5BAmount%5D%29&r=US&embed=1" \
  --max-time 10
# Note: embed=1 returns only the formatted code block, not full HTML page
```

### .pbi-context.md — Initial Creation Template

```markdown
# PBI Context

## Last Command
- Command: (none)
- Timestamp: (none)
- Measure: (none)
- Outcome: (none)

## Command History
| Timestamp | Command | Measure Name | Outcome |
|-----------|---------|--------------|---------|

## Analyst-Reported Failures
| Timestamp | Command | Measure Name | What Failed | Notes |
|-----------|---------|--------------|-------------|-------|
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.claude/commands/*.md` files | `.claude/skills/*/SKILL.md` directories | 2025 | Skills are the recommended path; commands still work but are legacy |
| No model pinning in commands | `model:` frontmatter field in skills | 2025 | Direct support for Haiku/Sonnet split without any code |
| No dynamic context injection | `!``bash command``` syntax in skill content | 2025 | Can read files, run curl, inject live data before Claude sees the prompt |
| `context: fork` requires explicit setup | Built-in `agent:` field with `context: fork` | 2025 | Subagent delegation is first-class in skill frontmatter |

**Deprecated/outdated:**
- `.claude/commands/` approach: Still works, not deprecated, but skills supersede it for new development. If a skill and a command share the same name, the skill takes precedence.
- Old DAX Formatter form-POST endpoint (`fx=` parameter): Still works per the 2014 blog post, but the API JSON endpoint (used by the .NET client since ~2021) is the preferred approach for programmatic use.

---

## Open Questions

1. **DAX Formatter JSON API endpoint path**
   - What we know: The .NET NuGet client `Dax.Formatter` uses a JSON REST API. The old form-POST endpoint (`POST https://www.daxformatter.com` with `fx=`) works and returns HTML with `embed=1`. A best-guess JSON path is `/api/daxformatter/dax`.
   - What's unclear: The exact JSON endpoint URL, the request body schema, and whether the response is a plain string or a JSON object. STATE.md explicitly flags this as MEDIUM confidence.
   - Recommendation: **Wave 0 task — verify with a live curl test before implementing `/pbi:format`.** If the JSON endpoint works, use it. If not, use the legacy `fx=` form-POST with `embed=1` and strip any residual HTML. Document the confirmed endpoint in a `skills/pbi-format/api-notes.md` supporting file.

2. **Context window impact of growing `.pbi-context.md`**
   - What we know: The `!` bash injection reads the entire file into the skill prompt at each invocation.
   - What's unclear: At what history length does this meaningfully impact quality or token cost?
   - Recommendation: Cap Command History to last 20 rows in the write step. Keep Analyst-Reported Failures uncapped (analyst actively curates these). Flag for review after Phase 2 if context size becomes a concern.

3. **`/pbi:load` Phase 1 stub — exact behaviour**
   - What we know: Phase 1 establishes the command slot; the full value arrives in Phase 2 when it reads PBIP files.
   - What's unclear: Should the stub respond with "Feature coming in Phase 2 — use paste-in mode for now" or silently do nothing?
   - Recommendation: Stub responds with one informative line: "Model context loading is available when a PBIP project is present (Phase 2). For now, paste your DAX measure directly into any `/pbi` command."

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None detected — this is a prompt/skill system, not compiled code |
| Config file | N/A |
| Quick run command | Manual: invoke `/pbi:explain` with a known DAX measure in Claude Code |
| Full suite command | Manual: run all five commands with test measures from `tests/fixtures/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-01 | `/pbi:explain` appears in `/` menu | smoke | Manual — type `/pbi` in Claude Code, verify menu | ❌ Wave 0 |
| CTX-01 | `.pbi-context.md` created after first command run | smoke | `ls .pbi-context.md` after invoking any skill | ❌ Wave 0 |
| CTX-02 | Context file read at startup; prior failure shown | manual | Run command, report failure, re-run, verify flag appears | ❌ Wave 0 |
| CTX-03 | Context file updated after each command | smoke | `cat .pbi-context.md` after run; verify Last Command section | ❌ Wave 0 |
| CTX-04 | Prior failure triggers alternative approach flag | manual | Report failure via context file; re-run command | ❌ Wave 0 |
| DAX-01 | Explain returns plain-English summary | manual | Paste `Revenue = SUM(Sales[Amount])`; verify output has summary section | ❌ Wave 0 |
| DAX-02 | Explain identifies filter/row context and transitions | manual | Paste `Total = CALCULATE(SUM(Sales[Amt]), FILTER(Sales, Sales[Year]=2024))`; verify sections present | ❌ Wave 0 |
| DAX-03 | Explain adapts to complexity level | manual | Test with simple SUM measure → expect Simple tag; test with nested SUMX → expect Advanced | ❌ Wave 0 |
| DAX-04 | Format returns SQLBI-style formatted output | manual | Paste unformatted multi-line measure; verify indented output | ❌ Wave 0 |
| DAX-05 | Formatted output in fenced code block | manual | Verify output contains ` ```dax ` block | ❌ Wave 0 |
| DAX-06 | API failure fallback shows one-line note | manual | Break API URL in skill; run format; verify fallback note appears | ❌ Wave 0 |
| DAX-07 | Optimise returns rewritten measure with rationale | manual | Paste `Slow = SUMX(Sales, Sales[Amount])`; verify rewrite to `SUM` with rationale | ❌ Wave 0 |
| DAX-08 | Slow patterns detected and rewritten | manual | Test FILTER-on-table, SUMX-over-column, redundant-CALCULATE patterns | ❌ Wave 0 |
| DAX-09 | Iterator over measure ref flagged, not rewritten | manual | Paste `Risk = SUMX(Customers, [CustomerRevenue])`; verify flag present, no rewrite | ❌ Wave 0 |
| DAX-10 | Multiple valid rewrites show alternatives | manual | Paste measure with two valid approaches; verify trade-off shown | ❌ Wave 0 |
| DAX-11 | Comment returns DAX with `//` inline comments | manual | Paste complex measure; verify `//` comments on meaningful lines | ❌ Wave 0 |
| DAX-12 | Comment returns Description field value block | manual | Verify second output block labelled "Description Field" present | ❌ Wave 0 |
| ERR-01 | Error command diagnoses PBI error from pasted log | manual | Paste known PBI error; verify diagnosis and root cause | ❌ Wave 0 |
| ERR-02 | Error correlates to last change in context | manual | Run a command, then paste related error; verify correlation | ❌ Wave 0 |
| ERR-04 | Same error seen before → skip failed approach | manual | Log error in context; paste same error again; verify lead-with-correct-method | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Manual smoke test — invoke each new skill once with a simple measure to confirm it appears in menu and responds
- **Per wave merge:** Full manual pass with test fixture measures for all five commands
- **Phase gate:** All manual tests pass before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/fixtures/simple-measure.dax` — `Revenue = SUM(Sales[Amount])` — covers DAX-01, DAX-03 (Simple)
- [ ] `tests/fixtures/intermediate-measure.dax` — `Sales YTD = CALCULATE([Revenue], DATESYTD('Date'[Date]))` — covers DAX-02, DAX-03 (Intermediate)
- [ ] `tests/fixtures/complex-measure.dax` — `Risky = SUMX(Customers, [Revenue])` — covers DAX-09 (iterator over measure ref)
- [ ] `tests/fixtures/slow-filter-measure.dax` — `Slow = CALCULATE(SUM(Sales[Amt]), FILTER(Sales, Sales[Year]=2024))` — covers DAX-08 (Rule 1)
- [ ] `tests/fixtures/error-log.txt` — sample Power BI error message — covers ERR-01
- [ ] `.pbi-context.md` initial file — created by Wave 0 setup task, not by a test

---

## Sources

### Primary (HIGH confidence)
- `code.claude.com/docs/en/slash-commands` — Full official skill system documentation: SKILL.md format, frontmatter fields (`name`, `description`, `disable-model-invocation`, `model`, `context`, `agent`, `allowed-tools`), `!` bash injection, `$ARGUMENTS` substitution, skill directory structure, invocation control
- SQLBI / context transition articles — SQLBI's canonical documentation on context transitions, FILTER vs column filters, SUMX/SUM patterns (verified via WebSearch cross-reference to sqlbi.com articles)

### Secondary (MEDIUM confidence)
- `www.sqlbi.com/blog/marco/2014/02/24/how-to-pass-a-dax-query-to-dax-formatter/` — Old DAX Formatter form-POST endpoint (`POST https://www.daxformatter.com`, `fx=` parameter, `embed=1` for clean output, `r=US` region). Verified working as of 2014; still referenced by tools in 2024/2025 but may not be the preferred path for programmatic use.
- `github.com/sql-bi/DaxFormatter` — .NET NuGet client library uses a JSON REST API; `DaxFormatterSingleRequest` and `DaxFormatterMultipleRequest` classes; `DaxFormatterClient.FormatAsync()`. Endpoint path not publicly documented.
- WebSearch findings on skill frontmatter fields (confirmed by official docs above)

### Tertiary (LOW confidence)
- Best-guess JSON endpoint `https://www.daxformatter.com/api/daxformatter/dax` — inferred from NuGet client naming conventions; NOT verified empirically. Must be confirmed with a live curl test before use.

---

## Metadata

**Confidence breakdown:**
- Standard stack (skill system): HIGH — verified against official Claude Code documentation at code.claude.com
- Architecture (skill structure, model pinning, bash injection): HIGH — all features documented in official source
- DAX optimisation patterns: HIGH — sourced from SQLBI canonical articles (FILTER, SUMX, context transition)
- DAX Formatter API: MEDIUM — old endpoint documented; JSON endpoint path is best-guess only
- .pbi-context.md schema: HIGH — simple Markdown; no external dependencies; design follows locked decisions directly

**Research date:** 2026-03-12
**Valid until:** 2026-06-12 for skill system (stable); 2026-04-12 for DAX Formatter endpoint (verify before building)
