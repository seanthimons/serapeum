---
phase: 03-topic-explorer
plan: 01
subsystem: api, database
tags: [openalex, topics, duckdb, cache, hierarchy]

# Dependency graph
requires:
  - phase: 00-foundation
    provides: database migration system with quality_cache_meta table
  - phase: 01-seed-paper-discovery
    provides: OpenAlex API integration patterns (build_openalex_request, parse functions)
provides:
  - OpenAlex Topics API fetching with pagination (fetch_all_topics, parse_topic)
  - DuckDB topic caching with 30-day TTL (cache_topics, get_cached_topics)
  - Hierarchy query functions for 4-level topic taxonomy (get_hierarchy_choices)
affects: [03-02-topic-explorer-ui, topic-based-discovery, paper-classification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "OpenAlex pagination with offset-based paging and rate limiting"
    - "Quality cache pattern with metadata tracking (used by predatory publishers, retractions, now topics)"
    - "Hierarchical data queries with parameterized parent filtering"

key-files:
  created: []
  modified:
    - R/api_openalex.R
    - R/db.R

key-decisions:
  - "Full refresh strategy for topics cache (DELETE + bulk insert) - topics data is static enough that incremental updates not needed"
  - "30-day cache TTL for topics - topics change infrequently, longer TTL reduces API load"
  - "Named character vectors for selectInput compatibility - IDs as values, display names as names"
  - "Separate hierarchy levels with explicit parent filtering - cleaner than self-join queries"

patterns-established:
  - "Topic hierarchy queries: domain → field → subfield → topic with cascading parent filters"
  - "Work count formatting with thousands separator in labels: 'Name (1,234 works)'"
  - "Cache freshness checking via quality_cache_meta before returning data"

# Metrics
duration: 2min
completed: 2026-02-11
---

# Phase 03 Plan 01: Topic Data Layer Summary

**OpenAlex Topics API integration with paginated fetching (~4,500 topics), DuckDB caching (30-day TTL), and hierarchy query functions for 4-level taxonomy (domain/field/subfield/topic)**

## Performance

- **Duration:** 2 minutes
- **Started:** 2026-02-11T01:28:49Z
- **Completed:** 2026-02-11T01:30:44Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fetch all ~4,500 topics from OpenAlex with offset-based pagination and rate limiting
- Cache topics in DuckDB with metadata tracking and 30-day staleness detection
- Query hierarchy choices at any level (domain/field/subfield/topic) with parent filtering for Shiny selectInput

## Task Commits

Each task was committed atomically:

1. **Task 1: Add topic fetching functions to api_openalex.R** - `034ba76` (feat)
2. **Task 2: Add topic caching and hierarchy query functions to db.R** - `c751da6` (feat)

## Files Created/Modified
- `R/api_openalex.R` - Added parse_topic() and fetch_all_topics() for OpenAlex Topics API
- `R/db.R` - Added cache_topics(), get_cached_topics(), get_hierarchy_choices() for topic data layer

## Decisions Made
- Full refresh strategy for topics cache (DELETE + bulk insert) instead of incremental updates - topics data is relatively static
- 30-day cache TTL for topics - balance between API load and data freshness
- Named character vectors for selectInput compatibility - IDs as values, display names as names
- Separate hierarchy levels with explicit parent filtering - cleaner than complex self-join queries
- Work count formatting with thousands separator in topic labels: "Name (1,234 works)"

## Deviations from Plan

None - plan executed exactly as written

## Issues Encountered

None - implementation followed existing patterns established in Phase 0 and Phase 1

## User Setup Required

None - no external service configuration required. API key already configured for OpenAlex.

## Next Phase Readiness

**Ready for Phase 3 Plan 2 (Topic Explorer UI Module)**

All data layer functions are complete and follow established patterns:
- `fetch_all_topics()` can be called from UI to populate cache
- `get_cached_topics()` checks freshness before fetching
- `get_hierarchy_choices()` provides selectInput-compatible choices for all 4 hierarchy levels
- Topics table is ready (created by migration 002_create_topics_table.sql)

No blockers for UI module implementation.

## Self-Check: PASSED

All files and commits verified:
- FOUND: R/api_openalex.R
- FOUND: R/db.R
- FOUND: 034ba76
- FOUND: c751da6

---
*Phase: 03-topic-explorer*
*Completed: 2026-02-11*
