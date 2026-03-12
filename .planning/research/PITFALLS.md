# Pitfalls Research

**Domain:** Power BI PBIP analyst skill / Claude slash-command tool
**Researched:** 2026-03-12
**Confidence:** HIGH (critical pitfalls verified against official Microsoft docs, Claude Code docs, and community sources)

---

## Critical Pitfalls

### Pitfall 1: Hardcoding the Model Format as model.bim (TMSL vs TMDL Blindness)

**What goes wrong:**
The tool assumes the semantic model is always stored as `model.bim` (TMSL/JSON). In practice, Power BI projects exist in two distinct formats: TMSL (`model.bim` — a single large JSON file) and TMDL (`/definition/` folder — one `.tmdl` file per table/measure). If the tool only knows about `model.bim`, it silently fails or corrupts a TMDL-format project. This is especially dangerous because TMDL is the direction Microsoft is pushing, and the upgrade from TMSL to TMDL is **irreversible** without a backup.

**Why it happens:**
Most documentation and tutorials were written when TMSL was the only option. TMDL moved to preview in 2023 and is now in broader adoption. Training data for LLMs skews heavily toward TMSL examples. The `definition.pbism` file specifies the version (1.0 = TMSL, 4.0+ = TMDL), but it is easy to miss.

**How to avoid:**
- At startup, read `definition.pbism` to detect the format version before touching any model files.
- Implement separate read/write paths for TMSL (`model.bim`) and TMDL (`/definition/` folder).
- If format is ambiguous, prompt the analyst rather than assuming.
- Never write `model.bim` into a TMDL project — this creates a corrupt state where both formats exist simultaneously.
- Reference: `definition.pbism` version property: version 1.0 = TMSL; version 4.0+ = TMDL.

**Warning signs:**
- Commands that work on one analyst's machine fail on another's.
- DAX edits appear to save but are not reflected when the report is opened.
- Git shows unexpected large diffs after a supposedly minor change.

**Phase to address:** Foundation / project detection phase (first phase). Must be solved before any read/write functionality is built.

---

### Pitfall 2: Ignoring the "Desktop Must Be Closed" Contract

**What goes wrong:**
Editing PBIP files on disk while Power BI Desktop has the project open causes silent data loss. Power BI Desktop holds the model in-memory and overwrites project files on save. If the tool writes a measure edit to `model.bim` or a TMDL file while Desktop is open, the analyst's next save in Desktop will overwrite all external changes without any warning.

**Why it happens:**
Power BI Desktop has no file-watch or live-reload mechanism for external edits. The architecture is: Desktop loads files on open, holds state in-memory, writes back on save. External tooling that edits files on disk is not observable by Desktop. This is a fundamental constraint of the PBIP format — not a bug that will be fixed.

**How to avoid:**
- Always detect whether Desktop is running before offering file-edit mode. On Windows, check for `PBIDesktop.exe` process.
- Surface two distinct modes clearly: "file-edit mode (Desktop must be closed)" and "paste-in mode (Desktop is open)".
- In paste-in mode, produce formatted output the analyst can copy-paste into Desktop's DAX editor — never write to disk.
- Warn explicitly before any disk write: "This will modify files on disk. Confirm Power BI Desktop is closed."
- Document in the skill's help text that restart is required after external edits.

**Warning signs:**
- Analyst reports that changes "disappeared" after saving in Desktop.
- Tool shows success but report still shows old measure definition.

**Phase to address:** Core architecture phase (very early). The two-mode design must be established before any command is built.

---

### Pitfall 3: PBIR Report Format Blindness (report.json vs PBIR per-visual files)

**What goes wrong:**
The report layer of a PBIP project also has two format variants: the legacy PBIR-Legacy format stores the report as a single `report.json` file; the new PBIR format stores each page, visual, and bookmark as individual files in a folder structure. As of March 2026, PBIR is the new default for Power BI Desktop. The upgrade is irreversible. A tool that only knows about `report.json` will fail silently on any new PBIR-format project.

**Why it happens:**
The PBIR format was in preview throughout most of 2024-2025 and only became the default in early 2026. The PBI-SKILL project was conceived during this transition. Most community documentation still references `report.json`.

