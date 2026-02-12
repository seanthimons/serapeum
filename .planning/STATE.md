# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-12)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration
**Current focus:** v2.0 Discovery Workflow & Output

## Current Position

Phase: 11 — DOI Storage & Migration Infrastructure ✅
Plan: 02 of 02 complete (verified)
Status: Phase complete — human-verified
Last activity: 2026-02-12 — Phase 11 verified and approved

Progress: v1.0 ✅ (9 plans) | v1.1 ✅ (6 plans) | v1.2 ✅ (2 plans) | v2.0 🔄 (2/2 phase 11 plans shipped) | Total: 20 plans shipped

## Performance Metrics

**By Milestone:**

| Milestone | Phases | Plans | Timeline |
|-----------|--------|-------|----------|
| v1.0 Fix + Discovery | 0-4 | 9 | 2 days |
| v1.1 Quality of Life | 5-8 | 6 | 13 days |
| v1.2 Stabilization | 9-10 | 2 | 1 day |
| Phase 11 P01 | 4 | 2 tasks | 4 files |
| Phase 11 P02 | 1.5 | 2 tasks | 2 files |

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

### Pending Todos

(None)

### Blockers/Concerns

(None)

## Session Continuity

Last session: 2026-02-12
Stopped at: Phase 11 verified and approved
Next: Execute next phase in v2.0 roadmap
