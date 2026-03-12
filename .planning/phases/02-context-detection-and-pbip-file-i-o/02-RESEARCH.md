# Phase 2: Context Detection and PBIP File I/O - Research

**Researched:** 2026-03-12
**Domain:** PBIP file format (TMDL / TMSL), process detection, Claude Code skill branching
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Desktop Safety Guard**
- Auto-detect `PBIDesktop.exe` process silently using `tasklist` before any file write — no prompt on the happy path
- If Desktop is running: abort the file write entirely, deliver paste-ready output with a clear note: "Desktop is open — paste manually, then save"
- No `--force` flag — if Desktop is detected as open, paste-ready output is always the result (no override)
- If no PBIP project found in the working directory: silent fallback to paste-in mode — no mention of file mode at all

**pbi-load Experience**
- Load full measure list + table structure: all tables with their measure names, column names, and a relationships summary — written into `.pbi-context.md`
- Output a summary table: `| Table | Measures | Columns |` with a conclusion line: "Context loaded — all DAX commands will now use model-aware analysis."
- Include format detection in the summary: "Format: TMDL" or "Format: TMSL (model.bim)"
- If no PBIP project found: respond with "No PBIP project found in this directory. All commands work with pasted DAX — paste a measure into any /pbi command to get started." Helpful, not an error.

**Post-Write Output**
- After a successful file write: show the full output (commented DAX + Description Field for `/pbi:comment`, diagnosis + fix for `/pbi:error`) then append a file confirmation line: "Written to: [MeasureName] in [file path]"
- Measure matching: search all TMDL / model.bim files for the exact measure name. If not found: "Measure [Name] not found in PBIP project — output is paste-ready for manual addition." No silent failures.
- Error recovery in file mode: preview the proposed fix (before/after of the affected lines), then ask "Apply this fix? (y/N)" before writing. `/pbi:comment` writes without a confirm prompt; `/pbi:error` requires explicit confirmation.

**Mode Detection Feedback**
- Announce file mode only when it is active — when in paste-in mode (no PBIP project), say nothing
- File mode header at the top of output: "File mode — PBIP project detected (TMDL) | Desktop: closed — will write to disk" or "Desktop: open — output is paste-ready"
- Format (TMDL/TMSL) is shown in the file-mode header and in the `pbi-load` summary only — not repeated elsewhere in command output

### Claude's Discretion
- Exact `tasklist` / process-check command and how to handle edge cases (empty output, permission errors)
- TMDL file structure traversal to locate a measure by name (directory path conventions)
- TMSL model.bim JSON path for measure lookup and write-back
- `.pbi-context.md` schema extension to store the loaded model summary (table/measure index)

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INFRA-03 | All commands support two modes: paste-in and PBIP file mode (reads from disk when Desktop is closed) | Mode-branching pattern via `!` bash injection at skill startup; both paths documented below |
| INFRA-04 | Context detection — commands detect whether a `.SemanticModel/` PBIP project exists in the working directory | `ls .SemanticModel/ 2>/dev/null` in bash injection returns exit code 0 if present; exact command documented |
| INFRA-05 | PBIP format detection — read `definition.pbism` version field to distinguish TMSL (`model.bim`) from TMDL (`definition/` folder) | `definition.pbism` JSON schema and version routing table documented; `grep`/`cat` approach viable |
| INFRA-06 | Desktop-open safety guard — before any file write, check for `PBIDesktop.exe` process or require explicit confirmation | `tasklist /fi "imagename eq PBIDesktop.exe"` + `findstr` exit code documented; pattern confirmed |
| DAX-13 | When in PBIP file mode, `/pbi:comment` writes inline comments and description back to target `.tmdl` or `model.bim` file | TMDL measure write-back pattern (regex for measure block, description via `///`) and model.bim JSON update both documented |
| ERR-03 | Error recovery proposes a specific fix and, when in PBIP file mode with Desktop closed, can apply the fix directly | Preview-then-confirm pattern; TMDL line-range replacement and model.bim JSON patch approaches documented |
</phase_requirements>

---

## Summary

Phase 2 extends the existing paste-in skills with a file-mode branch that activates only when a `.SemanticModel/` directory is present in the working directory. The branch is implemented entirely in bash injection at skill startup — no new tools, no new languages, no npm packages. The same SKILL.md pattern from Phase 1 gains a context detection header block that gates all subsequent file operations.

