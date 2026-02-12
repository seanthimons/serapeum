---
phase: 09-bug-fixes
plan: 01
subsystem: api-layer
tags:
  - bugfix
  - authentication
  - error-handling
  - user-experience
dependency_graph:
  requires: []
  provides:
    - openalex-query-param-auth
    - api-error-classification-system
    - friendly-error-toasts
    - no-duplicate-tab-requests
  affects:
    - R/api_openalex.R
    - R/api_openrouter.R
    - R/mod_search_notebook.R
    - R/mod_topic_explorer.R
    - app.R
tech_stack:
  added: []
  patterns:
    - custom-error-conditions
    - single-classification-data-flow
    - split-observer-pattern
key_files:
  created: []
  modified:
    - R/api_openalex.R
    - R/api_openrouter.R
    - R/mod_search_notebook.R
    - R/mod_topic_explorer.R
    - app.R
decisions: []
metrics:
  duration_minutes: 6
  completed: 2026-02-12T02:09:03Z
---

# Phase 09 Plan 01: API Bug Fixes Summary

**One-liner:** Fixed OpenAlex 401 auth (query param vs Bearer header), added friendly error toasts with expandable details, and prevented duplicate search requests on tab navigation.

## Objectives Met

✅ OpenAlex API requests authenticate via query param (fixes 401 errors on topic browsing)
✅ All API errors show plain-language messages with expandable technical details
✅ Error classification happens exactly once in API layer via custom conditions
✅ Tab navigation no longer triggers duplicate OpenAlex search requests

## Tasks Completed

### Task 1: Fix OpenAlex auth and create error classification system
- **Commit:** d490f32
- **Changes:**
  - Removed Bearer auth header from `build_openalex_request()` (line 19)
  - Added api_key as query parameter via `req_url_query(api_key = api_key)` (line 106)
  - Created `classify_api_error(e, service)` helper that returns {message, details, severity}
  - Created `stop_api_error(e, service)` that throws custom `api_error` condition with all three fields attached
  - Updated `search_papers()`, `fetch_all_topics()` in api_openalex.R to use `stop_api_error()`
  - Updated `chat_completion()`, `get_embeddings()` in api_openrouter.R to use `stop_api_error()`
  - Updated silent error loggers (get_citing_papers, get_cited_papers, get_related_papers) to use `classify_api_error()` for consistent messaging

### Task 2: Apply friendly toast notifications across all API call sites
- **Commit:** 57b8fab
- **Changes:**
  - Created `show_error_toast(message, details, severity, duration)` helper in mod_search_notebook.R
  - Toasts include expandable `<details>` section for technical error info
  - Severity-based styling: "error" (red) for hard failures, "warning" (yellow) for rate limits/timeouts
  - Updated all API call sites to extract pre-classified data from api_error conditions:
    - `if (inherits(e, "api_error"))` → extract `e$message`, `e$details`, `e$severity` directly
    - `else` fallback → call `classify_api_error()` for non-API errors
  - Applied to: search_papers() in mod_search_notebook.R (line 1315), rag_query() chat errors (line 1640), fetch_all_topics() in mod_topic_explorer.R (lines 92, 148), topic requests in app.R (line 814, 886), discovery requests in app.R (line 712)
  - Non-API validation errors (empty query, missing key) kept their simple `showNotification` style

### Task 3: Prevent duplicate OpenAlex requests on tab navigation
- **Commit:** 6678763
- **Changes:**
  - Extracted search refresh logic into local `do_search_refresh()` function (line 1276)
  - Split combined `observeEvent(list(input$refresh_search, search_refresh_trigger()), ...)` into two separate observers:
    - `observeEvent(input$refresh_search, ...)` with `ignoreInit = TRUE` and `ignoreNULL = TRUE` (line 1396)
    - `observeEvent(search_refresh_trigger(), ...)` with `ignoreInit = TRUE` (line 1401)
  - Prevents spurious fires when UI re-renders on tab navigation
  - Cached results persist in DB and display immediately when returning to search notebook

## Deviations from Plan

None - plan executed exactly as written.

## Outcomes

**Before:**
- Topic browsing failed with 401 Unauthorized (Bearer auth not supported by OpenAlex)
- Users saw raw HTTP error messages like "HTTP 429" or "HTTP 500"
- Switching tabs and returning to search notebook triggered duplicate API requests

**After:**
- Topic browsing works correctly with query param authentication
- Users see friendly messages: "OpenAlex rate limit reached. Please wait a moment and try again."
- Technical details available via expandable "Show details" link
- Tab navigation shows cached results instantly without API calls
- Error classification happens once (API layer) instead of redundantly in UI layer

## Technical Details

### Single-Classification Data Flow

API layer (api_openalex.R, api_openrouter.R):
1. Catch error from httr2
2. Call `stop_api_error(e, "ServiceName")`
3. This calls `classify_api_error()` once → returns {message, details, severity}
4. Throw custom condition with all three fields attached

UI layer (modules, app.R):
1. Catch `api_error` condition
2. Extract `e$message`, `e$details`, `e$severity` directly (no re-classification)
3. Pass to `show_error_toast()`

### Split Observer Pattern

**Problem:** Combined `observeEvent(list(input$refresh_search, trigger()), ...)` fires when UI re-renders because Shiny treats the input value transition from NULL (disconnected) to 0 (new button) as a change, even with `ignoreInit = TRUE`.

**Solution:** Split into two separate observers so each trigger is isolated:
- Button click observer only fires on actual clicks (`ignoreNULL = TRUE` prevents NULL transitions)
- Trigger observer only fires when explicitly incremented by save_search

## Files Modified

- **R/api_openalex.R** (98 lines added): Error helpers, auth fix, stop_api_error usage
- **R/api_openrouter.R** (2 lines changed): stop_api_error usage
- **R/mod_search_notebook.R** (92 lines added/changed): show_error_toast helper, condition extraction, split observer
- **R/mod_topic_explorer.R** (20 lines changed): Condition extraction
- **app.R** (30 lines changed): Condition extraction

## Self-Check: PASSED

✅ All created/modified files exist
✅ All commit hashes verified in git log
✅ Functions verified: `classify_api_error()`, `stop_api_error()`, `show_error_toast()`
✅ OpenAlex auth uses query param (grep confirmed `req_url_query.*api_key`)
✅ Combined observer pattern removed (grep confirmed no matches)
✅ All R files source without errors
