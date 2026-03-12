---
phase: 05-direct-editing-and-router
plan: 02
subsystem: skill
tags: [pbi-edit, tmdl, tmsl, pbip, claude-skill, before-after-preview, pre-write-checklist]

# Dependency graph
requires:
  - phase: 02-context-detection-and-pbip-file-i-o
    provides: PBIP detection bash block, Desktop check, Session Context pattern, Read-then-Write for .pbi-context.md
  - phase: 04-git-workflow
    provides: auto-commit block scoped to .SemanticModel/, conventional commit prefix rules
provides:
  - pbi-edit SKILL.md — general-purpose PBIP model editor with Before/After preview and pre-write checklist
  - unappliedChanges.json test fixture for EDIT-02 manual verification
affects: [05-direct-editing-and-router, 05-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Three-block startup pattern (PBIP Detection + Desktop Check + Session Context) extended to pbi-edit
    - Pre-write checklist: Desktop guard + unappliedChanges.json check + indentation check before any write
    - Before/After preview with File: header and capital-N default — confirmed as standard for write-gated skills
    - Entity resolution with fuzzy-match fallback for typo tolerance on measure names
    - Auto-commit block scoped to .SemanticModel/ with conventional prefix rules (chore/feat/fix)

key-files:
  created:
    - .claude/skills/pbi-edit/SKILL.md
    - tests/fixtures/pbip-tmdl/.SemanticModel/unappliedChanges.json
  modified: []

key-decisions:
  - "pbi-edit is PBIP-only — no paste-in fallback; stops with locked message on PBIP_MODE=paste"
  - "Pre-write checklist fires before computing After state — Desktop guard stops first, then unappliedChanges.json warning, then indentation check"
  - "Capital-N default on confirm prompt means Enter = cancel; only explicit y or Y proceeds to write"
  - "Auto-commit uses conventional prefix chore: for rename/expression/metadata, feat: for additions, fix: for removals"
  - "Entity ambiguity always requires analyst clarification — no auto-selection when same name found in multiple tables"
  - "TMSL expression form preserved — string stays string, array stays array; only converts string to array when new expression has line breaks"

patterns-established:
  - "Pre-write checklist pattern: Desktop guard → unappliedChanges.json → indentation check → compute change → preview → confirm"
  - "Fuzzy-match fallback: zero results triggers grep of all measures, then up to 3 candidates suggested with table names"
  - "Read-then-Write enforced for both target TMDL/TMSL files and .pbi-context.md"

requirements-completed: [EDIT-01, EDIT-02, EDIT-03, EDIT-04]

# Metrics
duration: 2min
completed: 2026-03-12
---

# Phase 5 Plan 02: pbi-edit Skill Summary

**General-purpose PBIP model editor with 7-step workflow: entity resolution with fuzzy-match, pre-write checklist (Desktop + unappliedChanges.json + indentation), Before/After preview with capital-N default, and auto-commit with conventional prefixes**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-12T16:48:38Z
- **Completed:** 2026-03-12T16:50:40Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `.claude/skills/pbi-edit/SKILL.md` with full 7-step workflow covering all EDIT-01 through EDIT-04 requirements
- Implemented entity resolution with grep-based lookup and fuzzy-match fallback for typo tolerance
- Pre-write checklist enforces Desktop-closed guard and unappliedChanges.json warning before any write
- Created `tests/fixtures/pbip-tmdl/.SemanticModel/unappliedChanges.json` fixture for EDIT-02 manual verification

## Task Commits

Each task was committed atomically:

1. **Task 1: Create pbi-edit skill** - `3b5900c` (feat)
2. **Task 2: Create unappliedChanges.json test fixture** - `5c68551` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `.claude/skills/pbi-edit/SKILL.md` - General-purpose PBIP model editor skill with 7-step workflow
- `tests/fixtures/pbip-tmdl/.SemanticModel/unappliedChanges.json` - Test fixture simulating Power BI Desktop unsaved-changes marker

## Decisions Made
- pbi-edit is PBIP-only with no paste-in fallback, stopping with the locked message "No PBIP project found. Run /pbi:edit from a directory containing .SemanticModel/." — enforces that direct file editing requires a PBIP project
- Pre-write checklist is ordered: Desktop guard first (hard stop), then unappliedChanges.json (soft warning with y/N), then indentation check (informational for write-back) — ordering ensures most critical stops happen earliest
- Capital-N default on confirm prompt means Enter = cancel, consistent with pbi-error confirm-before-write pattern established in Phase 2
- Commit prefix rules: chore: for all metadata/rename/expression updates, feat: for new entity additions, fix: for removals — carries forward Phase 4 auto-commit conventions exactly

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- pbi-edit SKILL.md is complete and ready for manual verification against tests/fixtures/pbip-tmdl/
- EDIT-01 through EDIT-04 requirements are fully covered by the skill's instruction steps
- Plan 05-03 (pbi router) can proceed — pbi-edit is a well-defined skill that the router will reference

## Self-Check: PASSED

- FOUND: .claude/skills/pbi-edit/SKILL.md
- FOUND: tests/fixtures/pbip-tmdl/.SemanticModel/unappliedChanges.json
- FOUND: .planning/phases/05-direct-editing-and-router/05-02-SUMMARY.md
- FOUND commit: 3b5900c (feat(05-02): create pbi-edit skill)
- FOUND commit: 5c68551 (feat(05-02): add unappliedChanges.json test fixture)

---
*Phase: 05-direct-editing-and-router*
*Completed: 2026-03-12*