**How to avoid:**
- Treat the report layer as a potentially compound format from day one.
- Check for the presence of a `definition/` folder under the report item versus a `report.json` file.
- For v1, the tool's scope is DAX and model layer — explicitly document that report-layer editing targets the model (`/SemanticModel/`) only.
- If the analyst asks about report-layer files, explain the PBIR format situation rather than attempting to parse it.

**Warning signs:**
- `/pbi:audit` or `/pbi:diff` commands that try to parse report.json fail on newer projects.
- Analyst says "the file doesn't look like what you described."

**Phase to address:** Foundation phase. Format detection must cover both the model layer (TMSL vs TMDL) and the report layer (PBIR-Legacy vs PBIR).

---

### Pitfall 4: Context Window Saturation from Inlining Large PBIP Files

**What goes wrong:**
PBIP model files can be very large. A `model.bim` for a non-trivial model can easily be 500 KB to several MB of JSON. Loading the entire file into the context window in every command response eats the 200K token window quickly and degrades response quality from ~80% fill onward (with a steep coherence loss between 80-95% saturation).

**Why it happens:**
The naive implementation of `/pbi:audit` or `/pbi:edit` reads the entire model file and inlines it into the prompt. TMDL format mitigates this somewhat (files are split per table), but a large model can still have many tables with hundreds of measures. Context saturation is invisible — the tool appears to work while giving increasingly degraded output.

**How to avoid:**
- Never load the full model file by default. Load relevant sections only (e.g., for `/pbi:optimize`, load the specific measure being optimised plus its dependencies).
- For `/pbi:audit`, implement a streaming/chunked approach: audit one domain at a time (naming conventions, then relationships, then measure quality) rather than loading everything at once.
- For TMDL format, this is naturally mitigated by the per-file structure — read only the table files relevant to the task.
- Use sub-agents for context isolation: spawn a sub-agent to read the model and extract only the relevant measures, then return a summary to the parent agent.
- Set a size threshold: if model.bim > 100 KB, warn the analyst and suggest targeted queries instead of full audit.

**Warning signs:**
- Audit output becomes less specific or misses obvious issues on large models.
- Tool begins hallucinating measure names that don't exist in the model.
- Long sessions produce increasingly generic advice.

**Phase to address:** Core command implementation phase. Chunk-loading strategy must be designed before `/pbi:audit` and `/pbi:edit` are built.

---

### Pitfall 5: DAX Context Transition Mistakes in Optimization Advice

**What goes wrong:**
The tool gives DAX optimization advice that is technically wrong because it ignores context transition side effects. The most common error: recommending wrapping a measure reference in `CALCULATE()` to "add filter context" without realising this triggers context transition, which can completely change the result in an iterator. Alternatively, recommending removal of a `CALCULATE()` wrapper as "unnecessary" when it is actually the mechanism providing the correct filter context.

**Why it happens:**
Context transition in DAX is one of the most counterintuitive concepts in the language. It occurs whenever a measure (which internally contains CALCULATE) is referenced inside an iterator — the row context is automatically converted to a filter context. This is not obvious from reading the formula. LLMs trained on DAX documentation learn the rules but frequently misapply them when the iterator + measure interaction is nested or indirect.

**How to avoid:**
- Never recommend removing a `CALCULATE()` wrapper without explicitly reasoning through whether context transition is being relied upon.
- When analyzing iterator functions (`SUMX`, `AVERAGEX`, etc.), always check whether the expression references other measures, not just column references.
- For `/pbi:optimize`, flag any measure that uses iterators over measures (not just columns) as "requires manual verification — context transition present."
- Avoid the blanket rule "SUMX on a single column is always slower than SUM" — this is a widely repeated simplification that is often wrong (SUMX on a single column is internally the same operation as SUM).
- Reference authoritative sources: SQLBI's "Understanding Context Transition in DAX" is the definitive treatment.

**Warning signs:**
- Optimization suggestions change a measure's result, not just its performance.
- Analyst reports that "the optimised measure gives different numbers."
- The tool recommends `SUM` everywhere as a replacement for `SUMX` without checking the expression body.

**Phase to address:** DAX analysis commands phase (`/pbi:optimize`, `/pbi:explain`). Must be addressed in the prompt engineering for those commands before they ship.

---

### Pitfall 6: Treating "dataset" and "semantic model" as Interchangeable in User-Facing Text