The two critical technical areas are PBIP format detection and TMDL/TMSL read-write mechanics. Format detection is straightforward: `definition.pbism` contains a `version` field — `1.0` means TMSL (model.bim), anything `4.0` or above means TMDL (`definition/` folder). The TMDL file structure is one `.tmdl` file per table in `definition/tables/`, and all measures for that table live inside that file. TMSL stores measures as a JSON array inside each table object in `model.bim`. Both formats are human-readable and writable with standard text tools (Read/Write).

The Desktop safety guard is a single `tasklist` call piped through `findstr`. On Windows (where Power BI Desktop runs), this is a reliable synchronous check with no elevated permissions required. The call returns exit code 0 if the process is found (Desktop open) and exit code 1 if not (Desktop closed) — the skill branches on this.

**Primary recommendation:** Implement Phase 2 as a startup detection block added to `pbi-load`, `pbi-comment`, and `pbi-error` SKILL.md files. The block runs bash checks at invocation, sets mental "mode" flags in the injected output, and the skill instructions branch accordingly. `/pbi:load` gets a full rewrite. `/pbi:comment` and `/pbi:error` gain a prepended file-mode branch before their existing Step 1.

---

## Standard Stack

### Core

| Component | Version / Location | Purpose | Why Standard |
|-----------|-------------------|---------|--------------|
| Claude Code skill `!` bash injection | Current (2026) | Run `ls`, `tasklist`, `cat`, `grep` at invocation time; result injected into skill context | Same mechanism used in Phase 1 for `.pbi-context.md` reads — established pattern |
| `tasklist` + `findstr` | Windows built-in | Detect `PBIDesktop.exe` process silently | Windows-native; no install; Git Bash on Windows passes these through to CMD |
| `ls .SemanticModel/` | Bash built-in | PBIP project presence check | Simplest reliable check; directory presence = project present |
| `cat .SemanticModel/definition.pbism` | Bash built-in | Read format version field | definition.pbism is a small JSON file; `grep` or `cat` + check for `"4.0"` suffices |
| `Read` tool (Haiku) | Claude Code | Read `.tmdl` and `model.bim` files | Established pattern from Phase 1; Haiku keeps cost low for file reading |
| `Write` tool (Haiku) | Claude Code | Write back to `.tmdl` and `model.bim` files | Same Read-then-Write pattern established in Phase 1 |

### Supporting

| Component | Version / Location | Purpose | When to Use |
|-----------|-------------------|---------|-------------|
| `grep -r` | Bash built-in | Find which table file contains a given measure name | Used in pbi-load to traverse all `.tmdl` files and index measures |
| `find .SemanticModel/definition/tables/ -name "*.tmdl"` | Bash built-in | Enumerate all table files | Used in pbi-load to build the model context summary |
| `python3 -c` / inline JSON with `grep` | Bash | Parse model.bim JSON to locate measure by name | TMSL only; grep for `"name": "MeasureName"` inside measures array is sufficient without a full JSON parser |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `tasklist` + `findstr` | PowerShell `Get-Process PBIDesktop` | PowerShell is more robust but adds a dependency; `tasklist` is available in any Windows shell including Git Bash |
| `grep` on definition.pbism | Full JSON parse with `python3 -c "import json"` | JSON parse is more correct but `grep` for the version string is sufficient — definition.pbism is tiny and predictable |
| Inline `grep` for measure search | TOM/.NET API calls | TOM requires .NET tooling; grep on TMDL text is sufficient for single-measure lookup |

**Installation:** No packages to install. All tools are bash built-ins, Windows system tools, or existing Claude Code facilities.

---

## Architecture Patterns

### Recommended PBIP Project Structure (for reference)

```
ProjectName.SemanticModel/
├── .pbi/
│   ├── localSettings.json     (gitignored)
│   └── cache.abf              (gitignored)
├── definition/                (TMDL format only)
│   ├── tables/
│   │   ├── Sales.tmdl         (all Sales measures live here)
│   │   ├── Date.tmdl
│   │   └── Customer.tmdl
│   ├── relationships.tmdl
│   ├── model.tmdl
│   └── database.tmdl
├── model.bim                  (TMSL format only — replaces definition/)
├── diagramLayout.json
└── definition.pbism           (REQUIRED — format detection file)
```

