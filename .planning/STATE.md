# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-10)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration
**Current focus:** Phase 3 - Topic Explorer (complete)

## Current Position

Phase: 3 of 4 (Topic Explorer)
Plan: 2 of 2 in current phase
Status: Complete - 2 of 2 plans complete
Last activity: 2026-02-11 -- Completed 03-02 Topic Explorer UI Module

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**
- Total plans completed: 7
- Average duration: 7 minutes
- Total execution time: 0.80 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 0-foundation | 1 | 25 min | 25 min |
| 1-seed-paper-discovery | 2 | 5 min | 2.5 min |
| 2-query-builder-sorting | 2 | 6 min | 3 min |
| 3-topic-explorer | 2 | 17 min | 8.5 min |

**Recent Trend:**
- Last 5 plans: 02-01 (4m), 02-02 (2m), 03-01 (2m), 03-02 (15m)
- Trend: 03-02 longer due to human verification + 5 bugfixes during UAT

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Dropped connections package — connConnection breaks dbWithTransaction, standard dbConnect sufficient (03-02)
- OpenAlex API key optional for topic fetching — polite pool with email works (03-02)
- Topic search includes keywords column — display_name too narrow for useful search (03-02)
- Topic consumer fetches papers outside withProgress to avoid <<- scoping issues (03-02)
- Full refresh strategy for topics cache (DELETE + bulk insert) - topics data is static enough that incremental updates not needed (03-01)
- 30-day cache TTL for topics - topics change infrequently, longer TTL reduces API load (03-01)
- Named character vectors for selectInput compatibility - IDs as values, display names as names (03-01)
- Separate hierarchy levels with explicit parent filtering - cleaner than self-join queries (03-01)
- LLM generates OpenAlex filter syntax but filter attributes are validated against allowlist before API call (02-02)
- Filter validation checks attribute names only, not values (hyphenated values like journal-article are valid) (02-02)
- Query preview shown to user with explanation, search terms, and filter string before execution (02-02)
- Sort preference is session-only (not persisted to database) (02-01)
- All metric sorts use NULLS LAST to sink papers with missing data (02-01)
- Producer-consumer pattern: discovery modules return reactive requests consumed by app.R to create notebooks (01-02)
- Discovery results populate search notebook without modifying mod_search_notebook.R (01-02)
- Phase 0 adds migration versioning before any schema changes
- Bootstrap existing databases at version 001 without re-executing init_schema (00-01)

### Pending Todos

- Bug: Seed discovery ("Discover from Paper") prompts for email even when already configured

### Blockers/Concerns

- mod_search_notebook.R is 1,760 lines -- new features must be separate modules, not additions to this file

## Session Continuity

Last session: 2026-02-11
Stopped at: Completed Phase 3 (Topic Explorer) - all plans complete, human verified
Resume file: .planning/phases/03-topic-explorer/03-02-SUMMARY.md
Next: Phase 4 - Startup Wizard + Polish
