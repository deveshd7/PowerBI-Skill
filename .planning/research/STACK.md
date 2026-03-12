# Technology Stack

**Project:** PBI Skill — Claude slash-command skill system for Power BI PBIP files
**Researched:** 2026-03-12
**Confidence:** HIGH (Claude skills format verified against official docs; PBIP/TMDL/PBIR verified against Microsoft Learn; DAX Formatter API MEDIUM due to undocumented HTTP endpoint)

---

## How Claude Slash Commands (Skills) Work

This is the most critical piece of infrastructure — understanding this first determines everything else.

### File Format

Claude Code skills are Markdown files with YAML frontmatter. There are two equivalent homes:

| Path | Scope |
|------|-------|
| `.claude/commands/pbi.md` | Project-scoped (legacy format, fully supported) |
| `.claude/skills/pbi/SKILL.md` | Project-scoped (new format, recommended) |

Both are identical in capability. The `skills/` directory format adds an optional directory for supporting files (templates, scripts, reference docs). The `commands/` format is simpler for single-file skills. **Use `commands/` for simple routing skills and `skills/` for complex skills with supporting files.**

Commit `.claude/commands/` and `.claude/skills/` to the repo so all team members get the skills.

### Frontmatter Fields

```yaml
---
name: pbi                          # becomes /pbi
description: "Power BI analyst assistant. Helps with DAX optimization, model auditing, git workflow, and PBIP file editing."
argument-hint: "[command]"         # shown in autocomplete
disable-model-invocation: true     # require explicit /pbi invocation, never auto-triggered
allowed-tools:                     # tools available without per-use approval
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---
```

Key fields for this project:

- `disable-model-invocation: true` — Mandatory for all `/pbi:*` commands. These are analyst-triggered workflows, never auto-invoked.
- `allowed-tools` — Whitelist `Bash` for git operations. Do not over-restrict; analysts will notice permission prompts.
- `argument-hint` — Show what sub-commands are available.

### Sub-Command Pattern (Like GSD)

GSD uses a naming convention where files become `namespace:command` paths:

```
.claude/commands/pbi/               # creates /pbi namespace
├── pbi.md                          # bare /pbi — routing command
├── optimize.md                     # /pbi:optimize
├── explain.md                      # /pbi:explain
├── format.md                       # /pbi:format
├── comment.md                      # /pbi:comment
├── audit.md                        # /pbi:audit
├── commit.md                       # /pbi:commit
├── diff.md                         # /pbi:diff
└── edit.md                         # /pbi:edit
```

Each file = one skill. The bare `/pbi` acts as a router that asks what the analyst wants and delegates. All sub-commands also work directly.

### Variable Substitutions

Inside skill content, use:
- `$ARGUMENTS` — everything typed after the command
- `$ARGUMENTS[0]`, `$0` — first argument
- `!`bash command`` — runs shell before Claude sees the prompt (inject dynamic context)

Example for `/pbi:diff`:
```yaml
---
name: pbi:diff
---
Show what changed since the last commit in this PBIP repo.

Git log context:
!`git log --oneline -10`

Git diff summary:
!`git diff HEAD --stat`
```

### Skill Directory for Complex Skills

For `/pbi:audit` and `/pbi:edit` which need reference material:

```
.claude/skills/pbi-audit/
├── SKILL.md              # main instructions
├── best-practices.md     # DAX/model best practice rules reference
└── patterns.md           # what bad patterns look like
```

Reference supporting files from SKILL.md using relative links.

**Confidence:** HIGH — verified against official Claude Code docs at code.claude.ai/docs/en/skills (updated March 2026)

---

## PBIP File Format

PBIP is a folder-based project format. Understanding the structure is required before reading or writing any files.

### Top-Level Structure

```
MyReport/
├── MyReport.Report/            # Report definition
├── MyReport.SemanticModel/     # Semantic model (tables, measures, relationships)
├── MyReport.pbip               # Shortcut pointer (optional for Git workflows)
└── .gitignore                  # Auto-generated; ignores cache.abf and localSettings.json
```

### SemanticModel Folder

Two formats exist. TMDL is the current standard (GA as of 2024, default from March 2026).

**TMSL format (legacy, single file):**
```
MyReport.SemanticModel/
├── model.bim                   # Full model as one JSON file (TMSL/JSON)
├── definition.pbism            # Required pointer; version 1.0 = TMSL only
└── .pbi/
    └── localSettings.json      # User-local, git-ignored
```