**What goes wrong:**
Microsoft renamed "dataset" to "semantic model" in late 2023. The tool generates advice, commit messages, or audit output using "dataset" terminology. This confuses analysts working in the modern Power BI Service UI (which shows "semantic model") while still being correct for analysts using older documentation. The REST API still uses "datasets" internally, adding further inconsistency.

**Why it happens:**
LLM training data is heavily weighted toward pre-rename documentation. "Dataset" is far more prevalent in training corpora than "semantic model." Without explicit instruction, outputs default to the older term.

**How to avoid:**
- In all user-facing output, use "semantic model" consistently.
- In PBIP file path references, use the folder name as-is (which Power BI Desktop names per the project — typically something like `ProjectName.SemanticModel/`).
- In the skill's CLAUDE.md / system context, explicitly instruct: "Always use 'semantic model', never 'dataset', when referring to the Power BI data model layer."
- Exception: when discussing the REST API or scripting contexts where the term "dataset" appears in the API surface, use both with explanation.

**Warning signs:**
- Commit messages generated by `/pbi:commit` say "Updated dataset measures" instead of "Updated semantic model measures."
- Audit output refers to "dataset best practices" in contexts where the current Microsoft guidance uses "semantic model."

**Phase to address:** Foundation phase. Establish a terminology glossary in the skill's system context before any command is built.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Only supporting model.bim (TMSL) initially | Simpler to build, most existing projects use it | Will break on TMDL projects; requires rewrite once TMDL adoption grows | Never — TMDL is the default direction; detect both from day one |
| Hardcoding file paths (e.g., always look for `model.bim`) | Faster initial development | Silent failures on TMDL projects; hard to debug | Never |
| Inlining full model files into context | Simpler code, no chunking logic | Context saturation on any non-trivial model | Only in prototyping/testing with tiny models |
| Single mode (file-edit only, no paste-in) | Half the complexity | Tool is unusable whenever Desktop is open, which is most of the time for active analysts | MVP only, if explicitly scoped — but paste-in is too important to defer long |
| Skip format detection, ask analyst every time | Avoids detection logic | Poor UX, analyst must know their own format | Acceptable in v1 if detection proves complex, but should auto-detect by v2 |
| Generic DAX optimization rules without context analysis | Easier to implement | Wrong advice in edge cases; damages trust | Never for optimization; acceptable for formatting/explaining |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Git + PBIP | Committing `cache.abf` and `localSettings.json` — these change every time Desktop opens, creating constant false diffs | Verify `.gitignore` excludes `.pbi/cache.abf`, `.pbi/localSettings.json`, and `*.abf` before staging |
| Git + PBIP | Staging the entire project directory including Copilot metadata and TMDLScripts scratch files | Stage only semantic model definition files and report definition files; exclude editor artifacts |
| TMDL files | Editing TMDL with incorrect whitespace/indentation | TMDL is whitespace-sensitive; malformed indentation causes Desktop to reject the file on open with a parse error |
| unappliedChanges.json | Overwriting M query edits made in Desktop by writing to the queries section of TMDL externally | Check for the presence of `unappliedChanges.json` before editing Power Query definitions — if present, external edits to queries will be overwritten when the analyst applies pending changes |
| diagramLayout.json | Treating this file as editable | Microsoft docs explicitly state this file "doesn't support external editing" during preview |
| PBIR report format | Assuming `report.json` exists in all PBIP report folders | Check for PBIR format (`definition/` subfolder in Report item) before any report-layer operations |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading full model.bim per command | Slow responses, context saturation on models > 50 tables | Load only relevant table/measure files; use TMDL per-file structure | Any model with more than ~30 measures if using TMSL |
| Running full `/pbi:audit` in a single context window | Audit output becomes generic and misses issues in second half of model | Split audit into domain-specific passes; use sub-agents per audit category | Models with more than ~15 tables or ~50 measures |
| Git diff parsing on TMSL model.bim | Full JSON diff is unreadable; diff parser returns walls of JSON | Prefer TMDL (per-file diffs are clean); for TMSL, parse the JSON and emit human-readable change summary | Any model change, immediately |
| Sub-agent spawning for every command | Overhead adds latency; context isolation means sub-agents miss model-wide context | Reserve sub-agents for heavy operations (audit, diff summarisation); use in-context reading for single-measure operations | Not a scale issue — a UX issue from the first use |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Outputting a rewritten measure without showing the diff | Analyst cannot review what changed; must manually compare old and new | Always show old → new with highlighted changes when rewriting any DAX |
| Silent file writes with no confirmation | Analyst loses work if Desktop was open; no recovery path | Require explicit confirmation before disk writes; show exactly which files will be changed |
| Generic "optimisation complete" with no explanation | Analyst learns nothing; cannot review correctness | Explain each change: what the original pattern was, why it was changed, what the new pattern does differently |
| Paste-in mode output with no copy-ready formatting | Analyst must reformat before pasting into Desktop | Produce output as a clean DAX block, correctly indented, ready to paste directly into the Desktop DAX editor |
| Commit messages that are technically accurate but business-meaningless | "Updated model.bim" or "Changed measure expression" — tells teammates nothing | Generate commit messages in business terms: "Add YoY Sales Growth % measure; fix CALCULATE filter context in Margin % measure" |
| Mixing paste-in and file-edit output in the same response | Confuses the analyst about whether files were changed | Clearly label every response: "File-edit mode: changes written to disk" or "Paste-in mode: copy the block below" |

