# PowerBI DAX Skills for Claude Code

A set of Claude Code slash commands (`/pbi:*`) that turn Claude into a Power BI DAX co-pilot. Paste in a DAX measure and get plain-English explanations, auto-formatting via the DAX Formatter API, optimisation suggestions with rule-based rewrites, inline comments, and error diagnosis — all with session memory that persists across commands.

---

## Commands

| Command | What it does |
|---------|-------------|
| `/pbi:explain` | Explains a DAX measure in plain English — filter context, row context, context transitions, performance notes |
| `/pbi:format` | Formats DAX using the DAX Formatter API (falls back to Claude inline formatting if API is unreachable) |
| `/pbi:optimise` | Applies 5 optimisation rules, detects context-transition guards, outputs side-by-side original vs optimised |
| `/pbi:comment` | Adds inline `//` comments and generates a Description Field value ready to paste into Power BI |
| `/pbi:error` | Diagnoses a Power BI error message using session context, correlates with last command run |
| `/pbi:load` | *(Phase 2)* Loads context from a `.pbip` project file |

All commands share a `.pbi-context.md` session file that tracks your last command, command history, and analyst-reported failures — so each command knows what you've already tried.

---

## Requirements

- [Claude Code](https://docs.anthropic.com/en/claude-code) (the Claude CLI)
- A Claude account (claude.ai or API key)

---

## Installation

**1. Clone the repository into your project directory:**

```bash
git clone https://github.com/deveshd7/PowerBI-Skill.git
cd PowerBI-Skill
```

**2. Copy the skills into your Claude Code skills directory:**

The skills live in `.claude/skills/`. Claude Code discovers skills from this folder automatically when you run it inside the project.

```bash
# The skills are already in .claude/skills/ — nothing to copy.
# Just open Claude Code from inside this directory:
claude
```

**3. Verify the commands are available:**

In Claude Code, type `/` and look for `pbi:` in the command list. You should see:

```
/pbi:explain
/pbi:format
/pbi:optimise
/pbi:comment
/pbi:error
/pbi:load
```

**4. Initialise the session file:**

The `.pbi-context.md` file is already present at the project root. It tracks command history and analyst-reported failures across your session. No setup needed.

---

## Usage

### Explain a measure

```
/pbi:explain
```
Claude will prompt:
> Paste your DAX measure below:

Paste your measure and press Enter. You'll get complexity classification (Simple / Intermediate / Advanced), plain-English summary, and four analysis sections.

Optional: add a table name for context:
```
/pbi:explain --table FactSales
```

### Format a measure

```
/pbi:format
```
Probes the DAX Formatter API at startup. If reachable, uses it. If not, formats inline with a one-line note.

### Optimise a measure

```
/pbi:optimise
```
Checks for 5 common performance issues (redundant FILTER, SUMX over column, unnecessary CALCULATE wrapper, etc.) and shows a side-by-side diff with explanations.

### Add comments

```
/pbi:comment
```
Adds `//` comments to each line of your measure and produces a Description Field value (max 300 characters, plain text, ready to paste into Power BI Desktop).

### Diagnose an error

```
/pbi:error
```
Paste an error message. Claude diagnoses it across 6 categories, correlates with the last command you ran, and avoids suggesting approaches that have already failed (tracked in `.pbi-context.md`).

---

## Session Memory

All commands read and write `.pbi-context.md` at the project root. This file has three sections:

- **Last Command** — command, timestamp, measure name, outcome
- **Command History** — rolling log of last 20 commands
- **Analyst-Reported Failures** — you manage this section manually to flag approaches that have already failed

The failure log feeds back into every command: if a measure has a known failed approach, the command will flag it before generating output.

---

## Project structure

```
.
├── .claude/
│   └── skills/
│       ├── pbi-explain/SKILL.md
│       ├── pbi-format/SKILL.md
│       ├── pbi-format/api-notes.md
│       ├── pbi-optimise/SKILL.md
│       ├── pbi-comment/SKILL.md
│       ├── pbi-error/SKILL.md
│       └── pbi-load/SKILL.md
├── .pbi-context.md          ← session memory (auto-updated by commands)
└── tests/
    └── fixtures/            ← sample DAX measures for testing
```

---

## Roadmap

- **Phase 1 (complete):** Paste-in DAX commands — explain, format, optimise, comment, error
- **Phase 2:** Context detection and `.pbip` file I/O — `/pbi:load` reads your Power BI project file and injects table/measure context automatically

---

## License

MIT
