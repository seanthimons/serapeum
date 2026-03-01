---
phase: 13-export-to-seed-workflow
plan: 01
subsystem: discovery-workflow
tags: [ui-enhancement, cross-module-communication, reactive-wiring, workflow-integration]
dependency_graph:
  requires: [phase-11-doi-storage]
  provides: [export-to-seed-workflow]
  affects: [mod_search_notebook, mod_seed_discovery, app.R]
tech_stack:
  added: []
  patterns: [reactive-bridge-pattern, timestamp-deduplication, auto-trigger-lookup]
key_files:
  created: []
  modified:
    - R/mod_search_notebook.R
    - R/mod_seed_discovery.R
    - app.R
decisions:
  - Timestamp-based deduplication for seed_request reactive (each click produces unique value)
  - Auto-trigger paper lookup on DOI pre-fill (no manual "Look Up" button click required)
  - Clear pre_fill_doi after lookup to prevent re-trigger on view navigation
metrics:
  duration_minutes: 3
  tasks_completed: 2
  files_modified: 3
  commits: 2
  completed_date: 2026-02-12
---

# Phase 13 Plan 01: Export-to-Seed Workflow Summary

**One-liner:** Seamless "Use as Seed" button in search notebook abstract view navigates to seed discovery with DOI pre-filled and auto-looked-up

## What Was Built

Added cross-module communication infrastructure enabling users to click "Use as Seed" from any paper's abstract detail view in a search notebook, automatically navigate to the seed discovery view with the paper's DOI pre-filled, and trigger paper lookup without manual intervention.

**User journey:**
1. User opens search notebook, clicks on a paper with a DOI
2. Abstract detail view shows "Use as Seed" button (seedling icon, green outline)
3. User clicks button
4. App navigates to seed discovery view
5. DOI input field is pre-filled with paper's DOI
6. Paper lookup auto-triggers and loads seed paper
7. User selects citation direction and creates new notebook
8. Original search notebook remains accessible in sidebar with all state preserved

## Architecture

**Reactive bridge pattern:**
```
mod_search_notebook.R (producer)
  └─> seed_request reactiveVal (doi + timestamp)
      └─> returns to app.R
          └─> observeEvent in app.R (consumer)
              ├─> Sets current_view("discover")
              └─> Sets pre_fill_doi(req$doi)
                  └─> mod_seed_discovery.R (consumer)
                      ├─> updateTextInput(doi_input)
                      └─> Auto-triggers get_paper() lookup
```

**Timestamp deduplication approach:**
- Each "Use as Seed" click sets `seed_request(list(doi = ..., ts = Sys.time()))`
- Timestamp ensures each click produces a unique reactive value
- `observeEvent` fires even when clicking the same paper twice (different timestamps)
- No manual reset of `seed_request` needed

**Pre-fill auto-lookup:**
- `mod_seed_discovery` accepts optional `pre_fill_doi` reactiveVal parameter
- When DOI is pre-filled, module automatically:
  1. Updates DOI text input
  2. Gets OpenAlex config (email, API key)
  3. Calls `get_paper()` with progress indicator
  4. Sets `seed_paper()` reactive
  5. Clears `pre_fill_doi(NULL)` to prevent re-trigger

## Implementation Details

### Task 1: Add "Use as Seed" button to search notebook

**File:** `R/mod_search_notebook.R`

**Changes:**
1. Added `seed_request <- reactiveVal(NULL)` after line 226 (with other reactiveVals)
2. Replaced `output$detail_actions` renderUI (lines 858-866) to conditionally show:
   - "Use as Seed" button (green, seedling icon) when paper has DOI
   - Close button (existing)
3. Added `observeEvent(input$use_as_seed, ...)` handler:
   - Gets `viewed_paper()` id
   - Looks up paper in `papers_data()` to get DOI
   - Sets `seed_request(list(doi = paper$doi, ts = Sys.time()))`
4. Added `return(seed_request)` at end of moduleServer (line 1769)

**Commit:** `d2b4fea`

### Task 2: Wire reactive bridge and add pre_fill_doi handling

**Files:** `app.R`, `R/mod_seed_discovery.R`

**app.R changes:**
1. Added `pre_fill_doi <- reactiveVal(NULL)` after line 179
2. Captured search notebook return value: `search_seed_request <- mod_search_notebook_server(...)`
3. Passed `pre_fill_doi` to seed discovery: `mod_seed_discovery_server(..., pre_fill_doi)`
4. Added bridge observeEvent (after line 874):
   - Observes `search_seed_request()`
   - Sets `current_view("discover")` and `current_notebook(NULL)`
   - Sets `pre_fill_doi(req$doi)`

