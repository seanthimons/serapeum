# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-25)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** Phase 33 - DOI Parsing Utilities

## Current Position

Phase: 33 of 39 (DOI Parsing Utilities)
Plan: 0 of ? in current phase
Status: Ready to plan
Last activity: 2026-02-25 — Roadmap created for v7.0 milestone

Progress: [████████████████████░░░░░░░░░░] 82% (32/39 phases complete across all milestones)

## Performance Metrics

**Velocity:**
- Total plans completed: 53 (across v1.0-v6.0)
- Total phases completed: 32 (across 9 milestones)
- v7.0 plans completed: 0

**Recent Milestones:**
- v6.0 (Phases 30-32): 8 plans, 3 days (2026-02-22 → 2026-02-25)
- v5.0 (Phase 29): 1 plan, <1 day (2026-02-22)
- v4.0 (Phases 25-28): 6 plans, 3 days (2026-02-18 → 2026-02-19)

**Recent Trend:**
- Velocity stable across recent milestones
- Small milestones (v5.0) ship in <1 day
- Medium milestones (v4.0, v6.0) ship in 2-3 days

*Will update after first v7.0 plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting v7.0 work:

- **v2.0**: Bare DOI storage format (10.xxxx/yyyy, not URL) — citation managers expect this
- **v2.0**: Store layout positions in DB to avoid recomputation — will apply to citation audit caching
- **v2.0**: BFS frontier pruning at 100 — prevents exponential API explosion, applies to citation audit
- **v2.1**: ExtendedTask + mirai for async builds — proven pattern for citation audit and bulk imports
- **v2.1**: File-based interrupt flags — cross-process cancellation for async operations
- **v3.0**: Per-notebook ragnar stores — clean isolation pattern continues in v7.0

### Pending Todos

- Explore partial BFS graph as intentional visualization mode
- Secondary ragnar leak: ensure_ragnar_store() in mod_search_notebook.R L2061
- 13 pre-existing test fixture failures (missing schema columns: section_hint, doi)

### Blockers/Concerns

**Known tech debt entering v7.0:**
- Connection leak in search_chunks_hybrid (#117)
- Section_hint not encoded in PDF ragnar origins (#118)
- Dead code: with_ragnar_store, register_ragnar_cleanup (#119)
- Tooltip overflow (#79)

**v7.0-specific risks (from research):**
- OpenAlex rate limiting (100 req/sec, $1/day budget) — Phase 34 must implement batching + delays
- BibTeX parsing fragility with real-world files — Phase 36 needs tolerant parsers
- SQL N+1 query explosion in citation audit — Phase 37 must use single-query aggregation
- Memory explosion with large select-all batches — Phase 38 needs batch size warnings

## Session Continuity

Last session: 2026-02-25 (roadmap creation)
Stopped at: Roadmap and STATE.md written, ready for Phase 33 planning
Resume file: None

**Next steps:**
1. Begin Phase 33 planning: `/gsd:plan-phase 33`

---
*Updated: 2026-02-25 — v7.0 roadmap created*
