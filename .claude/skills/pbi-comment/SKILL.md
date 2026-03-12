---
name: pbi-comment
description: Add inline // comments to a DAX measure and generate a Description field value for Power BI. Use when an analyst asks to comment, document, or annotate a DAX measure.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Write
---

## Session Context

!`cat .pbi-context.md 2>/dev/null | tail -80 || echo "No prior context found."`

## Instructions

### Step 1 — Initial Response

Respond immediately with:

> Paste your DAX measure below:

Wait for the analyst to paste their DAX measure before proceeding.

### Step 2 — Measure Extraction

- Extract the measure name from the text before the first `=` sign (strip whitespace). Example: `Revenue YTD = CALCULATE(...)` → measure name is `Revenue YTD`.
- If there is no `=` in the pasted text, use `[Measure]` as the placeholder name and append a note: `_Note: No measure name found — treating full input as expression._`
- If `$ARGUMENTS` contains `--table TableName`, use that table name as additional business context when writing comments (e.g., "filters to rows in the TableName table where…").

### Step 3 — Prior Failure Check

Scan the Session Context for the extracted measure name under the `Analyst-Reported Failures` section. If a matching entry exists, prepend this flag at the very top of the output (before the measure name heading):

> ⚠️ Previous attempt at this measure was reported as failed. Review comments carefully before use.

### Step 4 — Comment Placement Rules

Add `//` inline comments to the DAX measure according to these rules:

**Where to comment:**
- Add one comment immediately **above the measure name line** (the `MeasureName =` line) describing the overall business purpose in one plain-English sentence. Example: `// Returns year-to-date revenue, filtered to the selected region`.
- Add comments **on or above CALCULATE arguments** explaining the filter logic in business terms — not DAX terms. Say `// Filter to current year only`, not `// DATESYTD applies a year-to-date time intelligence filter`.
- Add comments **above or on VAR declarations** explaining what each variable holds in business terms. Example: `// Total orders placed before the selected date`.
- Add a comment **above the RETURN statement** (when variables are used) stating plainly what is being returned. Example: `// Return the ratio of converted leads to total leads`.
- For **simple single-line measures** (e.g., `Revenue = SUM(Sales[Amount])`): add exactly one comment above the expression describing the business calculation in a full sentence. Example: `// Total sales revenue — sums the Amount column across all visible rows`.

**What not to do:**
- Do NOT add a comment on every line — only comment lines where the intent is non-obvious.
- Do NOT translate DAX syntax word-for-word into English. Explain the business logic, not the code mechanics.
- Do NOT comment on closing parentheses, indentation, or structural syntax.
- Do NOT repeat the measure name in the comment.

**Complexity scaling:**
- Infer complexity from patterns: simple measures (SUM, DIVIDE, basic CALCULATE with one filter) → fewer, shorter comments; complex measures (context transitions, EARLIER, ALLEXCEPT, nested iterators, multiple VARs) → more detailed comments on each key step.

### Step 5 — Description Field Generation Rules

Write a Description Field value (plain text, not inside a code block) that:

- Is **1–3 sentences** in plain business English.
- States: (1) what the measure calculates, (2) any key filter conditions or time intelligence behaviour, (3) any important caveats for interpretation (e.g., "Returns blank when no sales exist for the period.").
- Does **not** use DAX function names — write "year-to-date" not "DATESYTD"; write "filtered to" not "CALCULATE"; write "for each row" not "SUMX"; write "ignoring all filters" not "ALL".
- Is a **maximum of 300 characters** — Power BI's Description property is displayed in a tooltip and truncates at approximately 250–300 characters. Count characters and trim if needed.
- Uses **no markdown formatting** — no bold, no italics, no bullet points, no code formatting. Plain text only.
- Ends with a period.

### Step 6 — Output Structure

Produce the output using exactly this structure (locked decision — two labelled blocks):

```
**[Measure Name] — Commented**

### Commented DAX
```dax
// [overall purpose comment]
[MeasureName] =
// [comment if needed]
[expression with inline // comments as appropriate]
```

### Description Field
[Plain-text description, 1–3 sentences, max 300 characters, no markdown, ready to paste into Power BI measure Description property]

---
**Next steps:** `/pbi:explain` · `/pbi:format` · `/pbi:optimise` · `/pbi:error`
```

### Step 7 — Context Update

After producing the output, update `.pbi-context.md` using Read then Write:

1. **Read** `.pbi-context.md` using the Read tool to get the current contents.
2. **Write** the updated file back using the Write tool with these changes:
   - Update the `## Last Command` section: set Command to `/pbi:comment`, Timestamp to current UTC time (ISO 8601), Measure to the extracted measure name, Outcome to `Commented`.
   - Append a new row to the `## Command History` table with columns: Timestamp, Command (`/pbi:comment`), Measure Name (extracted name), Outcome (`Commented`).
   - Keep the Command History table to a maximum of 20 rows — if adding the new row would exceed 20, remove the oldest row first.
   - Do **not** modify the `## Analyst-Reported Failures` section.

### Example Output

For input `Revenue = SUM(Sales[Amount])`:

**Revenue — Commented**

### Commented DAX
```dax
// Total sales revenue across all visible rows
Revenue =
SUM(Sales[Amount])
```

### Description Field
Total sales revenue. Sums the Amount column across all rows visible in the current filter context. Returns blank when no sales exist.

---
**Next steps:** `/pbi:explain` · `/pbi:format` · `/pbi:optimise` · `/pbi:error`