**TMDL format (current standard, separate files per table):**
```
MyReport.SemanticModel/
├── definition/                 # Required for TMDL; replaces model.bim
│   ├── database.tmdl           # Database-level properties
│   ├── model.tmdl              # Model settings, culture
│   ├── relationships.tmdl      # All relationships
│   ├── expressions.tmdl        # Parameters / named expressions (M queries)
│   ├── dataSources.tmdl        # Data source connections
│   ├── tables/
│   │   ├── Sales.tmdl          # One file per table — includes measures!
│   │   ├── Calendar.tmdl
│   │   ├── Customer.tmdl
│   │   └── Product.tmdl
│   ├── roles/
│   │   └── RoleName.tmdl
│   └── cultures/
│       └── en-US.tmdl
├── definition.pbism            # Required; version 4.0+ = TMDL supported
└── .pbi/
    ├── localSettings.json      # Git-ignored
    └── cache.abf               # Git-ignored; local data cache
```

### Where Measures Live

**This is the most important detail for this project.**

In TMDL, measures live inside their parent table's `.tmdl` file. There are no separate measure files — each table file contains all columns, measures, and partitions for that table.

Example `tables/Sales.tmdl`:
```tmdl
table Sales

    measure 'Sales Amount' = SUMX('Sales', [Quantity] * [Net Price])
        formatString: $ #,##0
        description: "Total revenue for the period"

    measure 'Sales YTD' =
            TOTALYTD([Sales Amount], 'Calendar'[Date])
        formatString: $ #,##0

    column 'Product Key'
        dataType: int64
        isHidden
        sourceColumn: ProductKey
```

To read all measures: glob `**/*.tmdl`, grep for `    measure ` (4-space indent).

In `model.bim` (TMSL format), measures are nested JSON under `model.tables[].measures[]`.

### Report Folder (PBIR vs PBIR-Legacy)

**PBIR-Legacy (single file, not externally editable):**
```
MyReport.Report/
├── report.json                 # Monolithic report JSON — DO NOT EDIT EXTERNALLY
└── definition.pbir             # Pointer file
```

**PBIR (new format, externally editable — becoming default March 2026):**
```
MyReport.Report/
├── definition/
│   ├── report.json             # Report-level filters, theme
│   ├── version.json            # Format version
│   ├── reportExtensions.json   # Report-level measures
│   └── pages/
│       └── [pageName]/
│           ├── page.json       # Page metadata and filters
│           └── visuals/
│               └── [visualName]/
│                   └── visual.json   # Visual config, query, formatting
└── definition.pbir
```

For the `/pbi:edit` command, target TMDL files (measures/tables) — these are the safe, publicly documented edit targets. PBIR visual files are also editable. The old `report.json` (PBIR-Legacy) explicitly does not support external editing.

