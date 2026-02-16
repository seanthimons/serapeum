# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** Phase 20 - Foundation & Connection Safety (v3.0 Ragnar RAG Overhaul)

## Current Position

Phase: 20 of 24 (Foundation & Connection Safety)
Plan: 1 of 2 in current phase
Status: In progress
Last activity: 2026-02-16 — Completed 20-01 (Ragnar Path & Metadata Helpers)

Progress: [████████████████████████████████░░░░] 84% (33/39 estimated plans completed across all milestones)

## Performance Metrics

**Velocity:**
- Total plans completed: 33 (across v1.0-v3.0)
- Average duration: ~2 minutes (v3.0 plan 01)
- Total execution time: ~3 days across 6 milestones

**By Milestone:**

| Milestone | Phases | Plans | Status |
|-----------|--------|-------|--------|
| v1.0 | 0-4 | 9 | Complete |
| v1.1 | 5-8 | 6 | Complete |
| v1.2 | 9-10 | 2 | Complete |
| v2.0 | 11-15 | 8 | Complete |
| v2.1 | 16-19 | 7 | Complete |
| v3.0 | 20-24 | 1/? | In progress |

**Recent Trend:**
- v2.1 completed in <1 day (4 phases, 7 plans)
- Velocity: Stable to improving
- Trend: Fast iteration on focused milestones

*Will update with v3.0 plan metrics as execution proceeds*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

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
- DuckDB connection locking risk with multiple open ragnar stores (needs single-active-store pattern)
- Section_hint encoding in origin field needs validation (may need chunks table sidecar backup)
- Ragnar 0.3.0 API stability unknown (pin version, add compatibility checks)
- User data loss if legacy deletion happens before validation (dual-write period recommended)

These are research-identified pitfalls to address during planning.

## Session Continuity

Last session: 2026-02-16 (phase 20 plan 01 execution)
Stopped at: Completed 20-01-PLAN.md — Ragnar Path & Metadata Helpers
Resume file: .planning/phases/20-foundation-connection-safety/20-01-SUMMARY.md

**Next action:** Execute 20-02-PLAN.md (Connection Safety)
