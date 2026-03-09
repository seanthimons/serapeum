# Phase 52: Load More Button - Research

**Researched:** 2026-03-09
**Domain:** R/Shiny UI patterns, reactive state management, button loading feedback
**Confidence:** HIGH

## Summary

Phase 52 adds a Load More button to the search notebook toolbar that fetches the next page of OpenAlex results and appends them to the existing paper list. The pagination infrastructure (cursor tracking, has_more flag, API client support) was completed in Phases 50-51. This phase focuses on:

1. **UI Component:** Add Load More button to toolbar with proper styling, icon, and placement
2. **Loading Feedback:** Spinner swap and disabled state during fetch operations
3. **Append Logic:** Reuse existing search logic with cursor parameter, handle deduplication
4. **Toast Notifications:** Success/error feedback with count information

**Primary recommendation:** Extend the existing `do_search_refresh()` function with a mode parameter (refresh vs append) to avoid duplicating the complex search/filter/save logic. Use standard Shiny reactive patterns (updateActionButton for spinner, observeEvent for click handler). The pagination_state layer from Phase 51 already provides all necessary state tracking.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Button placement & style:**
- Position: after Refresh button, before result count span
- Label: icon + "Load More" text (matches Refresh pattern)
- Icon: angles-down (double chevron down — conveys "fetch more below")
- Color: `btn-outline-info` (sapphire — matches Seed Citation Network button)
- Size: `btn-sm` (matches all toolbar buttons)
- Tooltip: descriptive text explaining the button's function (e.g., "Fetch next page of search results")

**Visibility & disabled state:**
- Always visible in toolbar (not conditionally rendered)
- Disabled when `pagination_state$has_more` is FALSE (including before first search)
- Disabled while a fetch is in progress (prevents double-clicks)
- Button remains in place — no layout shift from show/hide

**Loading feedback:**
- While fetching: button disabled, icon swaps to spinner
- After batch completes: result count ("X of Y results") updates once
- Success toast: "Loaded X more papers (Y total)" — brief confirmation
- On last page (has_more becomes FALSE): standard toast, button disabling is the signal — no special "all loaded" message
- Error: error toast ("Failed to load more — try again"), re-enable button for retry

