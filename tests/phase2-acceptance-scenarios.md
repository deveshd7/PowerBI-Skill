# PBI Skill v4.0 — Phase 2 Acceptance Test Scenarios

Phase 2 manual test script. Run these scenarios to verify all Phase 2 context-aware DAX behaviors work correctly.

**How to use:** Each scenario has preconditions, steps, expected output, and a pass criterion. Run them in order within each group, as later scenarios in a group may depend on state established by earlier ones.

**Requirements covered:** DAX-01 (context intake), DAX-02 (duplication check), DAX-03 (filter-sensitive gate), INTR-04 (non-filter guard), PHASE-02 (measures gate in deep mode)

---

## Group 1: Context Intake (DAX-01) — 4 scenarios

These scenarios verify that DAX commands ask a targeted context question when `.pbi-context.md` has no model context, and skip the question when context already exists.

---

### Scenario S2-01: `/pbi new` with empty context asks table/column question

**Covers:** DAX-01

**Preconditions:**
- Working directory has no `.pbi-context.md`, or `.pbi-context.md` exists but has no `## Model Context` section (create an empty file or delete it)
- No PBIP project required — paste mode is acceptable

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `/pbi new total revenue measure` | Skill asks "Which table should this measure go in, and which columns are relevant?" (or equivalent single question about table/columns). No DAX expression appears in this response. |
| 2 | Answer the question (e.g., "Sales table, Amount column") | Skill generates the DAX measure using the provided table and column names |

**Pass criteria:** The context question (about table and/or columns) appears in Step 1 BEFORE any DAX expression. Step 2 produces DAX that references the table/column names given. Fail if DAX appears in Step 1 without asking.

---

### Scenario S2-02: Second `/pbi new` in same session skips context question

**Covers:** DAX-01

**Preconditions:**
- S2-01 completed — `.pbi-context.md` now has a `## Model Context` section with table/column info written from the first run

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `/pbi new average order value measure` | Skill generates DAX immediately. No context question asked. Measure references the same table/columns saved from S2-01. |

**Pass criteria:** No "Which table..." or equivalent question appears. DAX output appears directly. Fail if the skill re-asks for table/column information already present in `.pbi-context.md`.

---

### Scenario S2-03: Each DAX command asks its command-specific context question with empty context

**Covers:** DAX-01

**Preconditions:**
- `.pbi-context.md` is empty or has no `## Model Context` section (reset between each sub-scenario below)
- Paste a real or invented DAX expression for commands that need one

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Reset `.pbi-context.md` to empty. Type `/pbi explain CALCULATE(SUM(Sales[Amount]), ALL(Date))` | Skill asks a context question related to understanding the measure (e.g., "Which table does this measure belong to?"). No explanation output yet. |
| 2 | Reset `.pbi-context.md` to empty. Type `/pbi optimise SUMX(Sales, Sales[Qty] * Sales[Price])` | Skill asks a context question before optimising (e.g., "Which table does this measure query?"). No optimised DAX output yet. |
| 3 | Reset `.pbi-context.md` to empty. Type `/pbi comment CALCULATE(SUM(Sales[Amount]), Date[Year]=2024)` | Skill asks a context question before commenting (e.g., "Which table does this measure belong to?"). No commented DAX output yet. |
| 4 | Reset `.pbi-context.md` to empty. Type `/pbi error` (paste a broken measure when prompted, or include it inline) | Skill asks a context question before diagnosing (e.g., "Which table is this measure part of?"). No error diagnosis yet. |
| 5 | Reset `.pbi-context.md` to empty. Type `/pbi format CALCULATE( SUM( Sales[Amount] ), Date[Year]=2024 )` | Skill asks a context question before formatting. No formatted DAX yet. |

**Pass criteria:** Each of the five commands (explain, optimise, comment, error, format) asks a context question about table/columns BEFORE producing any DAX output or analysis. Each question is specific to the command's purpose — it is not a generic interrogation form. Fail if any command produces output without first asking.

---

### Scenario S2-04: `/pbi load` then `/pbi new` — context from load skips intake question

**Covers:** DAX-01

**Preconditions:**
- Working directory is a PBIP project with a `.SemanticModel/` directory (use `tests/fixtures/pbip-tmdl/` if needed)
- `.pbi-context.md` has been populated by running `/pbi load` (run it now if not already done)
- Confirm `.pbi-context.md` contains a `## Model Context` section with table names

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `/pbi new measure for total sales by region` | Skill generates DAX immediately using model context from the load. No "Which table..." question asked. Generated measure references tables visible in the Model Context section. |

**Pass criteria:** No context intake question appears. DAX output references actual table/column names from the loaded model. Fail if skill re-asks for context that `/pbi load` already provided.

---

## Group 2: Duplication Check (DAX-02) — 2 scenarios

