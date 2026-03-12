# Architecture Research

**Domain:** Claude skill system for Power BI PBIP analyst tooling
**Researched:** 2026-03-12
**Confidence:** HIGH (skill system architecture verified against official Claude Code docs; PBIP file format verified against Microsoft Learn official docs)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    INVOCATION LAYER                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  /pbi        │  │ /pbi:optimize│  │ /pbi:audit  (etc.)   │  │
│  │ (bare router)│  │ (direct cmd) │  │                      │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                 │                      │              │
├─────────┴─────────────────┴──────────────────────┴──────────────┤
│                    CONTEXT DETECTION LAYER                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Mode: PBIP file access  OR  Paste-in (no file access)     │  │
│  │  "Is .SemanticModel/ present in cwd?"                      │  │
│  └────────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    CORE COMMAND LAYER                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │
│  │ DAX cmds │ │Model cmds│ │Git cmds  │ │Edit cmds         │   │
│  │ optimize │ │ audit    │ │ commit   │ │ edit             │   │
│  │ explain  │ │          │ │ diff     │ │                  │   │
│  │ format   │ │          │ │          │ │                  │   │
│  │ comment  │ │          │ │          │ │                  │   │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────────┬─────────┘   │
│       │            │            │                 │              │
├───────┴────────────┴────────────┴─────────────────┴──────────────┤
│                    FILE SYSTEM LAYER                             │
│  ┌───────────────────────────┐  ┌───────────────────────────┐    │
│  │  SemanticModel/           │  │  Report/                  │    │
│  │  ├─ model.bim (TMSL)      │  │  ├─ definition.pbir       │    │
│  │  │  OR                    │  │  ├─ definition/ (PBIR)    │    │
│  │  ├─ definition/ (TMDL)   │  │  │  ├─ pages/             │    │
│  │  ├─ definition.pbism      │  │  │  ├─ bookmarks/         │    │
│  │  └─ .pbi/                 │  │  │  └─ report.json        │    │
│  └───────────────────────────┘  └───────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `/pbi` bare router | Ask what the analyst wants; route to the right subcommand | `SKILL.md` with routing logic, mirrors GSD `/gsd:help` pattern |
| `/pbi:optimize` | Receive DAX (file or paste), detect slow patterns, rewrite | Skill with DAX knowledge in SKILL.md |
| `/pbi:explain` | Produce plain-English explanation of DAX | Skill with DAX knowledge |
| `/pbi:format` | Prettify DAX (indentation, caps, line breaks) | Skill with DAX formatting rules |
| `/pbi:comment` | Add inline `//` comments + populate `description` field | Skill; in PBIP mode also writes model.bim/TMDL |
| `/pbi:audit` | Read model files, check naming, relationships, dates, hidden cols | Skill with Read + Grep + Bash tools |
| `/pbi:commit` | Stage PBIP changes, generate human-readable commit message | Skill with Bash (git) tool; reads git diff |
| `/pbi:diff` | Parse git diff of PBIP files, produce plain English changelog | Skill with Bash (git diff) + JSON parsing |
| `/pbi:edit` | Read and write PBIP JSON files directly | Skill with Read + Write + Edit tools |
| Context detector | Determine file mode vs paste-in mode at command start | Inline logic in each command checking for `.SemanticModel/` |

## Recommended Project Structure

```
C:/Users/DeveshD/Documents/PBI-SKILL/
├── .claude/
│   └── skills/
│       └── pbi/
│           ├── SKILL.md              # Bare /pbi router entry point
│           ├── commands/
│           │   ├── optimize.md       # DAX rewrite logic
│           │   ├── explain.md        # Plain-English explanation
│           │   ├── format.md         # DAX prettifier
│           │   ├── comment.md        # Inline comments + description
│           │   ├── audit.md          # Full model audit
│           │   ├── commit.md         # Git commit workflow
│           │   ├── diff.md           # Git diff → plain English
│           │   └── edit.md           # Direct PBIP file editing
│           ├── knowledge/
│           │   ├── dax-patterns.md   # DAX anti-patterns reference
│           │   ├── audit-rules.md    # Model health rules
│           │   └── pbip-schema.md    # PBIP JSON path reference
│           └── scripts/
│               └── detect-context.sh # PBIP presence check
├── .planning/
│   ├── PROJECT.md
│   ├── config.json
│   ├── research/
│   │   └── ARCHITECTURE.md (this file)
│   ├── REQUIREMENTS.md
│   └── ROADMAP.md
```

