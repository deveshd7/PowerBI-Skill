---
name: pbi:audit
description: Run a full model health audit against a PBIP project. Checks naming conventions, relationship health, date table configuration, and measure quality. Produces a severity-graded CRITICAL / WARN / INFO report.
argument-hint: "(no arguments — runs from directory containing .SemanticModel/)"
disable-model-invocation: true
allowed-tools: Read, Write, Bash
model: sonnet
---

## PBIP Context Detection
!`PBIP_RESULT=""; if [ -d ".SemanticModel" ]; then PBISM=$(cat ".SemanticModel/definition.pbism" 2>/dev/null); if echo "$PBISM" | grep -q '"version": "1.0"'; then PBIP_RESULT="PBIP_MODE=file PBIP_FORMAT=tmsl"; else PBIP_RESULT="PBIP_MODE=file PBIP_FORMAT=tmdl"; fi; else PBIP_RESULT="PBIP_MODE=paste"; fi; echo "$PBIP_RESULT"`

## PBIP File Index
!`if [ -d ".SemanticModel/definition/tables" ]; then find ".SemanticModel/definition/tables/" -name "*.tmdl" 2>/dev/null; elif [ -f ".SemanticModel/model.bim" ]; then echo "tmsl:.SemanticModel/model.bim"; fi`

## Session Context
!`cat .pbi-context.md 2>/dev/null | tail -80 || echo "No prior context found."`

---

## Instructions

### Step 0 — Check PBIP detection output

Read the output from the PBIP Context Detection block above.

**If PBIP_MODE=paste:** output exactly this message and stop. Do not write any files. Do not proceed.

> No PBIP project found in this directory. Run /pbi:audit from a directory containing .SemanticModel/.

**If PBIP_MODE=file:** output a single progress line:

```
Auditing 4 domains...
```

Then proceed to Step 1.

---

### Step 1 — Read all model metadata

**For TMDL (PBIP_FORMAT=tmdl):**

The PBIP File Index block has already listed all `.tmdl` file paths under `.SemanticModel/definition/tables/`.

Use the Read tool to read every `.tmdl` file path returned by the PBIP File Index block.

Use the Read tool to read `.SemanticModel/definition/relationships.tmdl` — if not found, treat as "no relationships defined" (do not error).

From each table `.tmdl` file extract:

- **Table name:** the first non-blank line starting with `table ` — extract the name after `table `
- **Table-level dataCategory:** look for `dataCategory: Time` appearing BEFORE any `column` or `measure` keyword in the file. This is a table-level property, not inside a column or measure block.
- **Measure blocks:** each `measure Name =` or `measure 'Name' =` block. For each measure extract:
  - Name: text after `measure ` up to ` =`, stripping single quotes
  - Whether a `///` description line appears IMMEDIATELY above the measure keyword (no blank line between `///` and `measure`)
  - Whether `formatString:` appears inside the block (before the next `measure`, `column`, or end of block)
  - Whether `displayFolder:` appears inside the block (before the next `measure`, `column`, or end of block)
- **Column blocks:** each `column Name` line. Extract column name, strip quotes if present. Also extract `dataType:` for each column.

From `relationships.tmdl` extract: for each `relationship` block, the fromTable, fromColumn, toTable, toColumn, and crossFilteringBehavior value.

**For TMSL (PBIP_FORMAT=tmsl):**

Use the Read tool to read `.SemanticModel/model.bim`.

If model.bim is >2000 lines, use the offset/limit parameters to read in sections — extract only metadata fields (skip expression bodies after the first line).

From the JSON structure extract:

- `model.tables[]`: table name, dataCategory (flag if "Time"), measures array, columns array
- For each measure: name, description (flag as missing if absent OR if empty string ""), formatString (flag as missing if absent or ""), displayFolder (flag as missing if absent or "")
- `model.relationships[]`: fromTable, fromColumn, toTable, toColumn, crossFilteringBehavior (flag if "bothDirections")

Build an internal metadata structure. Do not output it yet.

---

### Step 2 — Domain Pass A: Relationships

Accumulate findings_relationships[]:

