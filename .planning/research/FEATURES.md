# Feature Research

**Domain:** Power BI PBIP analyst productivity — Claude slash-command skill
**Researched:** 2026-03-12
**Confidence:** HIGH (DAX tooling ecosystem well-documented; pain points confirmed across multiple community and official sources)

---

## Competitive Landscape Summary

The existing tool ecosystem covers distinct, non-overlapping niches:

| Tool | Primary Niche | Free? | Requires Desktop Open? |
|------|--------------|-------|------------------------|
| DAX Studio | Query execution, performance profiling, VertiPaq analysis | Yes | Yes (connects live) |
| Tabular Editor 3 | Model editing, BPA, bulk scripting | Paid (TE2 free) | No (reads PBIP/BIM directly) |
| ALM Toolkit / BISM Normalizer | Model compare/merge, environment promotion | Yes | Connects via XMLA |
| DAX Formatter (daxformatter.com) | DAX formatting (web paste-in only) | Yes | No (paste only) |
| Power BI Copilot | Report-layer AI assistant, Q&A | Paid (Fabric) | In-service only |
| Power BI MCP Server | Agent access to live model via TOM | Varies | Yes (live connection) |

**The gap this skill fills:** A Claude-native workflow that works from the PBIP file layer (no live connection required), available at any point in the analyst's terminal/editor session via slash commands, covering DAX quality + model auditing + Git — which no single existing tool does end-to-end.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features analysts assume exist. Missing these = the tool feels like a prototype, not a skill.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| DAX explanation in plain English | Analysts paste measures they didn't write; "what does this do?" is the single most common question | LOW | LLMs excel at this; o-series and Claude 3.x virtually eliminate DAX hallucinations for explanation tasks (HIGH confidence per pbidax.wordpress.com 2025) |
| DAX formatting / prettifying | daxformatter.com (SQLBI) has set the standard; analysts expect SQLBI-style indentation as the canonical format | LOW | SQLBI formatting rules are well-documented and deterministic; Claude can reproduce them precisely |
| DAX inline commenting | Best practice for complex measures; currently a fully manual task in Power BI Desktop | MEDIUM | Should produce `//` comments per block of logic, plus a measure Description field value — two outputs from one command |
| DAX performance issue detection | DAX Studio is used daily for this; analysts expect any DAX helper to flag common slow patterns | MEDIUM | Must cover: FILTER on full table instead of column, unnecessary SUMX where CALCULATE suffices, missing VAR for repeated sub-expressions, bidirectional filter side-effects |
| Model naming convention audit | Tabular Editor BPA rules (TabularEditor/BestPracticeRules on GitHub) define the community standard; analysts expect these checks | MEDIUM | Must check: table/column Pascal case, measure sentence case, key column visibility, date table marking, dimension prefix removal |
| Context-aware dual mode | PBIP files readable directly; paste-in when Desktop is open (Desktop must be closed for file writes) | LOW | Detect presence of PBIP files in cwd; fallback to paste-in output gracefully |
| Routing / help entry point | Bare `/pbi` without a subcommand should orient new users and route to the right command | LOW | Like GSD's bare `/gsd` — ask what they want, suggest the right command |

### Differentiators (Competitive Advantage)

