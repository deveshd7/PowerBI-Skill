# Codebase Concerns

**Analysis Date:** 2026-03-13

## Session Context Race Condition

**Issue:** Simultaneous skill invocations can overwrite each other's `.pbi-context.md` updates.
- Files: `.pbi-context.md`, all commands use Read-then-Write pattern
- Impact: In concurrent scenarios (multiple Claude Code instances), command history entries may be lost or corrupted. Last Command tracking becomes unreliable under parallel execution.
- Current mitigation: Documented as "not an issue in interactive use" but no locking mechanism exists
- Recommendations: Implement file-level locking (flock) or add a timestamp-based conflict resolution when reading stale context. Add a conflict detection check that warns if context was modified since last read.

## Audit Parallelism Overhead

**Issue:** Audit command spawns parallel agents for models with 5+ tables, but threshold is arbitrary.
- Files: `.claude/skills/pbi/commands/audit.md`
- Problem: No metrics on when parallelism becomes cost-efficient. Spawning 3 agents for 5 tables may be overkill; spawning for smaller models wastes tokens. No adaptive scaling.
- Scaling path: Add heuristic based on table count and measure complexity. Consider token cost vs speedup trade-off. Provide user-configurable threshold in context or skill options.

## Path Quoting Dependency

**Issue:** All bash paths must be manually double-quoted in every command file. No centralization.
- Files: All 14 command files in `.claude/skills/pbi/commands/`
- Risk: Easy to miss a quote. Spaces in directory names will break path handling silently. Currently scattered across multiple files with manual enforcement.
- Safe modification: Extract a helper bash function (e.g., `quote_path()`) in SKILL.md detection block or create a shared bash library. Alternatively, use `printf %q` to auto-quote paths.

## TMDL Tab-to-Space Conversion Risk

**Issue:** TMDL files use tabs for indentation; must never convert to spaces when writing back.
- Files: `.claude/skills/pbi/commands/edit.md`, `comment.md`, `comment-batch.md` (write TMDL)
- Risk: If any write operation uses `jq` or text replacements without preserving tabs, TMDL formatting breaks. Power BI's TMDL parser is sensitive to indentation.
- Safe modification: Use a post-write validation step: `diff <(cat original.tmdl | od -c) <(cat written.tmdl | od -c)` to confirm tab preservation. Add a comment in every command that writes TMDL reminding developers of this constraint.

## DAX Formatter API Dependency — Graceful Degradation Unclear

**Issue:** DAX Formatter API is a hard external dependency with fallback behavior not fully tested.
- Files: `.claude/skills/pbi/commands/format.md`
- Behavior: If API is unreachable, falls back to Claude inline formatting. Fallback is not documented as a tested path.
- Impact: User sees different formatting output if API fails. No warning that fallback is active. Silent degradation.
- Recommendations: Add explicit user notification when fallback is triggered. Log API probe result to session context. Add a health check command that validates API reachability upfront. Consider caching API status across invocations.

## Measure Name grep with Fixed-String Matching

**Issue:** Grep for measure names uses `-rlF` (fixed-string) to avoid metacharacter breakage, but this assumes measure names don't appear in comments.
- Files: All commands that update measures (edit.md, comment.md, comment-batch.md)
- Risk: If a user has a measure named `[Old Name]` and comments referencing `[Old Name]` in a different measure, the search will match both. No way to target only the measure definition.
- Fragile because: Measure names in DAX can contain special regex characters (brackets, parentheses). Fixed-string grep prevents regex breakage but introduces false positives in files with multiple measures.
- Safe modification: Use context-aware grep: search for the pattern `^[[:space:]]*"[MeasureName]"[[:space:]]*:` in TMDL to anchor to measure definition lines only.

## Auto-Commit Without Explicit User Consent

**Issue:** Four commands auto-commit after successful writes: `edit`, `comment`, `error`, `new`.
- Files: `.claude/skills/pbi/commands/edit.md`, `comment.md`, `error.md`, `new.md`
- Impact: User may not expect a git commit after running `/pbi comment`. Commits happen silently without confirmation. If the user hasn't reviewed the changes, they're already staged.
- Risk: Incomplete or incorrect changes could be committed before manual review. No undo UI guidance upfront.
- Recommendations: Add a pre-commit confirmation step or make auto-commit optional (skill option). Always prompt user to review diff before auto-committing. Make `/pbi undo` more discoverable in output.

## Empty Model Handling

