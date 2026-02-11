# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-10)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration
**Current focus:** Phase 2 - Query Builder + Sorting (complete)

## Current Position

Phase: 2 of 4 (Query Builder & Sorting)
Plan: 2 of 2 in current phase
Status: Complete - 2 of 2 plans complete
Last activity: 2026-02-10 -- Completed 02-02 LLM Query Builder

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**
- Total plans completed: 5
- Average duration: 7 minutes
- Total execution time: 0.60 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 0-foundation | 1 | 25 min | 25 min |
| 1-seed-paper-discovery | 2 | 5 min | 2.5 min |
| 2-query-builder-sorting | 2 | 6 min | 3 min |

**Recent Trend:**
- Last 5 plans: 01-01 (3m), 01-02 (2m), 02-01 (4m), 02-02 (2m)
- Trend: Consistently fast execution with established patterns

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- LLM generates OpenAlex filter syntax but filter attributes are validated against allowlist before API call (02-02)
- Filter validation checks attribute names only, not values (hyphenated values like journal-article are valid) (02-02)
- Query preview shown to user with explanation, search terms, and filter string before execution (02-02)
- Sort preference is session-only (not persisted to database) (02-01)
- All metric sorts use NULLS LAST to sink papers with missing data (02-01)
- Year sort maintains secondary sort by created_at for stable ordering (02-01)
- Producer-consumer pattern: discovery modules return reactive requests consumed by app.R to create notebooks (01-02)
- Citation API uses OpenAlex filters (cites:, cited_by:, related_to:) not paginated traversal (01-02)
- DOI normalization handles all common formats (plain, doi: prefix, URLs, OpenAlex IDs) (01-02)
- Discovery results populate search notebook without modifying mod_search_notebook.R (01-02)
- Use explicit type coercion for UUID comparisons between extracted strings and DB results (01-01)
- Create dedicated test-embedding.R for abstract pipeline regression prevention (01-01)
- Fix #55 before new features (embedding bug blocks all search notebook testing)
- Discovery modules use producer-consumer pattern (output query params to search notebook, do not expand mod_search_notebook.R)
- Phase 0 adds migration versioning before any schema changes
- Bootstrap existing databases at version 001 without re-executing init_schema (00-01)
- Use information_schema queries for connConnection compatibility (00-01)
- Keep ad-hoc migrations in init_schema during transition period (00-01)

### Pending Todos

None yet.

### Blockers/Concerns

- mod_search_notebook.R is 1,760 lines -- new features must be separate modules, not additions to this file

## Session Continuity

Last session: 2026-02-10
Stopped at: Completed Phase 2 Plan 2 (LLM Query Builder) - Phase 2 complete
Resume file: .planning/phases/02-query-builder-sorting/02-02-SUMMARY.md
Next: Phase 3 - Citation Network Exploration
