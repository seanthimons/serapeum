# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-12)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** Phase 17 - Year Range Filter (next)

## Current Position

Phase: 17 of 19 (Year Range Filter) — IN PROGRESS
Plan: 1/2 complete
Status: Plan 17-01 complete, Plan 17-02 pending
Last activity: 2026-02-13 — Phase 17 Plan 01 executed

Progress: [█████████████████░░░] 84% (16/19 phases complete, 1/2 plans in phase 17)

## Performance Metrics

**By Milestone:**

| Milestone | Phases | Plans | Timeline |
|-----------|--------|-------|----------|
| v1.0 Fix + Discovery | 0-4 | 9 | 2 days |
| v1.1 Quality of Life | 5-8 | 6 | 13 days |
| v1.2 Stabilization | 9-10 | 2 | 1 day |
| v2.0 Discovery Workflow & Output | 11-15 | 8 | 14 days |
| v2.1 Polish & Analysis | 16 | 1 | <1 day |

**Total:** 27 plans shipped across 16 phases (1 plan in progress for phase 17)

**Recent Execution (Phase 17-01):**
- Duration: 2.0 minutes (119 seconds)
- Tasks: 1
- Files modified: 2
- Files created: 0

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full log (26 decisions across 4 milestones).

Recent decisions affecting v2.1 work:
- **v2.0 - Store layout positions in DB**: Avoid recomputation on network reload (Phase 18 benefits)
- **v2.0 - BFS frontier pruning at 100**: Prevent API explosion (Phase 18 cancellation pattern)
- **v2.0 - Timestamp-based reactive deduplication**: Cross-module communication (Phase 17 year filter pattern)
- **v2.1 (16-01) - Use magick package for favicon generation**: R's base png() device crashes in headless mode; magick provides reliable PNG generation with text rendering
- **v2.1 (16-01) - Single hr() separator in footer**: Reduces visual clutter and saves ~60px vertical space while maintaining clear section separation
- [Phase 17]: 400ms debounce on year range slider prevents reactive storm during drag
- [Phase 17]: Dynamic slider bounds from database with COALESCE fallback (2000-2026) ensures valid ranges

### Pending Todos

- [#79](https://github.com/seanthimons/serapeum/issues/79): Tooltip overflow (deferred, not in v2.1)

### Blockers/Concerns

**Phase 17 (Year Filter):**
- Slider reactive storm requires debounce from day one
- DuckDB NULL year handling needs COALESCE strategy
- Cross-module state sharing must avoid circular dependencies

**Phase 18 (Progress Modal):**
- Shiny lacks native task cancellation — requires interrupt flag pattern
- Observer cleanup needed to prevent leaked processes

**Phase 19 (Conclusion Synthesis):**
- RAG prompt injection risk — requires OWASP LLM01:2025 hardening
- Section-targeted RAG needs adversarial testing

## Session Continuity

Last session: 2026-02-13
Stopped at: Completed 17-01-PLAN.md
Next: Execute 17-02-PLAN.md (citation network year filter)