**Key facts:**
- `definition.pbism` is always present — it is the REQUIRED format indicator
- TMDL: `definition/` folder present; `model.bim` absent
- TMSL: `model.bim` present; `definition/` folder absent
- All measures for a table live in ONE `.tmdl` file named `TableName.tmdl`
- There is no `measures/` subdirectory in TMDL — measures are inline in the table file

Source: [Microsoft Learn — Power BI Desktop project semantic model folder](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset)

### Pattern 1: Startup Context Detection Block

**What:** Every Phase 2-aware skill starts with a bash injection block that determines mode before Claude sees any analyst input.

**When to use:** Add to top of `pbi-load`, `pbi-comment`, `pbi-error` SKILL.md files.

```yaml
## PBIP Context Detection
!`
PBIP_DIR=$(ls -d .SemanticModel 2>/dev/null && echo "found" || echo "none")
if [ "$PBIP_DIR" = "found" ]; then
  PBISM=$(cat .SemanticModel/definition.pbism 2>/dev/null)
  if echo "$PBISM" | grep -q '"version": "1.0"'; then
    echo "PBIP_MODE=file PBIP_FORMAT=tmsl"
  else
    echo "PBIP_MODE=file PBIP_FORMAT=tmdl"
  fi
else
  echo "PBIP_MODE=paste"
fi
`
```

The injected text (`PBIP_MODE=file PBIP_FORMAT=tmdl` or `PBIP_MODE=paste`) becomes part of the skill's startup context. The skill instructions read this and branch accordingly.

Source: Phase 1 established `!` bash injection pattern; directory check is standard bash.

### Pattern 2: Desktop Safety Guard

**What:** Before any file write, check if PBIDesktop.exe is running. If yes, abort write and return paste-ready output only.

**When to use:** In `pbi-comment` and `pbi-error` file-mode branches, immediately before any Write tool call.

```bash
# Run in bash injection OR as a Bash tool call inside the skill
tasklist /fi "imagename eq PBIDesktop.exe" 2>/dev/null | findstr /i "PBIDesktop.exe" >nul 2>&1
# Exit code 0 = Desktop running (abort write)
# Exit code 1 = Desktop not found (safe to write)
```

In SKILL.md bash injection form:

```yaml
## Desktop Check
!`tasklist /fi "imagename eq PBIDesktop.exe" 2>/dev/null | findstr /i "PBIDesktop.exe" >nul 2>&1 && echo "DESKTOP=open" || echo "DESKTOP=closed"`
```

