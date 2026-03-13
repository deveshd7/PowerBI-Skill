# Coding Conventions

**Analysis Date:** 2026-03-13

## Overview

This is a Claude Code skill repository. All substantive code is written in **Markdown with embedded Bash**, using Claude's instruction-following capabilities to execute complex logic. There are no TypeScript, Python, or traditional source files. All conventions focus on markdown structure, bash scripting patterns, and instruction design.

## File Organization

**Skill routing layer:** `.claude/skills/pbi/SKILL.md`
- Single router file that dispatches to subcommands
- Contains detection blocks (bash probes run once, results shared with all subcommands)
- Routes keywords to appropriate command files using frontmatter-driven model selection

**Command files:** `.claude/skills/pbi/commands/*.md`
- One command per file, named after the subcommand (explain.md, format.md, audit.md, etc.)
- Each command is a self-contained set of step-numbered instructions
- Instructions are intended for Claude to execute directly (Read, Write, Bash tools)

**Shared resources:** `.claude/skills/pbi/shared/api-notes.md`
- Technical reference documentation (not executed)
- Documents external API endpoints, probes, and integration details

**Session context:** `.pbi-context.md` (project root)
- Markdown file updated by every command using Read-then-Write pattern
- Tracks last command, 20-row command history, analyst-reported failures
- Committed to `.gitignore` to prevent context pollution across branches

## Naming Patterns

**Commands:**
- Kebab-case: `comment`, `comment-batch`, `error`, `format`, `optimise`
- Each command maps 1:1 to a `.md` file in `commands/`
- Routing keywords in SKILL.md use English phrases (e.g., "what does", "speed up", "comment all")

**Variables in bash:**
- UPPERCASE with underscores: `PBIP_MODE`, `PBIP_FORMAT`, `AUTO_COMMIT`, `GIT_STATUS`
- Temporary vars: `TMPFILE`, `ENDFILE` (here-doc delimiters)

**Sections and headings:**
- H1 (`# `) for command name (e.g., `# /pbi explain`)
- H2 (`## `) for major sections (Step 0, Instructions, File Mode Branch)
- H3 (`### `) for step numbers and sub-sections
- H4 (`#### `) for parsing rules and detailed subsections

**Markdown tables:**
- Used for: command routing, domain rules, parsing rules, context sections
- Always include header separator
- Columns use standard markdown table syntax with pipes

## Code Style

### Markdown formatting

**Instructions are written as numbered steps:**
```markdown
### Step 1 — Extract measure name

- Extract the measure name from the text before the first `=` sign (strip whitespace).
- If no `=` is found, use `[Measure]` as placeholder.
```

**Step structure:**
- Each step is numbered sequentially (Step 0, Step 1, Step 2, etc.)
- Step 0 is reserved for guards/pre-flight checks
- Each major step includes a short summary line describing its purpose
- Complex steps are broken into sub-bullets with clear action language

**Code blocks:**
- Fenced code blocks use triple backticks with language tag: ` ```markdown `, ` ```bash `, ` ```dax `, ` ```json `
- Bash commands use `bash` tag
- DAX code uses `dax` tag
- Example configurations use relevant language tags

**Inline references:**
- Bash variables are backtick-quoted: `` `$VAR` ``
- File paths are backtick-quoted: `` ``.SemanticModel/`` ``
- Function/command names are backtick-quoted: `` `CALCULATE` ``, `` `/pbi audit` ``
- Measure names in examples use square brackets: `[Revenue]`, `[Revenue YTD]`

### Error handling patterns

**Guard clauses (Step 0):**
All commands begin with Step 0 that checks preconditions and may halt execution:
- PBIP_MODE checks: If paste mode and command requires file mode, output specific message and stop
- Git state checks: If no repo exists and command requires git, output specific message and stop
- File existence checks: If required file missing, check alternatives or output error

**Example guard clause pattern:**
```markdown
**If PBIP_MODE=paste:**
Respond with exactly this message and stop:
> No PBIP project found. Run /pbi audit from a directory containing .SemanticModel/.
```

**Graceful fallbacks:**
- DAX Formatter API failure → fall back to inline Claude SQLBI formatting
- Missing file in TMDL → fuzzy-match suggestions against other files
- Empty diff → output zero-changes message instead of empty report

**User confirmation:**
- Major destructive actions ask for confirmation with `(y/N)` pattern
- Default is always cancel (N) — user must explicitly type y or Y to proceed
- Non-confirmation outputs cancellation message: "Change discarded. No files modified."

**Information preservation:**
- Entire files always re-written (never partial writes) to preserve formatting and structure
- Original indentation style (tabs vs spaces) is detected and matched on re-write
- Original expression form (JSON string vs array in TMSL) is preserved unless modification requires conversion

## Import/Include Patterns

Commands do not import from each other. Instead:
- Router (`SKILL.md`) uses Read tool to load command file content
- Command receives detection results via documented variables (PBIP_MODE, PBIP_FORMAT, File Index, etc.)
- Each command is self-contained and can be executed independently
- Shared reference doc (`shared/api-notes.md`) is read on-demand by commands that call external APIs

