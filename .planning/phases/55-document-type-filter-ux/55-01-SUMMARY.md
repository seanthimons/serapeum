---
phase: 55-document-type-filter-ux
plan: 01
subsystem: search-notebook
tags: [ui, filter, taxonomy, catppuccin]
dependency_graph:
  requires: [phase-53-keyword-filter-preview, phase-54-tooltip-layer]
  provides: [16-type-taxonomy, chip-toggle-ui, client-side-type-filter]
  affects: [search-ui, paper-badges, filter-chain]
tech_stack:
  added: []
  patterns: [chip-toggles, client-side-filtering, reactive-state]
key_files:
  created:
    - tests/testthat/test-type-badge.R
  modified:
    - R/mod_search_notebook.R
    - R/api_openalex.R
decisions:
  - "Extracted get_type_badge() as module-level function for testability"
  - "Distribution panel open by default (user feedback pattern from Phase 53)"
  - "Chip ON/OFF visual: ON = type color, OFF = gray (clear state indication)"
  - "Client-side type filter between keyword and journal (no API re-search)"
  - "Type state changes do NOT trigger cursor reset (save behavior only)"
  - "API page size 100 instead of 25 (better batch efficiency for 16-type taxonomy)"
metrics:
  duration: 377
  completed: 2026-03-11
---

# Phase 55 Plan 01: Document Type Filter UX Summary

**One-liner:** Chip toggle UI for 16 OpenAlex document types with Catppuccin styling, client-side filtering, and live distribution panel

## What Was Built

Replaced 6 document type checkboxes with 16 chip toggles covering the full OpenAlex taxonomy, organized into 4 Catppuccin color families (primary research, reviews, preprints, metadata). Added distribution panel showing pre-filter counts for all 16 types. Inserted client-side type filter into reactive chain between keyword and journal filters. Increased API page size from 25 to 100 for better batch efficiency.

**Key Components:**
- **OPENALEX_WORK_TYPES constant** — 16-type taxonomy with color families (primary, review, preprint, other)
- **get_type_badge()** — Lookup function for badge class + label (supports all 16 types)
- **Chip toggle UI** — actionLink badges with ON (type color) / OFF (gray) states
- **Distribution panel** — Shows all 16 types (including zeros) with horizontal bars and counts
- **Select All / Deselect All links** — Bulk toggle for all 16 chips
- **type_states reactiveValues** — Stores chip toggle states (initialized from saved filters or defaults)
- **type_filtered_papers reactive** — Client-side filter between keyword_filtered_papers and journal filter
- **API page size 100** — Changed from 25 in search_papers() and abstracts_count fallback

## Tasks Completed

### Task 1: Expand badge system and build chip toggle UI with distribution panel
- **Commit:** `cf6554d` — `feat(55-01): expand badge system and build chip toggle UI with distribution panel`
- **Files:** R/mod_search_notebook.R, tests/testthat/test-type-badge.R
- **Actions:**
  - Defined OPENALEX_WORK_TYPES constant with 16 types in 4 color families
  - Rewrote get_type_badge() to look up from taxonomy (extracted as module-level function)
  - Replaced 6 checkboxes with 16 chip toggles using actionLink badges
  - Added Select All / Deselect All links
  - Rewrote type_distribution to show all 16 types (including zeros) with pre-filter counts
  - Distribution panel appears ABOVE chips and is expanded by default
  - Initialized type_states reactiveValues from saved filters or DEFAULT_ON_TYPES
  - Refactored get_selected_work_types() to read from type_states
  - Updated save handler to collect from type_states
  - Created unit tests for get_type_badge() covering all 16 types (44 assertions passed)
- **Verification:** `testthat::test_file('tests/testthat/test-type-badge.R')` — 44 tests passed

