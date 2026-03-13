# External Integrations

**Analysis Date:** 2026-03-13

## APIs & External Services

**DAX Code Formatting:**
- DAX Formatter (https://www.daxformatter.com) - Formats DAX code with consistent structure
  - SDK/Client: Curl (HTTP POST)
  - Status: Verified working 2026-03-12
  - Implementation file: `.claude/skills/pbi/shared/api-notes.md`

## Data Storage

**Databases:**
- Not applicable - Skill does not directly connect to databases

**File Storage:**
- Local filesystem only
- Reads/writes Power BI semantic model files:
  - TMDL files: `.SemanticModel/definition/tables/*.tmdl` (read/write)
  - TMSL files: `.SemanticModel/model.bim` (read/write)
  - PBIR files: `.Report/*.json` (read-only for visual layer audit)
  - Session context: `.pbi-context.md` (read/write)

**Caching:**
- Session memory via `.pbi-context.md` - Persists:
  - Last Command (name, timestamp, measure name, outcome)
  - Command History (rolling 20-row limit)
  - Model Context (tables, measures, columns, relationships)
  - Analyst-Reported Failures (manual tracking of failed approaches)

## Authentication & Identity

**Auth Provider:**
- Not applicable - No explicit authentication required

**API Access:**
- DAX Formatter: Public endpoint, no authentication required
- Claude Code: Authentication via Claude API key (managed by Claude Code CLI)

## Monitoring & Observability

**Error Tracking:**
- None - Errors are reported inline to the user in chat

**Logs:**
- Session context file (`.pbi-context.md`) serves as implicit command log
- Command History tracks last 20 commands with timestamps

## CI/CD & Deployment

**Hosting:**
- Not applicable - Skill runs within Claude Code on user's machine

**Installation:**
- `install.sh` script - Copies `.claude/` directory to target project
  - One-liner: `curl -sL https://raw.githubusercontent.com/deveshd7/PowerBI-Skill/main/install.sh | bash`
  - Can target specific project: `bash -s -- /path/to/project`

**Version Control:**
- Git integration for PBIP projects (read git history, stage/commit changes, diff detection)
- No mandatory deployment pipeline

## Environment Configuration

**Required env vars:**
- None - Skill operates entirely within Claude Code context

**Secrets location:**
- No secrets managed by skill
- DAX Formatter API is public (no credentials needed)
- User's Claude API key is managed externally by Claude Code CLI

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## External Service Dependencies

**Power BI Project Format Awareness:**
- PBIP (Power BI Project) - Project format with `.SemanticModel/` directory
- TMDL format - Tabular Model Definition Language (tab-indented text files)
- TMSL format - Tabular Model Scripting Language (JSON-based)
- PBIR format - Power BI Report files (JSON)

**Git Integration Points:**
- `git status` - Detect repository presence
- `git rev-parse HEAD` - Check for existing commits
- `git add .SemanticModel/` - Stage model changes
- `git commit -m "[msg]"` - Auto-commit after edits
- `git log` - Generate changelog
- `git revert` - Undo last commit

## DAX Formatter API Details

**Endpoint:** `https://www.daxformatter.com`

**Method:** POST (form-encoded)

**Parameters:**
- `fx` - URL-encoded DAX measure text (required)
- `r` - Region code (US) - controls list/decimal separator conventions
- `embed` - Set to 1 for page fragment response

**Response Format:**
- HTML containing `<div class="formatted">` element
- Requires HTML stripping (br→newline, span tags removed, &nbsp;→space)

**Fallback:** If API unreachable or returns empty, skill falls back to Claude inline SQLBI formatting

**Probe Location:** Verified in `.claude/skills/pbi/commands/format.md` (line 7)

**Note:** JSON endpoint at `/api/daxformatter/dax` returns 404 - form-POST legacy endpoint is the only working public API

---

*Integration audit: 2026-03-13*
