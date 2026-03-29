# Milestones

## v20.0 Shiny Reactivity Cleanup (Shipped: 2026-03-29)

**Phases completed:** 4 phases (64-67), 6 plans

**Key accomplishments:**

- Added req()/isolate() guards and input validation to prevent NULL crashes and infinite reactive loops (GARD-01..03)
- Hardened observer lifecycle with destroy-before-create pattern and cached docs_reactive() (LIFE-01..03)
- Added session$onSessionEnded cleanup hooks for slides and notebook modules (LIFE-04)
- Extracted shared show_error_toast() utility with modal-then-notify pattern across all 9 preset handlers (ERRH-01..02)
- Normalized SQL migration DDL to idempotent IF NOT EXISTS syntax for fresh installs (INFR-01)
- Added fresh-install startup regression tests for the DuckDB migration path

**Stats:** 7 files changed, +352 / -131 lines, ~82,900 R LOC + ~4,400 CSS LOC
**Timeline:** 3 days (2026-03-27 → 2026-03-29)
**Git range:** feat(64-01) → fix(67)

---

## v10.0 Theme Harmonization & AI Synthesis (Shipped: 2026-03-06)

**Phases completed:** 6 phases, 10 plans, 4 tasks

**Key accomplishments:**

- Fixed DuckDB connection leak in search_chunks_hybrid and removed dead ragnar code with automated regression tests
- Catppuccin design system with semantic color policy, 76 icon wrappers, and visual swatch sheet for light/dark validation
- Citation audit bug fixes — multi-paper import with duplicate tracking and abstract notebook sync
- Sidebar & button theming — custom peach/sky CSS classes, all 206 icon calls migrated to semantic wrappers, search buttons recolored to lavender
- Methodology Extractor preset — section-targeted RAG extracting study design, data sources, and statistical methods into GFM tables with DOI citations
- Gap Analysis Report preset — cross-paper synthesis identifying 5 gap dimensions with contradiction detection and blockquote formatting

**Stats:** 23 files changed, +3,327 / -298 lines, 27,046 R LOC + 4,446 CSS LOC
**Timeline:** 3 days (2026-03-04 → 2026-03-06)
**Git range:** test(44-01) → fix(49-02)

---

## v1.0 Fix + Discovery (Shipped: 2026-02-11)

**Phases completed:** 5 phases, 9 plans, 0 tasks

**Key accomplishments:**