**Append behavior:**
- New papers inserted into DB, then deduped by OpenAlex ID (same as existing Refresh logic — skip duplicates silently)
- After append, full paper list re-sorted by active sort criterion (client-side sort from Phase 51 applies to all papers)
- Scroll position: preserve current position (best effort — Claude's discretion on implementation given Shiny rendering)
- Papers persist until Refresh is clicked or filters change (existing behavior from Phase 51 cursor reset logic)

### Claude's Discretion

- Exact shinyjs/Shiny mechanism for spinner swap (updateActionButton vs JS toggle)
- Scroll position preservation approach (may depend on how the paper list renders)
- Whether to reuse `do_search_refresh()` with a mode parameter or create a separate `do_load_more()` function
- Toast message exact wording

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PAGE-02 | Load More button fetches next page of results (appends, advances cursor) | Existing `search_papers()` accepts cursor param; `pagination_state$cursor` tracks continuation token; append = call with cursor != NULL |
| PAGE-03 | Load More styled like Topics button (icon+text+sapphire color) | `btn-outline-info` maps to Catppuccin sapphire; icon wrapper pattern established; existing Seed Citation Network button shows sapphire precedent |
| PAGE-04 | Load More hidden when no more results available | `pagination_state$has_more` flag from Phase 51; use disabled state (not conditional rendering per CONTEXT decision) |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | Current (R package) | Reactive UI framework | Project foundation — all UI is Shiny-based |
| bslib | Current (R package) | Bootstrap 5 theming | Provides btn-outline-* classes, card components |
| DuckDB (via R) | Current | Local database | Stores abstracts, handles deduplication |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| shinyjs | Available but not required | DOM manipulation | Optional — only if updateActionButton insufficient |
| httr2 | Current | HTTP client | Already used in api_openalex.R |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| updateActionButton | Custom JS with shinyjs | updateActionButton is simpler; shinyjs adds dependency for minimal gain |
| Disabled state | Conditional rendering (show/hide) | User decision: disabled state prevents layout shift |

**Installation:**
No new packages needed — all dependencies already in project.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── mod_search_notebook.R   # Add Load More button UI + server logic
├── api_openalex.R          # Already supports cursor param (Phase 50)
├── theme_catppuccin.R      # Add icon_angles_down() wrapper if missing
└── db.R                    # Existing deduplication via notebook_id + paper_id unique check
```

### Pattern 1: Toolbar Button with Loading State
**What:** Action button that swaps icon to spinner during async operations
**When to use:** Any toolbar button triggering API calls or long-running operations
**Example:**
```r
# UI (in toolbar div)
actionButton(ns("load_more"), "Load More",
             class = "btn-sm btn-outline-info",
             icon = icon_angles_down(),
             title = "Fetch next page of search results")

# Server (observer pattern)
observeEvent(input$load_more, {
  # Disable and show spinner
  updateActionButton(session, "load_more",
                     label = "Load More",
                     icon = icon_spinner())
  shinyjs::disable("load_more")  # or use is_processing flag

  # Execute async operation
  # (in withProgress block)

  # Re-enable after completion
  updateActionButton(session, "load_more",
                     label = "Load More",
                     icon = icon_angles_down())
  shinyjs::enable("load_more")
})
```

**Source:** Existing pattern in mod_citation_network.R line 1361 uses updateActionButton for state changes.

### Pattern 2: Reuse Existing Logic with Mode Parameter
**What:** Extract common search/filter/save logic into function that handles both refresh and append modes
**When to use:** When new feature shares 90%+ code with existing feature but differs in one aspect (cursor handling)
**Example:**
```r
# Extract into local function with mode parameter
do_search <- function(mode = c("refresh", "append")) {
  mode <- match.arg(mode)

  # Common setup (nb, filters, config)
  cursor_param <- if (mode == "refresh") NULL else pagination_state$cursor

  # Call search_papers with appropriate cursor
  result <- search_papers(..., cursor = cursor_param)

  # Common save logic
  # Update pagination_state
  # Show appropriate notification based on mode
}

# Observers call with different modes
observeEvent(input$refresh_search, { do_search("refresh") })
observeEvent(input$load_more, { do_search("append") })
```

**Source:** Existing `do_search_refresh()` at line 2225 follows local-function extraction pattern.

### Pattern 3: Button Enable/Disable via Reactive Observer
**What:** Use observe() to watch pagination_state and update button enabled state
**When to use:** When button availability depends on reactive values
**Example:**
```r
# Observer pattern for button state
observe({
  # Enable Load More only if has_more is TRUE AND not currently processing
  if (pagination_state$has_more && !is_processing()) {
    shinyjs::enable("load_more")
  } else {
    shinyjs::disable("load_more")
  }
})
```

**Source:** Existing `is_processing` reactiveVal at line 368 used for state management.

### Anti-Patterns to Avoid
- **Conditional rendering (renderUI) for buttons:** Creates layout shift, loses DOM state, requires more reactive complexity than disabled state
- **Duplicating do_search_refresh logic:** The search/filter/save logic is complex (50+ lines) with error handling, excluded papers filtering, progress tracking — don't copy-paste
- **Parsing cursor value:** Phase 50 decision treats cursor as opaque string; never inspect or modify cursor contents
- **Client-side appending to paper list:** Papers must go through DB for deduplication and persistence; never append to UI state directly

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Button loading spinner | Custom CSS animation toggle | `updateActionButton()` with icon swap | Shiny's built-in mechanism handles icon updates; custom JS adds complexity for no benefit |
| Cursor-based pagination | Parse OpenAlex cursor format, build continuation logic | Use opaque cursor from `pagination_state$cursor` | Cursor format is API implementation detail that may change; treating as opaque prevents coupling (Phase 50 decision) |
| Duplicate detection | Check if paper exists before showing in UI | Insert to DB, rely on unique constraint (notebook_id, paper_id) | DB handles deduplication atomically; existing logic at line 2318-2322 already implements this |
| Progress feedback | Custom progress bar for Load More | `withProgress()` + toast notification | Existing pattern used throughout app; users expect consistent feedback |

**Key insight:** Shiny provides robust reactive patterns for button state management and progress feedback. The app already has established patterns for search operations, notifications, and DB operations. Reusing these patterns ensures consistency and reduces bug surface area.

## Common Pitfalls

### Pitfall 1: Reactive Loop with Button State
**What goes wrong:** Button enabled state depends on pagination_state, which updates during search, which can trigger unwanted re-runs of the enable/disable observer
**Why it happens:** Observe() runs whenever any dependency changes, including during the operation itself
**How to avoid:** Use `isolate()` for dependencies that shouldn't trigger observer, or structure logic to only check state when operation completes
**Warning signs:** Button flickers enabled/disabled during operation, console shows excessive observer runs

### Pitfall 2: Forgetting to Reset Button Icon After Error
**What goes wrong:** Button shows spinner indefinitely if error occurs before icon is swapped back
**Why it happens:** Error handlers may skip the icon reset step in the normal flow
**How to avoid:** Use `on.exit()` or `tryCatch()` with finally clause to ensure icon reset happens regardless of success/error
**Warning signs:** Button stays in spinner state after error toast appears

### Pitfall 3: Race Condition with Rapid Clicks
**What goes wrong:** User clicks Load More twice rapidly, triggering two concurrent API calls that may insert duplicates or cause state corruption
**Why it happens:** First click disables button via observer/updateActionButton, but second click may register before UI updates
**How to avoid:** Check `is_processing()` flag at start of observer and return early if TRUE; set flag immediately before any async work
**Warning signs:** Duplicate papers appear, pagination_state has inconsistent counts, error logs show concurrent API calls

### Pitfall 4: Assuming Scroll Position Persists After renderUI
**What goes wrong:** Scroll position jumps to top when new papers are added if paper list is rendered via renderUI
**Why it happens:** Shiny's renderUI replaces entire DOM subtree, losing scroll state
**How to avoid:** If paper list uses renderUI, consider JavaScript-based scroll preservation; if using static UI with dynamic inserts (uiOutput + insertUI), scroll may persist naturally
**Warning signs:** User reports scroll jumping to top after clicking Load More

### Pitfall 5: Not Updating total_fetched Count
**What goes wrong:** Result count shows "25 of 1000 results" even after loading more papers
**Why it happens:** `pagination_state$total_fetched` must be updated after papers are saved to DB, not just after API call
**How to avoid:** Query DB count after save loop completes, update `pagination_state$total_fetched <- dbGetQuery(...)`
**Warning signs:** Result count is stale, users can't tell if Load More worked

## Code Examples

Verified patterns from existing codebase:

### Load More Button UI (Toolbar Integration)
```r
# Insert after refresh_search button (line 110), before result count span
# Source: R/mod_search_notebook.R existing toolbar pattern

actionButton(ns("load_more"), "Load More",
             class = "btn-sm btn-outline-info",
             icon = icon_angles_down(),
             title = "Fetch next page of search results"),
```

### Load More Observer with Loading Feedback
```r
# Source: Adapted from existing do_search_refresh() pattern (line 2225)

observeEvent(input$load_more, {
  req(!is_processing())  # Prevent concurrent requests
  is_processing(TRUE)

  # Show loading state
  updateActionButton(session, "load_more",
                     icon = icon_spinner())

  nb_id <- notebook_id()
  req(nb_id)

  nb <- get_notebook(con(), nb_id)
  req(nb$type == "search")

  cfg <- config()
  newly_added <- 0L

  withProgress(message = "Loading more papers...", value = 0, {
    # Existing search logic here with cursor = pagination_state$cursor
    # ... (same as do_search_refresh but with cursor)

    # After save loop:
    pagination_state$cursor <- result$next_cursor
    pagination_state$has_more <- !is.null(result$next_cursor)

    # Update total_fetched from DB
    count_result <- dbGetQuery(con(),
      "SELECT COUNT(*) as n FROM abstracts WHERE notebook_id = ?",
      list(nb_id))
    pagination_state$total_fetched <- count_result$n

    paper_refresh(paper_refresh() + 1)

    if (newly_added > 0) {
      showNotification(
        paste("Loaded", newly_added, "more papers (",
              pagination_state$total_fetched, "total)"),
        type = "message"
      )
    }
  })

  # Reset button state
  updateActionButton(session, "load_more", icon = icon_angles_down())
  is_processing(FALSE)
}, ignoreInit = TRUE)
```

### Icon Wrapper for angles-down
```r
# Source: R/theme_catppuccin.R existing icon wrapper pattern
# Add if not present:

#' Angles down icon (double chevron down)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_angles_down <- function(...) shiny::icon("angles-down", ...)
```

### Button Enable/Disable Observer
```r
# Source: Reactive pattern for state-dependent UI
# Place in server function

observe({
  # Disable if no more results OR currently processing
  should_disable <- !pagination_state$has_more || is_processing()

  if (should_disable) {
    shinyjs::disable("load_more")
  } else {
    shinyjs::enable("load_more")
  }
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Offset-based pagination (`page=2`) | Cursor-based pagination | Phase 50 (2026-03-07) | Enables consistent pagination even as underlying data changes; aligns with OpenAlex API best practices |
| Server-side sort (re-fetch on sort change) | Client-side sort (reorder displayed papers) | Phase 51 (2026-03-09) | Sort no longer invalidates cursor; Load More preserves sort order across pages |
| Refresh replaces results | Refresh + Load More (append) | Phase 51-52 (2026-03-09) | Users can accumulate large result sets without losing context |

**Deprecated/outdated:**
- Offset-based pagination: OpenAlex API recommends cursor-based for reliability
- Conditional button rendering: Modern Shiny apps prefer disabled state to prevent layout shift

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat (R standard testing framework) |
| Config file | None — tests auto-discovered in tests/testthat/ |
| Quick run command | `Rscript -e "testthat::test_file('tests/testthat/test-{module}.R')"` |
| Full suite command | `Rscript -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PAGE-02 | Load More fetches next page with cursor | unit | `testthat::test_file('tests/testthat/test-load-more.R')` | ❌ Wave 0 |
| PAGE-03 | Button styled with sapphire color | manual | Visual inspection in running app | N/A manual |
| PAGE-04 | Button disabled when has_more=FALSE | unit | `testthat::test_file('tests/testthat/test-load-more.R')` | ❌ Wave 0 |

**Note:** Shiny UI tests (especially reactive button states) are challenging to automate without full Shiny testing framework (shinytest2). Unit tests will focus on helper functions and state logic. Visual/interaction tests are manual.

### Sampling Rate
- **Per task commit:** Unit tests for any new helper functions
- **Per wave merge:** Shiny smoke test (start app, verify button appears and is styled correctly)
- **Phase gate:** Full manual test (search → Load More → verify append → verify disabled state on last page)

### Wave 0 Gaps
- [ ] `tests/testthat/test-load-more.R` — covers button state logic, pagination_state updates
- [ ] `R/theme_catppuccin.R` — add `icon_angles_down()` wrapper if not present
- [ ] Shiny smoke test script — start app, verify no startup errors after button addition

*(Existing test infrastructure covers helper patterns; new test file needed for Load More-specific logic)*

## Sources

### Primary (HIGH confidence)
- R/mod_search_notebook.R (lines 78-111, 350-389, 2225-2350) — Existing toolbar pattern, pagination_state, do_search_refresh logic
- R/api_openalex.R (lines 1-100, 287-300) — Cursor handling, parse_search_response structure
- R/theme_catppuccin.R (lines 352, 467-472) — Icon wrapper pattern
- .planning/phases/51-pagination-state-management/51-01-PLAN.md — Phase 51 implementation details
- .planning/phases/50-api-pagination-foundation/50-01-SUMMARY.md — Cursor as opaque string decision

### Secondary (MEDIUM confidence)
- [Font Awesome angles-down icon](https://fontawesome.com/icons/angles-down) — Icon availability verified
- R/mod_citation_network.R (line 1361) — updateActionButton usage precedent

### Tertiary (LOW confidence)
- None — all findings verified against existing codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All patterns exist in current codebase
- Architecture: HIGH - Reusing established patterns from Phases 50-51
- Pitfalls: HIGH - Based on common Shiny reactive pitfalls and project-specific patterns
- Validation: MEDIUM - R unit testing is well-understood, but Shiny reactive testing has limitations

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (30 days — stable R/Shiny patterns, no fast-moving dependencies)
