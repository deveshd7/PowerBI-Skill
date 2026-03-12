# Phase 3: Model-Wide Audit - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

A single `/pbi:audit` command scans a PBIP project and produces a complete, severity-graded (CRITICAL / WARN / INFO) model health report across four domains: naming conventions, relationship health, date table configuration, and measure quality. No auto-fix in this phase — audit is read-only. Adding new audit categories or auto-fix belongs in a future phase.

</domain>

<decisions>
## Implementation Decisions

### Report Structure
- Severity-first layout: all CRITICALs grouped together, then WARNs, then INFOs — analyst sees worst problems first regardless of domain
- Each finding is tagged with its domain in brackets: `[Relationships]`, `[Naming]`, `[Date Table]`, `[Measures]`
- Every finding includes: specific table/measure name (never a JSON path) + one-line concrete recommendation

### Report Destination
- Both inline (printed in chat) and written to file
- File written to `audit-report.md` in the project root
- Inline shows the full report — no summary-only truncation

### Finding Severity for Naming
- Naming issues are always WARN or INFO — never CRITICAL (naming doesn't break the model, only hurts maintainability)
- Blank/missing names or names with special characters → WARN
- Style inconsistencies → INFO

### Naming Convention Rules
- Infer conventions from the model itself: scan existing names, detect the dominant pattern, flag deviations
- No hardcoded standard — works for any team's naming style
- Covers all four scopes: measure names, table names, column names, display folders (measures with no display folder flagged)

### Chunking and Progress
- All four domain passes run silently; analyst sees one final combined severity-sorted report
- Single progress line before report appears: "Auditing 4 domains..." — then the report
- No domain-by-domain streaming output

### Audit Scope
- Always runs all four domains — no domain flags in v1
- Simple and predictable: `/pbi:audit` with no arguments runs everything
- If run outside a PBIP project: clear error and stop — "No PBIP project found in this directory. Run /pbi:audit from a directory containing .SemanticModel/." No file written, no partial output.

### Claude's Discretion
- Exact inferred naming pattern detection algorithm (how dominant pattern is identified)
- Severity thresholds within WARN vs INFO for specific naming cases
- How to handle TMSL vs TMDL structural differences when reading model metadata
- `audit-report.md` exact header/footer formatting

</decisions>

<specifics>
## Specific Ideas

- The test fixtures from Phase 2 already include a bidirectional relationship (Sales→Customer) and a measure with no description (Revenue) — the audit should flag both when run against those fixtures
- Severity emoji used in report: 🔴 CRITICAL, 🟡 WARN, 🔵 INFO (matching the format the user confirmed during discussion)

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.claude/skills/pbi-load/SKILL.md`: PBIP detection bash blocks (PBIP_MODE, PBIP_FORMAT) and file index — audit uses the same startup detection pattern
- `tests/fixtures/pbip-tmdl/` and `tests/fixtures/pbip-tmsl/`: Both fixtures are ready for audit testing; TMDL fixture has bidirectional relationship + measure missing description; TMSL fixture has same
- `.pbi-context.md` session context injection pattern: established in Phase 1/2 — audit reads it at startup

### Established Patterns
- PBIP detection: check `.SemanticModel/` existence, read `definition.pbism` version to distinguish TMDL vs TMSL
- File reads: Read tool (not bash cat) for all PBIP files
- Session context: tail -80 of `.pbi-context.md` injected at startup; updated after execution
- Desktop check: not needed for audit (read-only, no writes) — can skip `tasklist` safety guard

### Integration Points
- Audit skill lives in `.claude/skills/pbi-audit/SKILL.md`
- Reads `.SemanticModel/definition/` (TMDL) or `.SemanticModel/model.bim` (TMSL) for model data
- Writes `audit-report.md` to project root and updates `.pbi-context.md` after run

</code_context>

<deferred>
## Deferred Ideas

- Auto-fix mode — apply CRITICAL and WARN fixes directly after audit with one confirmation (AUD-V2-02 in requirements backlog)
- Domain-specific flags (`--relationships`, `--naming`) — v2 if models get large enough to need it
- Hidden column hygiene check (AUD-V2-01) — not in v1 scope

</deferred>

---

*Phase: 03-model-wide-audit*
*Context gathered: 2026-03-12*
