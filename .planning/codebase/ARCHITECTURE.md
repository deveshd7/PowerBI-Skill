# Architecture

**Analysis Date:** 2026-03-13

## Pattern Overview

**Overall:** Single-skill router with command dispatch and dual execution paths

**Key Characteristics:**
- Single unified entry point (`/pbi`) that routes to subcommands based on keyword matching
- Detection blocks run once at skill invocation, shared by all subcommands
- Two execution models: direct Sonnet execution for DAX reasoning, Haiku Agent spawn for file/git operations
- Session memory via `.pbi-context.md` persists across invocations
- Mode-based architecture: paste-in mode (any directory) or PBIP file mode (requires `.SemanticModel/`)

## Layers

**Router & Detection Layer:**
- Purpose: Parse user input, detect PBIP format/git state, load session context
- Location: `.claude/skills/pbi/SKILL.md`
- Contains: Router logic, keyword matching table, detection blocks, category menu
- Depends on: File system checks (PBIP detection), shell commands (git state), session file
- Used by: All subcommands

**Subcommand Layer:**
- Purpose: Implement business logic for specific user tasks
- Location: `.claude/skills/pbi/commands/*.md`
- Contains: 14 command implementations across two categories
- Depends on: Detection outputs, session context, Read/Write/Bash/Agent tools
- Used by: Router

**Execution Dispatch:**
- **Sonnet Subcommands** (Direct): explain, format, optimise, comment, error, new, edit, comment-batch, audit
  - Invoked directly by router loading command file and executing inline
  - Models: DAX reasoning tasks, model editing, analysis

- **Haiku Subcommands** (Agent): load, diff, commit, undo, changelog
  - Invoked by spawning Haiku Agent with command file as instructions
  - Models: File I/O, git operations, data aggregation

**Session Context Layer:**
- Purpose: Persist state across invocations
- Location: `.pbi-context.md` at project root
- Contains: Last command info, rolling command history (20 max), analyst-reported failures
- Pattern: Read-then-Write (never bash append)

**Shared Resources:**
- Purpose: Shared knowledge and utilities
- Location: `.claude/skills/pbi/shared/api-notes.md`
- Contains: DAX Formatter API reference and integration notes

## Data Flow

**Paste-in Mode Flow:**

1. User invokes `/pbi [subcommand]` with DAX measure
2. Router detects `.SemanticModel/` is absent → PBIP_MODE=paste
3. Router matches subcommand keyword → routes to appropriate command file
4. Sonnet command loads, prompts user for DAX input (if needed)
5. Command processes DAX, returns explanation/format/optimisation
6. Session context updated with command info

**PBIP File Mode Flow:**

1. User invokes `/pbi [subcommand]` in a PBIP project directory
2. Router detects `.SemanticModel/` → determines format (TMDL or TMSL)
3. Router runs File Index → lists all table definitions or model.bim path
4. Router checks git state, loads session context
5. Router routes to command:
   - **Sonnet commands** (edit, comment, audit): Load command file, execute with detection data
   - **Haiku commands** (load, diff, commit): Spawn Agent with command file + detection data
6. Command reads/writes model files, updates git, updates session context
7. Auto-commits triggered by edit, comment, error, new subcommands

**Model Change Flow:**

1. User runs `/pbi edit` or `/pbi comment` with description
2. Sonnet command analyzes model structure and generates change
3. Files written to `.SemanticModel/` (TMDL or TMSL format)
4. Session context updated with measure name, outcome
5. Auto-commit triggered: stages `.SemanticModel/` and creates git commit
6. Session history rolls (max 20 entries)

## Key Abstractions

**PBIP Project Detection:**
- Purpose: Determine if user is in a Power BI project and what format
- Examples: `PBIP_MODE=paste`, `PBIP_FORMAT=tmdl`, `PBIP_FORMAT=tmsl`
- Pattern: File existence checks in detection blocks (`SKILL.md`)