### Structure Rationale

- **.claude/skills/pbi/**: Single skill directory; `SKILL.md` at root creates `/pbi` bare command; subcommands live in `commands/` as referenced files loaded by each command.
- **knowledge/**: Supporting reference files loaded into context only when needed. Keeps `SKILL.md` under 500 lines per the skills spec. `dax-patterns.md` loaded by optimize/audit; `audit-rules.md` loaded by audit; `pbip-schema.md` loaded by edit/comment/audit.
- **commands/*.md**: Each becomes a logical subcommand referenced from the root SKILL.md via the `/pbi:name` naming convention (directory name becomes the colon-prefixed subcommand).
- **scripts/**: Bash helpers executed via `!` dynamic context injection, not loaded as text.

## Architectural Patterns

### Pattern 1: Colon-Namespaced Subcommands

**What:** Place individual command files in `.claude/skills/pbi/commands/` and name each skill `pbi:optimize`, `pbi:explain`, etc., via the `name` field in frontmatter. The root `pbi` skill handles bare invocation only.

**When to use:** Always — this is the canonical Claude Code skill architecture for multi-command suites. It matches the GSD pattern exactly: `/gsd` for routing, `/gsd:plan-phase` for direct action.

**Trade-offs:** Each command is independent, can have its own `allowed-tools` and `disable-model-invocation` flags. No coupling between commands. The cost is more files, but each stays focused.

**Example frontmatter for `/pbi:optimize`:**
```yaml
---
name: pbi:optimize
description: Rewrite DAX measure for performance. Use when asked to optimize, speed up, or fix slow DAX.
argument-hint: "[measure name or paste DAX]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---
```

### Pattern 2: Two-Mode Context Detection

**What:** Every command starts by checking whether a `.SemanticModel/` folder exists in the working directory (or any parent within the project root). Branch on that result.

**When to use:** Every command that touches DAX or model content. The analyst may or may not have a PBIP project open.

**Trade-offs:** Adds a short preamble to every command. Avoids silent failures when the analyst pastes DAX but no PBIP exists.

**Example preamble in a command SKILL.md:**
```markdown
## Step 1: Detect context

Check for PBIP presence:
!`find . -name "definition.pbism" -maxdepth 4 2>/dev/null | head -1`

If a path is returned → PBIP mode: read model files, offer to write back.
If empty → Paste-in mode: work with what the analyst provides, output
formatted DAX for manual copy-paste.
```

### Pattern 3: Supporting Knowledge Files (Late-Loaded Reference)

**What:** Heavy reference content (DAX anti-pattern library, audit rule catalogue, PBIP JSON path cheatsheet) lives in `knowledge/*.md`. Commands reference these files explicitly: "For optimization patterns, see [dax-patterns.md](../knowledge/dax-patterns.md)." Claude only loads them when the command is active, not globally.

**When to use:** Any reference content over ~200 lines. Keeps the primary SKILL.md fast to load and focused on instructions.

**Trade-offs:** Requires explicit references so Claude knows to load the file. Slightly more setup, but prevents blowing the skills character budget (default: 2% of context window).

## Data Flow

### DAX Command Flow (e.g., `/pbi:optimize`)

```
Analyst invokes /pbi:optimize [measure or file reference]
    |
    v
Context detection: PBIP present? YES / NO
    |                               |
    v                               v
PBIP mode:                    Paste-in mode:
Read model.bim or             Work from analyst's
definition/ folder            pasted DAX expression
    |                               |
    +----------+--------------------+
               |
               v
Load DAX knowledge (dax-patterns.md)
               |
               v
Analyse: detect slow patterns
(FILTER on large table, row context leakage,
 CALCULATE iterator misuse, unnecessary SUMX)
               |
               v
Produce rewritten DAX + explanation of changes
               |
    +----------+--------------------+
    |                               |
    v                               v
PBIP mode:                    Paste-in mode:
Offer to write back to         Output formatted DAX
model file (Edit tool)        for manual copy-paste
(requires Desktop closed)
```

### Audit Flow (`/pbi:audit`)

```
/pbi:audit invoked
    |
    v
Locate .SemanticModel/ → read model.bim or definition/ folder
    |
    v
Parse all tables → columns → measures → relationships
    |
    v
Load audit-rules.md
    |
    v
Run checks in parallel (conceptually):
  - Naming conventions (PascalCase measures, no spaces in table names)
  - Bi-directional relationships (flag each one)
  - Missing date/calendar table
  - Hidden column hygiene (unused columns still visible)
  - Measure quality (blank formatString, empty description, nested CALCULATE)
    |
    v
Produce structured audit report: severity (CRITICAL / WARN / INFO), location,
recommendation
```

### Git Command Flow (`/pbi:commit`)

```
/pbi:commit invoked
    |
    v
!`git diff --staged --stat` + !`git diff HEAD -- "*.bim" "*.tmdl" "*.json"`
    |
    v
Parse diff: what tables/measures/columns changed?
(model.bim: traverse tables[].measures[], tables[].columns[]
 TMDL definition/: file names map directly to objects)
    |
    v
Generate human-readable summary:
  "Added measure [Total Revenue] to Sales table
   Modified measure [Gross Margin %]: expression changed
   Added column [Category Code] to Products table"
    |
    v
Propose commit message → analyst confirms or edits → Bash git commit
```

### Key Data Flows

1. **DAX in, DAX out (paste-in mode):** Analyst pastes → command processes in context → formatted/rewritten DAX returned as code block for manual copy.
2. **PBIP read-modify-write:** Command reads model file → parses JSON/TMDL → edits specific nodes (measure expression, description) → writes back with Edit tool → analyst restarts Power BI Desktop.
3. **Git diff summarisation:** Bash produces raw JSON diff → command interprets JSON path changes → produces English changelog.

## PBIP File Format Reference

### Project Root Structure

```
MyReport/
├── MyReport.SemanticModel/      # Semantic model (DAX, tables, relationships)
│   ├── definition.pbism         # Required: format version + settings
│   ├── model.bim                # TMSL format (one big JSON file) — OR —
│   ├── definition/              # TMDL format (one file per object)
│   │   ├── database.tmdl
│   │   ├── tables/
│   │   │   ├── Sales.tmdl       # All measures + columns for Sales table
│   │   │   └── Date.tmdl
│   │   └── relationships.tmdl
│   ├── diagramLayout.json       # Read-only during preview
│   └── .pbi/
│       ├── localSettings.json   # Gitignored (user-specific)
│       └── cache.abf            # Gitignored (binary data cache)
├── MyReport.Report/             # Report (pages, visuals, bookmarks)
│   ├── definition.pbir          # Required: format version + semantic model ref
│   ├── report.json              # PBIR-Legacy (single file, no external edit) — OR —
│   ├── definition/              # PBIR format (one file per object)
│   │   ├── report.json          # Report-level filters + theme
│   │   ├── pages/
│   │   │   └── [pageName]/
│   │   │       ├── page.json    # Page filters + formatting
│   │   │       └── visuals/
│   │   │           └── [visualName]/
│   │   │               └── visual.json
│   │   └── bookmarks/
│   └── .pbi/
│       └── localSettings.json   # Gitignored
├── .gitignore                   # Auto-generated by Power BI Desktop
└── MyReport.pbip                # Entry point pointer (optional shortcut)
```

### model.bim Measure Schema (TMSL)

The `model.bim` is a single JSON file. The JSON path to measures is:
`$.model.tables[?(@.name == "TableName")].measures[?(@.name == "MeasureName")]`

A measure object has these properties (all from official TMSL schema):

```json
{
  "name": "Total Revenue",
  "description": "Sum of all revenue lines including adjustments",
  "expression": "SUMX(Sales, Sales[Quantity] * Sales[Unit Price])",
  "formatString": "#,##0.00",
  "isHidden": false,
  "displayFolder": "Revenue",
  "annotations": [
    {
      "name": "PBI_FormatHint",
      "value": "{\"isGeneralNumber\":true}"
    }
  ]
}
```

Key fields for PBI skill commands:
- `expression` — the DAX to read/write for optimize, explain, format, comment
- `description` — populated by `/pbi:comment` command
- `formatString` — checked by `/pbi:audit` (blank = audit warning)
- `annotations[PBI_FormatHint]` — Power BI Desktop metadata; preserve on write

### TMDL Format (Per-Object Files)

When TMDL is enabled, `definition/tables/Sales.tmdl` contains:

```
table Sales
    measure 'Total Revenue' = SUMX(Sales, Sales[Quantity] * Sales[Unit Price])
        description = "Sum of all revenue lines"
        formatString: #,##0.00
        displayFolder: Revenue
```

TMDL is more diff-friendly (one file per table, human-readable syntax) but requires TMDL-aware parsing. For the skill system, treat TMDL files as text with known line syntax rather than JSON parsing.

**Version detection:** Read `definition.pbism` → check `"version"` field:
- Version `"1.0"` → TMSL format, parse `model.bim`
- Version `"4.0"` or higher + `definition/` folder exists → TMDL format, parse `.tmdl` files

### Files the Skill Can Edit vs. Read-Only

| File | Edit? | Notes |
|------|-------|-------|
| `model.bim` | YES | Full read/write; Desktop must be closed |
| `definition/*.tmdl` | YES | Full read/write; Desktop must be closed |
| `definition.pbism` | Read-only | Do not modify; version + settings |
| `diagramLayout.json` | Read-only | Explicitly unsupported during preview |
| `report.json` (PBIR-Legacy) | Read-only | Explicitly unsupported during preview |
| `definition/report.json` (PBIR) | YES | Supported with public JSON schema |
| `definition/pages/*/page.json` | YES | Supported with public JSON schema |
| `definition/pages/*/visuals/*/visual.json` | YES | Supported; used by potential future commands |
| `.pbi/localSettings.json` | NO | User-specific, gitignored |
| `.pbi/cache.abf` | NO | Binary, gitignored |

## Command Routing Architecture

### Bare `/pbi` vs. Specific `/pbi:optimize`

Following the GSD pattern exactly:

| Invocation | Behaviour |
|------------|-----------|
| `/pbi` (no arguments) | Router: presents a question "What do you want to do?" with options. Routes to the right command. |
| `/pbi:optimize [args]` | Goes straight to work. No preamble. |
| `/pbi:optimize` (no args) | Prompts for DAX input (paste or file reference). |

The bare `/pbi` SKILL.md uses `disable-model-invocation: true` so Claude doesn't trigger it automatically. Each subcommand also uses `disable-model-invocation: true` — these are explicit analyst actions, not things Claude should trigger on its own.

### Argument Handling

Commands support both file references and pasted content via `$ARGUMENTS`:

```markdown
## Input resolution

