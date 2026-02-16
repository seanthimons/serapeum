# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** v3.0 Ragnar RAG Overhaul

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-02-16 — Milestone v3.0 started

## Performance Metrics

**By Milestone:**

| Milestone | Phases | Plans | Timeline |
|-----------|--------|-------|----------|
| v1.0 Fix + Discovery | 0-4 | 9 | 2 days |
| v1.1 Quality of Life | 5-8 | 6 | 13 days |
| v1.2 Stabilization | 9-10 | 2 | 1 day |
| v2.0 Discovery Workflow & Output | 11-15 | 8 | 14 days |
| v2.1 Polish & Analysis | 16-19 | 7 | <1 day |
| v3.0 Ragnar RAG Overhaul | — | — | In progress |

**Total:** 32 plans shipped across 19 phases

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full log.

Decisions affecting v3.0 work:
- **v2.1 - Content-based section heuristics**: Section detection via chunk text keywords — must be preserved in ragnar migration
- **v2.1 - Three-level retrieval fallback**: Section-filtered → unfiltered → direct DB — will simplify with ragnar-only path
- **v2.1 - OWASP instruction-data separation**: Must be preserved in new retrieval path
- **v3.0 - Per-notebook ragnar stores**: Each notebook gets its own .ragnar.duckdb for clean isolation
- **v3.0 - Ragnar as hard dependency**: No legacy fallback, simpler code
- **v3.0 - Delete existing data, don't migrate**: Fresh re-embed is cleaner

### Pending Todos

- [#79](https://github.com/seanthimons/serapeum/issues/79): Tooltip overflow (deferred, not in v3.0)
- Move to renv for package namespace management (tooling)
- Fix citation network background color blending (ui) — bundle with #79
- Explore partial BFS graph as intentional visualization mode

### Blockers/Concerns

None yet — milestone just started.

## Session Continuity

Last session: 2026-02-16
Stopped at: Milestone v3.0 started, defining requirements
Next: Complete requirements definition, then roadmap creation
