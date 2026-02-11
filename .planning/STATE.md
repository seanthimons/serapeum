# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-10)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration
**Current focus:** Phase 3 - Topic Explorer (in progress)

## Current Position

Phase: 3 of 4 (Topic Explorer)
Plan: 1 of 2 in current phase
Status: In Progress - 1 of 2 plans complete
Last activity: 2026-02-11 -- Completed 03-01 Topic Data Layer

Progress: [████████░░] 50%

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: 6 minutes
- Total execution time: 0.63 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 0-foundation | 1 | 25 min | 25 min |
| 1-seed-paper-discovery | 2 | 5 min | 2.5 min |
| 2-query-builder-sorting | 2 | 6 min | 3 min |
| 3-topic-explorer | 1 | 2 min | 2 min |

**Recent Trend:**
- Last 5 plans: 01-02 (2m), 02-01 (4m), 02-02 (2m), 03-01 (2m)
- Trend: Consistently fast execution with established patterns

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Full refresh strategy for topics cache (DELETE + bulk insert) - topics data is static enough that incremental updates not needed (03-01)
- 30-day cache TTL for topics - topics change infrequently, longer TTL reduces API load (03-01)
- Named character vectors for selectInput compatibility - IDs as values, display names as names (03-01)
- Separate hierarchy levels with explicit parent filtering - cleaner than self-join queries (03-01)
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

Last session: 2026-02-11
Stopped at: Completed Phase 3 Plan 1 (Topic Data Layer) - Phase 3 in progress
Resume file: .planning/phases/03-topic-explorer/03-01-SUMMARY.md
Next: Phase 3 Plan 2 - Topic Explorer UI Module
