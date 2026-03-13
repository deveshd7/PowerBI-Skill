# Phase 1: Skill Core + Escalation - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Working skill file with a solve-first default and targeted escalation after explicit failure signals. Users get immediate DAX help without any upfront interrogation. Targeted questions fire only when the user signals something isn't working. Deep workflow mode exists as an explicit invocation stub (`/pbi deep`) — the full phase gates and model review are Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Skill entry point
- Free-text requests with no explicit subcommand keyword route to a new solve-first catch-all handler
- Existing subcommands (explain, format, new, audit, etc.) remain unchanged for explicit use
- Catch-all handles ALL free-text natural language requests, not just measure creation
- On receiving any request: attempt a solution immediately — no questions, no mode announcement, just solve
- Silent routing — no "Routing to /pbi explain..." announcement; behaves like a natural assistant

### Escalation detection
- Escalation triggers only on explicit user failure signals: negative/correction language ("that's wrong", "not what I meant", "still broken", "try again")
- No turn counter or automatic escalation — explicit signal only (no false positives from normal back-and-forth)
- When triggered: brief acknowledgment ("Let me get more context") then immediately ask the targeted question
- Escalation state written to `.pbi-context.md` — prevents re-asking questions already gathered this session
- If a post-escalation answer also fails: re-escalate by identifying the remaining unresolved gap and asking one more targeted question about it

### Targeted question scope
- Ask only what's blocking — do not always ask all 3 questions
- Diagnose the gap by reading the user's failure description: "filter is wrong" → visual/model context; "calculating the wrong thing" → business question; "we already have that" → existing measures
- Gap diagnosis via Claude's judgment — no meta-question to the user
- Questions are conversational free-text, not structured option lists
- After targeted context is gathered, retry automatically — no extra prompt for user to re-submit

### Deep mode invocation
- `/pbi deep` is the dedicated explicit entry point — no keyword-in-request trigger
- Without a description: ask "What are we working on in deep mode?" as the opening question
- Phase 1 scope: stub that accepts invocation and runs full upfront interrogation (business question, model state, existing measures)
- All gathered deep-mode context written to `.pbi-context.md` so Phase 2/3 commands inherit it without re-asking
- Full phase gates, model review phase, and verification gates are Phase 3 — out of scope here

### Claude's Discretion
- Exact failure-signal keyword list (what counts as negative/correction language)
- Session context schema additions (what fields to add for escalation state)
- Exact wording of acknowledgment before escalation questions

</decisions>

<specifics>
## Specific Ideas

- "Never block a data analyst — solve immediately, interrogate only when stuck or asked" — the core behavioral contract
- Progressive friction: default is zero friction, friction only introduced after the user signals it's needed
- The escalation path should feel like a smart collaborator asking one focused question, not a form being filled out

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SKILL.md` routing table: add one new catch-all row at the bottom (lowest-priority match) — "free-text, no keyword match" → solve-first handler
- `.pbi-context.md`: already exists and is read/written by all commands — add an escalation state section (e.g., `## Escalation State`) to track gathered context flags
- `commands/new.md`: existing Step 1 (Collect Requirements) shows the pattern for conversational intake — escalation questions can follow a similar structure

### Established Patterns
- Router reads `$ARGUMENTS` first word/keyword — catch-all is anything that doesn't match existing keywords
- All commands read `.pbi-context.md` with Read tool and write back with Write tool (never bash append)
- Sonnet for DAX reasoning, haiku Agent for file/git ops — catch-all solve-first and `/pbi deep` both use sonnet direct

### Integration Points
- SKILL.md routing table: new catch-all row added after all existing keyword rows
- `.pbi-context.md`: new `## Escalation State` section alongside existing `## Last Command`, `## Command History`, `## Analyst-Reported Failures`
- `commands/deep.md`: new file for the `/pbi deep` stub command

</code_context>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-skill-core-escalation*
*Context gathered: 2026-03-13*