**Rule R-01 — Bidirectional relationship (CRITICAL):**
- Any relationship where crossFilteringBehavior = "bothDirections" (TMDL or TMSL)
- Subject: `Relationship: [FromTable] → [ToTable]`
- Finding: `Bidirectional filter set on relationship from [FromTable][FromColumn] to [ToTable][ToColumn].`
- Recommendation: `Change crossFilteringBehavior to single-direction (fromTable → toTable). Bidirectional filters create ambiguous filter paths in star schemas and degrade query performance.`

**Rule R-02 — Isolated table heuristic (WARN):**
- Tables with NO outbound relationships (table does not appear as fromTable in any relationship) AND whose name matches typical patterns: name contains "Sales", "Orders", "Transactions", "Invoice", "Fact", or has no "Dim" prefix (i.e., it could be a fact table)
- Only flag if the table also has at least one numeric column (dataType: decimal or int64) — reduces false positives
- Subject: `Table: [TableName] (potential fact table with no outbound relationships)`
- Finding: `Table [TableName] has no outbound relationships to any other table.`
- Recommendation: `Verify this table is intentionally isolated. Fact tables typically have relationships to dimension tables for filter propagation.`

**Rule R-03 — No relationships at all (INFO):**
- If model has more than 2 tables AND zero relationships total
- Subject: `Model: .SemanticModel`
- Finding: `Model has [N] tables with no relationships defined.`
- Recommendation: `If tables are intentionally standalone this can be ignored. If relationships should exist, define them in Power BI Desktop.`

---

### Step 3 — Domain Pass B: Naming

Accumulate findings_naming[]:

**Naming inference algorithm:**
1. For each scope (measure names, table names, column names), collect all names
2. For scopes with 4+ names, detect dominant pattern:
   - Title Case: majority of words capitalised, spaces between words (e.g., "Revenue YTD", "Sales Amount")
   - PascalCase: no spaces, each word capitalised (e.g., "RevenueYTD", "SalesAmount")
   - snake_case: lowercase with underscores (e.g., "revenue_ytd")
   - Prefix pattern: names start with a consistent short prefix + separator (e.g., "kpi_", "[CAL] ")
   - Mixed: no dominant pattern (skip inference, emit no INFO findings)
3. Dominant pattern = pattern used by >50% of names in that scope
4. For scopes with fewer than 4 names: skip pattern inference — emit no naming INFO findings for that scope

**Rule N-01 — Blank or whitespace-only name (WARN):**
- Subject: `[Scope]: [Name in context]`
- Recommendation: `Provide a descriptive name. Blank names cause display issues in report visuals.`

**Rule N-02 — Special characters (WARN):**
- Names with leading/trailing spaces, or characters outside: letters, digits, spaces, underscores, hyphens, parentheses
- Recommendation: `Rename to remove special characters. Names with special characters require quoting in DAX expressions.`

**Rule N-03 — Naming style inconsistency (INFO):**
- Names deviating from inferred dominant pattern for their scope
- Only emit if 3+ names deviate (avoid noise on small models)
- Group all deviating names into ONE finding per scope (not one finding per name)
- Recommendation: `Standardise on [inferred pattern] (dominant pattern in this model).`

**Rule N-04:** SKIP — display folder is handled exclusively by Domain D Rule M-03. This avoids duplicate findings for the same measure.

---

### Step 4 — Domain Pass C: Date Table

Accumulate findings_date[]:

**Rule D-01 — No date table detected (WARN):**
- If no table has dataCategory = Time (TMDL table-level property) or "Time" (TMSL dataCategory field)
- Subject: `Model: .SemanticModel`
- Finding: `No table is marked as a date table in this model.`
- Recommendation: `Mark your date dimension table as a date table in Power BI Desktop (Table Tools > Mark as date table). Required for DAX time intelligence functions (DATESYTD, TOTALYTD, etc.).`

**Rule D-02 — Date table exists but no Date/DateTime column (INFO):**
- Table is marked as date table (dataCategory = Time) but has no column with dataType: dateTime or dataType: date (TMDL) / "dateTime" or "date" (TMSL)
- Subject: `Table: [DateTableName]`
- Finding: `Table [DateTableName] is marked as a date table but no Date or DateTime column was detected.`
- Recommendation: `Verify the date table has a Date/DateTime column as the key. The date column must contain unique, contiguous dates with no gaps.`

