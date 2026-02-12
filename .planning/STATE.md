# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-12)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration
**Current focus:** v2.0 Discovery Workflow & Output

## Current Position

Phase: 12 — Citation Network Visualization 🔄
Plan: 01 of 02 complete
Status: Executing phase 12
Last activity: 2026-02-12 — Phase 12 plan 01 complete (data layer)

Progress: v1.0 ✅ (9 plans) | v1.1 ✅ (6 plans) | v1.2 ✅ (2 plans) | v2.0 🔄 (2/2 phase 11, 1/2 phase 12 shipped) | Total: 21 plans shipped

## Performance Metrics

**By Milestone:**

| Milestone | Phases | Plans | Timeline |
|-----------|--------|-------|----------|
| v1.0 Fix + Discovery | 0-4 | 9 | 2 days |
| v1.1 Quality of Life | 5-8 | 6 | 13 days |
| v1.2 Stabilization | 9-10 | 2 | 1 day |
| Phase 11 P01 | 4 | 2 tasks | 4 files |
| Phase 11 P02 | 1.5 | 2 tasks | 2 files |
| Phase 12 P01 | 9 | 2 tasks | 3 files |

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full log.

Recent decisions:
- v1.2: Bootstrap 5 native collapse for single-card simplicity
- v1.2: Flexbox align-items-center for badge alignment
- [Phase 11]: Store DOI in bare format (10.xxxx/yyyy) not URL for BibTeX compatibility
- [Phase 11]: Nullable DOI column for backward compatibility with existing databases
- [Phase 11]: Separate normalize_doi_bare() from normalize_doi() to avoid naming conflict
- [Phase 11]: DOI displayed as clickable link opening in new tab with graceful fallback to citation key for legacy papers
- [Phase 12]: Manual cascade delete for DuckDB (doesn't support CASCADE on foreign keys)
- [Phase 12]: Store layout positions in network_nodes for instant reload without re-computing
- [Phase 12]: sqrt transform for citation counts to handle power-law distribution
- [Phase 12]: Prune BFS frontier to top 100 papers by citation count to prevent exponential blowup

### Pending Todos

(None)

### Blockers/Concerns

(None)

## Session Continuity

Last session: 2026-02-12
Stopped at: Completed phase 12 plan 01 (citation network data layer)
Next: Execute phase 12 plan 02 (citation network UI module)