**File Index:**
- Purpose: Build list of all editable model files for commands to reference
- Examples: TMDL case returns list of `.tmdl` files; TMSL case returns path to `model.bim`
- Pattern: Detection block in `SKILL.md`, consumed by edit and audit commands

**Keyword Routing Table:**
- Purpose: Map user intent to specific subcommands
- Examples: "explain" → commands/explain.md, "comment-batch" → commands/comment-batch.md
- Pattern: Defined in SKILL.md with keyword aliases to handle multiple user phrasings

**Session Context:**
- Purpose: Track last command, command history, and analyst-reported failures
- Examples: Command History table with timestamp, command name, measure name, outcome
- Pattern: YAML-style markdown sections, read/written by all commands, 20-row history max

**Execution Path Selection:**
- Purpose: Optimize cost and latency by choosing Sonnet vs Haiku
- Examples: Sonnet for DAX analysis (explain, optimise); Haiku for file ops (diff, commit)
- Pattern: Router dispatches based on command category in routing table

## Entry Points

**Skill Invocation:**
- Location: `.claude/skills/pbi/SKILL.md`
- Triggers: User types `/pbi` or `/pbi [subcommand]`
- Responsibilities: Run detection blocks once, parse input, route to subcommand, display category menu if no args

**Subcommand Execution:**
- **Paste-in Commands** (explain, format, optimise, comment, error, new):
  - Location: `.claude/skills/pbi/commands/[cmd].md`
  - Triggers: Router keyword match, direct Sonnet execution
  - Responsibilities: Prompt for/accept DAX input, apply transformation, output result

- **PBIP Commands** (load, audit, diff, commit, edit, undo, comment-batch, changelog):
  - Location: `.claude/skills/pbi/commands/[cmd].md`
  - Triggers: Router keyword match, with PBIP detection active
  - Responsibilities: Read model files, modify if needed, write back, update session/git

**Agent Entry Points (Haiku):**
- Commands: load, diff, commit, undo, changelog
- Flow: Router spawns Haiku Agent, passes command file + detection outputs
- Responsibility: Run file/git operations independently, return results

## Error Handling

**Strategy:** Layered approach with fallback paths and session memory

**Patterns:**
- **DAX Formatter API fallback**: If DAX Formatter API unreachable, format command falls back to Claude inline formatting with user notification
- **Git state checking**: Commands check for git repo before writing commits; if no git, offer to init repo (git init flow in load/commit commands)
- **PBIP format detection**: If `.SemanticModel/` exists but format unclear, defaults to TMDL
- **Session context robustness**: If `.pbi-context.md` missing or corrupted, commands start fresh without crashing
- **Measure not found**: Error command correlates error with last command context; if measure not found in session, prompts user to run `/pbi load` first
- **Analyst-reported failures**: Commands check failure log and flag if attempted approach has known failures

## Cross-Cutting Concerns

**Logging:** No external logging. Session context `.pbi-context.md` serves as audit trail. Command History table captures timestamp, command name, measure name, outcome.

**Validation:**
- PBIP format validation: File existence checks (model.bim vs definition/tables/)
- Path validation: All bash paths double-quoted to handle spaces
- DAX syntax: Paste-in commands do not validate DAX syntax; rely on Power BI for errors
- TMDL/TMSL file format: Write commands preserve original indentation (tabs for TMDL) and expression format

**Authentication:**
- No explicit auth layer. Claude Code handles user/API key authentication
- Power BI Desktop or online project access implicit (user must be authenticated to use PBIP commands)

**File I/O Conventions:**
- TMDL files: Use tabs only for indentation, never convert to spaces
- TMSL expressions: Preserve original form (JSON string vs array), use array form only if expression contains line breaks
- Measure name matching: Use `grep -rlF` (fixed-string) to avoid regex metacharacter issues
- DAX in shell: Write to temp file using single-quoted heredoc to prevent shell expansion of `$`, backticks

---

*Architecture analysis: 2026-03-13*