Arguments: $ARGUMENTS

If $ARGUMENTS contains a file path (starts with ./ or contains .bim/.tmdl):
  → Read that file using the Read tool
If $ARGUMENTS is blank:
  → Check for PBIP context; if present, prompt which measure to target
  → If paste-in mode, ask analyst to paste the DAX
Otherwise:
  → Treat $ARGUMENTS as the pasted DAX expression
```

## Suggested Build Order

Based on component dependencies and risk:

```
Phase 1: Foundation — Core DAX commands (no file I/O required)
  /pbi:explain    (pure text: read DAX, produce explanation)
  /pbi:format     (pure text: read DAX, reformat)
  /pbi:optimize   (pure text: read DAX, rewrite)
  Rationale: These work in paste-in mode only. No PBIP file parsing needed.
  Validates the core DAX knowledge base before adding file complexity.

Phase 2: Context detection + File I/O
  Context detector (shared utility used by all subsequent commands)
  /pbi:comment    (first command to write back to model.bim/TMDL)
  Rationale: Establishes the two-mode pattern. comment is lower-stakes
  than audit (modifying one measure vs. reading entire model).

Phase 3: Model-wide read commands
  /pbi:audit      (reads all tables, measures, relationships)
  Rationale: Depends on reliable PBIP parsing. Easier to validate
  read-only before adding audit write-back features.

