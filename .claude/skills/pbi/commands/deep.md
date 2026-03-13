# /pbi deep

> Detection context (PBIP_MODE, PBIP_FORMAT, File Index, Session Context) is provided by the router.

## Instructions

### Step 0 — Check Existing Context

Read Session Context from detection output. Check `.pbi-context.md` for existing sections:
- `## Business Question` — if present, display: "Business question on file: [content]" and ask "Still the focus, or something new?"
- `## Model Context` — if present, display: "Model context loaded from prior /pbi load."
- `## Existing Measures` — if present, display: "Existing measures on file: [summary]"

For any section that exists with content, skip asking that question in Step 1.

---

### Step 1 — Full Upfront Intake

Collect all three context dimensions. For each one NOT already in `.pbi-context.md`, ask the question. Ask them ONE AT A TIME (not all at once) to keep the conversation focused.

**Question 1 — Business Question:**
"What business question are we solving? (e.g., 'Compare regional sales performance month-over-month' or 'Track customer retention by cohort')"

Wait for answer. Then proceed to next missing question.

**Question 2 — Data Model State:**
"Describe your data model — key tables, how they relate, and any known issues. (e.g., 'Sales fact → Date dimension, Product dimension. No customer table yet.')"

Wait for answer. Then proceed to next missing question.

**Question 3 — Existing Measures:**
"What measures already exist that are relevant? (paste names, or say 'none yet' / 'not sure')"

Wait for answer.

---

### Step 2 — Write Context

Read `.pbi-context.md` with Read tool. Add or update these sections with the gathered answers:

- `## Business Question`: The stated business question, verbatim from user
- `## Existing Measures`: The user's answer about existing measures
- `## Last Command`: Command = `/pbi deep`, Timestamp = current UTC ISO 8601, Outcome = `Deep mode intake complete`
- `## Command History`: Append row, keep 20 max

Do NOT modify `## Analyst-Reported Failures`.
Do NOT modify `## Model Context` (that's managed by /pbi load).

Write the full file back with Write tool.

---

### Step 3 — Confirm and Ready

Output a summary of gathered context:

```
**Deep mode context gathered:**
- Business question: [summary]
- Model state: [summary or "from /pbi load"]
- Existing measures: [summary]

Context saved to .pbi-context.md. All /pbi commands will use this context going forward.

What would you like to work on first?
```

The user can now use any /pbi subcommand and the gathered context will inform the response via Session Context detection.

---

### Anti-Patterns
- NEVER enter deep mode unless the user explicitly typed `/pbi deep` — no automatic upgrade
- NEVER ask all 3 questions at once — ask one, wait, ask next
- NEVER re-ask a question if the answer is already in `.pbi-context.md`
- NEVER impose phase gates in Phase 1 — that's Phase 3 scope
