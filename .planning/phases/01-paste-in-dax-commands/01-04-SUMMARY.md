---
phase: 01-paste-in-dax-commands
plan: "04"
subsystem: dax
tags: [claude-skills, dax, power-bi, optimise, performance, context-transition]

requires:
  - phase: 01-paste-in-dax-commands/01-01
    provides: .claude/skills/pbi-optimise/ directory with placeholder SKILL.md and .pbi-context.md session schema

provides:
  - /pbi:optimise command — complete implementation with five optimisation rules, iterator-over-measure-reference guard, complexity-scaled rationale, and side-by-side output layout

affects:
  - 01-02-PLAN (pbi-explain — shares complexity inference and output layout conventions)
  - 01-03-PLAN (pbi-format — .pbi-context.md write pattern shared)
  - 01-05-PLAN (pbi-comment — shares next-steps menu convention)
  - 01-06-PLAN (pbi-error — .pbi-context.md read/write loop pattern shared)

tech-stack:
  added: []
  patterns:
    - "CRITICAL GUARD before rule application: iterator-over-measure-reference checked first, flagged not rewritten"
    - "Complexity-scaled rationale depth: simple=one sentence, intermediate=2-3 sentences, advanced=full paragraph"
    - "Multiple-valid-rewrites pattern: labelled Option A / Option B with trade-off notes"
    - "Rule 4 is a DO NOT REWRITE marker — guard handles it, rule slot preserved for clarity"

key-files:
  created: []
  modified:
    - .claude/skills/pbi-optimise/SKILL.md

key-decisions:
  - "Iterator-over-measure-reference is flagged only, never auto-rewritten — context transition semantics must be manually verified"
  - "Guard check (Step 3) is positioned explicitly BEFORE rules (Step 4) — order matters for correctness"
  - "Rule 5 (nested iterators) flags only unless inner expression is trivially collapsible (plain column ref, no formula)"
  - "Rationale depth scales with inferred complexity so simple measures get concise output and advanced measures get engine-level explanation"
  - "Flags section omitted entirely when no flags apply — keeps output clean for optimisable-but-not-guarded measures"

patterns-established:
  - "Side-by-side DAX layout: ### Original → ### Optimised → ### Changes → ### Flags (if any)"
  - ".pbi-context.md update via Read-then-Write after every command output — tracks measure name, rules applied, flags raised"

requirements-completed: [DAX-07, DAX-08, DAX-09, DAX-10, CTX-02, CTX-03, CTX-04]

duration: 4min
completed: 2026-03-12
---

# Phase 1 Plan 04: /pbi:optimise Summary

**DAX performance optimiser with five rules, an explicit iterator-over-measure-reference guard that prevents incorrect auto-rewrites, complexity-scaled rationale, and a locked side-by-side output layout**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-12T11:05:46Z
- **Completed:** 2026-03-12T11:09:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- `/pbi:optimise` SKILL.md fully implemented — replaces placeholder with 218-line complete instruction set
- CRITICAL GUARD (Step 3) detects iterator-over-measure-reference patterns before any rules fire; flagged measures are explained, not rewritten, protecting analysts from incorrect context-transition rewrites
- Three rewrite rules ship with detect + rewrite + rationale: FILTER-on-table (Rule 1), SUMX-over-single-column (Rule 2), redundant-CALCULATE (Rule 3)
- Rule 5 (nested iterators) flags Cartesian-product risk and rewrites only when trivially collapsible
- Rationale depth inferred from complexity: simple measures get one-sentence rationale, advanced measures get engine-level paragraphs
- `--table TableName` flag accepted; table context note injected at top of output
- Multiple-valid-rewrites alternative presentation documented with trade-off labels
- `.pbi-context.md` read/write loop updates Last Command, Command History (capped at 20 rows) after every invocation

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement /pbi:optimise SKILL.md** — `275e5aa` (feat)

## Files Created/Modified

- `.claude/skills/pbi-optimise/SKILL.md` — Complete /pbi:optimise implementation; 218 lines; five optimisation rules with detect/rewrite/rationale blocks; iterator-over-measure-ref guard; side-by-side output; .pbi-context.md update loop

## Decisions Made

- Iterator-over-measure-reference patterns are flagged with an explicit "context transition present" warning and never auto-rewritten. Context transitions (row-to-filter context via implicit CALCULATE) can silently change measure semantics — an analyst must manually verify the pattern is correct before refactoring.
- The guard (Step 3) is placed before Rule application (Step 4) by design. If rules fired first, a rewrite of a portion of the measure could occur before the guard had a chance to prevent it.
- Flags section is omitted when empty, keeping output uncluttered for common cases where rewrites are straightforward.
- Rule 5 only rewrites nested iterators when the inner expression is a plain column reference (trivially collapsible). Non-trivial inner expressions are flagged only — automating a Cartesian product reduction risks introducing logical errors.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Verification grep used lowercase "context transition" but file used sentence-case "Context transition"**
- **Found during:** Task 1 verification
- **Issue:** Plan's `<verify>` block uses `grep -q "context transition"` (lowercase); the guard section header used sentence-case "Context transition" which failed the case-sensitive grep
- **Fix:** Added "(context transition guard)" parenthetical to the Step 3 header so the lowercase string is present in the file
- **Files modified:** .claude/skills/pbi-optimise/SKILL.md
- **Verification:** All five grep checks in `<verify>` block return matches and combined `PASS`
- **Committed in:** 275e5aa (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in verification match)
**Impact on plan:** Minimal — a single word-case adjustment to satisfy the plan's own verification check. No functional change to the skill behaviour.

## Issues Encountered

None beyond the case-sensitivity deviation documented above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `/pbi:optimise` is complete and invocable via the Claude Code `/` command menu
- `.pbi-context.md` update pattern (Read → Write, cap 20 rows) is established and ready to serve as the reference pattern for plans 05 and 06
- Test fixture `tests/fixtures/slow-filter-measure.dax` provides a ready FILTER-on-table input for manual Rule 1 verification
- Test fixture `tests/fixtures/complex-measure.dax` (SUMX iterator) provides manual Rule 2 / iterator-guard verification input

---
*Phase: 01-paste-in-dax-commands*
*Completed: 2026-03-12*

## Self-Check: PASSED

- FOUND: .claude/skills/pbi-optimise/SKILL.md
- FOUND: .planning/phases/01-paste-in-dax-commands/01-04-SUMMARY.md
- FOUND: commit 275e5aa
