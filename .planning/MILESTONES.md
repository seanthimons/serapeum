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

