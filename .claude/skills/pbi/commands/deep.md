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
When you've finished generating measures, say "done" to review your session before closing.
```

The user can now use any /pbi subcommand and the gathered context will inform the response via Session Context detection.

---

### Step 4 -- Measures Gate (end of session)

This step activates ONLY when the analyst signals completion of the measures phase.

**Trigger phrases (case-insensitive):** "done", "that's all the measures", "finished", "I think we're good", "complete", "all done", "that's it"

**Do NOT trigger** this step after each individual /pbi new call. Wait for explicit analyst signal.

When triggered:

1. Read `.pbi-context.md` with Read tool. Collect all rows from `## Command History` where Command = `/pbi new`.

2. Output the session summary:

   > **Measures session summary:**
   > [For each /pbi new row in Command History: "- [Measure Name] -> added in this session"]
   > (If no /pbi new rows found: "- No measures generated in this session via /pbi new.")
   >
   > **Business question on file:** [Content of ## Business Question from .pbi-context.md]
   >
   > Do these measures answer the stated business question? (yes / no -- if no, describe what's missing)

3. Wait for the analyst's answer.
   - **Yes** (or any affirmative): proceed to step 4.
   - **No**: acknowledge the gap. Output: "Understood -- what's missing? Continue with /pbi new to add more measures." Do NOT close the session. Resume from Step 3's "What would you like to work on first?" state.

4. Output the confirmation prompt:
   > All measures complete -- confirm to close the deep mode session. (confirm / cancel)

5. Wait for response.
   - **confirm**: Output: "Deep mode session closed. Use /pbi diff or /pbi commit to review and save your changes."
   - **cancel** (or anything else): Output: "Session kept open. Continue with /pbi new or other commands." Resume from Step 3 state.

---

### Anti-Patterns
- NEVER enter deep mode unless the user explicitly typed `/pbi deep` — no automatic upgrade
- NEVER ask all 3 questions at once — ask one, wait, ask next
- NEVER re-ask a question if the answer is already in `.pbi-context.md`
- NEVER impose phase gates in Phase 1 — that's Phase 3 scope
- NEVER trigger the measures gate after each individual /pbi new call -- it fires only on analyst completion signal
- NEVER advance past the gate if the business question check returns "no" -- offer to continue generating
- NEVER impose visual or polish phases at the gate (Phase 3 scope)