**Confidence:** HIGH — verified against Microsoft Learn (updated 2025-12-15)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Claude Skills (SKILL.md / commands/) | Current | Slash-command routing and AI logic | The system itself — every `/pbi:*` command is a Markdown skill file, no build step, no runtime dependencies |
| Bash (via Claude's Bash tool) | Git for Windows bundled | Git operations, file discovery, diff generation | Already available in the Claude Code environment; no install needed on Windows |
| Node.js / JavaScript | 20 LTS | Helper scripts (DAX API calls, JSON transforms) | Already required by the GSD toolchain; available on the machine |
| Git | 2.43+ | Version control for PBIP repos | PBIP was designed for git; all `/pbi:commit` and `/pbi:diff` operations use git CLI directly |

### DAX Formatting

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| DAX Formatter HTTP API (SQLBI) | N/A (web service) | Format/prettify DAX expressions | Industry standard; same engine used by DAX Studio, Tabular Editor, Fabric Copilot; free; no install |
| Claude inline formatting (fallback) | N/A | Format DAX when offline or API unavailable | Zero-dependency fallback; sufficient for most cases |

DAX Formatter endpoint is `https://www.daxformatter.com` with a POST API. The request body sends the raw DAX expression; the response returns formatted DAX. The SQLBI NuGet package (`Dax.Formatter 1.2.0`) wraps this API for .NET callers, but for this project a simple `curl` or `fetch()` from Node.js is sufficient.

```bash
# Minimal curl call pattern (exact schema from GitHub/DaxFormatter source)
curl -X POST https://www.daxformatter.com/api/daxformatter/DaxText \
  -H "Content-Type: application/json" \
  -d '{"Dax":"CALCULATE(SUM(Sales[Amount]),FILTER(Sales,Sales[Region]=\"West\"))","ListSeparator":",","DecimalSeparator":"."}'
```

Because the HTTP API does not require authentication and the endpoint is stable (used by the entire Power BI ecosystem), this is LOW risk. If the API is unavailable, Claude can apply formatting rules directly — DAX formatting rules are well-documented and consistent.

**Confidence:** MEDIUM — API existence and usage confirmed; exact endpoint path from source code inspection is uncertain, should be verified empirically at project start.

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `simple-git` (npm) | 3.x | Programmatic git operations | Only if Bash-based git calls become insufficient; not needed for v1 |
| `@microsoft/vscode-jsonrpc` | N/A | NOT needed | Direct JSON.parse() is sufficient for PBIP files |
| Node.js `fs` built-in | built-in | Read/write TMDL and JSON files | All PBIP file I/O — no library needed, files are plain text |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| VS Code + TMDL extension | Edit TMDL files with syntax highlighting | Install `analysis-services.TMDL` from VS Code marketplace |
| VS Code + Power BI PBIP schemas | JSON validation for report files | Schemas at `github.com/microsoft/json-schemas/tree/main/fabric` |
| Git for Windows | All git operations | Use bash syntax; configure `core.autocrlf=true` for Windows |

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Bash tool for git operations | `simple-git` npm package | Only if complex git workflows require programmatic branching or merge logic (not needed for v1) |
| Claude inline DAX formatting (fallback) | Tabular Editor CLI (`te3 -S -F`) | If offline formatting quality becomes a user complaint; TE3 is free but requires .NET install on Windows |
| TMDL parsing via string manipulation (grep/regex) | TOM/AMO .NET library | If you need to write back complex model changes; for v1 read-only parsing is sufficient |
| Project-scoped `.claude/commands/pbi/` | Global `~/.claude/commands/pbi/` | Use global only if the analyst works on multiple PBIP repos and wants the skill everywhere |
| PBIR format (new default) | PBIR-Legacy (report.json) | PBIR-Legacy if working on reports created before March 2026; always detect format before editing |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `report.json` (PBIR-Legacy) for external editing | Microsoft explicitly states this file does not support external editing; changes will be lost or cause errors | PBIR `definition/` folder files for new projects; TMDL files for model/measures |
| `diagramLayout.json` editing | Not supported during preview; changes silently lost | Leave untouched; not needed for DAX/measure work |
| `.pbi/cache.abf` | Binary file; git-ignored by design; not human-readable | Read model definition from TMDL or model.bim instead |
| Python for DAX parsing | No mature Python DAX parser exists; regex approaches break on complex DAX | Use Claude's language understanding + DAX Formatter API for formatting |
| Regex to parse TMDL measures | TMDL indentation rules are strict but multiline measures span many lines — regex fails on complex expressions | Use Claude to read and interpret TMDL content; use glob+read for discovery |
| Power BI REST API / Service API | Out of scope for v1; requires Azure AD auth, Service connection, published dataset | Desktop/file-first approach as stated in PROJECT.md |
| `model.bim` when TMDL is available | model.bim is one large JSON file; harder to parse and diff than per-table TMDL files | Use TMDL `tables/*.tmdl` files for measure access |

---

## Stack Patterns by Variant

**If the PBIP uses TMDL format (version 4.0+, `definition/` folder exists):**
- Read measures from `SemanticModel/definition/tables/*.tmdl`
- Each table file contains all measures for that table
- Detect with: `test -d "*.SemanticModel/definition"` or check `definition.pbism` version property
- TMDL is the standard for all new projects from 2024 onward

**If the PBIP uses TMSL format (version 1.0, `model.bim` exists):**
- Read measures from `SemanticModel/model.bim` (JSON path: `model.tables[].measures[]`)
- Suggest analyst upgrade to TMDL (Power BI Desktop will prompt on next save)
- Still fully readable; just less ergonomic for diffs

**If the report uses PBIR (definition/ folder in Report folder):**
- Report-level measures live in `Report/definition/reportExtensions.json`
- Page metadata in `Report/definition/pages/[name]/page.json`
- Fully editable externally with schema validation

**If the report uses PBIR-Legacy (report.json):**
- Do not attempt to edit report.json — unsupported
- Only model-layer changes (TMDL files) are safe for external editing
- Inform analyst that report visual layer requires Power BI Desktop

**If Power BI Desktop is open:**
- Any file edits require Desktop restart to take effect
- For paste-in workflow: Claude outputs formatted DAX, analyst pastes into Desktop
- Detect "Desktop likely open" heuristic: check if `cache.abf` exists and is recently modified

**If running git operations on Windows:**
- Use `git` CLI via Bash tool (Git for Windows is always available in PBIP repos)
- PBIP uses CRLF line endings (Power BI Desktop saves with CRLF)
- Configure: `git config core.autocrlf true` — Power BI Desktop creates `.gitignore` with standard entries
- Avoid `\r\n` issues in diff output by piping through `tr -d '\r'` if needed

---

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| TMDL format | PBIP definition.pbism version 4.0+ | Older projects use version 1.0 (TMSL only); check before reading |
| PBIR format | PBIP report definition.pbir version 4.0+ | PBIR-Legacy uses version 1.0; becoming default March 2026 |
| Claude skills `SKILL.md` format | Claude Code current | `.claude/commands/*.md` legacy format also supported; identical capabilities |
| `disable-model-invocation` frontmatter | Claude Code current | Required for analyst-triggered commands; prevents unexpected auto-invocations |
| DAX Formatter API | Stable web service | No versioning exposed; SQLBI maintains backward compatibility |
| Git for Windows | 2.x+ | CRLF handling via `core.autocrlf=true`; set in project `.gitattributes` |

---

## PBIP File Reading Cheat Sheet

For each `/pbi:*` command, here is what to read:

| Command | Files to Read | Notes |
|---------|--------------|-------|
| `/pbi:optimize`, `/pbi:explain`, `/pbi:format`, `/pbi:comment` | `**/*.tmdl` files (grep for `measure`) OR pasted DAX | Detect mode: file path present vs raw paste |
| `/pbi:audit` | All `*.tmdl` files + `definition.pbism` + `relationships.tmdl` | Need full model picture |
| `/pbi:commit` | `git diff HEAD --stat`, `git diff HEAD -- *.tmdl` | Summarise what changed semantically |
| `/pbi:diff` | `git log --oneline`, `git diff <rev1>..<rev2> -- *.tmdl` | Human-readable summary of DAX/model changes |
| `/pbi:edit` | Specific table `.tmdl` file | Read → modify → write back; warn about Desktop restart |

---

## Installation

No npm packages to install for v1. The entire skill system runs on:

```bash
# Verify git is available (always true in a PBIP repo on Windows)
git --version

# Verify Node.js is available (required for DAX Formatter API calls)
node --version

# No other dependencies for v1
```

For the DAX Formatter API, use Node.js `fetch()` (native since Node 18) or curl via Bash. No npm package needed.

---

## Sources

- [Claude Code Skills documentation](https://code.claude.ai/docs/en/skills) — skill file format, frontmatter reference, invocation control (verified March 2026, HIGH confidence)
- [Power BI Desktop projects overview](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview) — PBIP structure, file roles, external editing rules (updated 2025-12-15, HIGH confidence)
- [Power BI Desktop project semantic model folder](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset) — TMDL vs TMSL formats, model.bim vs definition/ folder (updated 2026-01-20, HIGH confidence)
- [Power BI Desktop project report folder](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report) — PBIR vs PBIR-Legacy, report.json editorial restrictions (updated 2026-01-12, HIGH confidence)
- [TMDL overview](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview?view=sql-analysis-services-2025) — full TMDL syntax, measure format, folder structure (updated 2026-02-02, HIGH confidence)
- [DAX Formatter by SQLBI](https://www.daxformatter.com/) — formatting service, API existence confirmed (MEDIUM confidence — exact endpoint path unverified)
- [GitHub: sql-bi/DaxFormatter](https://github.com/sql-bi/DaxFormatter) — .NET client library; HTTP API wrapper (MEDIUM confidence)
- [GSD command file format](C:/Users/DeveshD/.claude/commands/gsd/new-project.md) — frontmatter structure, `@`-file includes, `$ARGUMENTS` pattern (LOCAL, HIGH confidence)

---

*Stack research for: PBI Skill — Claude slash-command system for Power BI PBIP files*
*Researched: 2026-03-12*