Phase 4: Git integration
  /pbi:diff       (reads git diff, produces changelog)
  /pbi:commit     (reads diff, proposes message, runs git commit)
  Rationale: Depends on a working PBIP project with git history.
  diff before commit: validate diff parsing before wiring commit.

Phase 5: Direct file editing
  /pbi:edit       (general-purpose PBIP file read/write)
  Rationale: Most open-ended command. Built last because it requires
  deep understanding of which files are safe to edit (established
  in Phase 2-3).

Phase 6: Bare router + polish
  /pbi            (routes to all above; can only be built after commands exist)
  Knowledge base refinement (dax-patterns.md, audit-rules.md)
```

## Anti-Patterns

### Anti-Pattern 1: Single Monolithic SKILL.md

**What people do:** Put all command logic into one large `SKILL.md` file with conditional branching for each subcommand.

**Why it's wrong:** The skills character budget (2% of context window, ~16k chars default) is consumed by the full monolith every session. Claude loads all instructions even for a simple `/pbi:format` call. Harder to maintain and test each command independently.

**Do this instead:** One SKILL.md per command in `.claude/skills/pbi/commands/`. Each loads its own knowledge references. The bare `/pbi` router is a thin file that just prompts and redirects.

### Anti-Pattern 2: Attempting to Edit Files While Desktop is Open

**What people do:** Use the Edit tool to modify `model.bim` or `.tmdl` files while the analyst has the report open in Power BI Desktop.

**Why it's wrong:** Power BI Desktop is not aware of external file changes. The analyst will see no change, or worse, Desktop will overwrite the edits when they save. This is explicitly documented by Microsoft.

**Do this instead:** Every command that writes to PBIP files must warn the analyst: "Power BI Desktop must be closed for these changes to take effect. After writing, restart Desktop." Default to outputting formatted DAX as a code block (paste-in output) unless the analyst explicitly confirms Desktop is closed.

### Anti-Pattern 3: Parsing report.json (PBIR-Legacy) for Measure References

**What people do:** Read `report.json` to find which measures are used on which pages, expecting structured JSON.

**Why it's wrong:** `report.json` is PBIR-Legacy format and Microsoft explicitly states it does not support external editing. Its schema is not publicly documented during preview. The file is brittle to parse and subject to change.

**Do this instead:** For measure usage tracking, read only the new PBIR `definition/` folder (where each visual.json has a public schema), or rely on the model file alone for measure operations. If PBIR-Legacy is the only format present, note the limitation to the analyst.

### Anti-Pattern 4: Assuming TMSL — Not Checking Format First

**What people do:** Hard-code JSON parsing paths assuming `model.bim` always exists.

**Why it's wrong:** Projects saved with TMDL Preview enabled use `definition/*.tmdl` files instead. `model.bim` will not exist. A command that assumes TMSL silently fails on any TMDL project.

**Do this instead:** Always read `definition.pbism` first. Check `"version"`: if `"4.0"` or higher AND `definition/` folder exists, use TMDL path. Otherwise use TMSL path. Build this check into the context detector utility.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Power BI Desktop | None (file-based) | Desktop must be closed for writes; restart required to see external changes |
| Git | Bash (`git diff`, `git add`, `git commit`) | Only for `/pbi:commit` and `/pbi:diff`; no special library needed |
| TMDL VS Code extension | Not integrated | Analyst uses separately; skill operates on raw files |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Context detector ↔ Each command | Inline check within each command's SKILL.md | Not a separate service; duplicated short check is fine at this scale |
| Knowledge files ↔ Commands | Explicit markdown references in SKILL.md | Claude loads on demand; not auto-injected |
| DAX commands ↔ Git commands | None | Completely independent command groups |
| `/pbi` router ↔ Subcommands | User is redirected; router does not programmatically call subcommands | Router displays options; analyst invokes the specific command |

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 analyst, 1 project | Current flat structure is fine |
| Team of analysts, multiple PBIP projects | Add project-level `.claude/skills/pbi/` override per project for project-specific audit rules |
| Large models (100+ measures) | `/pbi:audit` may need to paginate Read calls; batch by table rather than loading model.bim in one pass |
| TMDL adoption increases | If TMDL becomes the default (currently in preview), TMSL fallback can be simplified or removed |

## Sources

- [Power BI Desktop projects overview — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview) (verified 2026-03-12, doc updated 2025-12-15)
- [Power BI Desktop project semantic model folder — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset) (verified 2026-03-12, doc updated 2026-01-20)
- [Power BI Desktop project report folder — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report) (verified 2026-03-12, doc updated 2026-01-12)
- [Tables object (TMSL) — Microsoft Learn / Analysis Services](https://learn.microsoft.com/en-us/analysis-services/tmsl/tables-object-tmsl?view=asallproducts-allversions) (official TMSL measure schema)
- [Extend Claude with skills — Claude Code official docs](https://code.claude.com/docs/en/skills) (skill system architecture, frontmatter reference, verified 2026-03-12)
- GSD workflow reference: `C:/Users/DeveshD/.claude/get-shit-done/workflows/new-project.md` (command routing pattern)
- GSD command examples: `C:/Users/DeveshD/.claude/commands/gsd/*.md` (frontmatter pattern, subcommand naming)

---
*Architecture research for: Claude skill system for Power BI PBIP analyst tooling*
*Researched: 2026-03-12*
