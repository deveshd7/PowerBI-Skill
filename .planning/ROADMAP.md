# Roadmap: PBI Skill v2

## Milestones

- ✅ **v1.0 Core** — Phases 1-2 (shipped 2026-03-14)
- 📋 **v1.1 Deep Mode** — Phase 3 (planned)

## Phases

<details>
<summary>✅ v1.0 Core (Phases 1-2) — SHIPPED 2026-03-14</summary>

- [x] Phase 1: Skill Core + Escalation (2/2 plans) — completed 2026-03-13
- [x] Phase 2: Context-Aware DAX (5/5 plans) — completed 2026-03-14

Full phase details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### 📋 v1.1 Deep Mode (Planned)

- [ ] **Phase 3: Deep Mode + Verification** — On-demand structured workflow with model review phase, phase gates, and context re-injection
  - **Goal**: On-demand structured workflow is available with model review, hard phase gates, and context carry-forward
  - **Depends on**: Phase 2
  - **Requirements**: PHASE-01, VERF-01, VERF-02, VERF-03
  - **Success Criteria**:
    1. Model review runs before any DAX in deep mode: structured summary of tables, relationships, health flags
    2. Each phase boundary is a hard gate: user must confirm before advancing
    3. Final check that output answers the business question stated at the start
    4. Context (tables, relationships, existing measures, business question) restated at each phase start
  - **Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Skill Core + Escalation | v1.0 | 2/2 | Complete | 2026-03-13 |
| 2. Context-Aware DAX | v1.0 | 5/5 | Complete | 2026-03-14 |
| 3. Deep Mode + Verification | v1.1 | 0/TBD | Not started | - |