---

## "Looks Done But Isn't" Checklist

- [ ] **Format detection:** Does the tool handle both `model.bim` (TMSL) and `/definition/` folder (TMDL)? Test against a TMDL project before declaring done.
- [ ] **Desktop-open detection:** Does paste-in mode actually produce clean copy-pasteable DAX, not file paths or JSON? Verify on a measure that includes variables and formatting.
- [ ] **Git pre-commit check:** Does `/pbi:commit` verify that `.gitignore` correctly excludes `cache.abf` and `localSettings.json` before staging?
- [ ] **PBIR report format:** Does the tool gracefully handle the absence of `report.json` in PBIR-format projects, rather than throwing an error?
- [ ] **unappliedChanges.json guard:** Does any command that touches Power Query definitions check for `unappliedChanges.json` first?
- [ ] **Context transition in DAX:** Does `/pbi:optimize` flag measures using iterators over measure references as "requires manual verification" rather than blindly recommending simplification?
- [ ] **Terminology consistency:** Does every user-facing output say "semantic model" not "dataset"? Run a grep/search over all command outputs.
- [ ] **Large model handling:** Does `/pbi:audit` produce sensible output on a model with 100+ measures, or does it degrade silently?
- [ ] **TMDL whitespace safety:** Does any TMDL write operation preserve indentation exactly? Test by round-tripping a TMDL file through the tool and verifying Desktop still opens it.
- [ ] **diagramLayout.json:** Is this file explicitly excluded from all write operations?

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Overwrote TMDL files while Desktop was open | HIGH | Re-open Desktop, save immediately to re-export; if save fails, restore from git last known good commit; if no git, restore from `.pbi/cache.abf` backup |
| Upgraded TMSL to TMDL without backup (irreversible) | MEDIUM | No rollback available; work from TMDL going forward; if original is needed, re-open from a git commit pre-upgrade or a PBIX backup |
| Committed `cache.abf` to git — repo bloat | MEDIUM | Add to `.gitignore`, run `git rm --cached` for the file, rewrite history with `git filter-repo` if repo size is a problem |
| Context saturation produced wrong DAX | LOW | Re-run the specific command in a fresh session with only the relevant measure pasted in; compare output |
| TMDL parse error after external edit | LOW | Desktop shows error with line number; fix the specific indentation/syntax issue; TMDL errors are local and do not corrupt the whole model |
| Wrong optimization advice applied (e.g., broke context transition) | MEDIUM | Restore the original measure from git history or the analyst's notes; add a regression test measure to verify results match before/after |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| TMSL vs TMDL format blindness | Phase 1: Foundation / project detection | Test against a TMDL project; `definition.pbism` version correctly detected |
| Desktop-open file locking | Phase 1: Foundation / dual-mode design | Running PBIDesktop.exe during test; file-edit correctly blocked, paste-in correctly offered |
| PBIR report format blindness | Phase 1: Foundation / format detection | Test against a March 2026+ project saved with PBIR default |
| Context window saturation | Phase 2: Core commands (audit, edit) | Benchmark against a 100-measure model; no hallucinated measure names |
| DAX context transition mistakes | Phase 2: DAX commands (optimize, explain) | Test measures with SUMX over measure references; no incorrect simplification advice |
| "dataset" terminology | Phase 1: Foundation / skill system context | Grep all user-facing outputs for "dataset" — must be zero |
| Git noisy diffs / missing .gitignore | Phase 3: Git workflow (commit, diff) | Verify `.gitignore` guards before staging; test on TMDL and TMSL projects |
| unappliedChanges.json overwrite | Phase 2: Edit command | Test with a project that has pending Power Query changes |
| TMDL whitespace corruption | Phase 2: Edit command | Round-trip a TMDL file; Desktop opens without error |
| Commit message business-meaninglessness | Phase 3: Git workflow (commit) | Human review of generated commit messages against a set of test model changes |

