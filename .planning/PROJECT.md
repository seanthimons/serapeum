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

### Active

<!-- v4.0 Stability + Synthesis -->

**Phase 1 — Stabilize:**
- [ ] Fix seed paper not showing in abstract search (#110)
- [ ] Fix modal repeats multiple times on remove (#111)
- [ ] Fix cost tracking table not being updated (#116)
- [ ] Fix refresh button adding papers after removing (#86)
- [ ] Fix connection leak in search_chunks_hybrid (#117)
- [ ] Encode section_hint in PDF ragnar origins (#118)
- [ ] Remove dead code: with_ragnar_store, register_ragnar_cleanup (#119)
- [ ] Land PR #112: Fix duplicate toast notifications
- [ ] Land PR #115: Make keywords panel collapsible
- [ ] Fix tooltip overflow + citation network background color (#79, #89)
- [ ] Rebalance settings page two-column layout

**Phase 2 — Synthesis:**
- [ ] Merge Summarize + Key Points into unified Overview (#98)
- [ ] Literature Review Table — structured comparison matrix (#99)
- [x] Research Question Generator preset (#102) — Phase 27

### Out of Scope

- Recursive abstract searching (#11) — high complexity, future milestone
- PDF image pipeline (#44) — epic-level effort, future milestone
- Local model support (#8) — significant architecture change, future
- ~~Conclusion synthesis (#27)~~ — shipped in v2.1
- Audio overview (#22) — experimental, low priority
- Bulk DOI/.bib import (#24) — deferred, needs UX design
- Rich output preview (#50) — deferred, consider for next milestone
- Additional synthesis outputs (#63) — deferred, consider for next milestone
- Cross-notebook search — contradicts per-notebook isolation goal

## Context

Shipped v3.0 with ~14,000 LOC R across 13 modified production files (+2,009 / -692 from v2.1).
Tech stack: R + Shiny + bslib + DuckDB + OpenRouter + OpenAlex + igraph + visNetwork + commonmark + mirai + ragnar.
Architecture: Shiny module pattern (mod_*.R) with producer-consumer discovery modules.
7 database migrations (schema_migrations, topics, cost_log, blocked_journals, doi column, citation networks, section_hint).
Async infrastructure: ExtendedTask + mirai for non-blocking citation network builds and ragnar re-indexing with file-based interrupt flags.
RAG: ragnar is the sole backend — per-notebook DuckDB vector stores (`data/ragnar/{notebook_id}.duckdb`), hybrid VSS+BM25 retrieval, OpenRouter embedding. Section-targeted retrieval via keyword heuristics.
Known tech debt: #79 tooltip overflow, connection leak in search_chunks_hybrid, section_hint not encoded in PDF ragnar origins, dead code (with_ragnar_store, register_ragnar_cleanup).

## Constraints

- **Tech stack**: R + Shiny + bslib + DuckDB — no framework changes
- **API**: OpenRouter for LLM, OpenAlex for academic data — no new external services
- **Architecture**: Shiny module pattern (`mod_*.R`) — new features follow existing conventions
- **Local-first**: No server infrastructure; everything runs on user's machine
- **Dependencies**: igraph, visNetwork, commonmark (v2.0), ragnar (v3.0) — ragnar is a hard requirement
- **RAG**: ragnar is the sole retrieval backend — no legacy cosine similarity fallback

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

---
## Current Milestone: v4.0 Stability + Synthesis

**Goal:** Stabilize the codebase after rapid v1.0–v3.0 shipping, then deliver the highest-value AI synthesis outputs leveraging v3.0's ragnar infrastructure.

**Target features:**
- All known bugs fixed and tech debt resolved (clean foundation)
- Unified Overview preset replacing separate Summarize + Key Points
- Literature Review Table for structured paper comparison
- Research Question Generator for discovery-to-analysis workflow

---
*Last updated: 2026-02-19 after Phase 27*
