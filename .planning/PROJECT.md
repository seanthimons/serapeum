# Serapeum — Research Discovery Platform

## What This Is

Serapeum is a local-first research assistant built with R/Shiny that helps researchers find, filter, analyze, and synthesize academic papers. It combines document notebooks (upload PDFs, chat with per-notebook RAG) and search notebooks (OpenAlex paper search, quality filtering) with LLM-powered chat, slide generation, and conclusion synthesis. Three discovery modes — seed paper lookup, LLM-assisted query building, and topic hierarchy browsing — provide multiple entry points for finding relevant research. Discovery workflows are fluid: view a paper's abstract, explore its citation network, use it as a seed for a new search, filter by year range, or export results as BibTeX/CSV. RAG uses ragnar with per-notebook DuckDB vector stores for clean isolation and hybrid VSS+BM25 retrieval. Quality-of-life features include per-request cost tracking, dynamic model selection, interactive keyword filtering, journal quality controls, chat export to Markdown/HTML, async citation network builds with progress/cancellation, and AI-generated conclusion synthesis with disclaimers.

## Core Value

Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings.

## Requirements

### Validated

- ✓ Document notebooks with PDF upload and RAG chat — existing
- ✓ Search notebooks via OpenAlex with keyword filtering — existing
- ✓ Quality filtering (retraction watch, predatory journals/publishers) — existing
- ✓ Quarto slide deck generation from chat — existing
- ✓ Settings page with model configuration and API key validation — existing
- ✓ Deferred embedding workflow with "Embed Papers" button — existing
- ✓ Document type filters and OA/citation badges — existing
- ✓ Database migration versioning (INFRA-01) — v1.0
- ✓ Topics table schema (INFRA-02) — v1.0
- ✓ Fix abstract embedding #55 (DISC-01) — v1.0
- ✓ Seed paper search #25 (DISC-02) — v1.0
- ✓ Meta-prompt query builder #10 (DISC-03) — v1.0
- ✓ OpenAlex topics & discovery #40 (DISC-04) — v1.0
- ✓ Startup wizard UI #43 (DISC-05) — v1.0
- ✓ Rich sorting for search results #54 (DISC-06) — v1.0
- ✓ Fix slide generation citation size #51 (DISC-07) — v1.0
- ✓ Per-request LLM cost tracking (COST-01) — v1.1
- ✓ Session cost total in UI (COST-02) — v1.1
- ✓ Cost history and trends (COST-03) — v1.1
- ✓ Expanded model selection with pricing (MODL-01) — v1.1
- ✓ Model details in settings (MODL-02) — v1.1
- ✓ Keyword include filter (KWRD-01) — v1.1
- ✓ Keyword exclude filter (KWRD-02) — v1.1
- ✓ Visual keyword state distinction (KWRD-03) — v1.1
- ✓ Real-time keyword filtering (KWRD-04) — v1.1
- ✓ Predatory journal warning badges (JRNL-01) — v1.1
- ✓ Predatory journal filter toggle (JRNL-02) — v1.1
- ✓ Personal journal blocklist (JRNL-03) — v1.1
- ✓ Blocklist management (JRNL-04) — v1.1
- ✓ Fix 401 error on OpenAlex topic searches #59 (BUGF-01) — v1.2
- ✓ User-friendly API error messages #65 (BUGF-02) — v1.2
- ✓ Prevent tab-swap OpenAlex re-request #68 (BUGF-03) — v1.2
- ✓ Collapsible Journal Quality card #73 (UIPX-01) — v1.2
- ✓ Fix block badge misalignment #72 (UIPX-02) — v1.2
- ✓ DOI on abstract preview #66 (DOI-01) — v2.0
- ✓ Citation network graph #53 (CITE-01) — v2.0
- ✓ Export abstract to seeded paper search #67 (SEED-01) — v2.0
- ✓ Seeded search same view as abstract preview #71 (SEED-02) — v2.0
- ✓ Citation export #64 (EXPRT-01) — v2.0
- ✓ Export synthesis outputs #49 (EXPRT-02) — v2.0
- ✓ Synthesis preset icons and favicon (UIPX-01, UIPX-02) — v2.1
- ✓ Sidebar space optimization (UIPX-03) — v2.1
- ✓ Year range slider with histogram (YEAR-01, YEAR-02) — v2.1
- ✓ Citation network year filtering (YEAR-03) — v2.1
- ✓ Unknown year handling (YEAR-04) — v2.1
- ✓ Progress modal with cancellation (PROG-01, PROG-02, PROG-03) — v2.1
- ✓ Conclusion synthesis presets (SYNTH-01, SYNTH-02) — v2.1
- ✓ Section-targeted RAG retrieval (SYNTH-03) — v2.1
- ✓ Research gap synthesis (SYNTH-04) — v2.1
- ✓ AI-generated content disclaimers (SYNTH-05) — v2.1
- ✓ Per-notebook ragnar stores with deterministic paths (FNDTN-01) — v3.0
- ✓ Section_hint metadata encoding in ragnar origin (FNDTN-02) — v3.0
- ✓ Ragnar as hard dependency (FNDTN-03, LEGC-01) — v3.0
- ✓ Store lifecycle: auto-create, delete cascade, rebuild, orphan cleanup (LIFE-01..04) — v3.0
- ✓ Legacy RAG code removed: cosine similarity, dual codepaths, digest (LEGC-01..04) — v3.0
- ✓ Integration tests with mock embeddings (TEST-01) — v3.0
- ✓ Connection lifecycle with on.exit cleanup (TEST-02) — v3.0
- ✓ Fix seed paper not showing in abstract search #110 — v4.0
- ✓ Fix modal repeats multiple times on remove #111 — v4.0
- ✓ Fix cost tracking table not being updated #116 — v4.0
- ✓ Fix refresh button adding papers after removing #86 — v4.0
- ✓ Land PR #112: Fix duplicate toast notifications — v4.0
- ✓ Land PR #115: Make keywords panel collapsible — v4.0
- ✓ Unified Overview preset merging Summarize + Key Points #98 — v4.0
- ✓ Research Question Generator preset #102 — v4.0
- ✓ Literature Review Table — structured comparison matrix #99 — v4.0
- ✓ Fix ragnar embed closure serialization bug — v5.0
- ✓ Chat send button spinner — v5.0
- ✓ Catppuccin dark mode palette with WCAG AA contrast (DARK-01..05) — v6.0
- ✓ visNetwork dark canvas with rgba borders (COMP-02) — v6.0
- ✓ All components render correctly in dark mode (COMP-01, COMP-04) — v6.0
- ✓ Custom CSS uses Bootstrap variables, not hardcoded hex (COMP-03, COMP-05) — v6.0
- ✓ UI polish: spacing, typography, about page harmonization (UIPX-01..05) — v6.0
- ✓ bslib::input_dark_mode() replaces custom JS toggle — v6.0
- ✓ Cross-module dark mode validation passed (Phase 32) — v6.0
- ✓ Batch DOI parsing with multi-format support (BULK-01, BULK-02) — v7.0
- ✓ OpenAlex batch API with rate limiting and backoff (BULK-04) — v7.0
- ✓ Bulk DOI import UI with async progress (BULK-05, BULK-06) — v7.0
- ✓ BibTeX import with merge-not-replace enrichment (BULK-03, BULK-07, BULK-08) — v7.0
- ✓ Citation audit: backward refs + forward citations gap analysis (AUDIT-01..07) — v7.0
- ✓ Select-all batch import with tri-state checkbox (SLCT-01..03) — v7.0
- ✓ Slide healing: programmatic YAML, correct Quarto syntax, healing modal (SLIDE-01..04) — v7.0
- ✓ Multi-seed BFS engine with per-seed node cap and overlap detection (MSEED-01) — v8.0 Phase 40
- ✓ Shape-based overlap visualization: star/diamond/dot (MSEED-02) — v8.0 Phase 40
- ✓ Citation network module refactored for multi-seed state (MSEED-03) — v8.0 Phase 40
- ✓ Entry points: search notebook + BibTeX import seed buttons (MSEED-04) — v8.0 Phase 40
- ✓ Save/load multi-seed metadata as JSON array (MSEED-05) — v8.0 Phase 40
- ✓ Legend updated with star/diamond/dot shapes (MSEED-06) — v8.0 Phase 40
- ✓ Discovery + import workflow: missing papers tab with one-click import (MSEED-07) — v8.0 Phase 40
- ✓ Physics singularity collapse fix with position validation and debounced toggle (PHYS-01) — v9.0
- ✓ Ambient orbital drift for small/single-seed networks (PHYS-02) — v9.0
- ✓ Dynamic year filter bounds from actual network data (FILT-01) — v9.0
- ✓ Trim-to-influential toggle with adaptive thresholds and bridge preservation (FILT-02) — v9.0
- ✓ Custom HTML tooltip with container containment (TOOL-01) — v9.0
- ✓ Dark mode tooltip readability with Catppuccin styling (TOOL-02) — v9.0
- ✓ Connection leak fix + dead code removal (DEBT-01, DEBT-02) — v10.0
- ✓ Global color/theme/icon design system with swatch sheet (DSGN-01, DSGN-02) — v10.0
- ✓ Citation audit multi-paper import + abstract notebook sync (BUGF-01, BUGF-02) — v10.0
- ✓ Sidebar & button theming with semantic colors (THEM-01..05, DSGN-03, DSGN-04) — v10.0
- ✓ Methodology Extractor preset with section-targeted RAG (METH-01..05) — v10.0
- ✓ Gap Analysis Report preset with contradiction detection (GAPS-01..06) — v10.0