---

## Sources

- [Power BI Desktop project semantic model folder — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset) — TMSL vs TMDL format, file structure, `definition.pbism` version property, `unappliedChanges.json` behaviour, `diagramLayout.json` external editing restriction
- [PBIR will become the default Power BI Report Format — Microsoft Power BI Blog](https://powerbi.microsoft.com/en-us/blog/pbir-will-become-the-default-power-bi-report-format-get-ready-for-the-transition/) — PBIR as default from March 2026, irreversible upgrade, transition timeline
- [Transitioning to PBIR — nickyvv.com](https://www.nickyvv.com/2026/02/transitioning-to-new-power-bi-enhanced-report-format-pbir.html) — GA timeline (Q3 2026), PBIR-Legacy deprecation
- [AI agents that work with TMDL files — Tabular Editor Blog](https://tabulareditor.com/blog/ai-agents-that-work-with-tmdl-files) — TMDL whitespace sensitivity, validation without deployment, multi-syntax confusion in AI agents
- [Understanding context transition in DAX — SQLBI](https://www.sqlbi.com/articles/understanding-context-transition-in-dax/) — Authoritative treatment of context transition pitfalls
- [Context Transition's Dark Secret: The Performance Cost of Iterators in DAX — Medium](https://medium.com/@sandippalit009/context-transitions-dark-secret-the-performance-cost-of-iterators-in-dax-e246f2bc494a) — Hidden performance costs of context transition in iterators
- [SUM vs SUMX misunderstanding — Power of BI](https://www.powerofbi.org/2024/03/04/dax-sum-vs-sumx-misunderstanding/) — Debunking the blanket "SUMX is slower" advice
- [Datasets renamed to semantic models — Microsoft Power BI Blog](https://powerbi.microsoft.com/en-us/blog/datasets-renamed-to-semantic-models/) — Terminology change history; REST API still uses "datasets"
- [Claude Code Customization: CLAUDE.md, Slash Commands, Skills, and Subagents — alexop.dev](https://alexop.dev/posts/claude-code-customization-guide-claudemd-skills-subagents/) — Skill auto-trigger unreliability, context drift, skills vs slash commands distinction
- [Context Management with Subagents in Claude Code — RichSnapp.com](https://www.richsnapp.com/article/2025/10-05-context-management-with-subagents-in-claude-code) — Sub-agent context isolation, parallel spawning conflicts
- [Context Management Common Mistakes — SFEIR Institute](https://institute.sfeir.com/en/claude-code/claude-code-context-management/errors/) — 80% context fill performance degradation, context amnesia
- [.gitignore for Power BI Projects — jihwanpowerbifabric.wixsite.com](https://jihwanpowerbifabric.wixsite.com/supplychainflow/post/gitignore-for-power-bi-projects-a-simple-guide-for-the-modern-bi-developer) — Auto-generated files that create noisy diffs
- [The Good, the Bad, and the PBIP — Medium, Feb 2026](https://medium.com/@malharpawar/the-good-the-bad-and-the-pbip-mastering-power-bi-version-control-9bbb77ee53a5) — Real-world PBIP version control issues
- [Power BI Desktop projects (PBIP) — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview) — Canonical PBIP format documentation

---
*Pitfalls research for: Power BI PBIP analyst skill (Claude slash-command tool)*
*Researched: 2026-03-12*
