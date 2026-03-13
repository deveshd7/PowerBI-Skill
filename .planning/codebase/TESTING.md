# Testing Patterns

**Analysis Date:** 2026-03-13

## Overview

Testing for this skill is manual and fixture-based. There is no automated test runner (no Jest, Vitest, pytest, etc.). All testing is performed by Claude Code users executing commands against fixture projects and DAX samples. The repository includes structured test fixtures to enable reproducible manual testing.

## Test Fixtures Location

All test fixtures are stored in `tests/fixtures/`:

```
tests/fixtures/
├── *.dax                          # Individual DAX measures for paste-in testing
├── context-20-rows.md             # Pre-populated .pbi-context.md with 20-row history
├── error-log.txt                  # Sample Power BI error message for error diagnosis testing
├── pbip-tmdl/                     # Full TMDL project with git repo, 3 tables, measures, relationships
├── pbip-tmsl/                     # TMSL project (model.bim format)
├── pbip-no-repo/                  # TMDL project without git repo (tests git init flow)
└── pbip-empty-model/              # Project with tables but no measures
```

## Fixture Types

### DAX Measure Fixtures (paste-in testing)

Located in `tests/fixtures/`:
- `complex-measure.dax` — Contains `Risky Revenue = SUMX(Customers, [Revenue])` for complexity classification
- `intermediate-measure.dax` — DAX with CALCULATE and multiple filter arguments
- `multivar-measure.dax` — Multi-variable (VAR/RETURN) patterns
- `nested-iterator-measure.dax` — Advanced iterator nesting for performance analysis
- `no-equals-expression.dax` — Expression without measure name (tests placeholder handling)

**Usage:** Read file content and paste into `/pbi explain`, `/pbi format`, `/pbi optimise`, `/pbi comment`, or `/pbi error` commands.

### PBIP Project Fixtures

#### `pbip-tmdl/` (primary test project)

**Structure:**
```
pbip-tmdl/
├── .git/                          # Git repository with commit history
├── .SemanticModel/
│   ├── definition.pbism
│   └── definition/
│       ├── tables/
│       │   ├── Customers.tmdl     # Dimension table with no measures
│       │   ├── Date.tmdl          # Date dimension (dataCategory: Time)
│       │   ├── Products.tmdl      # Product dimension
│       │   └── Sales.tmdl         # Fact table with 2 measures
│       └── relationships.tmdl     # 3 relationships, includes one bidirectional (audit trigger)
└── .pbi-context.md               # Session context (optional, can be generated)
```

**Tables:**
- **Customers:** 2 columns, no measures, 0 relationships
- **Date:** 1 column (dateTime), no measures, marked as Time data category
- **Products:** 2 columns, no measures, 1 relationship
- **Sales:** 2 columns (Date, Amount), 2 measures (Revenue, Revenue YTD), 2 relationships

**Measures (Sales table):**
- `Revenue = SUM(Sales[Amount])` with formatString and displayFolder
- `Revenue YTD = CALCULATE([Revenue], DATESYTD('Date'[Date]))` with description (tests `///` block)

**Relationships:**
- Sales.Date → Date.Date (one-to-many)
- Sales.ProductKey → Products.ProductKey (one-to-many)
- Customers.CustomerKey ↔ Sales.CustomerKey (bidirectional — triggers R-01 audit finding)

**Git state:** Has commit history; used for `/pbi diff` and `/pbi commit` testing

**Tests:** audit findings (R-01 bidirectional, M-01 missing formatString, H-01 visible key column), diff parsing, commit messaging, model context loading

#### `pbip-tmsl/`

**Format:** TMSL (model.bim JSON structure)

**Tests:** Commands that support TMSL format; ensures dual-format handling works correctly

#### `pbip-no-repo/`

**Structure:** TMDL project identical to pbip-tmdl but without `.git/` directory

**Git state:** No git repo

**Tests:** `/pbi load` and `/pbi audit` outputs; git initialization flow when user runs `/pbi commit` in no-repo state

#### `pbip-empty-model/`

**Structure:** PBIP project with table files but no measures defined

**Tests:** Audit findings for empty measures, Model Context loading with zero measures, commands handle "no measures" gracefully

### Context Fixture

**`context-20-rows.md`**

Pre-populated `.pbi-context.md` with exactly 20 command history rows.

