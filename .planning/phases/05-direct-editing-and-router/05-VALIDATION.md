---
phase: 5
slug: direct-editing-and-router
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual / bash fixture-based (no automated test runner) |
| **Config file** | none — tests are manual inspection against fixtures in `tests/fixtures/` |
| **Quick run command** | Run `/pbi:edit` in `tests/fixtures/pbip-tmdl/` with a rename description; verify Sales.tmdl is updated correctly |
| **Full suite command** | Manual walkthrough of all scenarios for EDIT-01 through EDIT-04 and INFRA-02 against both TMDL and TMSL fixtures |
| **Estimated runtime** | ~10 minutes (manual) |

---

## Sampling Rate

- **After every task commit:** Manual inspection of modified fixture file and git log
- **After every plan wave:** Run all 5 requirement scenarios against both TMDL and TMSL fixtures
- **Before `/gsd:verify-work`:** All EDIT-01 through EDIT-04 and INFRA-02 manually verified
- **Max feedback latency:** ~5 minutes per task

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 5-router-01 | router | 1 | INFRA-02 | manual | Run bare `/pbi` — verify category menu; run `/pbi explain a measure` — verify direct route | ✅ no fixture needed | ⬜ pending |
| 5-edit-01 | edit | 1 | EDIT-01 | manual | Run `/pbi:edit` "rename measure [Revenue] to [Total Revenue] in Sales" in `tests/fixtures/pbip-tmdl/`; verify Sales.tmdl updated | ✅ `tests/fixtures/pbip-tmdl` | ⬜ pending |
| 5-edit-02 | edit | 1 | EDIT-02 | manual | (a) Run with Desktop open → verify blocked; (b) create `unappliedChanges.json` → verify warning prompt; (c) inspect written file → verify indentation preserved | ✅ `tests/fixtures/pbip-tmdl` | ⬜ pending |
| 5-edit-03 | edit | 1 | EDIT-03 | manual | Run `/pbi:edit` with any change; verify File header, Before/After blocks, `Write this change? (y/N)` prompt; press Enter → verify "Change discarded." | ✅ `tests/fixtures/pbip-tmdl` | ⬜ pending |
| 5-edit-04 | edit | 1 | EDIT-04 | manual | Run through full y-confirm flow; verify `git log --oneline` shows new commit with correct message and `.SemanticModel/` files staged | ✅ `tests/fixtures/pbip-tmdl` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/fixtures/pbip-tmdl/.SemanticModel/unappliedChanges.json` — test file for EDIT-02 unappliedChanges check (created for test, removed after)
- [ ] Git history in `tests/fixtures/pbip-tmdl/` — if not already initialised from Phase 4, run `git init` and create initial commit to enable EDIT-04 auto-commit verification
- [ ] TMSL rename test variant — update `"name"` field in `tests/fixtures/pbip-tmsl/model.bim` measures array to verify JSON integrity preserved

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `/pbi:edit` reads, modifies, and writes PBIP files | EDIT-01 | No automated test runner; skill output is Claude conversational response + file mutation | Run `/pbi:edit` with rename intent in `tests/fixtures/pbip-tmdl/`; verify TMDL file shows new measure name |
| Pre-write checklist enforced | EDIT-02 | Desktop-open check requires manual environment; `unappliedChanges.json` test requires manual file setup | Three sub-tests: (a) Desktop open, (b) unappliedChanges.json present, (c) indentation after write |
| Before/After preview + confirm | EDIT-03 | Interactive prompt flow cannot be automated without a test harness for Claude responses | Run and visually verify preview format and Enter=cancel behaviour |
| Auto-commit created | EDIT-04 | Requires live git repo with clean working tree | Verify `git log` after successful edit |
| Bare `/pbi` routing | INFRA-02 | Conversational routing — no file mutations to check | Run bare `/pbi` and verify category menu; run `/pbi [intent]` and verify direct route |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10 minutes
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
