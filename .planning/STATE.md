# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-12)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration
**Current focus:** v2.0 Discovery Workflow & Output

## Current Position

Phase: 14 — Citation Export
Plan: 02 of 02 complete
Status: Phase 14 Complete
Last activity: 2026-02-12 — Completed 14-02-PLAN.md

Progress: v1.0 ✅ (9 plans) | v1.1 ✅ (6 plans) | v1.2 ✅ (2 plans) | v2.0 ✅ (8/8 plans shipped: phase 11 + 12 + 13 + 14) | Total: 25 plans shipped

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
| Phase 12 P02 | ~30 | 2 tasks + checkpoint | 6 files |
| Phase 13 P01 | 3 | 2 tasks | 3 files |
| Phase 14 P01 | 9 | 2 tasks | 2 files |
| Phase 14 P02 | 11 | 2 tasks | 1 file |

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full log.

Recent decisions:
- [Phase 11]: Store DOI in bare format (10.xxxx/yyyy) not URL for BibTeX compatibility
- [Phase 11]: Nullable DOI column for backward compatibility with existing databases
- [Phase 12]: Manual cascade delete for DuckDB (doesn't support CASCADE on foreign keys)
- [Phase 12]: Store layout positions in network_nodes for instant reload without re-computing
- [Phase 12]: sqrt transform for citation counts to handle power-law distribution
- [Phase 12]: Plain author display strings instead of JSON serialization (avoids vapply errors)
- [Phase 12]: Cross-link discovery via referenced_works field (no extra API calls)
- [Phase 12]: Legend at top-right to avoid visNetwork nav button overlap
- [Phase 12]: Node cap floor lowered to 5, step to 5
- [Phase 13]: Timestamp-based deduplication for seed_request reactive
- [Phase 13]: Auto-trigger paper lookup on DOI pre-fill (no manual button click)
- [Phase 14]: Placeholder-based backslash escaping to avoid double-escaping
- [Phase 14]: Title-based fallback keys for papers without DOI
- [Phase 14]: Semicolon-separated authors in CSV export
- [Phase 14]: UTF-8 BOM for BibTeX files to ensure reference manager compatibility
- [Phase 14]: Export filtered papers (respects current search filters) not all notebook papers

### Pending Todos

- [#79](https://github.com/seanthimons/serapeum/issues/79): Tooltip overflow (tracked for next sprint)
- [#80](https://github.com/seanthimons/serapeum/issues/80): Progress modal with stop button

### Blockers/Concerns

(None)

## Session Continuity

Last session: 2026-02-12
Stopped at: Completed 14-02-PLAN.md (Phase 14 complete)
Next: Awaiting next phase planning