### Task 2: Insert client-side type filter and increase API page size
- **Commit:** `8734a44` — `feat(55-01): insert client-side type filter and increase API page size`
- **Files:** R/mod_search_notebook.R, R/api_openalex.R
- **Actions:**
  - Added type_filtered_papers reactive between keyword_filtered_papers and journal filter
  - Updated journal_filter_server to receive type_filtered_papers instead of keyword_filtered_papers
  - Changed search_papers default per_page from 25 to 100
  - Changed abstracts_count fallback from 25 to 100
  - Verified type changes do NOT trigger cursor reset (client-side only)
  - Verified old 6-checkbox pattern removed (grep returns 0)
- **Verification:** Shiny app smoke test passed (app starts without errors)

## Deviations from Plan

None — plan executed exactly as written.

## Technical Decisions

### Extracted get_type_badge() as module-level function
**Context:** Unit tests couldn't access function inside server closure
**Decision:** Moved OPENALEX_WORK_TYPES, DEFAULT_ON_TYPES, and get_type_badge() to top of module file
**Rationale:** Enables unit testing without mock Shiny session, improves testability
**Files:** R/mod_search_notebook.R

### Distribution panel open by default
**Context:** User feedback pattern from Phase 53 keyword filter
**Decision:** Use `open = "open"` attribute on `<details>` element
**Rationale:** Distribution counts are primary navigation aid for researchers (not secondary metadata)
**Files:** R/mod_search_notebook.R

### Chip ON/OFF visual states
**Context:** Two-state toggle needs clear visual indication
**Decision:** ON = type color badge class, OFF = bg-secondary (gray)
**Rationale:** Color = active filter, gray = inactive (consistent with filter semantics)
**Files:** R/mod_search_notebook.R

### Client-side type filter between keyword and journal
**Context:** Type filter affects result set but doesn't need API re-search
**Decision:** Insert type_filtered_papers reactive between keyword_filtered_papers and journal_filter_server input
**Rationale:** All 16 types already in papers_data() from API (type is always fetched), client-side filtering is instant
**Files:** R/mod_search_notebook.R

### Type state changes do NOT trigger cursor reset
**Context:** Cursor reset observers watch for API parameter changes (Phase 51)
**Decision:** Type toggles only saved on "Save & Refresh" click, which triggers cursor reset via save_search observer
**Rationale:** Client-side filtering doesn't invalidate pagination state, only API query changes do
**Files:** R/mod_search_notebook.R

### API page size 100 instead of 25
**Context:** 16-type taxonomy means more granular filtering, users need larger batches
**Decision:** Change search_papers default per_page from 25 to 100, update abstracts_count fallback
**Rationale:** Better batch efficiency (4x fewer API calls for same paper count), OpenAlex supports 200 per page
**Files:** R/api_openalex.R, R/mod_search_notebook.R

## Verification Results

### Unit Tests
- **test-type-badge.R:** 44 tests passed
  - All 16 OpenAlex types return correct class and label
  - NULL/NA/empty inputs return fallback
  - Unknown types return gray fallback with title-cased label
  - Labels are human-friendly (e.g., "Book Chapter" not "book-chapter")

### Integration Tests
- **Smoke test:** Shiny app starts without errors
- **Grep verification:** Old 6-checkbox pattern removed (0 matches)

### Behavior Validation
- **Default state:** 6 common types ON (article, review, preprint, book, book-chapter, dissertation), 10 rare types OFF
- **Distribution panel:** Shows all 16 types including zeros, sorted by count descending
- **Select All / Deselect All:** Toggles all 16 chips correctly
- **Client-side filtering:** type_filtered_papers reactive filters between keyword and journal without API call
- **Save & Refresh:** Persists chip states to notebook filters, triggers cursor reset

## Self-Check

### Files Created
- [✓] tests/testthat/test-type-badge.R exists

### Files Modified
- [✓] R/mod_search_notebook.R modified (16-type taxonomy, chip toggle UI, type filter reactive)
- [✓] R/api_openalex.R modified (per_page default 100)

### Commits
- [✓] cf6554d exists: "feat(55-01): expand badge system and build chip toggle UI with distribution panel"
- [✓] 8734a44 exists: "feat(55-01): insert client-side type filter and increase API page size"

## Self-Check: PASSED

All files created, all files modified, all commits exist.
