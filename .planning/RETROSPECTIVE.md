# Retrospective: PBI Skill v2

---

## Milestone: v1.0 — Core

**Shipped:** 2026-03-14
**Phases:** 2 (Phase 1: Skill Core + Escalation, Phase 2: Context-Aware DAX) | **Plans:** 7

### What Was Built

- SKILL.md v4.0 with progressive friction (solve-first, escalate on failure signals only)
- `/pbi deep` entry point for explicit deep mode invocation
- Model context intake (Step 0.5) added to all 6 DAX subcommands
- Always-on duplication check in `new.md`
- Filter-sensitive pattern gate with visual context write-back in `new.md`
- Measures Gate in `deep.md` — session-end review tied to business question

### What Worked

- **Inversion of the core model** (interrogation-first → solve-first) was validated in Phase 1 acceptance tests. The progressive friction pattern is clearly the right model for daily-use tooling.
- **Step 0.5 as a universal pattern** worked across all 6 subcommands with minimal friction — the skip-if-present logic prevents re-asking in multi-command sessions.
- **Phase 2 execution velocity**: 5 plans in ~30 min total (6 min/plan avg). Research-then-implement with tight scope is the right execution model for skill file changes.
- **Acceptance scenarios before implementation** (Plan 02-01 first): having 14 pass criteria written before touching code made the implementation targets unambiguous.

### What Was Inefficient

- **ROADMAP.md plan checkboxes not updated after execution**: the gsd-tools and VERIFICATION.md had the right state, but the human-readable plan checkboxes stayed stale. Created noise in the milestone audit.
- **REQUIREMENTS.md Phase 1 checkboxes**: 7 Phase 1 requirements stayed unchecked even after Phase 1 was verified complete. Caused a false "5/11 checked" reading at milestone completion.
- **STATE.md fragmentation**: two frontmatter blocks from different projects stacked in one file. Messy but functional.

### Patterns Established

- **Step 0.5 placement**: always after `## Instructions` header, before Step 1; always skip if `## Model Context` section present
- **Duplication check placement**: after Step 1 (intent recognition), before DAX generation
- **Filter-sensitive gate**: keyword-triggered, blocks generation until visual placement confirmed
- **Measures gate**: fires only on explicit user completion signal (not per-measure); restates business question

### Key Lessons

1. **Write acceptance tests before implementation plans** — had to do this explicitly (Plan 02-01 first in Phase 2). Should be a default step in every phase plan.
2. **Update requirement checkboxes at phase completion** — don't let them go stale. The verification step should include a REQUIREMENTS.md update.
3. **The solve-first pattern is contagious** — once implemented in the skill, it became the obvious model for everything. Don't overthink the design; ship and iterate.
4. **Tech debt is predictable at phase boundary**: all 3 v1.0 known issues (field name mismatches in `.pbi-context.md`) were identified by the integration audit. Future audits at phase boundaries prevent milestone-level surprises.

### Cost Observations

- Model mix: balanced profile (Sonnet default, Haiku for file ops)
- Sessions: ~4 sessions across 2 days
- Notable: Phase 2 executed in a single session at high velocity — tight scope + existing patterns from Phase 1 = fast execution

---

## Milestone: v1.1 — Complete

**Shipped:** 2026-03-14
**Phases:** 2 (Phase 3: Context Field Fixes, Phase 4: Deep Mode Complete) | **Plans:** 4

### What Was Built

- Locked four-line `## Last Command` block with `- Field:` bullet syntax across edit, optimise, diff, commit — closed all three context-schema bugs from v1.0 audit
- Four-phase deep mode workflow: Phase A (context intake), Gate A→B, Phase B (model review), Gate B→C, Phase C (DAX development), Phase D (final verification)
- Hard gate three-branch logic (exact token / cancel / re-output) — prevents soft-gate bypass
- Context re-injection blocks at Phase B, C, D starts to prevent context drift
- 8 acceptance scenarios (S5-01 to S5-08) covering PHASE-01, VERF-01, VERF-02, VERF-03

### What Worked

- **Tight scope execution**: 4 plans, ~7 min total (Phase 3: ~2 min, Phase 4: ~4 min). Clear bug descriptions + locked solution patterns = near-zero planning overhead.
- **Three-branch gate pattern**: Articulating the third branch (re-output on unmatched input) as the distinguishing feature of a *hard* gate resolved the design immediately. The insight "two-branch gates are soft gates" is a reusable heuristic.
- **Acceptance scenarios as completion signal**: Writing S5-01 to S5-08 in Plan 02 made Phase 4 completion unambiguous without requiring live PBI Desktop tests.
- **Locked `- Field:` bullet syntax**: Single change to instruction format eliminated an entire class of field-name ambiguity bugs. Generalizes to any context-write instruction.

### What Was Inefficient

- **v1.1-MILESTONE-AUDIT.md not created before close**: The v1.0 audit was available but no v1.1 audit was run before milestone completion. Low risk given the small scope, but the audit step provides value even for 2-phase milestones.
- **ROADMAP.md plan checkboxes stayed `[ ]` through phase execution**: Same pattern from v1.0 — the phase summary and VERIFICATION.md had the right state but the roadmap plan checkboxes were never updated. Minor noise.

### Patterns Established

- **Locked context-write format**: All future subcommands that update `## Last Command` should use the locked four-line `- Field:` bullet format — never prose, never `Field = value`
- **Hard gate structure**: Three branches always: (1) exact affirmative token → proceed, (2) cancel → stop, (3) anything else → re-output the full gate prompt. Never two-branch.
- **Acceptance scenarios before plan close**: Last plan of each phase should include or reference the acceptance scenario group for that phase. Serves as verifiable completion criteria without live tool access.

### Key Lessons

1. **"Two-branch gates are soft gates"** — the third branch (re-output on unmatched input) is what makes a gate hard. This is the key design insight from Phase 4.
2. **Field-name ambiguity is a class of bug** — any instruction that says "write Field = value" is a soft instruction. Lock it with `- Field: [value]` and the class disappears.
3. **Small milestones ship fast** — 2 phases, 4 plans, 7 minutes execution. Tight scope + clear bugs + existing patterns = very low friction. The overhead is in planning and closure, not execution.

### Cost Observations

- Model mix: balanced profile (Sonnet default)
- Sessions: ~2 sessions on 2026-03-14
- Notable: Both phases executed in a single day with minimal context; Phase 3 in ~2 min, Phase 4 in ~4 min — fastest v1.x milestone by far

---

## Cross-Milestone Trends

| Milestone | Phases | Plans | Avg/Plan | Tech Debt Items |
|-----------|--------|-------|----------|-----------------|
| v1.0 Core | 2 | 7 | ~10 min | 3 (field schema mismatches) |
| v1.1 Complete | 2 | 4 | ~2 min | 0 (debt-clearing milestone) |