These scenarios verify that `/pbi new` always asks whether a similar measure exists before generating, and that a "yes" answer produces a CALCULATE wrapper pattern instead of duplicating logic.

---

### Scenario S2-05: `/pbi new` asks duplication check before generating

**Covers:** DAX-02

**Preconditions:**
- `.pbi-context.md` has a `## Model Context` section (run `/pbi load` or complete S2-01 first so intake does not fire)
- This isolates the duplication check behavior from the context intake behavior

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `/pbi new year-to-date revenue measure` | Skill asks "Does a similar measure already exist in the model?" (or equivalent question about existing measures). No DAX expression appears in this response. |
| 2 | Answer "No" | Skill generates the YTD revenue DAX measure |

**Pass criteria:** The duplication check question appears in Step 1 BEFORE any DAX expression. Step 2 produces a complete YTD measure. Fail if DAX appears in Step 1 without the duplication check question.

---

### Scenario S2-06: Answering "yes" to duplication check produces CALCULATE wrapper

**Covers:** DAX-02

**Preconditions:**
- S2-05 completed, OR `.pbi-context.md` has `## Model Context` (no intake will fire)
- Have a realistic existing measure name ready (e.g., `Total Revenue`)

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `/pbi new year-to-date revenue measure` | Skill asks "Does a similar measure already exist in the model?" |
| 2 | Answer "Yes, we have `[Total Revenue]`" | Skill asks for more detail OR immediately generates a wrapper. Skill does NOT re-generate the base logic from scratch. |
| 3 | If skill asks for existing measure details, provide the DAX or name. Observe final output. | Skill outputs a new measure using `CALCULATE([Total Revenue], ...)` or `CALCULATE([Total Revenue], DATESYTD(Date[Date]))` pattern — the existing measure is called as a reference, not duplicated. |

**Pass criteria:** The final generated measure contains a `CALCULATE([Total Revenue], ...)` pattern (or similar wrapper) that references the named existing measure. The base `SUM(...)` or core aggregation logic is NOT duplicated in the new measure. Fail if the skill generates a measure with duplicated aggregation logic instead of wrapping.

---

## Group 3: Filter-Sensitive Gate (DAX-03 + INTR-04) — 4 scenarios

These scenarios verify that filter-sensitive DAX patterns (time intelligence and ratio/rank functions) trigger a visual context question BEFORE any DAX is generated, and that non-filter-sensitive requests do NOT trigger the gate.

---

### Scenario S2-07: DATESYTD request triggers visual context question before DAX

**Covers:** DAX-03, INTR-04

**Preconditions:**
- `.pbi-context.md` has a `## Model Context` section (no intake will fire)
- `.pbi-context.md` has NO `## Visual Context` section (gate must fire)

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `/pbi new year-to-date sales using DATESYTD` | Skill asks "Where will this be placed and what slicers are active?" (or equivalent question about visual placement and active date/filter slicers). No DAX expression appears in this response. The question must appear BEFORE any DATESYTD expression. |
| 2 | Answer "Card visual, year slicer active" | Skill generates the DATESYTD measure informed by the visual context provided |

**Pass criteria:** The visual context question fires in Step 1 BEFORE any DAX expression containing `DATESYTD` (or any time-intelligence function). Step 2 produces a complete measure. Fail if DAX appears in Step 1 before the question.

---

### Scenario S2-08: Second time-intelligence measure skips visual context question

**Covers:** DAX-03

**Preconditions:**
- S2-07 completed — `.pbi-context.md` now has a `## Visual Context` section with slicer/placement info written from the first run

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `/pbi new same-period-last-year comparison` | Skill generates the SAMEPERIODLASTYEAR (or equivalent) measure immediately. No visual context question asked. |

**Pass criteria:** No "Where will this be placed..." or equivalent question appears. DAX output appears directly, reusing visual context saved from S2-07. Fail if the skill re-asks for visual context already present in `.pbi-context.md`.

---

### Scenario S2-09: `SUM` measure does NOT trigger visual context question

**Covers:** INTR-04

**Preconditions:**
- `.pbi-context.md` has a `## Model Context` section (no intake will fire)
- Duplication check: answer "No" when asked

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `/pbi new total amount measure using SUM of Sales Amount` | Skill asks the duplication check question ("Does a similar measure already exist?"). After answering "No", skill generates `SUM(Sales[Amount])` or equivalent. No visual context question appears at any point. |

**Pass criteria:** The visual context question ("Where will this be placed...") does NOT appear. The measure is generated after the duplication check only. Fail if the filter-sensitive gate fires for a plain SUM aggregation.

---

### Scenario S2-10: RANKX request triggers visual context question before DAX

**Covers:** DAX-03, INTR-04

