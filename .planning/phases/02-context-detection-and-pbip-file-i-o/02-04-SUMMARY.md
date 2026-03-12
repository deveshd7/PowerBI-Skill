---
phase: 02-context-detection-and-pbip-file-i-o
plan: "04"
subsystem: infra
tags: [pbi-error, pbip, tmdl, tmsl, file-mode, error-recovery, confirm-before-write]

# Dependency graph
requires:
  - phase: 02-context-detection-and-pbip-file-i-o
    provides: "PBIP detection pattern (PBIP_MODE/PBIP_FORMAT/DESKTOP flags) from pbi-comment (02-03)"
  - phase: 02-context-detection-and-pbip-file-i-o
    provides: "TMDL and TMSL test fixtures from 02-01"
provides:
  - "pbi-error with PBIP detection header and file-mode routing"
  - "Confirm-before-write fix application for TMDL and TMSL projects"
  - "Desktop safety guard: open Desktop = paste-only output, no write"
  - "Before/after preview with 'Apply this fix? (y/N)' prompt"
  - "Graceful fallback for non-fixable categories (D, E, F)"
affects:
  - 03-model-auditing
  - future phases using pbi-error skill

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PBIP detection via bash injection identical to pbi-comment pattern"
    - "Desktop safety check via tasklist before any write operation"
    - "Confirm-before-write: show before/after preview, prompt 'Apply this fix? (y/N)', capital N = default No"
    - "Category-gated writes: only Categories A/B/C trigger file write; D/E/F output graceful fallback message"
    - "TMDL: grep-locate measure file, expression-only replacement, preserve all other properties"
    - "TMSL: read full model.bim, update expression field only, preserve string/array form"

key-files:
  created: []
  modified:
    - .claude/skills/pbi-error/SKILL.md

key-decisions:
  - "pbi-error requires explicit 'y' confirmation before writing — unlike pbi-comment which writes without confirm"
  - "Before/after preview is mandatory before the confirm prompt — analyst must see the proposed change"
  - "Confirm prompt: 'Apply this fix? (y/N)' — capital N = default No, prevents accidental overwrites"
  - "No --force flag — Desktop open always = paste-ready output only, no write path"
  - "Category-gated writes: only expression-fixable categories (A/B/C) can trigger write; D/E/F emit graceful fallback"
  - "Measure name confirmation skipped when error text explicitly names the measure — reduces friction for clear-cut errors"
  - "Manual live testing deferred pending Power BI Desktop access — implementation accepted by analyst"

patterns-established:
  - "Confirm-before-write pattern: unique to pbi-error vs pbi-comment's silent write"
  - "Graceful fallback for non-fixable categories: message explains why auto-fix is not possible"
  - "PBIP detection header pattern now consistent across pbi-comment and pbi-error"

requirements-completed: [INFRA-03, INFRA-06, ERR-03]

# Metrics
duration: continuation (Task 2 deferred-approved)
completed: 2026-03-12
---

# Phase 2 Plan 04: pbi-error File-Mode Branch Summary

**pbi-error skill extended with PBIP detection, Desktop safety guard, confirm-before-write fix preview, and category-gated TMDL/TMSL write-back**

## Performance

- **Duration:** Continuation plan — Task 1 executed previously, Task 2 verification deferred
- **Started:** 2026-03-12
- **Completed:** 2026-03-12
- **Tasks:** 2 of 2 (Task 2 verification deferred — approved by analyst)
- **Files modified:** 1

## Accomplishments

- Added PBIP Detection and Desktop Check bash injection blocks to pbi-error/SKILL.md, matching the established pbi-comment pattern
- Implemented File Mode Branch with full routing: paste-in path (unchanged behavior), file-mode path with Desktop=open abort and Desktop=closed confirm-before-write path
- Documented category-gated write logic: Categories A/B/C trigger before/after preview and "Apply this fix? (y/N)" confirm; Categories D/E/F emit graceful fallback explaining why auto-apply is not possible
- Preserved all existing Step 1-6 instructions and the Phase 1 locked decision (tail -100 for session context injection)

## Task Commits

Each task was committed atomically:

1. **Task 1: Prepend startup detection block to pbi-error and add file-mode branch** - `38ccdf8` (feat)
2. **Task 2: Manual verification of pbi-error file-mode paths** - deferred (verification approved without live PBI access)

**Plan metadata:** (to be added with this SUMMARY commit)

## Files Created/Modified

- `.claude/skills/pbi-error/SKILL.md` — Extended with PBIP Detection block, Desktop Check block, File Mode Branch section, and confirm-before-write File Fix Preview subsection

## Decisions Made

- **Confirm-before-write is unique to pbi-error:** pbi-comment writes silently after generation; pbi-error requires explicit "y" before any write. This asymmetry is intentional — error fixes carry higher risk than comment updates.
- **Capital N default on confirm prompt:** "Apply this fix? (y/N)" — the default is No. The analyst must actively type "y" to trigger a write. Prevents accidental overwrites.
- **Category-gated writes:** Only Categories A, B, C (expression-fixable DAX errors) can trigger the file write path. Categories D (data refresh), E (relationships), and F (unknown) emit a graceful fallback explaining why the fix cannot be auto-applied. This prevents the skill from attempting writes that would have no effect or require Desktop-side changes.
- **Measure name confirmation is conditional:** The skill skips the "is this the correct measure?" prompt when the error text explicitly names the failing measure (e.g. "The name '[Revenue YTD]' does not exist"). This reduces friction for unambiguous errors.
- **Manual live testing deferred:** Analyst confirmed they do not have Power BI Desktop access at this time. Implementation was reviewed and accepted. Live testing (Tests A–E from the checkpoint) will be conducted when PBI Desktop is available.

## Deviations from Plan

None - plan executed exactly as written. Task 2 was a checkpoint:human-verify that the analyst approved with testing deferred.

## Issues Encountered

- **Task 2 verification deferred:** Analyst does not currently have Power BI Desktop access. The 5 manual test cases (A: paste-in mode, B: TMDL write accepted, C: confirm rejected, D: Desktop open, E: non-fixable category) cannot be run until Desktop is available. Analyst reviewed the implementation and approved it as complete. Live verification is deferred to a future session.

## User Setup Required

None - no external service configuration required. When Power BI Desktop is available, run the 5 manual test cases documented in 02-04-PLAN.md Task 2 to confirm all paths behave as expected.

## Next Phase Readiness

- pbi-error now matches pbi-comment in PBIP awareness and file-mode routing
- Both skills (pbi-comment and pbi-error) follow the established PBIP detection pattern: same bash injection blocks, same DESKTOP check, same file-mode header format
- Phase 2 plan 04 is the final execution plan in the phase — Phase 2 is now functionally complete pending live PBI verification
- Phase 3 (model auditing) can proceed; it depends on PBIP fixtures (02-01) and context loading (02-02) which are complete

---
*Phase: 02-context-detection-and-pbip-file-i-o*
*Completed: 2026-03-12*
