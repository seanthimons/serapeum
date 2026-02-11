---
phase: 08-journal-quality-controls
plan: 01
subsystem: quality-controls
tags: [database, shiny-module, filtering]
dependency-graph:
  requires:
    - phase: 00
      plan: 01
      component: db.R
      reason: extends database CRUD functions
    - phase: 05
      plan: 02
      component: quality_filter.R
      reason: uses normalize_name() and predatory list functions
    - phase: 07
      plan: 01
      component: mod_keyword_filter.R
      reason: follows filter module pattern
  provides:
    - component: migrations/004_create_blocked_journals.sql
      capability: blocked_journals table schema
    - component: R/db.R (blocked journals functions)
      capability: CRUD operations for personal journal blocklist
    - component: R/mod_journal_filter.R
      capability: journal quality filter Shiny module
  affects:
    - component: mod_search_notebook.R
      reason: will integrate this module in Plan 02 (replace existing quality logic)
tech-stack:
  added: []
  patterns:
    - composable filter modules (returns filtered_papers reactive)
    - DB migration pattern (numbered SQL files)
    - reactiveVal invalidation for cache refresh
key-files:
  created:
    - path: migrations/004_create_blocked_journals.sql
      lines: 11
      purpose: database schema for personal journal blocklist
    - path: R/mod_journal_filter.R
      lines: 167
      purpose: journal quality filter Shiny module
  modified:
    - path: R/db.R
      lines-added: 96
      purpose: added 5 CRUD functions for blocked_journals table
decisions:
  - id: JRNL-FILTER-01
    summary: Filter toggle defaults to OFF (show all with warnings)
    rationale: Follows user decision JRNL-02 - user opts IN to filtering, not auto-filtered
  - id: JRNL-FILTER-02
    summary: Module annotates papers but doesn't render badges
    rationale: Parent module (mod_search_notebook.R) already has badge rendering logic (lines 589-595)
  - id: JRNL-FILTER-03
    summary: Use reactiveVal for blocklist refresh invalidation
    rationale: Increment trigger invalidates quality_sets reactive when journal added/removed
metrics:
  duration: 2 minutes
  tasks-completed: 2
  files-created: 2
  files-modified: 1
  commits: 2
  completed-date: 2026-02-11
---

# Phase 08 Plan 01: Journal Quality Controls Foundation Summary

**One-liner:** Created blocked_journals database table and journal quality filter module with tri-state annotation (predatory/blocked/clean) and optional hide-flagged toggle.

## What Was Built

### Migration 004: blocked_journals Table
- Created `migrations/004_create_blocked_journals.sql` with schema:
  - `id` (INTEGER PRIMARY KEY)
  - `journal_name` (VARCHAR) - original name as entered by user
  - `journal_name_normalized` (VARCHAR) - normalized for matching
  - `added_at` (TIMESTAMP)
- Unique index on `journal_name_normalized` prevents duplicates
- Follows existing migration pattern (001-003)

### Database CRUD Functions
Added 5 functions to `R/db.R`:

1. **`add_blocked_journal(con, journal_name)`** - Inserts journal with normalized name, ON CONFLICT DO NOTHING for duplicates
2. **`remove_blocked_journal(con, id)`** - Deletes by ID
3. **`list_blocked_journals(con)`** - Returns all blocked journals ordered by added_at DESC
4. **`is_journal_blocked(con, journal_name)`** - Single-check lookup (normalized)
5. **`get_blocked_journals_set(con)`** - Returns character vector for batch matching (same pattern as `get_predatory_journals_set`)

All functions follow existing db.R patterns:
- Parameter binding with `?`
- NULL/NA handling with explicit conversion
- Normalize names using `normalize_name()` from quality_filter.R

### Journal Filter Module
Created `R/mod_journal_filter.R` (167 lines) following Phase 7's mod_keyword_filter.R pattern:

**UI (`mod_journal_filter_ui`):**
- Toggle: "Hide flagged journals" (default OFF per JRNL-02)
- Summary: "X of Y papers flagged" (when flags exist)
- Blocklist info: "N journals blocked" with manage link

**Server (`mod_journal_filter_server`):**
- Accepts `papers_data` reactive (data.frame with venue column)
- Accepts `con` reactive (DB connection)
- Loads quality sets once (predatory journals, predatory publishers, blocked journals)
- Annotates papers with 4 new columns:
  - `is_predatory` (logical) - matches predatory lists
  - `is_blocked` (logical) - matches personal blocklist
  - `is_flagged` (logical) - either predatory OR blocked
  - `quality_flag_text` (character) - "Predatory journal", "Blocked journal", or "Predatory journal (blocked)"
- Filter toggle removes flagged papers when enabled
- Returns list with:
  - `filtered_papers` reactive
  - `block_journal(journal_name)` function
  - `blocklist_count` reactive

**Cache invalidation:** Uses `reactiveVal(blocklist_refresh)` that increments when journal added/removed, invalidating `quality_sets` reactive.

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

All verification steps passed:

1. `parse('R/db.R')` - OK
2. `parse('R/mod_journal_filter.R')` - OK
3. Migration file exists at `migrations/004_create_blocked_journals.sql` with CREATE TABLE
4. All 5 DB functions present and correctly implemented
5. Module exports UI and server functions, returns list with required elements

## Integration Notes

**Plan 02 will:**
- Integrate mod_journal_filter.R into mod_search_notebook.R
- Remove existing quality annotation logic (lines 331-383 in mod_search_notebook.R)
- Wire up block_journal function to UI action

**Badge rendering:**
- Module does NOT render badges (parent module already has this at lines 589-595)
- Module only annotates data with flags

**Filter chaining:**
- Follows Phase 7 pattern: returns `filtered_papers` reactive
- Can be composed with mod_keyword_filter.R for multi-stage filtering

## Self-Check: PASSED

**Files created:**
- migrations/004_create_blocked_journals.sql - EXISTS
- R/mod_journal_filter.R - EXISTS

**Files modified:**
- R/db.R - MODIFIED (5 new functions at end)

**Commits:**
- 902e347: feat(08-01): create blocked_journals table and CRUD functions - EXISTS
- 8909d82: feat(08-01): create journal filter module - EXISTS

**Functions verified:**
- add_blocked_journal - EXISTS in db.R
- remove_blocked_journal - EXISTS in db.R
- list_blocked_journals - EXISTS in db.R
- is_journal_blocked - EXISTS in db.R
- get_blocked_journals_set - EXISTS in db.R
- mod_journal_filter_ui - EXISTS in mod_journal_filter.R
- mod_journal_filter_server - EXISTS in mod_journal_filter.R

All claims verified. Plan execution complete.