Features that set this skill apart from DAX Studio, Tabular Editor, and DAX Formatter individually.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| DAX rewrite with rationale | Not just "here is formatted code" — explain *why* the rewrite is faster (e.g., "replaced FILTER(Table, ...) with CALCULATE(...) to push filter to Storage Engine, dropping FE time from 44ms to 2ms") | HIGH | Requires understanding of SE vs FE split; Claude reasoning models handle this well. Real-world benchmarks show SUMX→CALCULATE rewrites delivering 10x+ speed improvement |
| Git commit message generation from PBIP diff | Translates raw JSON diffs into human-readable summaries: "Added [Total Margin %] measure to Sales table. Modified [YTD Revenue] formula — replaced CALCULATE with SUMX pattern." | MEDIUM | PBIP/PBIR stores each measure as a separate file; a `git diff` produces granular, parseable diffs. No existing tool generates commit messages from these |
| Human-readable diff summary | `/pbi:diff` explains what changed between two commits in analyst language — not JSON keys, but "3 measures modified, 1 table added, bi-directional relationship removed from Orders→Products" | HIGH | Must parse PBIP folder structure: `.Dataset/definition/tables/*/measures/*.measure.json`, `.Dataset/definition/relationships.json`, `.Dataset/model.bim` |
| Full model audit in one command | DAX Studio covers performance; Tabular Editor BPA covers naming; nothing does both plus relationships, date table detection, and hidden column hygiene in a single conversational output | HIGH | Must synthesise: naming conventions + relationship health + date table marking + hidden column hygiene + measure quality + display folder usage |
| Adaptive skill-level responses | Intermediate analysts need "use DIVIDE instead of /" explained; advanced analysts need "your measure forces a FE materialisation loop" — same tool, different register | MEDIUM | Prompt engineering; infer from context (how they describe the problem, complexity of their existing DAX) |
| Measure Description field population | Power BI Desktop has a Description field per measure — almost never populated, making model documentation non-existent | LOW | `/pbi:comment` should produce both the `//` inline DAX comment AND a ready-to-paste Description field value, so analysts get two documentation artefacts at once |
| Direct PBIP JSON editing | When Desktop is closed, Claude can read and write `.Dataset/definition/tables/*/measures/*.measure.json` directly — no GUI required | MEDIUM | PBIP format is stable JSON; PBIR (GA planned Q3 2026) improves this further. Claude should never write to PBIP files when Desktop is open (undefined behaviour) |
| Slash-command discoverability | `/pbi:optimize`, `/pbi:explain`, `/pbi:format` etc. give analysts a predictable, memorable API — unlike free-form chat which requires prompt engineering skill | LOW | Architecture decision already taken in PROJECT.md; key differentiator vs asking Claude directly in chat |

### Anti-Features (Things to Deliberately NOT Build)

Features that seem useful but create problems — either they duplicate existing tools better, create scope creep, or conflict with the tool's "helper, not builder" identity.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Interactive query runner / VertiPaq viewer | Analysts see DAX Studio and want that inside Claude | DAX Studio does this perfectly and requires a live connection we don't have; building a read-only version is low value and high complexity | Detect when analyst needs query execution; tell them "run this in DAX Studio" and provide the exact query to paste |
| Full report creation from scratch | "Build me a sales dashboard" is a tempting use case | Scope explosion; visuals layer requires PBIR JSON knowledge that is immature (GA Q3 2026), and "report builder" is a completely different product category | Stay on DAX + model layer only; defer visual layer to v2+ after PBIR stabilises |
| Power BI Service / REST API integration | Publishing, dataset refresh, workspace management | Desktop-first scope for v1; Service API adds OAuth complexity, tenant permission issues, and environment coupling | Out of scope per PROJECT.md; Service integration is v2+ at earliest |
| Real-time model monitoring | "Alert me when a measure changes" | Requires persistent process, polling, or event hooks — not a slash-command pattern | One-shot audit on demand via `/pbi:audit` covers the actual need |
| M query / Power Query optimisation | Analysts also struggle with M | M is a different language, different engine, different failure modes; dilutes DAX expertise | Acknowledge M queries in audit output if they appear in PBIP; defer M-specific commands to v2 |
| Visual formatting suggestions | "Make my bar chart look better" | Completely outside the DAX + model layer; requires PBIR visual JSON (immature format pre-GA) | Explicitly out of scope per PROJECT.md |
| Multi-project / workspace-wide operations | "Audit all my reports at once" | PBIP is one-project-at-a-time by design; multi-project scope creates ambiguity in file paths and context | Single PBIP project per session as stated in PROJECT.md Constraints |
| Copilot-style inline suggestion in Desktop | Some users ask for IDE-style completions | Requires a persistent background process; Claude skills are invoked, not always-on | Slash-command pattern gives analysts instant access without always-on overhead |

---

## Feature Dependencies

```
/pbi:format
    └──enables──> /pbi:comment         (formatting first makes comment placement accurate)
    └──enables──> /pbi:optimize        (formatted code is easier to reason about for rewrite)

/pbi:explain
    └──informs──> /pbi:optimize        (explain output validates the analyst understands the proposed rewrite)

PBIP file detection (context mode)
    └──gates──> /pbi:edit              (edit mode only available when PBIP files present)
    └──gates──> /pbi:commit            (git operations require PBIP repo)
    └──gates──> /pbi:diff              (diff requires git history)
    └──gates──> /pbi:audit (full mode) (full audit reads model.bim / TMDL files)

paste-in mode
    └──enables──> /pbi:explain         (always works)
    └──enables──> /pbi:format          (always works)
    └──enables──> /pbi:optimize        (always works)
    └──enables──> /pbi:comment         (always works)
    └──BLOCKS──>  /pbi:edit            (cannot write without file access)
    └──BLOCKS──>  /pbi:commit          (no git context)
    └──BLOCKS──>  /pbi:diff            (no git context)
    └──BLOCKS──>  /pbi:audit (full)    (can audit pasted measure only, not whole model)

/pbi:audit
    └──requires──> PBIP folder readable
    └──reads──>    model.bim OR TMDL definition files
    └──outputs──>  findings that /pbi:edit can apply (when Desktop closed)

/pbi:diff
    └──requires──> git history (at least 2 commits)
    └──requires──> PBIP format (not legacy PBIX)
```