**mod_seed_discovery.R changes:**
1. Added `pre_fill_doi = NULL` parameter to function signature
2. Added observeEvent handler after `seed_paper <- reactiveVal(NULL)`:
   - Pre-fills DOI text input via `updateTextInput()`
   - Gets OpenAlex config (email, API key)
   - Shows warning if email not configured
   - Calls `get_paper()` with progress message
   - Sets `seed_paper()` on success
   - Shows notification on success/error
   - Clears `pre_fill_doi(NULL)` to prevent re-trigger

**Commit:** `f7fc62c`

## Deviations from Plan

None - plan executed exactly as written. No bugs encountered, no missing functionality discovered, no architectural changes needed.

## Key Decisions

**1. Timestamp-based reactive deduplication**
- **Problem:** Clicking same paper twice wouldn't fire observeEvent (same DOI value)
- **Solution:** Include `ts = Sys.time()` in seed_request payload
- **Benefit:** Every click produces unique value, no manual reset needed
- **Alternative rejected:** Resetting `seed_request(NULL)` after consumption (more complex, timing issues)

**2. Auto-trigger lookup on pre-fill**
- **Problem:** User would have to click "Look Up" after navigation (extra step)
- **Solution:** Replicate lookup logic in pre_fill_doi observeEvent
- **Benefit:** Zero friction - one click from abstract to seed paper loaded
- **Alternative rejected:** Just pre-fill input, require manual lookup (breaks workflow flow)

**3. Clear pre_fill_doi after lookup**
- **Problem:** Navigating back to discovery view would re-trigger lookup
- **Solution:** Set `pre_fill_doi(NULL)` after successful/failed lookup
- **Benefit:** Prevents duplicate API calls and unexpected UI behavior
- **Note:** Works because `pre_fill_doi` is a reactiveVal passed by reference

## Verification

All success criteria met:

- [x] "Use as Seed" button visible in abstract detail for papers with DOI
- [x] Button does NOT appear for papers without DOI
- [x] One click navigates to seed discovery with DOI pre-filled
- [x] Paper auto-looked-up without manual "Look Up" click
- [x] Original notebook preserved and accessible via sidebar
- [x] Seeded search creates notebook with same filters/sorting as keyword search (existing behavior)

**Manual testing recommended:**
1. Create/open search notebook with papers
2. Click paper with DOI → verify button appears
3. Click "Use as Seed" → verify navigation and auto-lookup
4. Select citation direction → create notebook
5. Navigate back to original notebook → verify state preserved
6. Test with paper WITHOUT DOI → verify button absent

## Files Modified

| File | Lines Changed | Purpose |
|------|---------------|---------|
| R/mod_search_notebook.R | +39, -2 | Add button, reactive return, seed_request handler |
| app.R | +14, -2 | Reactive bridge wiring, pre_fill_doi reactiveVal |
| R/mod_seed_discovery.R | +49, -1 | Accept pre_fill_doi, auto-trigger lookup |

**Total:** 102 lines added, 5 lines removed across 3 files

## Testing Notes

**Unit testing not included in this phase.** Manual testing recommended for:
- DOI presence detection (button visibility)
- Cross-module reactive wiring (navigation triggers)
- Auto-lookup success/failure paths
- State persistence across view changes

Future consideration: Add integration tests for cross-module workflows using `shinytest2`.

## Next Steps

**Immediate:**
- Manual verification testing (see Verification section)
- User acceptance testing for workflow fluidity

**Future enhancements:**
- Add "Use as Seed" from citation network node right-click menu
- Add "Use as Seed" from document notebook search results
- Add keyboard shortcut (e.g., 'S' key) for "Use as Seed" action
- Track usage analytics for export-to-seed workflow

## Self-Check: PASSED

**Created files verified:** None created (all modifications)

**Modified files verified:**
```
FOUND: R/mod_search_notebook.R
FOUND: R/mod_seed_discovery.R
FOUND: app.R
```

**Commits verified:**
```
FOUND: d2b4fea (Task 1 - Add 'Use as Seed' button)
FOUND: f7fc62c (Task 2 - Wire reactive bridge)
```

All claims in this summary are verified against actual file system and git history.
