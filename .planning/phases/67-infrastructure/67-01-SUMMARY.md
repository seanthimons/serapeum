---
phase: 67-infrastructure
plan: 01
subsystem: database
tags: [duckdb, migrations, bootstrap, infrastructure, r]

# Dependency graph
requires: []

provides:
  - Idempotent DDL across the risky migration audit surface
  - Clarified bootstrap comment documenting why fresh installs still hit version-001 bootstrapping after init_schema()

affects:
  - 67-02-startup-regression

# Tech tracking
tech-stack:
  added: []
  patterns:
    - idempotent-ddl: overlapping migrations use IF NOT EXISTS for tables, indexes, and columns
    - bootstrap-marker-clarity: db_migrations.R comment explicitly documents init_schema() before migration tracking

key-files:
  created: []
  modified:
    - migrations/005_add_doi_column.sql
    - migrations/006_create_citation_networks.sql
    - migrations/008_add_document_metadata.sql
    - migrations/012_add_duration_ms_to_cost_log.sql
    - migrations/018_create_prompt_versions.sql
    - R/db_migrations.R

key-decisions:
  - "Fixed the migration files themselves instead of adding duplicate-object tryCatch handling in the runner"
  - "Preserved the startup contract get_db_connection() -> init_schema() -> run_pending_migrations()"
  - "Left broader init_schema() cleanup for later only if Wave 2 tests expose a real mismatch"

requirements-completed:
  - INFR-01

# Metrics
duration: ~15min
completed: 2026-03-27
---

# Phase 67 Plan 01: Infrastructure Summary

**Normalized the vulnerable migration/bootstrap surface so fresh installs no longer depend on duplicate-object failures being swallowed by runtime behavior.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-27
- **Completed:** 2026-03-27
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Converted migration `005` to use `ADD COLUMN IF NOT EXISTS` for `abstracts.doi`
- Converted migration `006` table and index creation to `IF NOT EXISTS`
- Converted all five document metadata column additions in migration `008` to `ADD COLUMN IF NOT EXISTS`
- Converted migration `012` to `ADD COLUMN IF NOT EXISTS duration_ms`
- Converted migration `018` table creation to `CREATE TABLE IF NOT EXISTS`
- Clarified the bootstrap comment in `R/db_migrations.R` so the init-schema-before-tracker behavior is explicit
- Ran `testthat::test_file('tests/testthat/test-db-migrations.R')` successfully after the DDL changes

## Task Commits

1. **Task 1 + 2: Harden risky migrations and clarify bootstrap overlap** - pending commit at summary creation time

## Decisions Made

- Fixed the SQL files directly instead of teaching the migration runner to swallow duplicate-object errors
- Kept the existing startup order intact and documented why version `001` is still a marker after `init_schema()`
- Deferred any broader `R/db.R` cleanup until the startup-path regression test proves it is actually needed

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first targeted R test run failed under sandbox because `renv` needed access to the user R cache outside the workspace. Re-running with escalation resolved it.

## Next Phase Readiness

- Wave 1 complete - the risky migration files are now explicitly idempotent
- Wave 2 should add the fresh-install and rerun regression tests before Phase 67 is verified complete

---
*Phase: 67-infrastructure*
*Completed: 2026-03-27*