### Dependency Notes

- **Format before comment:** DAX formatting ensures consistent indentation so comment placement (`//` per logical block) aligns predictably with structure.
- **Context detection gates file-writes:** The single most important safety constraint — writing to PBIP files while Desktop is open produces corrupted state. Context detection must run before any edit/commit path.
- **Paste-in is always available:** Four commands (`explain`, `format`, `optimize`, `comment`) should work with zero file access — this is the highest-value entry point for analysts who run Desktop constantly.
- **Audit feeds edit:** `/pbi:audit` findings should be formatted so `/pbi:edit` can apply them as a follow-up without re-explaining context.

---

## MVP Definition

### Launch With (v1)

Minimum needed to validate the slash-command concept and deliver daily-use value.

- [ ] `/pbi` routing entry point — orient and route to the right subcommand
- [ ] `/pbi:explain` — plain English explanation of pasted DAX (paste-in, always available)
- [ ] `/pbi:format` — SQLBI-style DAX formatting (paste-in, always available)
- [ ] `/pbi:optimize` — detect top 5 slow patterns + rewrite with rationale (paste-in, always available)
- [ ] `/pbi:comment` — inline `//` comments + Description field value (paste-in, always available)
- [ ] Context detection — detect PBIP vs paste-in mode; gate file-write commands appropriately
- [ ] `/pbi:audit` — model audit reading PBIP files (naming, relationships, date tables, hidden columns)

The first four commands work with zero PBIP setup — this lets analysts use the skill immediately, even if they haven't migrated to PBIP format yet.

### Add After Validation (v1.x)

Add when core paste-in commands are confirmed valuable.

- [ ] `/pbi:commit` — stage + generate human-readable commit message from PBIP diff (trigger: analyst has PBIP repo and uses Git)
- [ ] `/pbi:diff` — human-readable summary of changes between commits (trigger: team is doing code review on PBIP PRs)
- [ ] `/pbi:edit` — direct PBIP JSON writes for audit-suggested fixes (trigger: analyst wants to apply audit findings without reopening Desktop)

### Future Consideration (v2+)

Defer until v1 usage patterns are understood.

- [ ] `/pbi:new` — scaffold a new measure with correct naming, format string, display folder, description (defer: need to understand analyst scaffolding patterns from v1 usage)
- [ ] M query audit support — extend `/pbi:audit` to cover Power Query steps (defer: different language, different expertise surface)
- [ ] PBIR visual layer support — read/write PBIR visual JSON for report-layer suggestions (defer: PBIR GA is Q3 2026; format still stabilising)
- [ ] Batch measure operations — apply formatting/commenting across all measures in a model at once (defer: scope + safety risk; need single-measure confidence first)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| `/pbi:explain` | HIGH | LOW | P1 |
| `/pbi:format` | HIGH | LOW | P1 |
| `/pbi:optimize` | HIGH | MEDIUM | P1 |
| `/pbi:comment` | HIGH | MEDIUM | P1 |
| Context detection (PBIP vs paste-in) | HIGH | LOW | P1 |
| `/pbi` routing entry point | MEDIUM | LOW | P1 |
| `/pbi:audit` (naming + relationships) | HIGH | HIGH | P1 |
| `/pbi:commit` | MEDIUM | MEDIUM | P2 |
| `/pbi:diff` | MEDIUM | HIGH | P2 |
| `/pbi:edit` (direct PBIP writes) | MEDIUM | MEDIUM | P2 |
| Adaptive skill-level responses | MEDIUM | MEDIUM | P2 |
| Batch measure operations | LOW | HIGH | P3 |
| M query audit | LOW | HIGH | P3 |
| PBIR visual layer | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch — validates the core value proposition
- P2: Should have — adds depth once P1 commands are proven
- P3: Nice to have — future phases only