**Issue:** Commands assume `.SemanticModel/` exists and contains at least one table; behavior on empty models not documented.
- Files: `.claude/skills/pbi/commands/load.md`, `audit.md`, `edit.md`
- Risk: If user runs audit on an empty model, agent may crash or return misleading results (no tables to audit = silent success).
- Recommendations: Add explicit empty model checks early in load.md. Output a warning: "Model has no tables — some audit checks will be skipped." Return gracefully with limited context.

## Session Context Size Unbounded Before Trim

**Issue:** Command History is limited to 20 rows after each write, but intermediate processing reads the entire `.pbi-context.md` file.
- Files: All commands that read/write `.pbi-context.md`
- Impact: On very old projects with hundreds of prior invocations, initial context read could be slow. No pagination or lazy loading.
- Scaling path: Add a `tail -n 100` to the initial read in SKILL.md detection block to cap initial context size. Trim earlier (10 rows) for faster processing.

## Model Selection Model Dispatch Not Observable

**Issue:** Router dispatches Sonnet for DAX reasoning and Haiku for file/git ops, but no transparency about which model executed or why.
- Files: `.claude/skills/pbi/SKILL.md` routing logic
- Impact: User cannot easily debug or understand model selection rationale. If a Haiku Agent fails on a complex task, user doesn't know why Sonnet wasn't used.
- Recommendations: Log model selection rationale to session context. Add a verbose flag or debug mode that outputs "Using haiku Agent for file/git-heavy command" before spawning.

## Desktop Detection Removed Without Replacement

**Issue:** Desktop detection (`tasklist` check) was removed in v3.0, but no equivalent fallback exists for non-PBIP scenarios.
- Files: Historical removal noted in CLAUDE.md; current code has no safety net
- Impact: File-mode commands always assume they can write to disk. If user is on a read-only filesystem or in a sandboxed environment, writes will fail with cryptic errors.
- Recommendations: Add a pre-flight test write to a temp file in the first command execution. Fail gracefully with user-facing message if filesystem is read-only.

## Definition/Tables Directory May Not Exist in TMDL Mode

**Issue:** File Index detection assumes `definition/tables/` exists for TMDL projects, but doesn't validate.
- Files: `.claude/skills/pbi/SKILL.md` detection block line 16
- Risk: If a project is declared TMDL format but directory structure is incomplete, all downstream commands fail.
- Safe modification: Validate directory structure in load.md. Return early with clear error: "TMDL directory structure incomplete — expected `.SemanticModel/definition/tables/`".

## Analyst-Reported Failures Section Protected But Not Validated

**Issue:** Commands never modify Analyst-Reported Failures, but no validation ensures the section exists or is well-formed.
- Files: `.pbi-context.md` structure
- Risk: If user manually deletes this section, all subsequent reads fail or ignore it silently. No schema validation.
- Recommendations: Add a schema check in load.md. If Analyst-Reported Failures section is missing, recreate it with a header and empty state.

## No Integration Test for Session Context Trim Logic

**Issue:** Command History is trimmed to 20 rows in-place, but no test covers edge cases (exactly 20 rows, 21 rows, 5 rows).
- Files: Test fixture `tests/fixtures/context-20-rows.md` exists but test invocation not found
- Risk: Trim logic could silently fail under boundary conditions. Users' early commands lost without warning.
- Priority: Medium — affects reliability of session continuity.

## PBIR Visual Audit Scope Unclear

**Issue:** Audit includes PBIR visual layer audit but no specification of what issues are checked.
- Files: `.claude/skills/pbi/commands/audit.md` mentions "PBIR visual layer" but details absent
- Impact: Users don't know what will be audited. Output may be incomplete or inconsistent across model sizes.
- Recommendations: Document PBIR audit scope (e.g., "Checks for orphaned visuals, invalid measure references, unused query groups"). Add this to skill README or in audit output header.

## Error Diagnosis Correlates With "Last Command" But Last Command May Be Stale

**Issue:** `/pbi error` correlates user's error message with "Last Command" from session context, but no validation that the context is current.
- Files: `.claude/skills/pbi/commands/error.md`
- Risk: If user runs `/pbi explain`, then manually edits the measure in Power BI, then runs `/pbi error`, the error diagnosis uses stale measure context.
- Recommendations: Add a timestamp check: "Last command was X minutes ago — context may be stale. Run `/pbi load` to refresh." Provide a refresh hint.

---

*Concerns audit: 2026-03-13*