### Active

- ✓ Color picker with 4 native swatch+hex pairs, font selector, save-as-custom-theme (THME-08, THME-10, THME-11) — v16.0 Phase 60

## Current Milestone: v16.0 Content & Output Quality

**Goal:** Give users more control over generated content — rich slide themes with AI generation, editable AI preset prompts, and page-level citation traceability across all outputs.

**Target features:**
- Slide theme system: built-in swatches, color picker, custom .scss upload, AI-generated themes (#132)
- Prompt editing UI: view/edit system prompts for all AI presets with date-versioned history (#120)
- Citation traceability: page-level citations in all preset and slide outputs (#52)

### Out of Scope

- Recursive abstract searching (#11) — high complexity, future milestone
- PDF image pipeline (#44) — epic-level effort, future milestone
- Local model support (#8) — significant architecture change, future
- ~~Conclusion synthesis (#27)~~ — shipped in v2.1
- Audio overview (#22) — experimental, low priority
- ~~Bulk DOI/.bib import (#24)~~ — shipped in v7.0
- Rich output preview (#50) — deferred, consider for next milestone
- Cross-notebook search — contradicts per-notebook isolation goal

## Context

Shipped v10.0 with ~27,000 LOC R + 4,400 CSS across 18 production files. 13 milestones shipped (v1.0–v10.0), 49 phases, 86 plans.
Tech stack: R + Shiny + bslib + DuckDB + OpenRouter + OpenAlex + igraph + visNetwork + commonmark + mirai + ragnar + thematic + bib2df.
Architecture: Shiny module pattern (mod_*.R) with producer-consumer discovery modules.
Theme: Catppuccin Latte/Mocha via bs_theme() + centralized dark CSS in R/theme_catppuccin.R. bslib::input_dark_mode() for toggle. Semantic color policy with 76 icon wrappers.
9 database migrations (schema_migrations, topics, cost_log, blocked_journals, doi column, citation networks, section_hint, import_runs, citation_audit_cache).
Async infrastructure: ExtendedTask + mirai for non-blocking citation network builds, ragnar re-indexing, bulk imports, and citation audit with file-based interrupt flags.
RAG: ragnar is the sole backend — per-notebook DuckDB vector stores (`data/ragnar/{notebook_id}.duckdb`), hybrid VSS+BM25 retrieval, OpenRouter embedding. Section-targeted retrieval via keyword heuristics. 7 AI presets (Overview, Study Guide, Outline, Conclusions, Lit Review, Methods, Research Gaps) plus Slides and Export.
Slide generation: Programmatic YAML frontmatter via build_qmd_frontmatter(), LLM outputs content only, strip_llm_yaml() handles non-compliant models.
Known tech debt: section_hint not encoded in PDF ragnar origins (#118), secondary ragnar leak in ensure_ragnar_store(), 13 pre-existing test fixture failures.

## Constraints

- **Tech stack**: R + Shiny + bslib + DuckDB — no framework changes
- **API**: OpenRouter for LLM, OpenAlex for academic data — no new external services
- **Architecture**: Shiny module pattern (`mod_*.R`) — new features follow existing conventions
- **Local-first**: No server infrastructure; everything runs on user's machine
- **Dependencies**: igraph, visNetwork, commonmark (v2.0), ragnar (v3.0), thematic (v6.0), bib2df (v7.0) — ragnar is a hard requirement
- **RAG**: ragnar is the sole retrieval backend — no legacy cosine similarity fallback
- **Theme**: Catppuccin palette only — no custom color schemes or multiple theme variants
- **AI presets**: Two-row layout (Quick/Deep) — approaching prompt template refactor threshold at 10+ presets
- **Design system**: Semantic color policy + 76 icon wrappers in R/theme_catppuccin.R — primary=lavender, info=sapphire, custom peach/sky for sidebar (v10.0)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fix #55 before new features | Abstract embedding broken = search chat broken | ✓ Good — unblocked all RAG testing |
| Startup wizard as discovery hub | Users need clear entry points | ✓ Good — three clear paths |
| All three discovery paths (seed, query, topic) | Serve different research workflows | ✓ Good — cohesive discovery experience |
| Producer-consumer pattern for discovery modules | Clean separation, reused across 3 modules | ✓ Good — reusable pattern |
| Migration versioning via schema_migrations table | DuckDB lacks PRAGMA user_version | ✓ Good — clean upgrade path |
| LLM filter validation against allowlist | Prevents injection of invalid OpenAlex filters | ✓ Good — safe query generation |
| 30-day cache TTL for topics | Topics change infrequently | ✓ Good — fast browsing |
| CSS injection for slide citations | Self-contained slides without external deps | ✓ Good |
| API functions return structured lists (v1.1) | Needed for cost metadata alongside content | ✓ Good — all callers updated |
| Mutable pricing_env for dynamic model pricing | Live pricing from API without breaking compat | ✓ Good — accurate cost estimates |
| Composable filter chain pattern (v1.1) | keyword → journal quality → display | ✓ Good — clean modular pipeline |
| Blocked journals always hidden, predatory toggleable | Blocking is explicit user intent | ✓ Good — intuitive UX |
| Separate modules for new features (v1.1) | Prevent monolith growth | ✓ Good — reduced main file by 368 lines |
| Bare DOI storage format (v2.0) | BibTeX/citation managers expect 10.xxxx/yyyy, not URL | ✓ Good — compatible with all exporters |
| Nullable DOI column (v2.0) | DuckDB can't add NOT NULL to populated tables | ✓ Good — clean migration |
| Manual cascade delete for DuckDB (v2.0) | DuckDB doesn't support CASCADE on foreign keys | ✓ Good — referential integrity preserved |
| Store layout positions in DB (v2.0) | Avoid 1-2s layout recomputation on network reload | ✓ Good — instant reload |
| BFS frontier pruning at 100 (v2.0) | Prevent exponential API call explosion | ✓ Good — manageable network sizes |
| sqrt transform for citation node sizes (v2.0) | Power-law distribution would dominate graph | ✓ Good — readable visualization |
| Timestamp-based reactive deduplication (v2.0) | Same paper clicked twice needs unique event | ✓ Good — reliable reactive bridge |
| Placeholder-based LaTeX escaping (v2.0) | Prevents double-escaping of backslashes | ✓ Good — correct BibTeX output |
| UTF-8 BOM for BibTeX/HTML exports (v2.0) | Ensures reference managers/browsers read encoding | ✓ Good — wide compatibility |
| Embedded CSS in HTML export (v2.0) | Standalone files work offline in any browser | ✓ Good — no external deps |
| 400ms debounce on year slider (v2.1) | Prevents reactive storm during drag | ✓ Good — smooth UX |
| Apply Filter button for citation network (v2.1) | Prevents janky graph redraws during drag | ✓ Good — deliberate interaction |
| ExtendedTask + mirai for async builds (v2.1) | Replaces blocking withProgress, keeps UI responsive | ✓ Good — non-blocking |
| File-based interrupt flags (v2.1) | Mirai runs in isolated process, can't share memory | ✓ Good — reliable cross-process |
| Content-based section heuristics (v2.1) | Match chunk text not headings for robustness | ✓ Good — works across paper styles |
| OWASP instruction-data separation (v2.1) | Prevents prompt injection via RAG content | ✓ Good — security baseline |
| Three-level retrieval fallback (v2.1) | Section-filtered → unfiltered → direct DB | ✓ Good — works on all notebooks |
| Per-notebook ragnar stores (v3.0) | Eliminates cross-notebook pollution, faster retrieval | ✓ Good — clean isolation |
| Ragnar as hard dependency (v3.0) | Simpler code, no dual codepaths | ✓ Good — 554 lines of legacy code removed |
| Delete legacy embeddings, don't migrate (v3.0) | Fresh re-embed is cleaner than migration | ✓ Good — clean start with toast notification |
| Pipe-delimited metadata encoding (v3.0) | Human-readable format for section/doi/type in ragnar origin | ✓ Good — easier debugging than JSON |
| Lazy version check with session cache (v3.0) | Check ragnar on first use, not startup | ✓ Good — no penalty for non-RAG users (later removed when ragnar became hard dep) |
| Store health tri-state NULL/TRUE/FALSE (v3.0) | Avoids false positives on startup | ✓ Good — accurate state tracking |
| rag_ready separate from store_healthy (v3.0) | Migration vs corruption are different concerns | ✓ Good — independent lifecycles |
| ragnar store version=1 required (v3.0) | insert_chunks_to_ragnar creates v1-format chunks | ✓ Good — caught by integration tests |
| DBI::dbDisconnect(store@con) for S7 objects (v3.0) | S7 DuckDBRagnarStore has no DBI method registered | ✓ Good — caught by integration tests |
| Standalone generate_research_questions() (v4.0) | Separate function, not added to generate_preset() — different prompt structure, paper metadata enrichment | ✓ Good — clean separation |
| %in% set membership for disclaimer check (v4.0) | Extensible for future preset types vs chained identical() | ✓ Good — Literature Review Table will benefit |
| Catppuccin Latte/Mocha palette (v6.0) | Official palette with proven WCAG contrast ratios, not ad-hoc colors | ✓ Good — 11.8:1 contrast ratio |
| Centralized dark CSS via bs_add_rules() (v6.0) | Single function generates all dark overrides, avoids scatter | ✓ Good — DARK-05 satisfied |
| Inline block expression for bs_theme (v6.0) | Keeps theme creation + augmentation together in page_sidebar() | ✓ Good — readable, no separate variable |
| rgba borders for viridis node visibility (v6.0) | Semi-transparent borders work on both light and dark canvas | ✓ Good — all viridis scales visible |
| bslib::input_dark_mode() over custom JS (v6.0) | Native thematic integration, fewer moving parts | ✓ Good — eliminated 13 lines of custom JS |
| bg-body-secondary for panels, bg-body-tertiary for badges (v6.0) | Bootstrap semantic classes adapt to both themes automatically | ✓ Good — zero dark mode overrides needed |
| thematic_shiny() for auto-themed R plots (v6.0) | Plot backgrounds adapt to theme without manual CSS | ✓ Good — future-proofed for any R plots added |
| CSS !important for Sass-compiled value box text (v6.0) | Sass compilation bakes colors at build time, runtime override needed | ✓ Good — Mocha Crust text visible in dark mode |
| Pipe-separated batch DOI filter syntax (v7.0) | OpenAlex supports OR via pipe in filter values | ✓ Good — 50 DOIs per request |
| Import run created in main session before mirai (v7.0) | Avoids FK constraint issues in worker process | ✓ Good — clean async pattern |
| db_path parameter for worker DB connections (v7.0) | Mirai workers need independent DuckDB connections | ✓ Good — no cross-process sharing |
| Merge-not-replace for BibTeX enrichment (v7.0) | Preserve .bib metadata when OpenAlex has partial data | ✓ Good — no data loss |
| Single-query SQL aggregation for citation audit (v7.0) | Avoids N+1 query explosion with large collections | ✓ Good — handles 500+ papers |
| Programmatic YAML frontmatter for slides (v7.0) | LLM-generated YAML was fragile; regex injection mangled themes | ✓ Good — eliminated entire class of bugs |
| LLM outputs content only, no YAML (v7.0) | Separation of concerns: app handles config, LLM handles content | ✓ Good — consistent across models |
| Quarto ^[text] inline footnotes (v7.0) | Correct Quarto syntax; ^1 and [^1] were wrong for RevealJS | ✓ Good — validated against Quarto docs via Context7 |
| Concrete syntax examples in prompts (v7.0) | Correct/wrong examples work better than abstract instructions | ✓ Good — 8/8 pass rate across Claude Sonnet 4 and Gemini Flash |
| Per-seed BFS loop (v8.0) | Simpler deduplication than unified traversal | ✓ Good — clean merge + overlap detection |
| seed_paper_ids as JSON array (v8.0) | Flexible storage for variable seed counts | ✓ Good — backward compat with single-seed |
| Shape encoding for overlap (v8.0) | Diamond for overlap preserves year color gradient | ✓ Good — three-shape system works |
| navset_card_tab for side panel (v8.0) | Tabbed Paper Details + Missing Papers | ✓ Good — clean discovery workflow |
| Always pass full solver config on physics re-enable (v9.0) | vis.js reverts to barnesHut without explicit config | ✓ Good — eliminated collapse bug |
| Position validation on data, not render flags (v9.0) | Render flags unreliable for saved graph loading | ✓ Good — deterministic behavior |
| Custom tooltip via htmlwidgets::onRender (v9.0) | vis.js title uses textContent not innerHTML | ✓ Good — HTML rendering, containment, dark mode |
| tooltip_html column + title=NA pattern (v9.0) | Separate custom data from vis.js default tooltip | ✓ Good — no dual-tooltip conflict |
| Adaptive citation percentile for trim (v9.0) | Different thresholds for different network sizes | ✓ Good — balanced filtering |
| Lavender for primary, not blue (v10.0) | Blue too plain in light mode; lavender has more character | ✓ Good — matches existing theme, no breaking change |
| Info semantic color: blue → sapphire (v10.0) | Better visual distinction from primary lavender | Pending — Phase 47 will apply |
| Semantic icon wrappers in theme_catppuccin.R (v10.0) | Centralized icon-to-action mapping for consistency | ✓ Good — 20 wrappers, color-neutral |

## Current State

**Latest shipped:** v11.0 Search Notebook UX (2026-03-11)
**Total milestones:** 14 shipped (v1.0–v11.0)
**Total phases:** 61 complete across 101 plans
**Current:** v16.0 Content & Output Quality

**Phase 61 complete:** AI theme generation — users describe a theme in plain language, LLM returns validated JSON (5 fields: bg, fg, accent, link, font), hex colors validated, font matched against curated list with fallback, values populate color pickers for manual tweaking before save.

**Known tech debt:**
- Secondary ragnar leak in `ensure_ragnar_store()` (mod_search_notebook.R)
- 13 pre-existing test fixture failures (missing schema columns)
- Settings page two-column layout rebalancing

---
*Last updated: 2026-03-20 after phase 61 completion*
