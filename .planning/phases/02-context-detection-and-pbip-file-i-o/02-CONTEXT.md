# Phase 2: Context Detection and PBIP File I/O - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Commands detect whether a PBIP project is present in the working directory and which format it uses (TMSL vs TMDL), enforce a Desktop-open safety guard before any file write, wire up `/pbi:load` to actually read PBIP model files, and enable `/pbi:comment` and `/pbi:error` to write back to PBIP files when Desktop is confirmed closed. Paste-in mode continues to work unchanged for all commands.

</domain>

<decisions>
## Implementation Decisions

### Desktop Safety Guard
- Auto-detect `PBIDesktop.exe` process silently using `tasklist` before any file write — no prompt on the happy path
- If Desktop is running: abort the file write entirely, deliver paste-ready output with a clear note: "Desktop is open — paste manually, then save"
- No `--force` flag — if Desktop is detected as open, paste-ready output is always the result (no override)
- If no PBIP project found in the working directory: silent fallback to paste-in mode — no mention of file mode at all

### pbi-load Experience
- Load full measure list + table structure: all tables with their measure names, column names, and a relationships summary — written into `.pbi-context.md`
- Output a summary table: `| Table | Measures | Columns |` with a conclusion line: "Context loaded — all DAX commands will now use model-aware analysis."
- Include format detection in the summary: "Format: TMDL" or "Format: TMSL (model.bim)"
- If no PBIP project found: respond with "No PBIP project found in this directory. All commands work with pasted DAX — paste a measure into any /pbi command to get started." Helpful, not an error.

### Post-Write Output
- After a successful file write: show the full output (commented DAX + Description Field for `/pbi:comment`, diagnosis + fix for `/pbi:error`) then append a file confirmation line: "Written to: [MeasureName] in [file path]"
- Measure matching: search all TMDL / model.bim files for the exact measure name. If not found: "Measure [Name] not found in PBIP project — output is paste-ready for manual addition." No silent failures.
- Error recovery in file mode: preview the proposed fix (before/after of the affected lines), then ask "Apply this fix? (y/N)" before writing. `/pbi:comment` writes without a confirm prompt; `/pbi:error` requires explicit confirmation.

### Mode Detection Feedback
- Announce file mode only when it is active — when in paste-in mode (no PBIP project), say nothing
- File mode header at the top of output: "File mode — PBIP project detected (TMDL) | Desktop: closed — will write to disk" or "Desktop: open — output is paste-ready"
- Format (TMDL/TMSL) is shown in the file-mode header and in the `pbi-load` summary only — not repeated elsewhere in command output

### Claude's Discretion
- Exact `tasklist` / process-check command and how to handle edge cases (empty output, permission errors)
- TMDL file structure traversal to locate a measure by name (directory path conventions)
- TMSL model.bim JSON path for measure lookup and write-back
- `.pbi-context.md` schema extension to store the loaded model summary (table/measure index)

</decisions>

<specifics>
## Specific Ideas

- Phase 1 established `/pbi:load` as an explicit gate: "run this first when you want model-aware analysis." Phase 2 makes it real — analysts already know the pattern.
- Paste-ready output is never suppressed even in file mode — the analyst always has something they can act on immediately, regardless of whether the file write succeeded.
- `/pbi:error` confirm prompt before writing reflects the higher-risk nature of fix application vs. comment addition.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `pbi-load/SKILL.md` — existing stub with `disable-model-invocation: true`; Phase 2 removes the stub body and wires in real PBIP file reading (Haiku, `allowed-tools: Read, Bash`)
- `pbi-comment/SKILL.md` — full paste-in implementation exists; Phase 2 adds a file-mode branch before Step 1
- `pbi-error/SKILL.md` — full paste-in implementation exists; Phase 2 adds a file-mode branch (with confirm prompt) before context update
- `.pbi-context.md` — created by Phase 1 with `## Last Command`, `## Command History`, `## Analyst-Reported Failures` sections; Phase 2 adds a `## Model Context` section for `pbi-load` output

### Established Patterns
- Haiku for file reading/retrieval (low-cost), Sonnet for reasoning — applies directly to pbi-load (Haiku reads PBIP files, Sonnet not needed)
- Read-then-Write for `.pbi-context.md` updates — applies to pbi-load writing model summary
- Session context injected via bash: `` !`cat .pbi-context.md 2>/dev/null | tail -N` `` — pbi-comment and pbi-error already do this; model context from pbi-load lands in the same file and is thus auto-included
- `disable-model-invocation: true` used in stubs — pbi-load stub uses this; remove it in Phase 2 when wiring real logic

### Integration Points
- `.pbi-context.md` in project root — pbi-load writes a `## Model Context` section here; all DAX commands read it via their session context bash injection (already wired from Phase 1)
- `definition.pbism` — format detection reads this file's version field to route to TMDL vs TMSL path
- `.SemanticModel/` directory — presence check is the PBIP project detection trigger
- `definition/tables/*/measures/*.tmdl` (TMDL) or `model.bim` (TMSL) — write-back targets for comment and error-fix

</code_context>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-context-detection-and-pbip-file-i-o*
*Context gathered: 2026-03-12*