**Pattern for command dispatch:**
```markdown
1. Use the Read tool to load the command file from `commands/[cmd].md` (relative to this skill file's directory).
2. Execute the loaded instructions directly in the current context. Pass through the detection block outputs above.
```

## Session Context Management

**All commands follow Read-then-Write pattern for `.pbi-context.md`:**

1. Use Read tool to get current file content
2. Modify in memory (update sections, append rows, trim to 20 rows max)
3. Use Write tool to write entire file back
4. Never use bash append commands (cat >>, echo >>)

**Sections never modified by any command:**
- `## Analyst-Reported Failures` — only analyst edits this section manually
- Any section not explicitly listed in command's "Update context" step

**Command History pruning:**
- Always keep to last 20 rows maximum
- When appending new row exceeds 20, remove oldest rows first
- Pruning happens in memory during the single Read-then-Write pass

## Bash Conventions

**Path quoting:**
- All file paths in bash commands use double quotes to handle spaces: `"$VAR"`, `".SemanticModel/"`
- Prevents shell word-splitting and glob expansion in Power BI paths

**DAX in bash:**
- Use single-quoted here-doc delimiter to prevent shell expansion: `<<'ENDDAX'`
- Protects DAX `$` symbols, backticks, and other shell metacharacters
- Example:
  ```bash
  cat > "$TMPFILE" <<'ENDDAX'
  Revenue = SUM(Sales[Amount])
  ENDDAX
  ```

**grep for measure/table names:**
- Always use `grep -rlF` (fixed-string search) to avoid regex metacharacter issues
- Measure names may contain parentheses, brackets, spaces — fixed-string prevents interpretation
- Example: `grep -rlF "[MeasureName]" ".SemanticModel/definition/tables/" 2>/dev/null`

**Status checking pattern:**
- Commands capture bash output and check for status indicators
- Pattern: `GIT_STATUS=$(cmd && echo "yes" || echo "no")`
- Output indicators: `AUTO_COMMIT=ok`, `API_OK`, `PBIP_MODE=file`

**Error suppression:**
- Non-critical failures redirect stderr to `/dev/null`: `2>/dev/null`
- Critical failures are allowed to output (e.g., actual Read/Write errors)
- Silent errors (grep no match, file not found) are handled with echo fallback

## Comment Conventions

**When to comment:**
- Step summaries: every major step has a one-line summary after the heading
- Complex parsing rules: detailed subsections explain algorithm or decision logic
- Bash commands: inline comment after command explaining what it checks/captures

**What to comment:**
- Complex multi-step algorithms (e.g., "Naming inference algorithm" in audit.md)
- Non-obvious file structure assumptions (e.g., "TMDL files use tabs for indentation")
- Decision criteria (e.g., "Simple vs Intermediate vs Advanced" complexity classification)

**What NOT to comment:**
- Simple sequential steps that are self-explanatory
- Single bash pipes
- Straightforward table formatting

**Format:**
- Comments use markdown # heading hierarchy to organize subsections
- Bullet points for procedural details
- Inline code formatting for technical terms

## TMDL-Specific Conventions

**Indentation preservation:**
- When reading a TMDL file, note the indentation style (tabs or spaces) and indent depth
- When writing back, match the original style exactly — never convert tabs to spaces or vice versa

**Measure name extraction:**
- Extract from lines: `measure Name =` or `measure 'Name' =`
- Strip single quotes if present
- Text is everything after `measure ` up to ` =`, trimmed

**Column name extraction:**
- Extract from lines: `column Name` or `column 'Name'`
- Strip single quotes if present

**Description lines:**
- Appear as `/// [description text]` immediately above measure declaration
- No blank line between `///` and `measure` keyword
- Multiple `///` lines may appear (multi-line description)

**Property lines:**
- Inside measure blocks: `formatString: [value]`, `displayFolder: "[value]"`, `isHidden: true/false`
- Properties appear after expression body
- Property lines must be preserved exactly when re-writing unrelated changes

## TMSL-Specific Conventions

**Expression format preservation:**
- Original expression may be JSON string: `"expression": "SUM(...)"`
- Or JSON array of strings: `"expression": ["SUM(...)", "...)"]`
- **CRITICAL:** detect the original form and preserve it
- Only convert string → array if modification creates line breaks
- Never convert array → string

**Property handling:**
- All non-expression fields must be preserved: `description`, `formatString`, `displayFolder`, `annotations`
- Only update targeted fields; leave all others unchanged

## Anti-Patterns to Avoid

1. **Partial file writes:** Always write entire file, never just the changed block
2. **Indentation conversion:** Detect original style and match it; never convert tabs↔spaces
3. **Bash append:** Never use `cat >>` or `echo >>` for context updates; always Read-then-Write
4. **Ambiguous table selection:** When entity appears in multiple tables, ask analyst to specify; never auto-select
5. **Default accept on confirm:** Default is always cancel (N); only proceed if analyst types y/Y
6. **Modifying protected sections:** Never touch Analyst-Reported Failures or sections not explicitly listed in command
7. **Skipping detection steps:** All commands must execute detection blocks; results are provided to command
8. **Non-transactional context updates:** Updates to `.pbi-context.md` must be atomic (single Read-then-Write); never split into multiple calls

---

*Convention analysis: 2026-03-13*
