# Phase 3: Model-Wide Audit - Research

**Researched:** 2026-03-12
**Domain:** Claude skill system / PBIP model metadata analysis / Power BI model health rules
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Report Structure**
- Severity-first layout: all CRITICALs grouped together, then WARNs, then INFOs — analyst sees worst problems first regardless of domain
- Each finding is tagged with its domain in brackets: `[Relationships]`, `[Naming]`, `[Date Table]`, `[Measures]`
- Every finding includes: specific table/measure name (never a JSON path) + one-line concrete recommendation
- Severity emoji used in report: 🔴 CRITICAL, 🟡 WARN, 🔵 INFO

**Report Destination**
- Both inline (printed in chat) and written to file
- File written to `audit-report.md` in the project root
- Inline shows the full report — no summary-only truncation

**Finding Severity for Naming**
- Naming issues are always WARN or INFO — never CRITICAL (naming doesn't break the model, only hurts maintainability)
- Blank/missing names or names with special characters → WARN
- Style inconsistencies → INFO

**Naming Convention Rules**
- Infer conventions from the model itself: scan existing names, detect the dominant pattern, flag deviations
- No hardcoded standard — works for any team's naming style
- Covers all four scopes: measure names, table names, column names, display folders (measures with no display folder flagged)

**Chunking and Progress**
- All four domain passes run silently; analyst sees one final combined severity-sorted report
- Single progress line before report appears: "Auditing 4 domains..." — then the report
- No domain-by-domain streaming output

**Audit Scope**
- Always runs all four domains — no domain flags in v1
- Simple and predictable: `/pbi:audit` with no arguments runs everything
- If run outside a PBIP project: clear error and stop — "No PBIP project found in this directory. Run /pbi:audit from a directory containing .SemanticModel/." No file written, no partial output.

### Claude's Discretion
- Exact inferred naming pattern detection algorithm (how dominant pattern is identified)
- Severity thresholds within WARN vs INFO for specific naming cases
- How to handle TMSL vs TMDL structural differences when reading model metadata
- `audit-report.md` exact header/footer formatting

### Deferred Ideas (OUT OF SCOPE)
- Auto-fix mode — apply CRITICAL and WARN fixes directly after audit with one confirmation (AUD-V2-02)
- Domain-specific flags (`--relationships`, `--naming`) — v2 if models get large enough to need it
- Hidden column hygiene check (AUD-V2-01) — not in v1 scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUD-01 | User can run `/pbi:audit` against a PBIP project and receive a structured severity-graded report (CRITICAL / WARN / INFO) | Skill structure pattern from Phase 1/2 applies directly; severity grading algorithm documented below |
| AUD-02 | Audit checks naming conventions: table, column, and measure names follow a consistent pattern | Naming inference algorithm documented; dominant pattern detection approach defined |
| AUD-03 | Audit checks relationship health: flags bidirectional relationships, missing relationships between fact and dimension tables | TMDL `crossFilteringBehavior: bothDirections` and TMSL `"crossFilteringBehavior": "bothDirections"` properties documented; fixture already contains both |
| AUD-04 | Audit checks date table presence and correct configuration (marked as date table, continuous date range, no gaps) | Date table detection via `dataCategory: Time` in TMDL / `dataCategory` field in TMSL documented; validation logic documented |
| AUD-05 | Audit checks measure quality: blank `formatString`, empty `description`, measures with no display folder | Measure property paths documented for both TMDL and TMSL; existing fixtures already have both missing-description and present-description cases |
| AUD-06 | Audit is chunked by domain (one pass per category) to avoid context window saturation on large models | Four-pass architecture documented; silent accumulation pattern defined |
| AUD-07 | Audit report includes specific location (table/measure name) and a concrete recommendation for each finding | Finding data model documented; name-extraction rules for both TMDL and TMSL defined |
</phase_requirements>

---

## Summary

Phase 3 builds a read-only model health scanner that runs entirely within a single Claude skill. It reads the same PBIP files established in Phase 2 (TMDL `definition/tables/*.tmdl` + `definition/relationships.tmdl`, or TMSL `model.bim`), processes them across four domain passes in the skill's working context, and produces a single severity-sorted markdown report printed inline and written to `audit-report.md`.

The skill is structurally the same as Phase 2 skills: a startup detection block sets `PBIP_MODE` and `PBIP_FORMAT`, then the instruction steps execute. The key difference is that this skill only reads — no Desktop safety check needed, no Write to model files. The output file (`audit-report.md`) is a new file created by the skill, not a modification to model files.

The four audit domains — Relationships, Naming, Date Table, Measures — are architecturally independent checks that Claude runs in sequence. "Chunking" in this context means: Claude reads and analyses one domain category at a time, building a findings list per domain, then merges all findings into the final report sorted by severity. This stays well within context limits for models up to ~200 measures because each domain pass reads only the metadata it needs.

**Primary recommendation:** Implement `/pbi:audit` as a new skill at `.claude/skills/pbi-audit/SKILL.md`. Reuse the Phase 2 PBIP detection startup block verbatim. Define the four audit domains as sequential instruction steps with named findings accumulators. Emit one progress line at the start, then the complete merged report at the end.

---

## Standard Stack

### Core

| Component | Version / Location | Purpose | Why Standard |
|-----------|-------------------|---------|--------------|
| Claude Code skill `!` bash injection | Current (2026) | PBIP detection and session context at startup | Same mechanism as Phases 1 and 2 — established pattern |
| `Read` tool | Claude Code | Read TMDL and model.bim files | Only tool needed; audit is read-only |
| `Write` tool | Claude Code | Write `audit-report.md` to project root | Same Read-then-Write pattern established in Phase 1 |
| PBIP detection block | Phase 2 established | Set `PBIP_MODE` and `PBIP_FORMAT` | Copy verbatim from pbi-load startup block |

### Supporting

| Component | Version / Location | Purpose | When to Use |
|-----------|-------------------|---------|-------------|
| `find` + bash | Bash built-in | Enumerate all `.tmdl` table files and relationships file | TMDL projects only; same `find .SemanticModel/definition/tables/ -name "*.tmdl"` pattern from Phase 2 |
| Session context injection (`tail -80`) | Established in Phase 1 | Inject `.pbi-context.md` for prior audit context | Allows audit to note if same issues were found previously |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Read tool for all files | Bash `cat` for model.bim | Read tool is the established pattern; gives better error handling and is file-size safe |
| Single monolithic pass over all files | Four domain passes | Single pass risks context saturation on large models; domain passes are explicitly required by AUD-06 |
| Hardcoded naming standards | Inferred dominant pattern | Hardcoded standards break on teams with different conventions; inference works universally |

**Installation:** No packages to install. Same toolset as Phases 1 and 2.

---

## Architecture Patterns

### Recommended Skill Structure

```
.claude/skills/pbi-audit/
└── SKILL.md              # /pbi:audit skill — all audit logic inline
```

No knowledge sub-file is needed: the four domain rules are concise enough to embed directly in SKILL.md without exceeding the skills character budget.

### Skill Frontmatter

```yaml
---
name: pbi:audit
description: Run a full model health audit against a PBIP project. Checks naming conventions, relationship health, date table configuration, and measure quality.
argument-hint: "(no arguments — runs from directory containing .SemanticModel/)"
disable-model-invocation: true
allowed-tools: Read, Write, Bash
model: sonnet
---
```

### Pattern 1: Startup Detection Block (verbatim from Phase 2)

```yaml
## PBIP Context Detection
!`PBIP_RESULT=""; if [ -d ".SemanticModel" ]; then PBISM=$(cat ".SemanticModel/definition.pbism" 2>/dev/null); if echo "$PBISM" | grep -q '"version": "1.0"'; then PBIP_RESULT="PBIP_MODE=file PBIP_FORMAT=tmsl"; else PBIP_RESULT="PBIP_MODE=file PBIP_FORMAT=tmdl"; fi; else PBIP_RESULT="PBIP_MODE=paste"; fi; echo "$PBIP_RESULT"`

## PBIP File Index
!`if [ -d ".SemanticModel/definition/tables" ]; then find ".SemanticModel/definition/tables/" -name "*.tmdl" 2>/dev/null; elif [ -f ".SemanticModel/model.bim" ]; then echo "tmsl:.SemanticModel/model.bim"; fi`

## Session Context
!`cat .pbi-context.md 2>/dev/null | tail -80 || echo "No prior context found."`
```

Note: Desktop check block is NOT needed for audit — it is read-only. Omit the `tasklist` injection.

### Pattern 2: No-PBIP Error and Stop

If `PBIP_MODE=paste` (no `.SemanticModel/` found), the skill must output this exact message and stop immediately:

```
No PBIP project found in this directory. Run /pbi:audit from a directory containing .SemanticModel/.
```

No `audit-report.md` is written. No further steps execute.

### Pattern 3: Four-Pass Audit Architecture

Each domain pass is a numbered instruction step. Claude accumulates findings per domain, then merges and sorts at the end.

```
Step 1 — Read all model metadata (tables, measures, columns, relationships)
Step 2 — Domain Pass A: Relationships audit → findings_relationships[]
Step 3 — Domain Pass B: Naming audit → findings_naming[]
Step 4 — Domain Pass C: Date Table audit → findings_date[]
Step 5 — Domain Pass D: Measures audit → findings_measures[]
Step 6 — Merge all findings, sort by severity (CRITICAL first, then WARN, then INFO)
Step 7 — Emit progress line, then full report inline
Step 8 — Write audit-report.md to project root
Step 9 — Update .pbi-context.md
```

**The "chunking" in AUD-06** means Claude analyses one category at a time (one step per domain), not that Claude makes multiple API calls. Each domain step focuses Claude's reasoning on one rule set, preventing cross-domain confusion and keeping each reasoning window small even for large models.

### Pattern 4: Model Metadata Extraction

**For TMDL projects:**

Claude reads:
- Each file returned by `find .SemanticModel/definition/tables/ -name "*.tmdl"` using the Read tool
- `.SemanticModel/definition/relationships.tmdl` using the Read tool (if it exists)

From each table `.tmdl` file, extract:
- Table name: from `table TableName` declaration at top of file
- Measure names, formatString, description (triple-slash `///`), displayFolder: from `measure` blocks
- Column names and dataTypes: from `column` blocks
- `dataCategory:` property at table level (marks date table)

From `relationships.tmdl`, extract:
- Each `relationship` block: `fromTable`, `fromColumn`, `toTable`, `toColumn`, `crossFilteringBehavior`

**For TMSL projects:**

Claude reads `.SemanticModel/model.bim` once. Extract:
- `model.tables[].name` — table names
- `model.tables[].measures[]` — measure names, `expression`, `description`, `formatString`, `displayFolder`
- `model.tables[].columns[]` — column names, `dataType`
- `model.tables[].dataCategory` — date table indicator (`"Time"` = marked as date table)
- `model.relationships[]` — `fromTable`, `fromColumn`, `toTable`, `toColumn`, `crossFilteringBehavior`

### Pattern 5: Finding Data Model

Each finding is a structured object:

```
{
  severity: "CRITICAL" | "WARN" | "INFO",
  domain: "[Relationships]" | "[Naming]" | "[Date Table]" | "[Measures]",
  subject: "Table: SalesOrders" | "Measure: Revenue" | "Column: Sales[CustomerKey]",
  finding: "One-line description of what is wrong",
  recommendation: "One-line concrete action to fix it"
}
```

In the report, rendered as:

```
🔴 CRITICAL [Relationships] Sales → Date (Date → Date)
Bidirectional filter — both directions set on relationship from Sales to Date.
Recommendation: Set to single-direction (Sales → Date). Bidirectional filters cause ambiguous filter paths and degrade query performance.
```

### Pattern 6: Report Format

```markdown
# PBI Model Audit Report
**Project:** .SemanticModel
**Format:** TMDL / TMSL
**Date:** YYYY-MM-DD HH:MM UTC
**Findings:** X CRITICAL · Y WARN · Z INFO

---

## 🔴 CRITICAL

### [Relationships] Sales → Date
Bidirectional relationship on Sales[Date] → Date[Date].
**Recommendation:** Change to single-direction filter (Sales → Date). Bidirectional filters create ambiguous filter paths and degrade query performance in star schemas.

---

## 🟡 WARN

### [Date Table] No date table detected
No table with dataCategory: Time found in the model.
**Recommendation:** Mark your date dimension table as a date table (Table Tools > Mark as date table in Power BI Desktop). Required for classic DAX time intelligence functions.

### [Measures] Revenue — no description
Measure 'Revenue' in table Sales has no description.
**Recommendation:** Add a description explaining the business calculation. Use /pbi:comment to generate one automatically.

---

## 🔵 INFO

### [Naming] Mixed measure naming pattern
3 of 5 measures use Title Case (e.g., 'Sales Amount'), 2 use prefixed lower (e.g., 'rev_ytd').
**Recommendation:** Standardise on Title Case (dominant pattern) for all measures to improve maintainability.

---

*Audit complete. Report written to: audit-report.md*
```

### Anti-Patterns to Avoid

- **Reporting JSON paths instead of names:** Never write `model.tables[0].measures[1]`. Always extract and use the actual table and measure names.
- **Streaming domain-by-domain output:** The locked decision is silent passes then one final report. Do not print intermediate results.
- **Running Desktop check:** Audit is read-only. The `tasklist` injection adds unnecessary latency. Omit it entirely.
- **Writing to model files:** Audit is read-only in v1. Never modify `.tmdl` or `model.bim`. Only write `audit-report.md` (a new file, not a model file).
- **Blocking on missing relationships file:** In TMDL, `relationships.tmdl` may not exist if the model has no relationships. Treat its absence as "no relationships defined" — a valid WARN finding, not an error.

---

## Audit Domain Rules

### Domain A: Relationships

**Rule R-01 — Bidirectional relationship (CRITICAL)**
- TMDL: any `relationship` block with `crossFilteringBehavior: bothDirections`
- TMSL: any `model.relationships[]` with `"crossFilteringBehavior": "bothDirections"`
- Subject: `"Relationship: [FromTable] → [ToTable]"`
- Recommendation: `"Change crossFilteringBehavior to oneDirection. Bidirectional filters create ambiguous filter paths in star schemas and degrade query performance."`
- Fixture: both existing fixtures have this case (Sales → Date with bothDirections)

**Rule R-02 — Missing fact-to-dimension relationship (WARN)**
- Detection heuristic: tables with names matching typical fact patterns (no prefix, or `fact` prefix, or containing "Sales", "Orders", "Transactions", "Invoice", "Fact") that have NO outbound relationships to any other table
- Subject: `"Table: [TableName] (potential fact table with no outbound relationships)"`
- Recommendation: `"Verify this table is intentionally isolated. Fact tables typically have relationships to dimension tables for filter propagation."`
- Note: This is heuristic — the audit should flag for human review, not definitively diagnose. Mark as WARN not CRITICAL.
- Confidence: MEDIUM — heuristic detection; the analyst must confirm

**Rule R-03 — No relationships defined (INFO)**
- If the model has more than 2 tables and zero relationships
- Subject: `"Model: .SemanticModel"`
- Recommendation: `"Model has [N] tables with no relationships. If tables are intentionally standalone, this can be ignored. If relationships should exist, define them in Power BI Desktop."`

### Domain B: Naming

**Naming inference algorithm (Claude's discretion):**

1. Collect all measure names, all table names, all column names separately
2. For each scope (measures, tables, columns), detect the dominant pattern:
   - Title Case (words separated by spaces, each word capitalised): "Sales Amount", "Revenue YTD"
   - PascalCase (no spaces, each word capitalised): "SalesAmount", "RevenueYTD"
   - snake_case (lowercase with underscores): "sales_amount", "revenue_ytd"
   - Prefix pattern (measure name starts with a short prefix + underscore or space): "rev_", "kpi_", "[CAL] "
   - Mixed/no pattern: no dominant pattern detectable
3. Dominant pattern = the pattern used by the majority (>50%) of names in that scope
4. Flag deviations from dominant pattern as INFO
5. Flag blank or whitespace-only names as WARN
6. Flag names with leading/trailing spaces as WARN
7. Flag measures with no display folder as WARN

**Rule N-01 — Blank or missing name (WARN)**
- Any measure, table, or column with an empty or whitespace-only name
- Recommendation: `"Provide a descriptive name. Blank names cause display issues in report visuals."`

**Rule N-02 — Special character in name (WARN)**
- Names containing characters that require TMDL quoting but are unconventional: leading/trailing spaces, or characters outside alphanumeric + space + underscore
- Recommendation: `"Rename to remove special characters. Names with special characters require quoting in DAX expressions."`

**Rule N-03 — Naming style inconsistency (INFO)**
- Names deviating from the inferred dominant pattern for their scope
- Group by scope: only report if 3+ names deviate (avoid false positives on small models)
- Recommendation: `"Standardise on [inferred pattern] (dominant pattern in this model)."`

**Rule N-04 — Measure with no display folder (WARN)**
- Any measure where displayFolder is absent or empty string
- Subject: `"Measure: [Name] in [Table]"`
- Recommendation: `"Assign a display folder to organise measures in the Fields pane. Use /pbi:comment to set a display folder."`
- Source: AUD-05 requirement explicitly lists this

### Domain C: Date Table

**Rule D-01 — No date table detected (WARN)**
- TMDL: no table file has `dataCategory: Time` at the table level
- TMSL: no `model.tables[]` entry has `"dataCategory": "Time"`
- Subject: `"Model: .SemanticModel"`
- Recommendation: `"Mark your date dimension table as a date table in Power BI Desktop (Table Tools > Mark as date table). Required for DAX time intelligence functions (DATESYTD, TOTALYTD, etc.)."`
- Note: If the model has no fact table relationships at all (e.g., pure DAX model with auto date/time), this is expected. The audit should note this nuance.

**Rule D-02 — Date table exists but date column not detectable (INFO)**
- Table is marked as date table (`dataCategory: Time`) but has no column with `dataType: dateTime` or `dataType: date`
- Subject: `"Table: [DateTableName]"`
- Recommendation: `"Verify the date table has a Date/DateTime column designated as the key date column. The date column must contain unique, contiguous dates with no gaps."`

**How to detect `dataCategory: Time` in each format:**
- TMDL: look for the line `dataCategory: Time` at the table level (top of the `.tmdl` file, before the first `column` or `measure` block). This is a table-level property.
- TMSL: `model.tables[n].dataCategory` field = `"Time"` (string value)

**Validation criteria for a properly configured date table (per Microsoft Learn):**
- Date column contains unique values
- Date column contains no BLANKs
- Date column contains contiguous date values (no gaps)
- Date column is Date or DateTime data type

**NOTE:** The audit cannot verify actual data content (row-level validation) — it can only check whether the table is marked as a date table and whether a DateTime/Date column exists. Data content checks (gaps, blanks) are out of scope for a static file-based audit. Flag the inability as INFO: "Date table found — data content validation (gaps, blank dates) requires Power BI Desktop."

### Domain D: Measure Quality

**Rule M-01 — Empty formatString (WARN)**
- TMDL: measure block has no `formatString:` property line
- TMSL: measure object has no `"formatString"` field, or `"formatString"` is empty string
- Subject: `"Measure: [Name] in Table: [TableName]"`
- Recommendation: `"Add a format string. Example: '#,##0' for integers, '#,##0.00' for decimals, '0.0%' for percentages. Missing format strings cause inconsistent display in reports."`

**Rule M-02 — Empty description (INFO)**
- TMDL: measure block has no `///` description line immediately above it
- TMSL: measure object has no `"description"` field, or `"description"` is empty string
- Subject: `"Measure: [Name] in Table: [TableName]"`
- Recommendation: `"Add a description explaining the business logic. Use /pbi:comment to generate a description automatically."`
- Severity: INFO (not WARN) — missing descriptions hurt discoverability but don't affect correctness

**Rule M-03 — No display folder (WARN)**
- Same as Rule N-04 above — measure quality and naming domains overlap here
- TMDL: measure block has no `displayFolder:` property line
- TMSL: measure object has no `"displayFolder"` field, or it is empty string
- Subject: `"Measure: [Name] in Table: [TableName]"`
- Recommendation: `"Assign a display folder to group related measures in the Fields pane."`

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PBIP format detection | Custom parser | `cat definition.pbism \| grep '"version"'` — same as Phase 2 | Same established pattern; no new code needed |
| Model metadata index | Custom TOM/XMLA reader | Read TMDL/model.bim with Read tool; extract via text patterns | Files are human-readable text by design |
| Naming pattern classifier | ML model or regex library | Count occurrences of each pattern type, pick majority — simple frequency analysis | Sufficient accuracy for audit use case; no dependencies |
| Date gap detection | Date range calculator | Acknowledge limitation in report: data validation requires live query; flag as INFO | Static file audit cannot inspect row-level data |
| Bidirectional relationship severity | Complex graph analysis | Simple property check: `crossFilteringBehavior: bothDirections` = CRITICAL, done | This is a direct property, not derived from graph topology |

**Key insight:** The audit skill is still pure prompt-and-file work. Power BI's PBIP file formats expose all model metadata that the audit needs (property names, relationships, data categories) as human-readable text. No compiled analysis tools are required.

---

## Common Pitfalls

### Pitfall 1: Extracting TMDL dataCategory as Column Property Not Table Property

**What goes wrong:** `dataCategory` appears in TMDL at both the table level (marks the whole table as a date/time table) and at the column level (marks specific columns as date-related). Reading a column's `dataCategory` line and concluding the table is marked as a date table is incorrect.

**Why it happens:** TMDL uses indentation for scope. A `dataCategory: Time` line at table level (no indentation or one indent) is different from a column-level `dataCategory:` line (two indents, inside a `column` block).

**How to avoid:** Parse the TMDL table file structurally. The table-level `dataCategory: Time` appears at the top of the file before the first `column` or `measure` declaration. Column-level `dataCategory` appears inside column blocks. When checking for date table status, look only for the table-level property.

**Warning signs:** Audit reports "date table found" for a table that is not marked as a date table in Power BI Desktop.

### Pitfall 2: Missing relationships.tmdl Treated as Error

**What goes wrong:** Skill errors out or produces no relationships output when `relationships.tmdl` does not exist.

**Why it happens:** A model with no relationships has no `relationships.tmdl` file. This is a valid state, not a missing file error.

**How to avoid:** Use `Read tool` with awareness that the file may not exist. If the file is not found, treat as "no relationships defined" and apply Rule R-03 if applicable. Do not error.

**Warning signs:** Audit fails entirely or reports an unhandled error for models without relationships.

### Pitfall 3: Reporting Both N-04 and M-03 as Separate Findings for the Same Measure

**What goes wrong:** The "no display folder" check appears in both the Naming domain (N-04) and the Measures domain (M-03). Both rules fire for the same measure, producing duplicate findings.

**Why it happens:** The audit domain split was designed for conceptual clarity, but display folder touches both naming and measure quality.

**How to avoid:** Deduplicate findings before the final merge. If a measure is flagged for "no display folder" in both domains, emit only one finding. Alternatively, assign display folder check exclusively to the Measures domain (M-03) and remove N-04 from Naming.

**Warning signs:** The same measure appears twice in the final report for the same issue.

### Pitfall 4: TMDL Measure Description Not Found Due to Blank Line

**What goes wrong:** Audit fails to detect a measure description because there is a blank line between the `///` comment and the `measure` keyword.

**Why it happens:** TMDL requires the `///` description to be on the line immediately above `measure` with no blank line between them. If a blank line exists, the `///` is not associated with the measure.

**How to avoid:** When extracting measure descriptions from TMDL, search for `///` lines immediately preceding (no blank line gap) the `measure` keyword. A `///` line with a blank line above the `measure` keyword is not a description.

**Warning signs:** Audit reports missing description for measures that have `///` lines in the file.

### Pitfall 5: TMSL model.bim Missing `description` Field vs. Empty String

**What goes wrong:** In TMSL, a measure may have `"description": ""` (empty string) or may have no `"description"` key at all. Checking only for the presence of the key misses the empty string case.

**Why it happens:** Power BI Desktop writes `"description": ""` when a description was typed and then cleared. New measures have no `"description"` key at all.

**How to avoid:** When checking measure quality in TMSL, flag a measure as missing description if: (a) no `"description"` key exists, or (b) the `"description"` value is an empty string or whitespace-only string.

**Warning signs:** Audit does not flag measures with `"description": ""` as missing descriptions.

### Pitfall 6: Large model.bim Context Saturation

**What goes wrong:** For models with 50+ tables and 200+ measures, reading the entire `model.bim` in one step saturates Claude's working context before auditing begins.

**Why it happens:** `model.bim` grows proportionally with model complexity. A model with 50 tables, 5 columns each, and 200 measures can produce a 500KB+ JSON file.

**How to avoid:** For TMSL projects, read `model.bim` once and extract only the metadata needed for each domain pass before running rules. Do not re-read the file per domain. The four-pass architecture still processes one domain at a time, but the file read is shared. If model.bim is extremely large (>2000 lines), consider reading in sections using the offset/limit parameters of the Read tool.

**Warning signs:** Skill times out or produces incomplete output for large models.

---

## Code Examples

Verified patterns from Phase 2 research and official sources:

### Startup Detection (verbatim from pbi-load)

```yaml
## PBIP Context Detection
!`PBIP_RESULT=""; if [ -d ".SemanticModel" ]; then PBISM=$(cat ".SemanticModel/definition.pbism" 2>/dev/null); if echo "$PBISM" | grep -q '"version": "1.0"'; then PBIP_RESULT="PBIP_MODE=file PBIP_FORMAT=tmsl"; else PBIP_RESULT="PBIP_MODE=file PBIP_FORMAT=tmdl"; fi; else PBIP_RESULT="PBIP_MODE=paste"; fi; echo "$PBIP_RESULT"`

## PBIP File Index
!`if [ -d ".SemanticModel/definition/tables" ]; then find ".SemanticModel/definition/tables/" -name "*.tmdl" 2>/dev/null; elif [ -f ".SemanticModel/model.bim" ]; then echo "tmsl:.SemanticModel/model.bim"; fi`

## Session Context
!`cat .pbi-context.md 2>/dev/null | tail -80 || echo "No prior context found."`
```

Note: Desktop check block (`tasklist`) is deliberately omitted — audit is read-only.

### TMDL: Detecting a Date Table

```tmdl
table Date
	dataCategory: Time    ← TABLE LEVEL property — this marks the table as a date table

	column Date
		dataType: dateTime
		dataCategory: PaddedDateTableDates    ← COLUMN LEVEL property — different scope
```

Detection: read the `.tmdl` file for a table. If the first few non-blank lines after `table TableName` contain `dataCategory: Time` (before any `column` or `measure` block), the table is a date table.

### TMSL: Detecting a Date Table

```json
{
  "name": "Date",
  "dataCategory": "Time",
  "columns": [...]
}
```

Detection: check `model.tables[n].dataCategory == "Time"`.

### TMDL: Detecting Bidirectional Relationship

```tmdl
relationship 'Sales_Date'
	fromTable: Sales
	fromColumn: Date
	toTable: Date
	toColumn: Date
	crossFilteringBehavior: bothDirections    ← CRITICAL flag
```

### TMSL: Detecting Bidirectional Relationship

```json
{
  "name": "Sales_Date",
  "fromTable": "Sales",
  "fromColumn": "Date",
  "toTable": "Date",
  "toColumn": "Date",
  "crossFilteringBehavior": "bothDirections"    ← CRITICAL flag
}
```

Source: Phase 2 confirmed `crossFilteringBehavior` property; fixtures already contain both variants.

### TMDL: Extracting Measure Quality Fields

```tmdl
/// Year-to-date revenue filtered to visible periods.  ← description (INFO if absent)
measure 'Revenue YTD' =
		CALCULATE([Revenue], DATESYTD('Date'[Date]))
	formatString: #,##0                               ← WARN if absent
	displayFolder: "Time Intelligence"                ← WARN if absent
```

Absent description: no `///` line immediately above `measure` keyword.
Absent formatString: no `formatString:` line inside the measure block.
Absent displayFolder: no `displayFolder:` line inside the measure block.

### TMSL: Extracting Measure Quality Fields

```json
{
  "name": "Revenue",
  "expression": "SUM(Sales[Amount])",
  "formatString": "#,##0",         ← WARN if missing or empty
  "displayFolder": "Base Measures" ← WARN if missing or empty
  // "description" absent          ← INFO (missing description)
}
```

### .pbi-context.md Update After Audit

After writing `audit-report.md`, update `.pbi-context.md`:
- `## Last Command`: Command = `/pbi:audit`, Timestamp = current UTC, Outcome = `Audit complete — [N CRITICAL, M WARN, P INFO findings]. Report written to audit-report.md`
- `## Command History`: Append row with same values

---

## Fixture Verification

The existing Phase 2 fixtures already exercise the key audit rules:

| Fixture | Property | Expected Audit Finding |
|---------|----------|------------------------|
| `pbip-tmdl/relationships.tmdl` | `crossFilteringBehavior: bothDirections` | 🔴 CRITICAL [Relationships] Sales → Date — bidirectional |
| `pbip-tmdl/Sales.tmdl` (measure Revenue) | No `///` description | 🔵 INFO [Measures] Revenue — no description |
| `pbip-tmsl/model.bim` (relationship) | `"crossFilteringBehavior": "bothDirections"` | 🔴 CRITICAL [Relationships] Sales → Date — bidirectional |
| `pbip-tmsl/model.bim` (measure Revenue) | No `"description"` field | 🔵 INFO [Measures] Revenue — no description |
| Both fixtures | No table with `dataCategory: Time` / `"dataCategory": "Time"` | 🟡 WARN [Date Table] No date table detected |

No new fixtures need to be created for Phase 3 — the Phase 2 fixtures are sufficient for all verification cases. A Wave 0 task should add a date table entry to one fixture to exercise the positive case (date table found, correctly configured).

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Tabular Editor BPA for model auditing | Direct PBIP file inspection via Claude skill | 2024–2025 (PBIP GA) | No external tool required; model metadata readable as plain text |
| Audit requires TOM/XMLA connection | Static file analysis | 2024 (TMDL GA) | Audit can run without Power BI Desktop or Analysis Services connection |
| Single-pass model analysis | Domain-chunked passes | Phase 3 design decision | Prevents context saturation on large models |

**Deprecated/outdated:**
- Tabular Editor BPA as the only audit option: TMDL makes model metadata available as plain text, enabling Claude-based auditing without Tabular Editor installation.
- XMLA-only relationship inspection: Relationship properties are now directly readable in `relationships.tmdl` and `model.relationships[]` in model.bim.

---

## Open Questions

1. **TMDL table-level dataCategory exact syntax**
   - What we know: Multiple sources confirm `dataCategory: Time` is the TMDL property for marking a table as a date table. Search results show `table Date dataCategory: Time` syntax.
   - What's unclear: Whether `dataCategory: Time` appears on the `table` declaration line or on a separate indented line below it.
   - Recommendation: Wave 0 task — inspect an actual TMDL file from a model with a marked date table. If no real model is available, add a `Date.tmdl` fixture to the test fixtures with a marked date table. Treat as indented property (separate line) pending empirical verification, since all other table-level properties in the existing `Sales.tmdl` fixture are indented.
   - Confidence: MEDIUM

2. **Naming pattern detection edge cases for small models**
   - What we know: The dominant-pattern detection algorithm works on frequency; majority wins.
   - What's unclear: What to do when a model has only 2–3 measures (no clear majority possible).
   - Recommendation: For models with fewer than 4 items in a scope, skip naming pattern inference for that scope and emit no INFO findings. Avoid false positives on minimal models.

3. **Missing fact-to-dimension relationship heuristic reliability**
   - What we know: Rule R-02 uses table name patterns to identify potential fact tables. This is heuristic.
   - What's unclear: False positive rate for models that don't use `dim`/`fact` naming but have intentionally isolated tables (e.g., parameter tables, disconnected tables).
   - Recommendation: Set severity to WARN (not CRITICAL) and phrase the finding as "verify this is intentional" rather than "this is a problem". The analyst is the final arbiter.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — prompt/skill system with no compiled code |
| Config file | N/A |
| Quick run command | Manual: invoke `/pbi:audit` in directory containing `tests/fixtures/pbip-tmdl/.SemanticModel/` |
| Full suite command | Manual: run `/pbi:audit` against both TMDL and TMSL fixtures; verify expected findings appear |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUD-01 | `/pbi:audit` produces CRITICAL/WARN/INFO graded report | smoke | Manual — run `/pbi:audit` from TMDL fixture dir; verify report has severity sections | ✅ Fixture exists |
| AUD-02 | Naming conventions checked across all four scopes | manual | Run `/pbi:audit` from TMDL fixture; verify naming findings appear in report | ✅ Fixture exists |
| AUD-03 | Bidirectional relationships flagged as CRITICAL | manual | Run `/pbi:audit` from TMDL fixture; verify 🔴 CRITICAL [Relationships] Sales → Date appears | ✅ Fixture exists |
| AUD-03 | Missing fact-to-dimension relationships flagged as WARN | manual | Run `/pbi:audit` with fixture that has isolated table; verify WARN appears | ❌ Wave 0 |
| AUD-04 | Date table absence flagged as WARN | manual | Run `/pbi:audit` from fixture with no date table; verify 🟡 WARN [Date Table] appears | ✅ Fixture exists (no date table in current fixtures) |
| AUD-04 | Date table presence acknowledged | manual | Run `/pbi:audit` with date table fixture; verify positive detection | ❌ Wave 0 — need Date table fixture |
| AUD-05 | Missing description flagged as INFO | manual | Run `/pbi:audit` from TMDL fixture; verify 🔵 INFO [Measures] Revenue appears | ✅ Fixture exists |
| AUD-05 | Missing formatString flagged as WARN | manual | Verify existing fixtures — both measures have formatString, so no WARN expected | ✅ Fixture exists (but no gap to test WARN) |
| AUD-05 | No display folder flagged as WARN | manual | Run `/pbi:audit` from fixture; both measures have displayFolder so no WARN expected | ✅ Fixture exists (but no gap) |
| AUD-06 | Audit runs in four domain passes | structural | Review SKILL.md instruction steps — verify four numbered domain steps | ❌ Wave 0 (skill file not yet written) |
| AUD-07 | Every finding includes table/measure name and recommendation | manual | Inspect report output; verify no JSON paths, all findings have subject + recommendation | ✅ Verified via report format spec |

### Sampling Rate

- **Per task commit:** Bash smoke — `ls audit-report.md 2>/dev/null && echo "exists"` after running `/pbi:audit`
- **Per wave merge:** Full manual pass against both TMDL and TMSL fixtures; verify all expected findings appear
- **Phase gate:** All manual tests pass before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/fixtures/pbip-tmdl/.SemanticModel/definition/tables/Date.tmdl` — date table fixture with `dataCategory: Time` property to test AUD-04 positive case
- [ ] `tests/fixtures/pbip-tmdl/.SemanticModel/definition/tables/Products.tmdl` — isolated table with no outbound relationships to test AUD-03 missing-relationship WARN case
- [ ] Verify TMDL `dataCategory: Time` exact syntax empirically by reading the Date.tmdl fixture after creation

---

## Sources

### Primary (HIGH confidence)
- [Microsoft Learn — TMDL Object Definitions](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-reference-tabular-object?view=sql-analysis-services-2025) — TMDL property-to-TOM mapping, relationship syntax, table properties (updated 2026-03-09)
- [Microsoft Learn — Design guidance for date tables](https://learn.microsoft.com/en-us/power-bi/guidance/model-date-tables) — date table requirements: unique dates, no BLANKs, no gaps, Date/DateTime type, mark as date table (updated 2026-01-02)
- [Microsoft Learn — Set and use date tables](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-date-tables) — mark as date table validation criteria, when required (updated 2026-01-30)
- Phase 2 RESEARCH.md — TMDL/TMSL file structure, measure property extraction, startup detection pattern (HIGH confidence, verified 2026-03-12)
- Existing test fixtures — `relationships.tmdl` confirms `crossFilteringBehavior: bothDirections` TMDL syntax; `model.bim` confirms TMSL equivalent

### Secondary (MEDIUM confidence)
- [SQLBI DAX Naming Conventions](https://docs.sqlbi.com/dax-style/dax-naming-conventions) — standard measure naming guidance: Title Case for visible measures, PascalCase for hidden
- Web search results (2025) — `dataCategory: Time` confirmed as TMDL table-level property for date tables; `bothDirections` confirmed as the bidirectional relationship value
- [Tabular Editor BestPracticeRules GitHub](https://github.com/TabularEditor/BestPracticeRules) — rule categories confirmed (Naming/META/PERF/DAX); specific rule IDs not extracted (JSON files not fetched)

### Tertiary (LOW confidence)
- TMDL `dataCategory: Time` exact line placement (table declaration line vs. indented sub-property): confirmed as a property but exact formatting not verified from official source — recommend empirical Wave 0 check

---

## Metadata

**Confidence breakdown:**
- Standard stack (bash tools, Read/Write): HIGH — identical to Phase 2 stack
- TMDL bidirectional relationship syntax (`crossFilteringBehavior: bothDirections`): HIGH — confirmed in Phase 2 fixtures and web search
- TMSL bidirectional relationship syntax: HIGH — confirmed in Phase 2 fixtures
- Date table detection via `dataCategory: Time`: MEDIUM — property name confirmed by multiple sources; exact TMDL line placement needs empirical check
- Naming inference algorithm design: MEDIUM — frequency-based dominant pattern is reasonable; no official precedent for this specific approach
- Missing relationship heuristic (R-02): MEDIUM — heuristic by design; false positive risk acknowledged

**Research date:** 2026-03-12
**Valid until:** 2026-06-12 (PBIP format and audit rule semantics are stable; naming conventions are enduring practices)
