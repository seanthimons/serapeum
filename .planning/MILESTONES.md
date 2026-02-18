# Milestones

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

