# Project Research Summary

**Project:** Serapeum v4.0 — Stability + Synthesis
**Domain:** Local-first academic research assistant (R/Shiny RAG application)
**Researched:** 2026-02-18
**Confidence:** HIGH

## Executive Summary

Serapeum v4.0 is a milestone on an existing, well-architected 14,000+ LOC R/Shiny codebase. The three new synthesis features (Unified Overview preset, Literature Review Table, Research Question Generator) follow a clear pattern: all new user-facing outputs should route through the existing `generate_preset()` / `chat_completion()` pipeline in `R/rag.R`, render as GFM markdown (using table syntax for structured output), and surface in the existing chat panel via `commonmark::markdown_html()`. Only two new R packages are needed — `DT` (interactive table widget with export) and `writexl` (Excel export) — with all other functionality delivered by extending existing infrastructure. The recommended implementation approach is incremental: tackle tech debt and bugs first to stabilize the foundation, then add features in ascending complexity order (Overview -> Research Questions -> Literature Review Table).

The primary risk in this milestone is structured LLM output reliability for the Literature Review Table. LLMs produce syntactically valid markdown or JSON that fails schema adherence: missing rows, wrong column names, or hallucinated numerical values. OpenRouter's Response Healing fixes syntax only and explicitly does not fix schema violations. The correct mitigation is defensive R-side validation after parsing, a "Not reported" instruction in the prompt, a row count cap (30 papers per call), and a fallback to a user-facing error message rather than a crash. A secondary risk is the existing DuckDB connection leak in `search_chunks_hybrid()` (issue #117), which on Windows causes file locking that blocks `rebuild_notebook_store()` and amplifies as each new synthesis feature adds more callers. This must be fixed before new features are implemented.

The competitive landscape (Elicit, SciSpace, AnswerThis) confirms the v4.0 feature set is well-calibrated: unified overview and literature review table are table stakes, research question generation from gap analysis is a differentiator, and custom column prompts / PICO framing / CSV export are correctly deferred. The local-first, privacy-preserving architecture remains a strong competitive differentiator that no major competitor offers.

## Key Findings

### Recommended Stack

The base stack (R, Shiny, bslib, DuckDB, OpenRouter, ragnar, igraph, visNetwork, commonmark, mirai, ExtendedTask) is already validated and not re-researched. Two new packages are needed: `DT` (v0.34.0) for interactive HTML table rendering with built-in CSV export via the Buttons extension, and `writexl` (v1.5.4) for zero-dependency Excel export. All other features extend existing dependencies — notably `jsonlite::fromJSON()` for parsing structured LLM output, `httr2` for the `response_format` parameter addition to `chat_completion()`, and `commonmark` for rendering GFM markdown tables (already supported via `extensions = TRUE`).

**Core technology additions:**
- `DT` 0.34.0: Interactive table widget with Buttons extension for CSV export — Shiny-native, no Java required; use `DTOutput()`/`renderDT()` (NOT `dataTableOutput()`/`renderDataTable()`) to avoid Shiny namespace conflicts
- `writexl` 1.5.4: Excel export via `write_xlsx()` — zero dependencies, benchmark fastest for flat data frame output
- `jsonlite::fromJSON()` (existing): Parse structured JSON from LLM with `simplifyDataFrame = TRUE`
- `httr2` `response_format` parameter (existing): Add optional `json_object` mode to `chat_completion()` — use `json_object` not `json_schema` because `json_schema` fails on budget models users may select
- `commonmark` GFM table extension (existing): Already renders markdown tables via `extensions = TRUE`; CSS styling in `app.R` needed for Bootstrap 5 table appearance

**Libraries evaluated and rejected:** `reactable` (no built-in export), `gt`/`flextable` (static report tools, not interactive Shiny), `openxlsx2` (overkill for flat export), `json_schema` mode (fails on budget models), `ellmer` (unnecessary migration of working client).

### Expected Features

Research against production tools (Elicit, SciSpace, AnswerThis) confirms the feature prioritization.

