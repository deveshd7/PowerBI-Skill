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

## Cross-Milestone Trends

| Milestone | Phases | Plans | Avg/Plan | Tech Debt Items |
|-----------|--------|-------|----------|-----------------|
| v1.0 Core | 2 | 7 | ~10 min | 3 (field schema mismatches) |

