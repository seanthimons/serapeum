---
phase: 00-foundation
plan: 01
subsystem: database-migrations
tags: [infrastructure, database, schema-versioning, foundation]
dependency-graph:
  requires: [init_schema from db.R]
  provides: [versioned migrations, topics table schema]
  affects: [all future schema changes, Phase 3 Topic Explorer]
tech-stack:
  added: [migrations/ directory, schema_migrations tracking table]
  patterns: [transactional migrations, bootstrap detection, SQL file versioning]
key-files:
  created:
    - R/db_migrations.R: "Migration runner with 4 functions"
    - migrations/001_bootstrap_existing_schema.sql: "Baseline marker migration"
    - migrations/002_create_topics_table.sql: "Topics table DDL with hierarchy"
    - tests/testthat/test-db-migrations.R: "Comprehensive migration test suite"
  modified:
    - R/db.R: "get_db_connection() now runs migrations on startup"
    - tests/testthat/test-db.R: "Fixed to use close_db_connection() wrapper"
decisions:
  - Bootstrap existing databases at version 001 without re-executing init_schema
  - Use information_schema queries for compatibility with connConnection wrapper
  - Split SQL on semicolons after removing comment lines (DuckDB requirement)
  - Keep ad-hoc migrations in init_schema for backward compatibility during transition
metrics:
  duration: "~25 minutes"
  tasks-completed: 2
  tests-added: 7
  tests-total: 66 (31 migration + 35 db)
  commits: 2
  completed: 2026-02-10T23:55:27Z
---

# Phase 0 Plan 1: Database Migration Versioning System

**One-liner:** Transactional SQL migration versioning with automatic bootstrap detection and topics table schema for OpenAlex hierarchy.

## Overview

Replaced ad-hoc try-catch ALTER TABLE blocks in `db.R` (lines 102-219) with a proper migration versioning system. All future schema changes will use numbered `.sql` files in `migrations/` directory that execute automatically on app startup within transactions. Also created the `topics` table schema that Phase 3 (Topic Explorer) will populate.

## What Was Built

### Migration Runner (`R/db_migrations.R`)

Four core functions:

1. **`get_applied_migrations(con)`** - Creates `schema_migrations` tracking table if missing, returns integer vector of applied versions
2. **`apply_migration(con, version, description, sql)`** - Executes migration in transaction, splits SQL on semicolons (DuckDB requirement), records version, rolls back on error
3. **`run_pending_migrations(con)`** - Lists `.sql` files matching `^\\d{3}_.*\\.sql$`, applies pending migrations in order
4. **`bootstrap_existing_database(con)`** - Detects existing databases (by checking for `notebooks` table), marks version 001 as applied WITHOUT executing

### SQL Migration Files

- **`migrations/001_bootstrap_existing_schema.sql`** - Marker migration representing the baseline schema created by `init_schema()`. For existing databases, bootstrap marks this as applied without execution. For fresh databases, it's a no-op marker.

- **`migrations/002_create_topics_table.sql`** - Creates `topics` table with 4-level OpenAlex hierarchy (domain → field → subfield → topic), plus 4 indexes for efficient querying.

### Integration & Tests

- Modified `get_db_connection()` to call `run_pending_migrations(con)` before returning - ensures every database connection is migrated on first use
- Comprehensive test suite with 7 test cases covering: tracking table creation, migration application, skip logic, error rollback, pending migrations, bootstrap detection, and topics table creation
- Fixed existing `test-db.R` to use `close_db_connection()` wrapper instead of direct `dbDisconnect()` for compatibility with `connConnection` objects

## Technical Highlights

**Bootstrap Detection Logic:**
- Fresh database (no `notebooks` table): `init_schema()` creates base tables → migrations 001 (no-op) and 002 (topics) execute normally
- Existing database (has `notebooks` table): Bootstrap marks version 001 as applied → migration 002 adds topics table → no data loss

**DuckDB SQL Splitting:**
Migration files can contain multiple statements separated by semicolons. The `apply_migration()` function removes comment lines, splits on semicolons, and executes each statement individually within a transaction.

**connConnection Compatibility:**
Uses `information_schema.tables` query instead of `dbListTables()` to detect existing tables - works with both standard DBI connections and `connConnection` wrappers from the `connections` package.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test-db.R to use close_db_connection() wrapper**
- **Found during:** Task 2 testing
- **Issue:** Existing tests failed because they called `dbDisconnect()` directly on `connConnection` objects, which doesn't have that method
- **Fix:** Updated all test cleanup code to use `close_db_connection()` helper function that handles both connection types
- **Files modified:** tests/testthat/test-db.R
- **Commit:** ccb4cd2

**2. [Rule 1 - Bug] Fixed bootstrap_existing_database() compatibility with connConnection**
- **Found during:** Task 2 testing
- **Issue:** `dbListTables()` doesn't work with `connConnection` objects wrapped by the `connections` package
- **Fix:** Changed to use `information_schema.tables` query which works with both connection types
- **Files modified:** R/db_migrations.R
- **Commit:** ccb4cd2

**3. [Rule 1 - Bug] Improved SQL statement splitting logic**
- **Found during:** Task 1 testing (migration 002 CREATE INDEX failures)
- **Issue:** Naive semicolon splitting was breaking multi-line statements, causing INDEX creation to fail
- **Fix:** Enhanced `apply_migration()` to first remove comment-only lines, then split on semicolons
- **Files modified:** R/db_migrations.R
- **Commit:** ccb4cd2

## Verification Results

### Test Results
- ✅ All 7 migration tests pass (31 assertions)
- ✅ All 13 existing db tests pass (35 assertions)
- ✅ No regressions introduced

### Success Criteria Met
- ✅ `schema_migrations` table tracks applied migration versions
- ✅ Migration 001 bootstraps existing databases without re-executing `init_schema()`
- ✅ Migration 002 creates `topics` table with 4-level hierarchy columns and indexes
- ✅ `get_db_connection()` automatically runs pending migrations
- ✅ App starts without errors on both fresh and existing databases

## Commits

1. **5313259** - `feat(00-foundation-01): create migration runner and SQL migration files`
   - Created R/db_migrations.R with 4 functions
   - Created migrations/001_bootstrap_existing_schema.sql
   - Created migrations/002_create_topics_table.sql

2. **ccb4cd2** - `feat(00-foundation-01): wire migration runner into app startup and add tests`
   - Modified get_db_connection() to auto-migrate
   - Added comprehensive test suite
   - Fixed connConnection compatibility issues
   - All tests passing

## Impact

**Immediate:**
- All schema changes now trackable and versioned
- Topics table ready for Phase 3 population
- Existing databases upgrade seamlessly on next app startup

**Future:**
- New features add migrations in `migrations/` directory
- No more ad-hoc ALTER TABLE try-catch blocks
- Database schema version queryable for debugging

**Tech Debt Reduction:**
- After all users migrate past version 001, can remove ad-hoc migration blocks from `init_schema()` (lines 102-219 in db.R)

## Self-Check: PASSED

**Created files verified:**
- ✅ R/db_migrations.R exists
- ✅ migrations/001_bootstrap_existing_schema.sql exists
- ✅ migrations/002_create_topics_table.sql exists
- ✅ tests/testthat/test-db-migrations.R exists

**Commits verified:**
- ✅ Commit 5313259 exists in git log
- ✅ Commit ccb4cd2 exists in git log

**Test results:**
- ✅ Migration tests: 31 PASS, 0 FAIL
- ✅ Database tests: 35 PASS, 0 FAIL