**Tests:** Command history trimming logic; appending new row when at 20 rows should drop oldest row, keeping exactly 20.

**Structure:**
```markdown
## Last Command
[current state]

## Command History
| Timestamp | Command | Measure Name | Outcome |
|-----------|---------|--------------|---------|
| 2026-03-12T10:00:00Z | /pbi:explain | Revenue YTD | Success |
[... 18 more rows ...]
| 2026-03-12T08:25:00Z | /pbi:explain | Sales Amount | Success |

## Analyst-Reported Failures
[1 sample failure entry]
```

**Usage:** Copy into project root as `.pbi-context.md`, run a command, verify new row is appended and oldest row is dropped.

### Error Message Fixture

**`error-log.txt`**

Sample Power BI error message for `/pbi error` testing.

**Tests:** Error parsing, diagnosis category classification, fix generation when applicable.

## Test Execution Pattern

### Paste-in commands testing

1. **Setup:** Copy a `.dax` file from `tests/fixtures/`
2. **Command:** Open Claude Code and invoke `/pbi explain`, `/pbi format`, `/pbi optimise`, `/pbi comment`
3. **Input:** Paste the DAX content when prompted
4. **Verification:**
   - Output structure matches expected format (Complexity tag, sections in order, Next steps)
   - Measure name extracted correctly
   - Session context (`.pbi-context.md`) is updated with command history

### PBIP commands testing

1. **Setup:** Copy fixture directory (e.g., `pbip-tmdl/`) to a test workspace
2. **Initialization:** Run `/pbi load` to populate `.pbi-context.md` with model context
3. **Command:** Execute target command (`/pbi audit`, `/pbi diff`, `/pbi edit`, etc.)
4. **Verification:**
   - Output format matches specification
   - File modifications (if any) preserve indentation and formatting
   - Git state (if applicable) shows expected commits or staging
   - Context file updated correctly

## Key Testing Scenarios

### Scenario 1: Paste-in DAX commands with complexity classification

**Commands:** `/pbi explain`, `/pbi format`, `/pbi optimise`

**Fixtures:** `complex-measure.dax`, `intermediate-measure.dax`

**Expected behavior:**
- Simple measures: minimal jargon, one-paragraph explanations
- Intermediate measures: parenthetical explanations of key concepts
- Advanced measures: explicit pattern names, full technical depth
- Formatting uses SQLBI rules (UPPERCASE keywords, proper indentation, function grouping)
- Optimization applies 10 rules, detects context transitions, shows side-by-side diff

### Scenario 2: Model audit with parallel domain passes

**Command:** `/pbi audit`

**Fixtures:** `pbip-tmdl/` (5+ tables triggers parallelism, but this fixture has 4)

**Expected behavior:**
- Detects bidirectional relationship (R-01 CRITICAL finding)
- Missing formatString in one measure (M-01 WARN)
- Relationship key column visible (H-01 WARN)
- Date table correctly configured (D-02 INFO)
- Produces severity-sorted report (CRITICAL first, then WARN, then INFO)
- Optionally offers auto-fix for R-01, H-01, H-02 findings

### Scenario 3: Session context command history trimming

**Fixture:** `context-20-rows.md` (already at 20 rows)

**Command:** `/pbi explain` with new measure

**Expected behavior:**
- New row appended to Command History
- Command History kept at exactly 20 rows (oldest row dropped)
- `.pbi-context.md` updated in single atomic Write operation

### Scenario 4: TMDL indentation preservation

**Command:** `/pbi edit` (rename or update measure)

**Fixture:** `pbip-tmdl/Sales.tmdl` (uses tabs)

**Expected behavior:**
- Original tab indentation detected
- Modified file written back with tabs preserved (not converted to spaces)
- All unchanged content, properties, and expressions remain identical

### Scenario 5: Git workflow in no-repo project

**Fixture:** `pbip-no-repo/` (no `.git/` directory)

**Command:** `/pbi edit` or `/pbi comment` (both auto-commit)

**Expected behavior:**
- File modifications succeed
- Auto-commit detects no git repo
- Output: "No git repo — run /pbi commit to initialise one."
- Subsequent `/pbi commit` initializes git, creates first commit

### Scenario 6: Model Context loading

**Command:** `/pbi load`

**Fixture:** `pbip-tmdl/`