---

## Competitor Feature Analysis

| Feature | DAX Studio | Tabular Editor 3 | DAX Formatter | This Skill |
|---------|------------|------------------|---------------|------------|
| DAX explanation | No | No | No | Yes — plain English |
| DAX formatting | Yes (editor) | Yes (editor) | Yes (web paste) | Yes — in-terminal |
| DAX optimization suggestions | Partial (query plan) | Via BPA rules | No | Yes — with rationale |
| Inline DAX commenting | No | No | No | Yes |
| Measure Description population | Manual | Manual | No | Yes — auto-generated |
| Model naming audit | No | Yes (BPA) | No | Yes |
| Relationship audit | No | Partial (BPA) | No | Yes |
| Date table detection | No | Via BPA | No | Yes |
| Git commit message generation | No | No | No | Yes |
| Human-readable diff | No | No | No | Yes |
| Direct PBIP file edit | No | Yes | No | Yes |
| Works without live connection | No | Yes | Yes (paste) | Yes |
| Works when Desktop is open | Yes | Partial | Yes | Yes (paste-in mode) |
| Requires GUI install | Yes | Yes | No (web) | No (Claude skill) |

**Key insight:** This skill uniquely combines DAX intelligence (explain/format/optimize/comment) with model governance (audit) and Git workflow (commit/diff) in a single, no-install, terminal-native tool. No existing tool covers all three pillars.

---

## Daily vs Occasional Usage Mapping

Understanding cadence drives which features belong in v1.

**Daily use (highest friction, most ROI):**
- Explaining unfamiliar measures (inherited models, team handovers)
- Formatting newly written DAX before committing
- Optimizing measures flagged as slow in report testing
- Adding comments before sharing work

**Weekly use:**
- Auditing model before publishing a new report version
- Writing commit messages after a development session
- Reviewing what changed in a colleague's PR (`/pbi:diff`)

**Occasional use:**
- Full model health check on a new project
- Applying bulk naming fixes via direct PBIP edit
- Scaffolding new measure sets from scratch

This cadence confirms the P1 priority: paste-in DAX commands deliver daily value before the analyst even needs a PBIP repo.

---

## Sources

- [DAX Studio official site](https://daxstudio.org/) — Feature list, 2025 release notes (HIGH confidence)
- [Tabular Editor 3 — January 2026 release](https://tabulareditor.com/blog/tabular-editor-3-january-2026-release) — Current TE3 features (HIGH confidence)
- [TabularEditor/BestPracticeRules on GitHub](https://github.com/TabularEditor/BestPracticeRules) — Official BPA rule categories (HIGH confidence)
- [LLMs and DAX: Where Things Stand Today — pbidax.wordpress.com (May 2025)](https://pbidax.wordpress.com/2025/05/14/llms-and-dax-where-things-stand-today/) — LLM capabilities/limits for DAX (MEDIUM confidence — single author blog, but technically detailed)
- [Automate Power BI Model Optimization: BPA Meets Claude AI — Fabric Community Blog](https://community.fabric.microsoft.com/t5/Power-BI-Community-Blog/Automate-Power-BI-Model-Optimization-Best-Practice-Analyzer/ba-p/5000187) — Claude + BPA workflow validation (MEDIUM confidence)
- [AI agents that work with Power BI semantic model MCP servers — Tabular Editor blog](https://tabulareditor.com/blog/ai-agents-that-work-with-power-bi-semantic-model-mcp-servers) — AI agent capabilities and limits (MEDIUM confidence)
- [Power BI Desktop Projects (PBIP) — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview) — PBIP file structure (HIGH confidence)
- [PBIR transition — nickyvv.com Feb 2026](https://www.nickyvv.com/2026/02/transitioning-to-new-power-bi-enhanced-report-format-pbir.html) — PBIR default timeline (MEDIUM confidence — community blog, matches official announcements)
- [DAX Formatter by SQLBI](https://www.daxformatter.com/) — Canonical formatting standard (HIGH confidence)
- [The 7 Deadly Sins of DAX — Medium 2025](https://medium.com/decoded-by-datacast/the-7-deadly-sins-of-dax-why-your-measures-are-killing-performance-and-how-to-fix-them-in-2025-d416e3bf67d3) — Common slow patterns confirmed (MEDIUM confidence)

---
*Feature research for: PBI Skill — Claude slash-command system for Power BI PBIP analysts*
*Researched: 2026-03-12*