- Database migration versioning system with automatic schema upgrades on app startup
- Fixed critical abstract embedding bug (#55) that broke all search notebook RAG chat
- Seed paper discovery module — find related papers via DOI/title through citation relationships
- LLM-assisted query builder with OpenAlex filter validation and rich result sorting
- Topic explorer with 4-level OpenAlex hierarchy browsing and local DuckDB caching
- Startup wizard guiding new users to three discovery paths, with slide citation CSS fix

**Stats:** 42 files changed, +9,006 / -58 lines, 9,856 R LOC total
**Timeline:** 2 days (2026-02-10 → 2026-02-11)
**Git range:** feat(00-foundation-01) → feat(04-01)

---

## v1.2 Stabilization (Shipped: 2026-02-12)

**Phases completed:** 2 phases (9-10), 2 plans

**Key accomplishments:**

- Fixed 401 error on OpenAlex topic searches (#59)
- User-friendly error messages for OpenAlex/OpenRouter API failures (#65)
- Prevented OpenAlex re-request when swapping tabs (#68)
- Collapsible Journal Quality card (#73)
- Fixed block journal badge vertical misalignment (#72)

**Stats:** 5 files changed, bug fixes and UI polish
**Timeline:** 1 day (2026-02-12)
**Git range:** feat(09-01) → feat(10-01)

---

## v1.1 Quality of Life (Shipped: 2026-02-11)

**Phases completed:** 4 phases (5-8), 6 plans
**Deferred:** Phase 9 (Bulk Import) → v1.2

**Key accomplishments:**

- Per-request cost tracking with session totals, cost history, and trend visualization
- Dynamic chat model selector with 10+ OpenRouter models, live pricing, and model info panel
- Tri-state keyword filtering (neutral/include/exclude) replacing destructive delete-by-keyword
- Journal quality controls: predatory warnings, personal blocklist, blocklist management modal
- Modularized search notebook: extracted 3 new modules, reduced monolith from 1,778 to ~1,410 lines

**Stats:** 17 files changed, +1,569 / -287 lines
**Timeline:** 13 days (2026-01-29 → 2026-02-11)
**Git range:** feat(05-01) → feat(08-02)

---

## v2.0 Discovery Workflow & Output (Shipped: 2026-02-13)

**Phases completed:** 5 phases (11-15), 8 plans, ~16 tasks

**Key accomplishments:**

- DOI storage infrastructure with migration, normalization, batch backfill, and clickable DOI links in abstract preview
- Interactive citation network visualization with BFS traversal, visNetwork graphs, save/load persistence, and cross-link discovery via referenced_works
- Seamless export-to-seed workflow — one-click "Use as Seed" from abstract detail navigates to seed discovery with auto-lookup
- Citation export as BibTeX and CSV with LaTeX escaping, collision-free citation keys, and 79 unit tests
- Synthesis export — chat conversations downloadable as Markdown or standalone HTML from both notebook types

**Stats:** 40 files changed, +8,342 / -57 lines, ~11,500 R LOC total
**Timeline:** 14 days (2026-01-29 → 2026-02-12)
**Git range:** feat(11-01) → feat(15-01)
**Tech debt accepted:** #79 tooltip overflow, #80 progress modal, missing Phase 12 VERIFICATION.md

---

## v2.1 Polish & Analysis (Shipped: 2026-02-13)

**Phases completed:** 4 phases (16-19), 7 plans

**Key accomplishments:**

- Distinct preset icons, browser favicon (blue "S" lettermark), and sidebar optimization reclaiming 60-90px vertical space
- Interactive year range slider with histogram preview for search notebooks, Apply Filter button for citation network
- Async citation network builds with ExtendedTask + mirai, file-based interrupt flags, progress modal with cancellation and partial results
- Conclusion synthesis with section-targeted RAG retrieval, keyword-based section detection heuristics, and OWASP LLM01:2025 hardened prompts
- AI-generated content disclaimer banners on all synthesis outputs across both notebook types

**Stats:** 10 files changed, +1,244 / -142 lines, 12,569 R LOC total
**Timeline:** <1 day (2026-02-13)
**Git range:** feat(16-01) → feat(19-02)
**Tech debt accepted:** Synthesis response time (large context), chat UX spinners needed

---

## v3.0 Ragnar RAG Overhaul (Shipped: 2026-02-17)

**Phases completed:** 5 phases (20-24), 9 plans

**Key accomplishments:**

- Per-notebook ragnar stores with deterministic path construction and pipe-delimited metadata encoding for clean notebook isolation
- Full store lifecycle management — auto-creation on first content, deletion cascade, corruption detection with rebuild modal, and orphan cleanup in settings
- Both document and search notebook modules migrated to per-notebook stores with async cancellable re-indexing (ExtendedTask + mirai) and migration prompts
- Legacy code removal — eliminated 554 lines of dual-codepath RAG code; ragnar is now the sole unconditional backend with rlang::hash replacing digest::digest
- End-to-end integration tests with mock embeddings validating full per-notebook ragnar pipeline
- Production bugs auto-fixed during integration testing: ragnar store version compatibility (v1 format) and S7 object dbDisconnect

**Stats:** 13 production files changed, +2,009 / -692 lines; 48 commits total
**Timeline:** 2 days (2026-02-16 → 2026-02-17)
**Git range:** gsd/v1.0-ragnar-rag-overhaul branch
**Tech debt accepted:** Connection leak in search_chunks_hybrid, section_hint not encoded in PDF ragnar origins, dead code (with_ragnar_store, register_ragnar_cleanup)

---

## v4.0 Stability + Synthesis (Shipped: 2026-02-22)

**Phases completed:** 4 phases (25-28), 6 plans

**Key accomplishments:**

- Bug fixes: seed paper display (#110), modal repeat (#111), cost tracking updates (#116), refresh after remove (#86)
- Landed PR #112 (duplicate toasts) and PR #115 (collapsible keywords)
- Unified Overview preset merging Summarize + Key Points into single synthesis output
- Research Question Generator as standalone preset with paper metadata enrichment
- Literature Review Table — structured comparison matrix for search notebook papers

**Timeline:** 3 days (2026-02-18 → 2026-02-19)
**Git range:** gsd/v4.0-stability-synthesis branch

---

## v5.0 Fix Document Embeddings (Shipped: 2026-02-22)

**Phases completed:** 1 phase (29), 1 plan

**Key accomplishments:**

- Fixed critical ragnar embed closure serialization bug — runtime @embed property attachment bypasses broken deserialization
- Fixed origin metadata parsing and stale chunk cleanup on delete
- Added chat send button spinner for user feedback

**Timeline:** <1 day (2026-02-22)
**Git range:** gsd/v5.0-fix-document-embeddings branch

---

## v6.0 Dark Mode + UI Polish (Shipped: 2026-02-25)

**Phases completed:** 3 phases (30-32), 8 plans

**Key accomplishments:**

- Catppuccin Latte/Mocha palette via bs_theme() + bs_add_rules() with 11.8:1 contrast ratio
- Centralized dark CSS in R/theme_catppuccin.R (~244 lines) — single source of truth for all dark overrides
- visNetwork dark canvas with rgba borders for viridis node visibility across all color scales
- Replaced all hardcoded colors with theme-aware Bootstrap classes (bg-body-secondary, text-body, etc.)
- Replaced custom JS toggle with bslib::input_dark_mode() for native thematic integration
- Phase 32 validation passed all checks with 0 code changes needed

**Stats:** 14 files changed, +454 / -105 lines
**Timeline:** 3 days (2026-02-22 → 2026-02-25)
**Git range:** gsd/v6.0-dark-mode-ui-polish branch

---

## v7.0 Citation Audit + Quick Wins (Shipped: 2026-02-27)

**Phases completed:** 7 phases (33-39), 14 plans

**Key accomplishments:**

- Robust batch DOI parsing with multi-format support (URLs, bare, comma/newline-separated) and categorized error reporting
- OpenAlex batch API with 50-DOI batching, rate limiting, and exponential backoff on 429 errors
- Full bulk DOI import UI — modal workflow with paste/upload, async ExtendedTask execution, progress bars, retry, and import history
- BibTeX import via bib2df with merge-not-replace metadata enrichment and citation network seeding
- Citation audit — one-click gap analysis finding frequently-cited missing papers via backward references + forward citations, with ranked results and single-click import
- Select-all batch import with tri-state checkbox, confirmation for large selections, and async progress
- Slide healing overhaul — programmatic YAML frontmatter (eliminated regex injection), correct Quarto ^[text] footnote syntax, healing modal with quick-pick chips, 2-retry fallback to template

**Stats:** 21 files changed, +5,696 / -199 lines, 83 commits
**Timeline:** 3 days (2026-02-25 → 2026-02-27)
**Git range:** gsd/v1.0-citation-audit-quick-wins branch
**Known gaps:** BULK-01/02/04/05/06 checkboxes were not updated in REQUIREMENTS.md during execution (phases completed, bookkeeping only)

---

## v8.0 Multi-Seeded Citation Network (Shipped: 2026-03-03)

**Phases completed:** 2 phases (40, 40.1), 6 plans

**Key accomplishments:**

- Multi-seed BFS citation network engine with per-seed node caps, deduplication, and overlap detection for papers appearing in 2+ seed traversals
- Shape-based overlap visualization: star (seed), diamond (overlap), dot (regular) — preserves year color gradient
- Citation network module refactored for multi-seed state with search notebook + BibTeX import entry points
- Missing papers discovery panel (navset_card_tab) with one-click import workflow for papers found in citations but not in notebook
- Save/load multi-seed metadata as JSON array with backward compatibility for single-seed networks
- Hotfix (Phase 40.1): seed network crash, progress file race condition, DOI-to-Work-ID fallback, physics toggle relocation, button alignment, load network crash fix

**Stats:** 7 R files changed, +99 / -38 lines, ~20,000 R LOC total
**Timeline:** 2 days (2026-03-01 → 2026-03-02)
**Git range:** Phase 40 + Phase 40.1 on main

---

## v9.0 Network Graph Polish (Shipped: 2026-03-04)

**Phases completed:** 3 phases (41-43), 3 plans

**Key accomplishments:**

- Fixed singularity collapse on physics toggle with position validation and debounced controls (PHYS-01)
- Added ambient orbital drift for small/single-seed networks after stabilization (PHYS-02)
- Dynamic year filter bounds from actual network data + trim-to-influential toggle with bridge preservation (FILT-01, FILT-02)
- Custom HTML tooltip replacing vis.js default — proper rendering, dark mode styling, container containment (TOOL-01, TOOL-02)
- Legacy saved network compatibility: paper_title preservation and HTML sanitization

**Stats:** 24 commits, 2 days (2026-03-03 → 2026-03-04)
**Key files:** R/mod_citation_network.R, R/citation_network.R, R/db.R

---
