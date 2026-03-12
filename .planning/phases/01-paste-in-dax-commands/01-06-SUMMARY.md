---
phase: 01-paste-in-dax-commands
plan: "06"
subsystem: skill
tags: [claude-skills, power-bi, error-diagnosis, dax, session-context]

requires:
  - phase: 01-paste-in-dax-commands/01-01
    provides: .claude/skills/pbi-error/ directory with placeholder SKILL.md and .pbi-context.md schema

provides:
  - /pbi:error command — complete error diagnosis skill with six error categories, prior-failure check, and last-command correlation

affects:
  - Phase 2+ skills that use .pbi-context.md session state (pattern established here for error tracking)

tech-stack:
  added: []
  patterns:
    - "tail -100 on .pbi-context.md for error skills (more history needed than DAX skills which use tail -80)"
    - "ERR-04 prior-failure guard: scan Analyst-Reported Failures before generating recommendations"
    - "ERR-02 last-command correlation: surface Last Command section in diagnosis output for contextual specificity"
    - "Six-category error classification: A (name resolution), B (circular dependency), C (context transition), D (data refresh/type), E (relationship), F (unknown)"

key-files:
  created: []
  modified:
    - .claude/skills/pbi-error/SKILL.md

key-decisions:
  - "tail -100 used instead of tail -80 for session context injection — error recovery benefits from more history, particularly the full Analyst-Reported Failures table"
  - "Six categories (A-F) cover the vast majority of real Power BI errors encountered in practice; Category F (unknown) with explicit low-confidence signal ensures graceful degradation"
  - "Do NOT modify Analyst-Reported Failures in context update loop — analyst manages failures manually, skill only writes to Last Command and Command History"

patterns-established:
  - "Prior-failure guard pattern: scan context before recommendations, exclude previously-failed methods"
  - "Last-command correlation: tie error diagnosis to the most recent /pbi:* command for specificity"

requirements-completed: [ERR-01, ERR-02, ERR-04, CTX-02, CTX-03, CTX-04]

duration: 2min
completed: 2026-03-12
---

# Phase 1 Plan 06: pbi-error Skill Summary

**Context-aware Power BI error diagnosis with six error categories, prior-failure avoidance (ERR-04), and last-command correlation (ERR-02) via .pbi-context.md session state**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-12T10:24:09Z
- **Completed:** 2026-03-12T10:26:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- `/pbi:error` SKILL.md fully implemented (129 lines) — replaces the "Instructions pending" placeholder with a complete, invocable skill
- ERR-04 satisfied: prior-failure check scans "Analyst-Reported Failures" section from session context before producing recommendations; excluded approaches are not surfaced
- ERR-02 satisfied: last-command correlation reads "## Last Command" section and includes a specific correlation line in the diagnosis output, with examples of how each /pbi:* command type might relate to common errors
- Six named error categories (A-F) with patterns, root cause, and actionable numbered fix steps — Category F provides graceful degradation for unrecognised errors with explicit low-confidence signal
- Context update loop present: reads then writes .pbi-context.md, updating Last Command and Command History (capped at 20 rows), leaving Analyst-Reported Failures untouched

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement /pbi:error SKILL.md** — `d2c1aca` (feat)

## Files Created/Modified

- `.claude/skills/pbi-error/SKILL.md` — Complete /pbi:error command: session context injection (tail -100), prior-failure guard, last-command correlation, six error categories, structured output with Root Cause + Fix + Verification, and .pbi-context.md update loop

## Decisions Made

- `tail -100` used rather than `tail -80` for session context — error diagnosis benefits from seeing more history, especially the Analyst-Reported Failures table which can have multiple rows
- Six categories rather than five: added Category F (unknown/generic) to handle unrecognised errors gracefully with a low-confidence signal rather than producing a confident-sounding wrong diagnosis
- Analyst-Reported Failures is not updated by the skill — kept analyst-managed to avoid the skill auto-appending false positives; only the analyst can confirm that an approach "failed"

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All six Phase 1 skills are now complete: pbi-explain (01-02), pbi-format (01-03), pbi-optimise (01-04), pbi-comment (01-05), pbi-error (01-06), and pbi-load (01-01)
- Phase 1 is ready for completion — all paste-in DAX commands are invocable from the Claude Code `/` command menu
- Phase 2 (PBIP file integration) can proceed: the .pbi-context.md session state schema and skill patterns established in Phase 1 carry forward unchanged

---
*Phase: 01-paste-in-dax-commands*
*Completed: 2026-03-12*