**Must have (table stakes):**
- Unified Overview preset (#98) — running two separate presets for a complete picture is friction; every major tool defaults to a combined overview
- Literature Review Table (#99) — per-paper comparison matrix is the primary structured output researchers expect; Elicit built its entire product around this feature
- Per-paper citation attribution in the table — each row must map to a source paper; researchers verify claims against sources
- Research Question Generator (#102) — gap-to-question flow is a natural research workflow expected by users of AnswerThis and Elicit
- AI-generated content disclaimer on all new outputs — already required by existing presets; omitting it on new features would be inconsistent

**Should have (competitive differentiators for v4.x):**
- Gap Analysis Report preset (#101) — extract gap analysis from Conclusions into a standalone named preset; builds on existing infrastructure with no new patterns
- Methodology Extractor preset (#100) — methods-section-targeted retrieval; depends on section_hint fix (#118) being complete for reliable results
- PICO-structured output toggle for Research Questions — high value for health/biomedical researchers; defer until field usage confirmed

**Defer (v5+):**
- Custom dimension columns in Literature Review Table — requires UI design + dynamic prompt construction; ship fixed standard columns first and validate demand
- CSV export specifically for Literature Review Table — markdown tables are already copy-pasteable; defer dedicated CSV export until post-v4.0 demand confirmed
- Editable table cells — significant Shiny state management complexity; export-to-Excel workflow covers the use case adequately

**Anti-features confirmed by research (do not build):**
- Auto-refresh table on paper additions — expensive LLM call; keep generation manual/button-triggered
- Real-time streaming for table generation — parsing partial markdown tables is fragile; generate full response then render
- Research question scoring/ranking — LLM judging LLM outputs adds a second API call for marginal value; researchers are better judges of field priorities

### Architecture Approach

All new synthesis features integrate into the existing four-layer architecture (Shiny UI -> Module layer -> Business logic in `R/rag.R` -> Data in DuckDB/ragnar stores) without structural changes. The existing preset pipeline — button click -> `is_processing(TRUE)` -> append message -> call `R/rag.R` function -> `chat_completion()` -> markdown string -> `commonmark::markdown_html()` — handles all three new features. The Literature Review Table uses GFM markdown tables (not JSON-parsed HTML tables) to stay within this pipeline without requiring message object changes. The critical architectural constraint is that Literature Review Table retrieval must use direct SQL (`dbGetQuery` for all abstracts) rather than RAG top-k retrieval, because a comparison matrix requires complete coverage, not semantic relevance ranking.

**Major components to add or modify:**

1. `R/rag.R` — Add `generate_lit_review_table()` (~60 lines) and `generate_research_questions()` (~50 lines); add `"overview"` case to `generate_preset()` presets list; owns all prompt text and retrieval strategy
2. `mod_document_notebook.R` — Replace `btn_summarize` + `btn_keypoints` with `btn_overview`; no new files needed
3. `mod_search_notebook.R` — Add `btn_lit_review` and `btn_rq_generator` to offcanvas preset row; both are additive changes
4. `R/db.R` — Add `on.exit()` connection cleanup in `search_chunks_hybrid()` (5-line fix for issue #117)
5. `R/_ragnar.R` — Encode `section_hint` in `insert_chunks_to_ragnar()` (issue #118 fix); verify then delete dead code `with_ragnar_store()` / `register_ragnar_cleanup()` (issue #119)
6. `app.R` — Add `.chat-markdown table` CSS via `tags$style()` for Bootstrap 5 table styling, scoped to existing `.chat-markdown` div class so it cannot leak to other UI sections

**Patterns to follow (critical for consistency):**
- Keep prompt text in `R/rag.R`, not in module observers — existing pattern that keeps prompts testable and discoverable in one file
- Keep message objects as `{role, content, timestamp, preset_type}` — do not add new fields; all differentiation belongs in the content string
- Use GFM markdown tables for structured output — do NOT add `content_type` branching to the message pipeline

**Anti-patterns confirmed by architecture research:**
- Using RAG top-k retrieval for Literature Review Table (would miss papers — comparison matrix needs complete coverage)
- Returning structured data through the message pipeline via `content_type = "table"` (complicates export, breaks string assumptions)
- Putting prompt text directly in module `observeEvent` handlers (belongs in `R/rag.R`)

### Critical Pitfalls

1. **LLM schema adherence vs. syntax correctness are different problems** — OpenRouter Response Healing (launched 2025) fixes syntax errors only; it explicitly does NOT fix wrong field names, missing rows, or inconsistent column counts. Avoid by: using `json_object` mode with explicit prompt-guided structure (not `json_schema` which fails on budget models), validating with `tryCatch(jsonlite::fromJSON(...))` plus R-side field presence checks, returning a user-facing error on failure, capping at 30 papers per call, and including "Not reported" instruction to prevent hallucinated numbers.

2. **Merging presets breaks existing code in multiple locations** — `btn_summarize` and `btn_keypoints` IDs appear in at least four places: `presets` list, `observeEvent` bindings, button `inputId` values, and tests. Avoid by: grepping all occurrences across `R/`, `tests/`, and `app.R` before touching code; updating tests first; keeping `"summarize"` as an alias in `generate_preset()` for one phase before removing.

3. **DuckDB connection leak in `search_chunks_hybrid()` blocks Windows file operations** — every RAG call opens a DuckDB connection that is not closed, holding Windows file locks that block `delete_notebook_store()` and `rebuild_notebook_store()`. Avoid by: adding `on.exit({ DBI::dbDisconnect(store@con, shutdown = TRUE) })` for internally-created connections; fixing this BEFORE adding new synthesis features that multiply the callers; using `on.exit(..., add = TRUE)` to ensure the cleanup fires on error paths too.

4. **`section_hint` not encoded in PDF ragnar origins causes silent retrieval degradation** — structured synthesis features using `section_filter` silently fall back to "general" for pre-fix notebooks, giving broader-than-expected results with no error. Avoid by: fixing `insert_chunks_to_ragnar()` to call `encode_origin_metadata()`; adding fallback in new synthesis functions (if filtered results < 3, retry without filter); documenting degraded behavior for pre-fix notebooks.

5. **Dead code removal risks hidden callers in a 14,000+ LOC codebase** — `with_ragnar_store()` and `register_ragnar_cleanup()` look unused but may exist in tests or `.planning/` files; `with_ragnar_store()` implements the same `on.exit()` pattern needed for the connection leak fix. Avoid by: resolving the connection leak first (Pitfall 3), then deciding whether to delete or repurpose `with_ragnar_store()`; running full test suite before and after deletion.

## Implications for Roadmap

Based on combined research, the optimal phase structure is 4 phases matching the natural dependency graph: stabilize first, then add features in ascending complexity order.

### Phase 25: Bug Fixes and Tech Debt

**Rationale:** Tech debt items (#117 connection leak, #118 section_hint encoding, #119 dead code, #111 modal repeat, #110 seed paper, #116 cost pricing, #86 refresh behavior) are self-contained, reduce noise during feature work, and — critically — the connection leak fix (#117) is a prerequisite for adding more synthesis callers. The preset merge analysis also requires a grep audit before any code changes in Phase 26.

**Delivers:** Stable foundation with no file-locking risk on Windows; correct section filtering for newly uploaded PDFs; clean codebase (dead code removed after connection leak fix decision); bug-free paper deletion modal and seed paper flow; current model pricing in static table.

**Addresses:** Overview preset merge safety (grep audit in this phase enables safe execution in Phase 26); structured synthesis foundation (section_hint fix enables section-targeted retrieval for subsequent features)

**Avoids:** Pitfalls 2 (preset merge breaks observers), 3 (connection leak amplification), 4 (silent section filtering failure), 5 (dead code removal with hidden callers)

**Research flag:** No additional research needed. All root causes are identified from direct code analysis with specific file and line references. All fixes are 5-20 line changes.

### Phase 26: Unified Overview Preset (#98)

**Rationale:** Lowest complexity new feature. No new files, no new libraries, single prompt addition in `generate_preset()`. Validates the "merge buttons without breaking things" approach before tackling heavier features. Delivers immediate UX improvement for all users on every notebook.

**Delivers:** Single "Overview" button combining Summary + Key Points in one LLM call; both modules updated (document notebook + search notebook); existing Summarize/Key Points buttons kept as secondary options initially.

**Uses:** `generate_preset()` (existing); `commonmark::markdown_html()` (existing); no new libraries

**Implements:** `"overview"` case added to `presets` list in `R/rag.R`; button replacement in both module UI files; single `handle_preset("overview", "Overview")` handler replacing two handlers

**Avoids:** Pitfall 2 (preset merge) — Phase 25 grep audit is completed first; `"summarize"` kept as alias in `generate_preset()` during transition

**Research flag:** No additional research needed. Identical to existing preset pattern with documented files and change locations.

### Phase 27: Research Question Generator (#102)

**Rationale:** Medium complexity, follows the exact same pattern as `generate_conclusions_preset()`. Gap-to-question workflow is well-understood from competitor analysis. Introduces the "chained synthesis" concept (run gap analysis first, then generate questions) without requiring structured table output, validating the new function pattern before the more complex Literature Review Table.

**Delivers:** New `generate_research_questions()` function in `R/rag.R`; new `btn_rq_generator` button in search notebook offcanvas; 5-7 gap-grounded research questions as numbered markdown list with per-question rationale and gap citation.

**Uses:** `search_chunks_hybrid()` (existing, with #117 fix from Phase 25); gap-focused retrieval query ("research gaps limitations future work unanswered questions"); `chat_completion()` (existing); markdown output mode (not JSON mode)

**Implements:** `generate_research_questions()` in `R/rag.R`; `btn_rq_generator` and handler in `mod_search_notebook.R`

**Avoids:** Over-engineering — use markdown mode not JSON mode for question output (per STACK.md recommendation; numbered markdown list is easier to read and export than parsed JSON list)

**Research flag:** No additional research needed. Direct copy of `generate_conclusions_preset()` pattern with a new prompt.

### Phase 28: Literature Review Table (#99)

**Rationale:** Most complex feature, done last. Requires CSS addition, a different retrieval strategy (full SQL query rather than RAG), structured output quality risk from LLM compliance, and new packages. Building after Phases 25-27 ensures the connection leak fix is in place (reduces file locking risk during testing), the section_hint fix improves retrieval quality for newly uploaded PDFs, and the team has practice with the preset function pattern from Phase 27.

**Delivers:** New `generate_lit_review_table()` function using direct SQL retrieval (all abstracts, not RAG top-k); GFM markdown table output in chat with 5 standard columns (Author/Year, Methodology, Sample, Key Findings, Limitations); Bootstrap 5 table styling in `app.R`; export via existing markdown/HTML export mechanism; optional `DT` widget path if GFM quality proves poor.

**Uses:** `DT` 0.34.0 (new) + `writexl` 1.5.4 (new) for enhanced export; direct `dbGetQuery` for all-paper retrieval; `commonmark::markdown_html(extensions = TRUE)` (existing); `response_format = list(type = "json_object")` optional addition to `chat_completion()` for JSON fallback path

**Implements:** `.chat-markdown table` CSS in `app.R` via `tags$style()`; `generate_lit_review_table()` in `R/rag.R`; `btn_lit_review` and handler in `mod_search_notebook.R`; optional extension to `mod_document_notebook.R`

**Avoids:** Pitfall 1 (LLM schema adherence) via "Not reported" instruction + 30-paper cap + row count validation + user-facing error on parse failure; Anti-Pattern 1 (using RAG for lit review — direct SQL is required for complete coverage); Anti-Pattern 2 (returning structured data through message pipeline — use GFM markdown string instead)

**Research flag:** LLM table compliance testing required during implementation. Test with notebooks of 3, 10, and 20 papers. If GFM output quality is poor with the configured default model, the JSON path (`chat_completion()` with `response_format` + `DT` widget) is pre-documented in ARCHITECTURE.md as the fallback — implement during this phase if needed.

### Phase Ordering Rationale

- Phase 25 first because the connection leak (#117) is a multiplier risk (each new feature adds callers) and the preset merge grep audit is a prerequisite for Phase 26 safety
- Phase 26 before 27/28 because it validates the button-replacement pattern with zero data flow change before adding new `R/rag.R` functions
- Phase 27 before 28 because it introduces new functions in `R/rag.R` without the structured output complexity, proving the file modification approach in a lower-risk context
- Phase 28 last because it has the most moving parts (CSS, retrieval strategy change, LLM compliance risk, new packages) and benefits from all prior fixes being in place

### Research Flags

**No additional research needed for any phase** — all implementation details are documented in ARCHITECTURE.md and STACK.md with specific file names, line number references, and code-level patterns confirmed by direct codebase analysis.

**Phase requiring implementation validation during execution:**
- **Phase 28 (Literature Review Table):** LLM compliance with "output ONLY a table" instructions is model-dependent and cannot be validated pre-implementation. Test with real notebook data before considering phase complete. The JSON fallback path is pre-documented if needed.

**Phases with fully documented patterns (standard execution, no additional research):**
- **Phase 25:** All bug root causes confirmed by direct code analysis with line references
- **Phase 26:** Single prompt addition, identical to existing pattern
- **Phase 27:** Direct copy of `generate_conclusions_preset()` pattern with a new prompt

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official OpenRouter docs verified 2026-02-18; DT/writexl confirmed on CRAN with version numbers; all integration points verified by reading actual codebase files (`R/api_openrouter.R`, `R/rag.R`, etc.) |
| Features | MEDIUM-HIGH | Competitor analysis based on public docs and third-party reviews; Elicit's "99.4% accuracy" claim is marketing; extraction accuracy studies show nuance; core feature set and anti-feature decisions are well-validated |
| Architecture | HIGH | Based on direct codebase analysis with specific file paths and line numbers; existing patterns confirmed working; bug root causes identified with code evidence; integration options evaluated with pros/cons |
| Pitfalls | HIGH | DuckDB connection behavior confirmed via official issue tracker; OpenRouter structured output behavior confirmed via official docs + Response Healing announcement (what it does and does not fix); LLM positional bias confirmed by peer-reviewed research |

**Overall confidence:** HIGH

### Gaps to Address

- **LLM table compliance testing:** Cannot be resolved pre-implementation. The GFM markdown vs JSON path decision for Literature Review Table should be made after testing with the actual configured default model against real notebooks at 3, 10, and 20 paper scales. Both paths are pre-documented in ARCHITECTURE.md.
- **Search notebook Overview button scope:** Architecture research notes the search notebook currently only has a `conclusions_btn_ui` — confirm during Phase 26 whether search notebook needs `btn_overview` added or whether Overview is document-notebook-only for this milestone. Small scope question but needs an explicit decision.
- **Literature Review Table in document notebooks:** ARCHITECTURE.md recommends implementing in `mod_search_notebook.R` first (abstracts available) and optionally extending to `mod_document_notebook.R` (PDFs). Scope the document notebook extension explicitly in Phase 28 planning based on time available.
- **v4.x candidates (#101 Gap Analysis Report, #100 Methodology Extractor):** Correctly deferred to post-v4.0. Both have complete dependency analysis in FEATURES.md and can be implemented without additional research when prioritized.

## Sources

### Primary (HIGH confidence)

- [OpenRouter Structured Outputs docs](https://openrouter.ai/docs/guides/features/structured-outputs) — json_object vs json_schema mode, model support matrix — verified 2026-02-18
- [OpenRouter API Parameters docs](https://openrouter.ai/docs/api/reference/parameters) — response_format parameter syntax
- [OpenRouter Response Healing Announcement](https://openrouter.ai/announcements/response-healing-reduce-json-defects-by-80percent) — confirmed: fixes syntax only, not schema adherence
- [OpenRouter Provider Routing docs](https://openrouter.ai/docs/guides/routing/provider-selection) — require_parameters to prevent silent schema downgrade
- DT package v0.34.0 — rdrr.io/cran/DT — Buttons extension and DTOutput/renderDT confirmed
- writexl v1.5.4 — rdrr.io/cran/writexl — zero-dependency confirmed
- [DuckDB R Package GC Warning](https://github.com/duckdb/duckdb-r/issues/34) — confirmed connection leak mechanism
- [DuckDB File Locking Discussion](https://github.com/duckdb/duckdb/discussions/8126) — Windows file lock behavior confirmed
- Serapeum codebase — direct analysis of `R/rag.R`, `R/db.R`, `R/_ragnar.R`, `mod_document_notebook.R`, `mod_search_notebook.R`, `R/api_openrouter.R`, `R/utils_export.R`; issues #98, #99, #102, #110, #111, #116, #117, #118, #119

### Secondary (MEDIUM confidence)

- [Elicit: AI for Scientific Research](https://elicit.com/) — feature set confirmed; 99.4% accuracy claim is marketing
- [Data Extractions Using Elicit and Human Reviewers (Bianchi, 2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12462964/) — extraction accuracy nuances (PMC, peer-reviewed)
- [Evaluating Elicit as Semi-Automated Second Reviewer (Hilkenmeier et al., 2025)](https://journals.sagepub.com/doi/10.1177/08944393251404052) — extraction accuracy nuances
- [SciSpace Literature Review: 2025 Review](https://effortlessacademic.com/scispace-an-all-in-one-ai-tool-for-literature-reviews/) — third-party review
- [AnswerThis: Research Gap Finder](https://answerthis.io/ai/research-gap-finder) — gap-to-question workflow verified
- [LLM Positional Bias in Tables](https://arxiv.org/html/2305.13062v4) — U-shaped accuracy in large contexts (peer-reviewed)
- [LLM Table Format Accuracy Study](https://www.improvingagents.com/blog/best-input-data-format-for-llms) — Markdown-KV outperforms CSV for LLM accuracy

### Tertiary (context/patterns)

- [PICO Question Builder — INRA.AI](https://www.inra.ai/question-builder) — PICO framework (v4.x consideration only, deferred)
- [8 Best AI Tools for Literature Review (Dupple, 2026)](https://dupple.com/learn/best-ai-for-literature-review) — general landscape context
- [LLM Engineering Failure Modes 2025](https://medium.com/@gbalagangadhar/llm-engineering-in-2025-the-failure-modes-that-actually-matter-and-how-i-fix-them-ad1f6f1da77e) — structured output failure mode patterns

---
*Research completed: 2026-02-18*
*Ready for roadmap: yes*