If a date table IS found and IS correctly configured (has Date/DateTime column):
- Add an INFO finding: `Table [DateTableName] is marked as a date table with a Date/DateTime column. Data content validation (gaps, blank dates) requires Power BI Desktop.`

---

### Step 5 — Domain Pass D: Measures

Accumulate findings_measures[]:

**Rule M-01 — Empty formatString (WARN):**
- Any measure with no formatString property (TMDL: no `formatString:` line in block; TMSL: field absent or empty string)
- Subject: `Measure: [Name] in Table: [TableName]`
- Finding: `Measure '[Name]' has no format string.`
- Recommendation: `Add a format string. Examples: '#,##0' for integers, '#,##0.00' for decimals, '0.0%' for percentages. Missing format strings cause inconsistent display in reports.`

**Rule M-02 — Empty description (INFO):**
- Any measure with no description (TMDL: no `///` line immediately above measure keyword; TMSL: "description" field absent OR empty string)
- Subject: `Measure: [Name] in Table: [TableName]`
- Finding: `Measure '[Name]' has no description.`
- Recommendation: `Add a description explaining the business logic. Use /pbi:comment to generate a description automatically.`

**Rule M-03 — No display folder (WARN):**
- Any measure with no displayFolder (TMDL: no `displayFolder:` line in block; TMSL: field absent or empty string)
- Subject: `Measure: [Name] in Table: [TableName]`
- Finding: `Measure '[Name]' has no display folder.`
- Recommendation: `Assign a display folder to group related measures in the Fields pane.`

---

### Step 6 — Merge and sort all findings

Combine findings_relationships[] + findings_naming[] + findings_date[] + findings_measures[] into one list.

Sort order: CRITICAL findings first, then WARN, then INFO.

Count totals: N_critical, N_warn, N_info.

---

### Step 7 — Emit the report inline

Output the following markdown report to chat (print in full — no truncation):

```
# PBI Model Audit Report
**Project:** .SemanticModel
**Format:** [TMDL or TMSL (model.bim)]
**Date:** [current UTC date and time, format: YYYY-MM-DD HH:MM UTC]
**Findings:** [N_critical] CRITICAL · [N_warn] WARN · [N_info] INFO

---

## 🔴 CRITICAL
[one subsection per CRITICAL finding, format:
### [domain tag] [subject]
[finding text]
**Recommendation:** [recommendation text]
]

[If no CRITICAL findings: "## 🔴 CRITICAL\n_None_"]

---

## 🟡 WARN
[one subsection per WARN finding]

[If no WARN findings: "## 🟡 WARN\n_None_"]

---

## 🔵 INFO
[one subsection per INFO finding]

[If no INFO findings: "## 🔵 INFO\n_None_"]

---

*Audit complete. Report written to: audit-report.md*
```

CRITICAL RULES for report output:
- Never use JSON paths (e.g., `model.tables[0]`). Always use actual table and measure names.
- Every finding MUST have a subject (table/measure name) and a Recommendation line.
- Domain tag format: `[Relationships]`, `[Naming]`, `[Date Table]`, `[Measures]`
- Severity emoji: 🔴 CRITICAL, 🟡 WARN, 🔵 INFO (locked by user decision)

---

### Step 8 — Write audit-report.md

Write the exact same report content to `audit-report.md` in the project root (the directory where /pbi:audit was invoked) using the Write tool.

Use Read-then-Write:
1. Attempt to Read `audit-report.md` (may not exist — that is fine)
2. Write the full report content using the Write tool, overwriting any previous audit report

---

### Step 9 — Update .pbi-context.md

Use Read-then-Write to update `.pbi-context.md`:
1. Read `.pbi-context.md` using the Read tool
2. Update:
   - `## Last Command` section: Command = `/pbi:audit`, Timestamp = current UTC, Outcome = `Audit complete — [N_critical] CRITICAL, [N_warn] WARN, [N_info] INFO findings. Report written to audit-report.md`
   - `## Command History` section: append a row with same values; trim to 20 rows max
3. Do NOT modify `## Model Context`, `## Analyst-Reported Failures`, or any other sections
4. Write the full updated file using the Write tool
