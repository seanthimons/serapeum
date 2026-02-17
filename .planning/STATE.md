# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** Phase 24 - Integration Testing & Cleanup (v3.0 Ragnar RAG Overhaul) — COMPLETE

## Current Position

Phase: 24 of 24 (Integration Testing & Cleanup)
Plan: 1 of 1 in current phase (phase complete)
Status: Complete — v3.0 Ragnar RAG Overhaul complete
Last activity: 2026-02-17 — Completed 24-01: integration tests, toast notification, ragnar store bug fixes

Progress: [████████████████████████████████████████] 100% (42/42 estimated plans completed across all milestones)

## Performance Metrics

**Velocity:**
- Total plans completed: 35 (across v1.0-v3.0)
- Average duration: ~2.5 minutes (v3.0 plans 01-03)
- Total execution time: ~3 days across 6 milestones

**By Milestone:**

| Milestone | Phases | Plans | Status |
|-----------|--------|-------|--------|
| v1.0 | 0-4 | 9 | Complete |
| v1.1 | 5-8 | 6 | Complete |
| v1.2 | 9-10 | 2 | Complete |
| v2.0 | 11-15 | 8 | Complete |
| v2.1 | 16-19 | 7 | Complete |
| v3.0 | 20-24 | 5 | Complete |

**Recent Trend:**
- v2.1 completed in <1 day (4 phases, 7 plans)
- v3.0 completed across 5 phases: foundation, store lifecycle, module migration (3 plans), legacy removal, integration testing
- Velocity: Stable to improving
- Trend: Fast iteration on focused milestones

**v3.0 Plan Metrics:**
| Phase | Duration | Tasks | Files |
|-------|----------|-------|-------|
| 24-integration-testing-cleanup P01 | 9min | 2 tasks | 3 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- **rag_ready separate from store_healthy (22-02)**: store_healthy tracks corruption recovery (Phase 21), rag_ready tracks migration need (Phase 22) — different lifecycles, different triggers
- **rag_available = store_healthy AND rag_ready (22-02)**: both must be TRUE for chat/RAG; JS handler placed in UI not modal to avoid duplicate handler registration
- **rlang::hash replaces digest::digest (23-01)**: Same chunk hashing semantics, no separate digest dependency required — rlang is already a transitive dependency
- **NULL guard in search_chunks_hybrid (23-01)**: file.exists(NULL) errors without ragnar_available() guard — added !is.null() check before file.exists()
- **Embed not blocked by rag_available (22-03)**: Embed is the mechanism to create the per-notebook store for new papers; blocking embed would create chicken-and-egg
- **Store_healthy NULL on open (22-03)**: Migration check observeEvent sets it accurately; starting NULL avoids false positives before check completes
- **uiOutput for rag-gated buttons (22-03)**: renderUI renders disabled HTML button tag when rag_available=FALSE — no JS needed
- **NULL default ragnar_store_path (22-01)**: Derive path inside search_chunks_hybrid from notebook_id; callers need not know store path
- **Structured rebuild return (22-01)**: list(success, count, partial, error) distinguishes user cancellation (partial=TRUE) from errors
- **Store health tri-state NULL/TRUE/FALSE (21-02)**: NULL=unchecked avoids false positives on startup; proactive check fires on notebook open not app start — avoids penalizing non-RAG users
- **Rebuild modal easyClose=FALSE (21-02)**: Forces explicit user choice (Rebuild or Later) for corruption recovery
- **Orphan cleanup as simple settings button (21-02)**: Under Maintenance header, not a dedicated maintenance screen — keeps settings clean
- **Lazy version check with session cache (20-02)**: Check ragnar version on first RAG use (not startup), cache result per session — avoids penalizing non-RAG users
- **Warn-but-allow version mismatch (20-02)**: Allow ragnar version differences with warnings, not blocking — renv will handle strict pinning later
- **Aggressive on.exit() cleanup (20-02)**: Close connections on ANY exit (error or success) — can optimize to selective cleanup later
- **Pipe-delimited metadata encoding (20-01)**: Human-readable format for section/doi/type metadata in ragnar origin field — easier debugging than JSON
- **Per-notebook ragnar stores (v3.0)**: Eliminates cross-notebook pollution, faster retrieval — isolate stores by notebook_id
- **Ragnar as hard dependency (v3.0)**: Simpler code, no dual codepaths — remove all legacy fallback
- **Delete legacy embeddings, don't migrate (v3.0)**: Fresh re-embed is cleaner than migration — user choice to start fresh
- **Section-targeted RAG (v2.1)**: Keyword heuristics classify chunks by section type for focused synthesis
- **ExtendedTask + mirai for async (v2.1)**: Non-blocking citation builds with progress/cancellation

- **ragnar store version=1 required (24-01)**: insert_chunks_to_ragnar creates v1-format chunks; ragnar_store_create must specify version=1 (default v2 causes mismatch error)
- **ragnar disconnect via store@con (24-01)**: DBI::dbDisconnect(store, shutdown=TRUE) fails for S7 DuckDBRagnarStore objects — must use store@con slot

See PROJECT.md for full decision history.

### Pending Todos

- [#79](https://github.com/seanthimons/serapeum/issues/79): Tooltip overflow (deferred, not in v3.0)
- Move to renv for package namespace management (tooling)
- Fix citation network background color blending (ui) — bundle with #79
- Explore partial BFS graph as intentional visualization mode

### Blockers/Concerns

**v3.0 Migration Considerations:**
- ~~DuckDB connection locking risk with multiple open ragnar stores~~ — RESOLVED: on.exit() cleanup + session hooks in Phase 20
- ~~Section_hint encoding in origin field needs validation~~ — RESOLVED: pipe-delimited encoding with graceful fallback in Phase 20
- ~~Ragnar 0.3.0 API stability unknown~~ — RESOLVED: version check with warn-but-allow pattern in Phase 20
- User data loss if legacy deletion happens before validation (dual-write period recommended) — Phase 23-24

Phase 20 foundation complete. Phase 21 store lifecycle verified and approved.
Phase 22 complete — all 3 plans done: backend wiring (22-01), document notebook migration (22-02), search notebook migration (22-03).
Phase 23 complete — 23-01: single-sweep removal of all legacy RAG code from 6 production files + test cleanup.
Phase 24 complete — 24-01: deferred toast for legacy store deletion, integration tests (workflow/section_hint/legacy cleanup), ragnar store bug fixes.

v3.0 Ragnar RAG Overhaul complete.

## Session Continuity

Last session: 2026-02-17 (24-01 complete: integration tests passing, toast notification added, ragnar store version and disconnect bugs fixed)
Stopped at: Completed 24-01-PLAN.md
Resume file: none

**Next action:** v3.0 milestone complete. No further planned phases.