**Expected behavior:**
- Reads all `.tmdl` files from `definition/tables/`
- Extracts table names, measure names, column names
- Parses relationships from `relationships.tmdl`
- Outputs summary table: Tables | Measures | Columns
- Updates `.pbi-context.md` with Model Context section
- Preserves Analyst-Reported Failures section (no modification)

### Scenario 7: Empty repository fallback

**Fixture:** `pbip-tmdl/` with `.git/` directory but no commits

**Command:** `/pbi diff`

**Expected behavior:**
- Detects HAS_COMMITS=no state
- Falls back to `git status --porcelain` instead of `git diff HEAD`
- Treats all listed files as NEW additions
- Output: "All model files are new (no prior commit)"

### Scenario 8: DAX Formatter API fallback

**Command:** `/pbi format`

**Conditions:**
- Simulate API failure (e.g., network unavailable or endpoint down)

**Expected behavior:**
- API probe fails (API_OK=no)
- Falls back to inline SQLBI formatting
- Outputs: "_DAX Formatter API unavailable — formatted inline by Claude_"
- Formatting rules applied: keyword capitalization, function grouping, proper indentation

### Scenario 9: Measure name disambiguation

**Fixture:** `pbip-tmdl/` with same measure name in multiple tables (not in current fixture, would need to be added)

**Command:** `/pbi comment`

**Expected behavior:**
- Detects multiple files containing measure name
- Outputs: "Measure found in multiple tables: [list]. Which table?"
- Does NOT auto-select or guess
- Waits for analyst specification

### Scenario 10: Prior failure flagging

**Setup:** Analyst manually adds entry to Analyst-Reported Failures in `.pbi-context.md`

**Command:** `/pbi explain` on the flagged measure

**Expected behavior:**
- Detects measure name in Analyst-Reported Failures section
- Prepends warning at top of output: "Previous attempt at this measure used [approach] and failed."
- Continues with normal explanation flow

## Testing Checklist

Use this checklist when adding new commands or modifying existing ones:

- [ ] **Guard clauses:** Step 0 checks PBIP_MODE, git state, file existence
- [ ] **Paste-in mode:** Command works without .SemanticModel/ (if applicable)
- [ ] **File mode:** Command works with PBIP project and outputs format header
- [ ] **TMDL support:** Reads .tmdl files correctly, preserves indentation on write-back
- [ ] **TMSL support:** Handles model.bim JSON, preserves expression format (string vs array)
- [ ] **Session context:** Updates .pbi-context.md using Read-then-Write pattern
- [ ] **Command history:** Appends new row, keeps to 20 rows max
- [ ] **Analyst-Reported Failures:** Never modifies this section
- [ ] **Bash quoting:** All file paths double-quoted, DAX in single-quoted here-doc
- [ ] **Error messages:** Specific and actionable; outputs exactly as documented
- [ ] **Confirmation flow:** Major actions ask (y/N); default is cancel
- [ ] **Git handling:** Auto-commit prefix matches pattern (feat:, chore:, fix:)
- [ ] **External APIs:** Fallback documented and tested (if applicable)

## Manual Testing Workflow

**For local development:**

1. Copy fixture directory to a temporary workspace:
   ```bash
   cp -r tests/fixtures/pbip-tmdl /tmp/test-project
   cd /tmp/test-project
   ```

2. Open Claude Code:
   ```bash
   claude
   ```

3. Invoke command and observe behavior:
   ```
   /pbi audit
   ```

4. Verify output and file state:
   - Check stdout against expected structure
   - Inspect `.pbi-context.md` for correct updates
   - Inspect `.SemanticModel/` files for correct modifications

5. Clean up and re-run with fresh fixture:
   ```bash
   cd /tmp
   rm -rf test-project
   cp -r /path/to/repo/tests/fixtures/pbip-tmdl test-project
   ```

## Notes on Test Design

- **No headless testing:** Tests are designed for Claude users to execute interactively. No CI/CD pipeline or automated test runner exists.
- **Fixtures as ground truth:** Fixtures define expected model structure, error messages, and context format.
- **Manual regression testing:** When commands are modified, manually run against all relevant fixtures to ensure backward compatibility.
- **Fixture version stability:** Fixtures should be stable; only update them when fixing test coverage gaps or adding new test scenarios.

---

*Testing analysis: 2026-03-13*
