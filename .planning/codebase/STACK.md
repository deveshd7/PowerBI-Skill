# Technology Stack

**Analysis Date:** 2026-03-13

## Languages

**Primary:**
- Markdown - All skill and command definitions, documentation
- Bash - File I/O, git operations, API calls, text processing

**Secondary:**
- DAX (Data Analysis Expressions) - Subject domain for user code analysis and generation
- TMDL (Tabular Model Definition Language) - Power BI semantic model files (read/write)
- TMSL (Tabular Model Scripting Language) - Power BI semantic model JSON format (read/write)
- JSON - Power BI Report (PBIR) file format parsing

## Runtime

**Environment:**
- Claude Code (Claude API with File I/O and Bash tool access)

**Model Selection:**
- Sonnet (Claude 3.5 Sonnet) - DAX reasoning commands (explain, format, optimise, comment, error, new, edit, comment-batch, audit)
- Haiku (Claude 3.5 Haiku) - File/git-heavy commands dispatched as agents (load, diff, commit, undo, changelog)

**Package Manager:**
- Git - Version control for PBIP projects
- Curl - HTTP requests to external APIs

## Frameworks

**Core Skill Framework:**
- Claude Code Skill System - Custom markdown-based skill architecture (v3.0.0)
- Location: `.claude/skills/pbi/SKILL.md` - Router and detection blocks
- Command files: `.claude/skills/pbi/commands/` - Subcommand implementations

**Testing:**
- Manual/fixture-based testing
- Test fixtures in `tests/fixtures/`:
  - `.dax` files - Individual DAX measures for paste-in testing
  - `pbip-tmdl/` - TMDL project with git repo, 3 tables, relationships, bidirectional filter
  - `pbip-tmsl/` - TMSL project (model.bim format)
  - `pbip-no-repo/` - TMDL project without git repo
  - `pbip-empty-model/` - Project with tables but no measures
  - `context-20-rows.md` - Saturated command history test case

**Build/Dev:**
- `install.sh` - One-liner install script for deploying skill to target projects
- Git for version control

## Key Dependencies

**Critical:**
- Bash tools (grep, sed, find, etc.) - Core file parsing and manipulation
- Curl - DAX Formatter API integration
- Git - Repository operations for PBIP projects

**Infrastructure:**
- Claude Code Agent spawning - For Haiku-dispatched commands (load, diff, commit, undo, changelog)

## Configuration

**Environment:**
- Session context via `.pbi-context.md` - Persists command history, model context, analyst-reported failures
- No configuration files required beyond git repo state

**Build:**
- No build pipeline
- Skill is deployed via `install.sh` script which copies `.claude/` directory to target project

**Execution Detection (in SKILL.md):**
- PBIP mode detection (TMDL vs TMSL format)
- PBIR (Power BI Report) detection for visual layer audit
- Git repository state detection
- File index generation for all TMDL or model.bim

## Platform Requirements

**Development:**
- Claude Code CLI with API key
- Bash shell
- Git (for PBIP operations)
- Text editor for skill modification

**Production:**
- Claude Code (CLI or web IDE)
- Bash environment (macOS, Linux, Windows with WSL/Git Bash)
- Git (optional, only for PBIP file mode commands)
- Internet access for DAX Formatter API calls

## Tooling & Utilities Available

**Allowed Tools (from SKILL.md):**
- Read - File reading for skill files and semantic model files
- Write - File writing for TMDL/TMSL edits, session context updates
- Bash - Shell commands for git, file processing, API calls
- Agent - Spawning Haiku agents for file/git-heavy commands

---

*Stack analysis: 2026-03-13*