**Preconditions:**
- `.pbi-context.md` has a `## Model Context` section (no intake will fire)
- `.pbi-context.md` has NO `## Visual Context` section (gate must fire, or reset it)

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `/pbi new rank products by revenue using RANKX` | Skill asks "Where will this be placed and what slicers are active?" (or equivalent visual context question). No DAX expression containing `RANKX` appears in this response. |
| 2 | Answer "Table visual, product category slicer active" | Skill generates the RANKX measure informed by the visual context |

**Pass criteria:** The visual context question fires in Step 1 BEFORE any DAX containing `RANKX`. Step 2 produces a complete RANKX measure. Fail if DAX appears before the gate question. Confirm RANKX (a ratio/rank trigger) correctly fires the gate, not just time-intelligence functions.

---

## Group 4: Measures Gate in Deep Mode (PHASE-02) — 4 scenarios

These scenarios verify that completing a deep mode session with "done" triggers a measures gate showing all generated measures, restating the business question, and offering session close confirmation.

---

### Scenario S2-11: "Done" at end of deep mode session shows measures summary

**Covers:** PHASE-02

**Preconditions:**
- A deep mode session is in progress: run `/pbi deep`, complete the intake (business question, data model, existing measures), and generate at least 2 measures using `/pbi new` during the session
- `.pbi-context.md` has both `## Business Question` and `## Command History` sections with at least 2 `/pbi new` rows

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `done` (or "I'm done", "finish session", or similar closing signal) | Skill outputs a measures session summary listing all measures generated during the session (names + target tables). The summary is drawn from the `/pbi new` rows in `## Command History`. |

**Pass criteria:** The gate output contains a list of measure names generated in the session. At least the 2 measures created in preconditions appear in the list. The word "done" or closing signal correctly triggers the gate — it does NOT close the session immediately. Fail if no measure list appears.

---

### Scenario S2-12: Measures gate output restates business question from `.pbi-context.md`

**Covers:** PHASE-02

**Preconditions:**
- S2-11 completed — measures gate is currently displayed
- `.pbi-context.md` has a `## Business Question` section with a specific question noted (e.g., "Compare regional sales performance month-over-month")

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Read the gate output from S2-11 carefully | Gate output contains the exact or paraphrased business question from `## Business Question` in `.pbi-context.md`. It asks "Do these measures answer [business question]?" |

**Pass criteria:** The business question from `.pbi-context.md` is visible in the gate output. It is not a generic question — it references the specific business question recorded during intake. Fail if the business question is absent or if a generic placeholder appears instead.

---

### Scenario S2-13: Answering "no" to the measures gate does NOT close the session

**Covers:** PHASE-02

**Preconditions:**
- S2-12 completed — gate is showing measure summary + business question

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Answer "no" (or "not yet", "missing one") to "Do these measures answer the business question?" | Skill does NOT close the session. Skill acknowledges that the measures are incomplete and offers to continue generating (e.g., "What else do you need?" or "Which measure is missing?"). |

**Pass criteria:** Session is NOT closed. No "Deep mode session closed" message appears. Skill actively offers to continue or asks what is still needed. Fail if the session closes after a "no" answer.

---

### Scenario S2-14: Answering "confirm" closes the deep mode session

**Covers:** PHASE-02

**Preconditions:**
- Deep mode session is active. Measures gate has fired (from S2-11 or equivalent state). The "Do these measures answer..." question has been answered "yes" (or the gate has proceeded to the close confirmation prompt).

**Steps:**

| Step | User Action | Expected Response |
|------|-------------|-------------------|
| 1 | Type `confirm` (or equivalent confirmation) in response to the session close prompt | Skill outputs session closed message. Message includes guidance for next steps, such as "Deep mode session closed. Use /pbi diff or /pbi commit to save your changes." |

**Pass criteria:** A session closed message appears. Message references `/pbi diff` or `/pbi commit` as next steps (or equivalent guidance on what to do after the session). Fail if no session closed message appears, or if the message does not include next-step guidance.

---

## Verification Notes

- Run S2-01 first — it establishes `.pbi-context.md` state used by later scenarios
- Groups 1–3 can be run independently if you control `.pbi-context.md` state per precondition
- Group 4 requires a full deep mode session in progress — budget ~5 minutes to complete intake before running S2-11 through S2-14
- Reset `.pbi-context.md` between groups by deleting it or removing the relevant sections as specified in preconditions
- All pass criteria are binary — no judgment calls required. The stated response either appears (pass) or does not (fail).

**Requirement cross-reference:**

| Requirement ID | Scenarios |
|----------------|-----------|
| DAX-01 | S2-01, S2-02, S2-03, S2-04 |
| DAX-02 | S2-05, S2-06 |
| DAX-03 | S2-07, S2-08, S2-10 |
| INTR-04 | S2-07, S2-09, S2-10 |
| PHASE-02 | S2-11, S2-12, S2-13, S2-14 |
