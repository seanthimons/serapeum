# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** Phase 22 - Module Migration (v3.0 Ragnar RAG Overhaul)

## Current Position

Phase: 22 of 24 (Module Migration)
Plan: 0 of ? in current phase
Status: Ready to plan
Last activity: 2026-02-17 — Phase 21 verified and approved, fixed settings card overflow

Progress: [██████████████████████████████████████░░] 93% (37/39 estimated plans completed across all milestones)

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
| v3.0 | 20-24 | 5/? | In progress |

**Recent Trend:**
- v2.1 completed in <1 day (4 phases, 7 plans)
- Velocity: Stable to improving
- Trend: Fast iteration on focused milestones

*Will update with v3.0 plan metrics as execution proceeds*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

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
Ready for Phase 22 — switch modules to per-notebook ragnar stores.

## Session Continuity

Last session: 2026-02-17 (Phase 21 approved, two bugfixes: settings card overflow + cleanup timestamps)
Stopped at: Phase 22 ready to plan
Resume file: none

**Next action:** Plan Phase 22 (Module Migration) — switch document and search notebook modules to per-notebook ragnar stores.
