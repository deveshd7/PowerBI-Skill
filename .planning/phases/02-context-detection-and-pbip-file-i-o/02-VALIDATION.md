---
phase: 2
slug: context-detection-and-pbip-file-i-o
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — prompt/skill system with no compiled code |
| **Config file** | N/A |
| **Quick run command** | Manual: invoke `/pbi:load` in a directory with a test PBIP fixture |
| **Full suite command** | Manual: run `/pbi:load`, `/pbi:comment`, `/pbi:error` with TMDL + TMSL fixtures |
| **Estimated runtime** | ~5 minutes (manual only) |

---

## Sampling Rate

- **After every task commit:** Bash smoke test — verify mode-detection block outputs correct header for directory with/without `.SemanticModel/`
- **After every plan wave:** Full manual pass with PBIP test fixtures for all modified skills
- **Before `/gsd:verify-work`:** All manual tests pass

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-P01 | 01 | 0 | INFRA-04 | smoke | `ls tests/fixtures/pbip-tmdl/.SemanticModel 2>/dev/null && echo found || echo none` | ❌ W0 | ⬜ pending |
| 02-P02 | 01 | 0 | INFRA-05 | smoke | `cat tests/fixtures/pbip-tmdl/definition.pbism` | ❌ W0 | ⬜ pending |
| 02-P03 | 02 | 1 | INFRA-03, INFRA-04 | manual | Run `/pbi:comment` without PBIP dir; verify no file-mode header | ❌ W0 | ⬜ pending |
| 02-P04 | 02 | 1 | INFRA-03, INFRA-04 | manual | Run `/pbi:comment` with TMDL fixture; verify "File mode — PBIP project detected (TMDL)" header | ❌ W0 | ⬜ pending |
| 02-P05 | 02 | 1 | INFRA-05 | manual | Run `/pbi:load` with TMDL fixture; verify "Format: TMDL" in summary | ❌ W0 | ⬜ pending |
| 02-P06 | 02 | 1 | INFRA-05 | manual | Run `/pbi:load` with TMSL fixture; verify "Format: TMSL (model.bim)" in summary | ❌ W0 | ⬜ pending |
| 02-P07 | 03 | 2 | INFRA-06 | manual | Confirm Desktop not running; run `/pbi:comment`; verify "Desktop: closed — will write to disk" | ❌ W0 | ⬜ pending |
| 02-P08 | 03 | 2 | INFRA-06 | manual | Simulate Desktop open (run notepad.exe or use actual PBIDesktop); verify "Desktop: open — output is paste-ready" and no file written | ❌ W0 | ⬜ pending |
| 02-P09 | 04 | 3 | DAX-13 | manual | Run `/pbi:comment` with TMDL fixture (Desktop closed); read `.tmdl` file after; verify `///` description and `//` comments present | ❌ W0 | ⬜ pending |
| 02-P10 | 04 | 3 | DAX-13 | manual | Run `/pbi:comment` with TMSL fixture; verify `description` and `expression` updated in `model.bim` JSON | ❌ W0 | ⬜ pending |
| 02-P11 | 04 | 3 | DAX-13 | manual | Paste measure name not in PBIP project; verify "not found — paste-ready for manual addition" message | ❌ W0 | ⬜ pending |
| 02-P12 | 05 | 4 | ERR-03 | manual | Run `/pbi:error` in file mode; verify before/after preview and "Apply this fix? (y/N)" prompt appear | ❌ W0 | ⬜ pending |
| 02-P13 | 05 | 4 | ERR-03 | manual | Respond "y" to confirm; verify file is written with corrected expression and "Written to:" line shown | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/fixtures/pbip-tmdl/.SemanticModel/` — TMDL project wrapper directory
- [ ] `tests/fixtures/pbip-tmdl/definition.pbism` — TMDL format file (version 4.0)
- [ ] `tests/fixtures/pbip-tmdl/definition/tables/Sales.tmdl` — sample TMDL table with at least one measure and `///` description
- [ ] `tests/fixtures/pbip-tmsl/.SemanticModel/` — TMSL project wrapper directory
- [ ] `tests/fixtures/pbip-tmsl/definition.pbism` — TMSL format file (version 1.0)
- [ ] `tests/fixtures/pbip-tmsl/model.bim` — minimal TMSL JSON with one table and one measure (with name, expression, description fields)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Desktop open → no file written | INFRA-06 | Requires a running process to detect | Run actual PBIDesktop.exe or simulate; run `/pbi:comment`; verify paste-ready output only |
| Desktop closed → file write occurs | INFRA-06 | Requires confirming process absence | Confirm PBIDesktop not in tasklist; run command; verify "Written to:" line |
| `/pbi:comment` TMDL write-back | DAX-13 | Requires reading modified file after command | Check `.tmdl` file content post-command |
| `/pbi:comment` TMSL write-back | DAX-13 | Requires JSON inspection post-command | Check `model.bim` JSON for updated description and expression |
| `/pbi:error` preview + confirm flow | ERR-03 | Interactive confirm prompt (y/N) | Manually respond to confirm prompt and verify write outcome |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