**Edge cases (Claude's discretion):**
- `tasklist` permission error (rare, non-admin context): treat output as empty string; assume Desktop is closed and log a note — do not block the write on uncertainty
- Empty output from `tasklist` (no processes at all): also treat as Desktop not running

### Pattern 3: TMDL Measure Location and Write-Back

**What:** Find a measure by name across all `.tmdl` table files, read the file, modify the measure block, write back.

**When to use:** `pbi-comment` file-mode branch (write description and inline comments); `pbi-error` file-mode branch (write fix).

**Step 1 — Locate the measure:**

```bash
# Find which table file contains the measure (searches all tmdl files)
grep -rl "measure 'Revenue YTD'" .SemanticModel/definition/tables/ 2>/dev/null
# Returns: .SemanticModel/definition/tables/Sales.tmdl
# If empty: measure not found in TMDL
```

For measure names without single quotes (single-word names):

```bash
grep -rl "measure Revenue" .SemanticModel/definition/tables/ 2>/dev/null
```

**Step 2 — Read the table file with the Read tool.**

**Step 3 — Locate the measure block within the file:**

TMDL measure syntax (from official TMDL docs):

```tmdl
/// This is the Measure Description (triple-slash = description)
measure 'Revenue YTD' =
        CALCULATE([Revenue], DATESYTD('Date'[Date]))
    formatString: #,##0
    displayFolder: "Time Intelligence"
```

- Description is the `///` line(s) immediately above the `measure` keyword — no blank line between description and measure declaration
- The measure expression follows `=` either on the same line (single-line) or indented on the next line(s)
- Properties (`formatString`, `displayFolder`) are indented one level under the measure declaration

**Step 4 — Modify and write back:**

For `/pbi:comment`: Claude replaces the `///` description line (or adds one if absent) with the generated Description Field value, and updates the expression body to include `//` inline comments.

For `/pbi:error`: Claude replaces the expression block with the corrected DAX.

**Indentation rule (CRITICAL):** TMDL uses tab indentation. Measure properties are indented one tab. Multi-line expressions are indented two tabs. Do not convert tabs to spaces when writing back.

Source: [Microsoft Learn — TMDL overview](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview?view=sql-analysis-services-2025)

### Pattern 4: TMSL model.bim Measure Location and Write-Back

**What:** Find a measure by name in the JSON `model.bim` file, update the `expression` and `description` fields, write back.

**When to use:** `pbi-comment` and `pbi-error` when `PBIP_FORMAT=tmsl`.

**JSON structure (from TMSL schema):**

```json
{
  "model": {
    "tables": [
      {
        "name": "Sales",
        "measures": [
          {
            "name": "Revenue YTD",
            "expression": "CALCULATE([Revenue], DATESYTD('Date'[Date]))",
            "description": "Year-to-date revenue.",
            "formatString": "#,##0",
            "displayFolder": "Time Intelligence"
          }
        ]
      }
    ]
  }
}
```

**Locate measure:** `grep` for `"name": "Revenue YTD"` within the `measures` array context. Because model.bim can be large, use the Read tool and let Claude locate the measure object.

**Write back:** Read entire model.bim → Claude identifies the measure JSON object → updates `expression` (for `/pbi:error`) and/or `description` + `expression` (for `/pbi:comment`) → Write tool writes entire file back. Do not write partial JSON.

**Critical constraint:** JSON must remain valid. Never write back without verifying the JSON structure is intact. Claude must preserve all existing fields (formatString, displayFolder, annotations, etc.) and only modify `expression` and/or `description`.

Source: [Microsoft Learn — Tables object (TMSL)](https://learn.microsoft.com/en-us/analysis-services/tmsl/tables-object-tmsl?view=asallproducts-allversions)

### Pattern 5: pbi-load Model Context Extraction

**What:** Read all table/measure/column names from TMDL or model.bim, write a `## Model Context` section to `.pbi-context.md`.

**When to use:** `/pbi:load` full implementation.

**TMDL approach (Haiku reads files):**

```bash
# List all table files
find .SemanticModel/definition/tables/ -name "*.tmdl" 2>/dev/null
```

For each table file, Haiku reads it and extracts:
- Table name (from filename or `table TableName` declaration)
- Measure names (lines matching `measure 'Name'` or `measure Name`)
- Column names (lines matching `column 'Name'` or `column Name`)

**TMSL approach:**

Read `model.bim` once. The JSON structure gives tables → measures and tables → columns directly.

**Output format for `.pbi-context.md` `## Model Context` section:**

```markdown
## Model Context
**Loaded:** 2026-03-12T10:00:00Z
**Format:** TMDL
**Project:** .SemanticModel

| Table | Measures | Columns |
|-------|----------|---------|
| Sales | Revenue, Revenue YTD, Sales Amount | Amount, Quantity, Date |
| Date | (none) | Date, Year, Month, Quarter |
| Customer | Customer Count | CustomerKey, Name, Region |

**Relationships summary:** Sales[Date] → Date[Date] (many-to-one) · Sales[CustomerKey] → Customer[CustomerKey] (many-to-one)
```

### Anti-Patterns to Avoid

- **Checking for TMDL by looking for `model.bim` absence:** The correct check is whether `definition/` folder exists OR whether `definition.pbism` version is `1.0`. Checking for `model.bim` absence is fragile during migration states.
- **Writing partial TMDL files:** Always Read → modify → Write the full table file. Never append or patch with `echo >>`. TMDL indentation is structural — a partial write risks corrupting the file.
- **Assuming measure names are unique across tables:** They are not. Two tables can have a measure with the same name. When locating a measure, `grep -rl` may return multiple files. If multiple matches: report "Measure [Name] found in multiple tables — please specify with `--table TableName`."
- **Announcing file mode when no PBIP project exists:** The locked decision is explicit: paste-in mode is silent. Do not add any "no PBIP project found" message to `pbi-comment` or `pbi-error` — only `pbi-load` does this.
- **Blocking on tasklist permission errors:** If `tasklist` fails for any reason, default to "Desktop is closed" and proceed. A write to a file while Desktop is open causes Desktop to overwrite the change on next save — but this is less harmful than blocking the user on a permission edge case.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PBIP format detection | Custom parser for definition.pbism | `cat definition.pbism` + `grep '"version"'` — the file is tiny JSON with one key field | The file is 3-10 lines; a grep is sufficient |
| TMDL parse tree | Custom TMDL tokenizer | Regex/grep for `measure 'Name'` and `/// description` — TMDL is line-oriented and human-readable | Full parse is unnecessary for single-measure locate-and-update |
| model.bim parse | Custom JSON parser | Read full file with Read tool; let Claude locate the measure object | Claude can navigate JSON structure directly; no JSON library needed in bash |
| Process detection | Win32 API calls | `tasklist` + `findstr` — standard Windows CLI, available in Git Bash | No install required; works in every Windows terminal including Git Bash |
| File write safety | Transaction/backup system | Read → Write pattern established in Phase 1; write entire file, not partial patches | Atomic Read→Write is already the established pattern; partial writes are the dangerous anti-pattern |

**Key insight:** This phase is still pure prompt-and-file work. The PBIP file formats (TMDL and model.bim) are both human-readable text formats designed to be edited in any text editor — that is their explicit design goal. Claude can read, understand, and rewrite them without any compiled tools.

---

## Common Pitfalls

### Pitfall 1: TMDL Measure Name Quoting

**What goes wrong:** Measure names with spaces or special characters are quoted with single quotes in TMDL: `measure 'Revenue YTD'`. Single-word names have no quotes: `measure Revenue`. A grep for `measure Revenue YTD` without the quotes will fail.

**Why it happens:** TMDL follows specific quoting rules: names with spaces, dots, colons, equals signs, or other special characters must be wrapped in single quotes.

**How to avoid:** When searching for a measure by name, build the grep pattern to match both forms: `grep -rl "measure.*Revenue YTD"` (uses `.*` to match with or without quotes). Alternatively, normalise by always searching for the measure name substring without caring about the exact quoting.

**Warning signs:** `grep` returns empty despite the measure existing; skill reports "measure not found" incorrectly.

### Pitfall 2: TMDL Description Location (Triple-Slash Above, Not Below)

**What goes wrong:** The TMDL `///` description must appear IMMEDIATELY above the `measure` keyword with no blank line between them. If a blank line separates the `///` from `measure`, the description is not associated with the measure object.

**Why it happens:** TMDL uses whitespace as structure; the `///` description syntax requires adjacency. This differs from code comment conventions where blank lines before a function are common.

**How to avoid:** When writing a description, place `/// [description text]` on the line directly above `measure 'Name' =`. When updating an existing description, find the existing `///` line(s) above the measure declaration and replace them. When adding a description to a measure that has none, insert the `///` line directly above the `measure` line — no blank line.

**Warning signs:** Power BI Desktop opens the file after edit and shows an empty description field despite the `///` being present.

### Pitfall 3: model.bim Expression as Array (Multi-line DAX)

**What goes wrong:** In TMSL model.bim, the `expression` field can be either a string or an array of strings for multi-line DAX. If a measure has a simple one-line expression, the JSON looks like: `"expression": "SUM(Sales[Amount])"`. For multi-line DAX with VARs, it looks like: `"expression": ["VAR result = SUMX(...)", "RETURN result"]`. Writing a string value when the original was an array (or vice versa) produces invalid TMSL.

**Why it happens:** The TMSL schema allows both forms. Power BI Desktop uses the array form for any expression with line breaks.

**How to avoid:** When reading a measure's expression field, detect whether it is a string or array. When writing back, preserve the same form. For expressions with inline `//` comments (which add lines), use the array form.

**Warning signs:** Power BI Desktop fails to open the file after write; JSON parse errors in model.bim.

### Pitfall 4: Desktop Detection Produces "INFO: No tasks..." Output

**What goes wrong:** On Windows, `tasklist /fi "imagename eq PBIDesktop.exe"` when the process is NOT running outputs: `INFO: No tasks are running which match the specified criteria.` rather than empty output. The exit code is still 0 — `tasklist` succeeded as a command. Only `findstr` correctly identifies whether the process name is in the output.

**Why it happens:** `tasklist` reports command success, not process presence. Process presence detection requires the secondary filter.

**How to avoid:** Always pipe through `findstr /i "PBIDesktop.exe"` and use THAT exit code for branching. The pattern `tasklist /fi "imagename eq PBIDesktop.exe" 2>/dev/null | findstr /i "PBIDesktop.exe"` is correct: `findstr` exits 0 only if the process name string was found in the tasklist output.

**Warning signs:** Skill always reports "Desktop: closed" even when Desktop is open, or vice versa.

### Pitfall 5: pbi-load Writes Overwrite .pbi-context.md History

**What goes wrong:** `/pbi:load` adds a `## Model Context` section to `.pbi-context.md`. If it overwrites the entire file rather than inserting the new section, it destroys the existing Command History and Analyst-Reported Failures data.

**Why it happens:** The Read-then-Write pattern requires careful merging: read the current file, find the correct insertion point or existing `## Model Context` section, replace/insert, write back.

**How to avoid:** When writing the model context: Read the current `.pbi-context.md`, check if `## Model Context` already exists (update it), or append it after the existing sections. Never overwrite the whole file with only the Model Context section.

**Warning signs:** After running `/pbi:load`, the Command History table is empty; previous commands are gone.

---

## Code Examples

Verified patterns from official sources and Phase 1 established patterns:

### Startup Detection Block (complete, for any Phase 2 skill)

```yaml
## PBIP Context Detection
!`PBIP_RESULT=""; if [ -d ".SemanticModel" ]; then PBISM=$(cat ".SemanticModel/definition.pbism" 2>/dev/null); if echo "$PBISM" | grep -q '"version": "1.0"'; then PBIP_RESULT="PBIP_MODE=file PBIP_FORMAT=tmsl"; else PBIP_RESULT="PBIP_MODE=file PBIP_FORMAT=tmdl"; fi; else PBIP_RESULT="PBIP_MODE=paste"; fi; echo "$PBIP_RESULT"`

## Desktop Safety Check
!`tasklist /fi "imagename eq PBIDesktop.exe" 2>/dev/null | findstr /i "PBIDesktop.exe" >nul 2>&1 && echo "DESKTOP=open" || echo "DESKTOP=closed"`

## Session Context
!`cat .pbi-context.md 2>/dev/null | tail -80 || echo "No prior context found."`
```

Note: Desktop check only needs to run when `PBIP_MODE=file`. In practice, inject both; the skill instructions only use `DESKTOP=` output when in file mode.

### TMDL Measure Search Command

```bash
# Source: TMDL folder structure (Microsoft Learn TMDL overview)
# Find which table file contains a given measure
grep -rl "measure.*Revenue YTD" ".SemanticModel/definition/tables/" 2>/dev/null

# Enumerate all table files for pbi-load
find ".SemanticModel/definition/tables/" -name "*.tmdl" 2>/dev/null
```

### TMDL Measure Write-Back Pattern (conceptual, for planner)

```
Read: .SemanticModel/definition/tables/Sales.tmdl
Locate: the block starting with (optional) `///` description + `measure 'Revenue YTD' =`
Modify:
  - Replace or insert `///` line with new description
  - Replace expression body with commented DAX (preserving indentation)
  - Do not touch other measures, columns, or table-level properties
Write: entire file back to .SemanticModel/definition/tables/Sales.tmdl
```

### TMSL Measure Write-Back Pattern (conceptual, for planner)

```
Read: .SemanticModel/model.bim (entire file)
Locate: within model.tables[n].measures[], find object where "name" == "Revenue YTD"
Modify:
  - Update "expression" field (string or array form — match original)
  - Update "description" field (string)
  - Preserve all other fields (formatString, displayFolder, annotations, etc.)
Write: entire model.bim back
```

### definition.pbism Version Routing Table

```
version "1.0"    → TMSL  → read/write model.bim
version "4.0"+   → TMDL  → read/write definition/tables/TableName.tmdl
```

Source: [Microsoft Learn — Power BI Desktop project semantic model folder](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset) — version table confirmed in official docs.

### .pbi-context.md Model Context Section Schema

```markdown
## Model Context
**Loaded:** 2026-03-12T10:00:00Z
**Format:** TMDL
**Project:** .SemanticModel

| Table | Measures | Columns |
|-------|----------|---------|
| Sales | Revenue, Revenue YTD, Sales Amount | Amount, Quantity, Date |
| Date | (none) | Date, Year, Month, Quarter |

**Relationships summary:** Sales[DateKey] → Date[Date] (many-to-one)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single `.pbix` file (binary) | PBIP project folder with `.SemanticModel/` | Power BI Desktop preview feature, broadly available 2023–2025 | Files are now human-editable text; direct edit is officially supported |
| TMSL only (`model.bim` JSON) | TMSL or TMDL (`definition/` folder) | TMDL preview enabled by default in 2024/2025 | New projects use TMDL; existing projects may still use TMSL until upgraded |
| Model editing only via Desktop UI | External edits in VS Code / any text editor | Officially supported with TMDL (requires Desktop restart to reload) | Skill can write files directly — this is the intended use case |

**Deprecated/outdated:**
- TMSL-only assumption: New PBIP projects created with TMDL preview enabled will use TMDL. Phase 2 must support both. The version field in `definition.pbism` is the reliable discriminator.
- PBIP as "preview": As of 2025, PBIP is broadly available. The "preview" label in some Microsoft docs refers to specific sub-features (e.g., TMDL view in Desktop), not PBIP itself.

---

## Open Questions

1. **definition.pbism exact JSON shape — version field key name**
   - What we know: Microsoft Learn confirms the file contains a `version` property. Version `1.0` = TMSL; version `4.0` or above = TMDL-capable.
   - What's unclear: The exact JSON key name in the file (`"version"` vs `"pbismVersion"` vs another key). Microsoft Learn states the version field exists but does not show the raw JSON.
   - Recommendation: Wave 0 task — read an actual `definition.pbism` file from any available PBIP project. If no sample project exists, create a test PBIP from Power BI Desktop. Add a test fixture: `tests/fixtures/definition-tmsl.pbism` and `tests/fixtures/definition-tmdl.pbism` with the actual JSON. Grep pattern should match both cases safely: `grep -q '"version"' definition.pbism` then check the value.
   - Interim approach: Check for presence of `definition/` folder (exists = TMDL) vs `model.bim` (exists = TMSL) as a fallback if the version field shape is unclear. This is the most reliable physical check.

2. **Measure name disambiguation when name appears in multiple tables**
   - What we know: TMDL allows measures with the same name in different tables. The search via `grep -rl` will return multiple files.
   - What's unclear: How often this actually occurs in practice; what the right UX is.
   - Recommendation: When multiple files match, output: "Measure [Name] found in [N] tables: [Table1], [Table2]. Use `--table TableName` to specify which one." Paste-ready output is still provided. No write occurs without disambiguation.

3. **Relationships extraction for pbi-load**
   - What we know: In TMDL, all relationships are in a single `relationships.tmdl` file. In TMSL, they are in `model.relationships[]` in `model.bim`.
   - What's unclear: Relationship syntax in TMDL relationships.tmdl (from/to column references).
   - Recommendation: For Phase 2, provide a best-effort relationships summary from `relationships.tmdl` or model.bim. The exact TMDL relationship syntax can be read empirically from an actual file; a grep for `fromColumn:` and `toColumn:` is likely sufficient.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None detected — prompt/skill system with no compiled code |
| Config file | N/A |
| Quick run command | Manual: invoke `/pbi:load` in a directory with a test PBIP project fixture |
| Full suite command | Manual: run `/pbi:load`, `/pbi:comment`, `/pbi:error` with PBIP fixtures |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-03 | Commands operate in paste-in mode when no `.SemanticModel/` present | smoke | Manual — run `/pbi:comment` without PBIP dir; verify no file-mode output | ❌ Wave 0 |
| INFRA-03 | Commands operate in file mode when `.SemanticModel/` present | smoke | Manual — run `/pbi:comment` with test PBIP fixture; verify file-mode header | ❌ Wave 0 |
| INFRA-04 | `.SemanticModel/` presence check correctly detects project | smoke | `ls .SemanticModel 2>/dev/null && echo found \|\| echo none` | ❌ Wave 0 |
| INFRA-05 | Format detection routes TMSL projects to model.bim path | smoke | Manual — place test `definition.pbism` v1.0 + `model.bim` fixture; run `/pbi:load`; verify "Format: TMSL" in output | ❌ Wave 0 |
| INFRA-05 | Format detection routes TMDL projects to `definition/` path | smoke | Manual — place test `definition.pbism` v4.0 + `definition/tables/*.tmdl` fixture; run `/pbi:load`; verify "Format: TMDL" | ❌ Wave 0 |
| INFRA-06 | Desktop running → paste-ready output only (no file write) | manual | Open PBIDesktop.exe (or simulate); run `/pbi:comment`; verify "Desktop: open" header and no write | ❌ Wave 0 |
| INFRA-06 | Desktop closed → file write occurs | manual | Confirm Desktop not running; run `/pbi:comment` in file mode; verify "Written to:" confirmation line | ❌ Wave 0 |
| DAX-13 | `/pbi:comment` writes description and comments to TMDL file | manual | Run command with TMDL fixture; read file after; verify `///` description and `//` comments present | ❌ Wave 0 |
| DAX-13 | `/pbi:comment` writes to model.bim when TMSL format | manual | Run with TMSL fixture; verify `description` and `expression` fields updated in JSON | ❌ Wave 0 |
| ERR-03 | `/pbi:error` shows before/after preview and prompts for confirm | manual | Run in file mode; verify preview shown and "Apply this fix? (y/N)" prompt appears | ❌ Wave 0 |
| ERR-03 | `/pbi:error` applies fix on "y" confirmation | manual | Respond "y"; verify file is written with corrected expression | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Bash smoke test — verify startup detection block outputs correct `PBIP_MODE=` string for directory with/without `.SemanticModel/`
- **Per wave merge:** Full manual pass with PBIP test fixtures for all three modified skills
- **Phase gate:** All manual tests pass before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/fixtures/pbip-tmdl/definition.pbism` — TMDL format sample file (version 4.0)
- [ ] `tests/fixtures/pbip-tmdl/definition/tables/Sales.tmdl` — sample TMDL table file with at least one measure and description
- [ ] `tests/fixtures/pbip-tmsl/definition.pbism` — TMSL format sample file (version 1.0)
- [ ] `tests/fixtures/pbip-tmsl/model.bim` — minimal TMSL JSON with one table and one measure
- [ ] `tests/fixtures/pbip-tmsl/.SemanticModel/` wrapper — or note that fixtures replicate the relevant subdirectory structure

*(If no gaps: "None — existing test infrastructure covers all phase requirements")*

---

## Sources

### Primary (HIGH confidence)
- [Microsoft Learn — Power BI Desktop project semantic model folder](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset) — definition.pbism version table, file/folder structure, TMDL vs TMSL routing (updated 2026-01-20)
- [Microsoft Learn — TMDL overview](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview?view=sql-analysis-services-2025) — complete TMDL syntax including measure declaration, `///` description syntax, folder structure, indentation rules (updated 2026-02-02)
- [Microsoft Learn — Tables object (TMSL)](https://learn.microsoft.com/en-us/analysis-services/tmsl/tables-object-tmsl?view=asallproducts-allversions) — full TMSL JSON schema for measures array: `name`, `expression`, `description`, `formatString`, `displayFolder` fields confirmed

### Secondary (MEDIUM confidence)
- [SS64.com — tasklist](https://ss64.com/nt/tasklist.html) — `tasklist /fi "imagename eq *.exe"` syntax confirmed; Windows-native command
- WebSearch results confirming `tasklist | findstr` exit-code pattern for process detection in batch/bash scripts on Windows

### Tertiary (LOW confidence)
- definition.pbism exact JSON key name for the version field — confirmed by name in Microsoft Learn table but raw JSON not shown; recommend empirical verification via Wave 0 fixture task

---

## Metadata

**Confidence breakdown:**
- Standard stack (bash tools, Read/Write): HIGH — same tools as Phase 1, confirmed working
- TMDL file format and syntax: HIGH — verified against official Microsoft Learn TMDL overview (updated 2026)
- TMSL model.bim JSON schema: HIGH — verified against official TMSL tables object reference
- definition.pbism version routing: HIGH — confirmed in official Microsoft Learn docs (version table present)
- definition.pbism raw JSON shape: MEDIUM — routing logic confirmed, exact JSON key name needs empirical check
- tasklist process detection: HIGH — standard Windows CLI, confirmed via multiple sources
- Measure multi-table disambiguation: MEDIUM — behavior derived from TMDL spec; UX design is Claude's discretion

**Research date:** 2026-03-12
**Valid until:** 2026-06-12 (PBIP format is stable; version routing table is unlikely to change)
