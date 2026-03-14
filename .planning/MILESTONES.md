# Milestones

## v1.0 Core (Shipped: 2026-03-14)

**Phases completed:** 2 phases (Phase 1: Skill Core + Escalation, Phase 2: Context-Aware DAX)
**Plans:** 7 | **Requirements shipped:** 12/16 v1 (Phase 3 requirements deferred to v1.1)

**Key accomplishments:**
- SKILL.md v4.0 rewrite: solve-first catch-all default, 2-step escalation on failure signals, `/pbi deep` entry point
- 19 manual acceptance scenarios covering solve-first, escalation paths, deep mode intake (Phase 1 test suite)
- `new.md` upgraded: universal model context intake (Step 0.5), always-on duplication check, filter-sensitive pattern gate with Visual Context write-back
- Step 0.5 model context check added to `explain`, `format`, `optimise` — grounding DAX in table context, non-blocking variant in `format`
- Step 0.5 context intake added to `comment` and `error` — skips when context already recorded
- Measures Gate (`deep.md` Step 4) — terminal session review that restates business question, requires confirmation before closing

**Tech debt deferred:**
- pbi-edit writes `Entity:` not `Measure:` to session context (cross-phase ERR-02 degradation)
- pbi-diff / pbi-commit omit `Measure:` field (stale pbi-error correlation)
- pbi-optimise Command History row format misaligned with schema

**Archives:**
- `.planning/milestones/v1.0-ROADMAP.md`
- `.planning/milestones/v1.0-REQUIREMENTS.md`
- `.planning/milestones/v1.0-MILESTONE-AUDIT.md`

---

