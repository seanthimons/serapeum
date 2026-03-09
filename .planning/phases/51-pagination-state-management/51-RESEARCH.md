# Phase 51: Pagination State Management - Research

**Researched:** 2026-03-09
**Domain:** Shiny reactive state management for API pagination
**Confidence:** HIGH

## Summary

Phase 51 establishes a server-side state management layer for OpenAlex cursor-based pagination using Shiny's `reactiveValues()`. The phase tracks pagination cursor, has_more flag, total_fetched count, and API total — enabling distinct Refresh vs Load More behaviors while preventing reactive loops. Research confirms that `reactiveValues()` with `observeEvent()` is the standard Shiny pattern for complex state tracking, and `isolate()` is essential to prevent infinite loops when observers modify reactive values they depend on.

The existing codebase already uses this pattern extensively (e.g., `delete_observers`, `block_journal_observers` at mod_search_notebook.R:361-364), so integration follows established project conventions. The key challenges are: (1) coordinating cursor resets across multiple filter change observers, (2) avoiding reactive loops when updating `total_fetched` from `papers_data()`, and (3) ensuring Refresh behavior resets cursor while maintaining accumulate semantics.

**Primary recommendation:** Use a single `pagination_state` reactiveValues object with four fields (`cursor`, `has_more`, `total_fetched`, `api_total`), reset cursor in all filter change observers using `isolate()` for reads, and update state after each API call in `do_search_refresh()`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Refresh behavior:**
- Refresh keeps current accumulate behavior: fetches page 1 with `cursor = NULL`, adds new papers, skips duplicates — never deletes existing papers
- Refresh is a recovery/fix tool for weird states, not the primary data loading mechanism
- Refresh always resets cursor to NULL so next Load More starts from page 2 of current results
- Refresh button always visible (shows warning toast if no query exists)

**Cursor reset scope:**
- Cursor resets when ANY Edit Search parameter changes (query, year, type, OA, min citations, retracted, search field) — simple rule: if the API query changes, cursor is invalid
- `save_search` observer already triggers `do_search_refresh()` which will reset cursor
- Year slider on main view does NOT reset cursor — it's display-side filtering only, doesn't change API query
- Sort order does NOT reset cursor — sort becomes client-side only (see Sort decision below)
- Deleting papers locally does NOT reset cursor — API pagination position is unaffected by local removals

**Sort order change:**
- Sort becomes client-side display reordering only
- `search_papers()` always fetches with `sort = "relevance_score"` regardless of dropdown selection
- Sort dropdown reorders the displayed paper list locally
- This simplifies cursor management — cursor is never affected by sort changes

**Total fetched tracking:**
- `pagination_state` reactiveValues tracks: `cursor` (string or NULL), `has_more` (logical), `total_fetched` (integer), `api_total` (integer from meta.count)
- `total_fetched` = total paper count in notebook (all papers, not session-scoped)
- `api_total` = total matching results from OpenAlex `meta.count` field
- Display format: "X of Y results" shown in toolbar area
- No hard cap on fetching — users can Load More as long as `has_more` is TRUE
- Display only — informational, no behavioral limits

### Claude's Discretion

- Exact placement within toolbar area for the result count
- Whether to store cursor in DB (for session persistence) or keep in-memory only
- Reactive loop prevention strategy (isolate vs observeEvent patterns)
- Error handling when cursor becomes invalid mid-session

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PAGE-01 | Refresh button retries current search (replaces results, resets cursor) | `reactiveValues()` cursor tracking + reset in `do_search_refresh()` |
| PAGE-05 | Cursor state resets when search query or filters change | `observeEvent()` pattern for filter changes with cursor reset logic |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | Latest stable | Reactive web framework | Project foundation — all state management uses Shiny reactivity |
| reactiveValues() | Built-in | Multi-field reactive state | Standard for complex state with multiple related fields |
| observeEvent() | Built-in | Event-driven observers | Preferred over `observe()` — explicit trigger makes reactive dependencies clear |
| isolate() | Built-in | Break reactive dependencies | Essential for preventing infinite loops when observers modify values they depend on |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| reactiveVal() | Built-in | Single-value reactive | Simple scalars (already used: `paper_refresh`, `is_processing`) |
| debounce() | Built-in | Delay reactive updates | Already used for year slider (400ms) — not needed for pagination state |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| reactiveValues() | reactiveVal(list(...)) | reactiveValues provides individual field reactivity; reactiveVal(list) treats entire list as atomic unit requiring manual change propagation |
| observeEvent() | observe() + isolate() | observeEvent is syntactic sugar — same behavior, clearer intent |
| In-memory state | DB-persisted cursor | DB persistence enables session recovery but adds DB write overhead + schema changes; pagination is transient — in-memory sufficient |

**Installation:**
No additional packages required — all built-in Shiny primitives.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── mod_search_notebook.R  # Add pagination_state reactiveValues here
├── api_openalex.R         # Already returns (papers, next_cursor, count)
└── db.R                   # Count papers for total_fetched
```

### Pattern 1: Pagination State Container
**What:** Single `reactiveValues()` object holding all pagination-related state
**When to use:** Multiple related state fields that update together or independently
**Example:**
```r
# Source: Mastering Shiny Chapter 15 (reactiveValues best practice)
# Location: mod_search_notebook.R, near existing reactiveValues (line 361-364)
pagination_state <- reactiveValues(
  cursor = NULL,           # NULL = page 1, string = continuation token
  has_more = FALSE,        # Can fetch another page
  total_fetched = 0L,      # Total papers in notebook (from DB)
  api_total = 0L           # Total matching results (from meta.count)
)
```

### Pattern 2: Cursor Reset on Filter Changes
**What:** Reset cursor to NULL when API-affecting parameters change
**When to use:** Any observer handling Edit Search parameters
**Example:**
```r
# Source: Mastering Shiny Chapter 16 (observeEvent coordination)
# Location: save_search observer (line 2127)
observeEvent(input$save_search, {
  # ... existing update_notebook logic ...

  # Reset pagination state before triggering refresh
  pagination_state$cursor <- NULL
  pagination_state$has_more <- FALSE

  # Trigger search refresh (existing)
  search_refresh_trigger(search_refresh_trigger() + 1)
})
```

### Pattern 3: Update State After API Call (Avoiding Reactive Loops)
**What:** Update `pagination_state` in `do_search_refresh()` after API response
**When to use:** API response provides new cursor/count — update state without creating reactive dependency
**Example:**
```r
# Source: Mastering Shiny Chapter 15 (isolate to prevent loops)
# Location: do_search_refresh() function (line 2189)
do_search_refresh <- function() {
  # ... existing query/filters logic ...

  result <- search_papers(
    nb$search_query,
    email, api_key,
    # ... filters ...
    cursor = isolate(pagination_state$cursor)  # Read without dependency
  )

  # Update state after successful fetch
  pagination_state$cursor <- result$next_cursor
  pagination_state$has_more <- !is.null(result$next_cursor)
  pagination_state$api_total <- result$count

  # Update total_fetched from DB after adding papers
  nb_id <- notebook_id()
  pagination_state$total_fetched <- nrow(list_abstracts(con(), nb_id))

  # ... rest of function ...
}
```

### Pattern 4: Display Result Count Reactively
**What:** Render "X of Y results" text output from pagination state
**When to use:** Any UI element needing to display pagination status
**Example:**
```r
# Source: Shiny fundamentals (reactive outputs)
# Location: New output in mod_search_notebook.R server
output$result_count <- renderText({
  fetched <- pagination_state$total_fetched
  total <- pagination_state$api_total

  if (total == 0) {
    ""
  } else if (fetched >= total) {
    paste(total, "results")
  } else {
    paste(fetched, "of", total, "results")
  }
})
```

### Anti-Patterns to Avoid

- **Modifying reactiveValues inside reactive() without isolate:** Creates infinite loops when the reactive depends on the value it modifies. Always use `isolate()` for reads when the same observer/reactive writes to that value.
- **Multiple observers updating cursor independently:** Creates race conditions. Centralize cursor updates in `do_search_refresh()` and resets in filter change observers.
- **Storing cursor in reactive() instead of reactiveValues():** Makes it read-only from observer perspective. Use `reactiveValues()` for state that observers must mutate.
- **Resetting cursor in year slider observer:** Year slider is display-side only (confirmed in CONTEXT.md) — don't add API-level state changes here.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reactive state with multiple fields | Custom R6 class with change callbacks | `reactiveValues()` | Shiny's reactive system handles invalidation/propagation automatically; custom callbacks break reactive graph |
| Debouncing state updates | Manual `invalidateLater()` + timestamp tracking | `debounce()` (if needed) | Built-in handles edge cases (rapid changes, session cleanup). Not needed for pagination — state updates are discrete events |
| Coordinating observers | Global flag variables (`pagination_reset_flag <<- TRUE`) | `observeEvent()` + `isolate()` | Global state breaks Shiny's reactive graph; use reactive primitives for proper dependency tracking |
| Cursor persistence | Custom file-based state saving | In-memory only (or `reactiveValues()` + DB if needed) | Pagination is transient — users expect fresh search on reload. DB persistence adds complexity without user value |

**Key insight:** Shiny's reactive primitives (`reactiveValues()`, `observeEvent()`, `isolate()`) are designed specifically for the coordination and loop-prevention problems that pagination state management encounters. Custom solutions lose automatic invalidation tracking and create hard-to-debug reactive cycles.

## Common Pitfalls

### Pitfall 1: Infinite Reactive Loop (High Likelihood)
**What goes wrong:** Observer modifies a `reactiveValues()` field it depends on, causing infinite re-execution
**Why it happens:** When you read `pagination_state$cursor` inside an observer and also write to it without `isolate()`, Shiny creates a reactive dependency on cursor, which triggers the observer again when written
**How to avoid:**
- Use `isolate()` when reading values you'll write: `cursor = isolate(pagination_state$cursor)`
- Or structure as `observeEvent(trigger, { pagination_state$cursor <- new_value })` where trigger is a different reactive
**Warning signs:** App freezes, browser tab becomes unresponsive, R session CPU spikes to 100%

**Example (WRONG):**
```r
observe({
  current_cursor <- pagination_state$cursor  # Creates dependency
  result <- search_papers(..., cursor = current_cursor)
  pagination_state$cursor <- result$next_cursor  # Triggers observer again → infinite loop
})
```

**Example (CORRECT):**
```r
observeEvent(search_refresh_trigger(), {  # Trigger is external
  result <- search_papers(..., cursor = isolate(pagination_state$cursor))  # No dependency
  pagination_state$cursor <- result$next_cursor  # Safe update
})
```

### Pitfall 2: Cursor Reset Forgotten in New Filter Observer
**What goes wrong:** New filter added (e.g., author filter in future phase), observer updates notebook but forgets to reset cursor — Load More fetches wrong continuation
**Why it happens:** Cursor reset logic not centralized, easy to miss when adding new filters
**How to avoid:**
- Document pattern: "All Edit Search parameter observers MUST reset cursor"
- Add comment block in save_search observer listing all reset requirements
- Consider helper function: `reset_pagination_state()` called from all filter observers
**Warning signs:** After changing filters, Load More returns papers that don't match new criteria; duplicate papers appear

### Pitfall 3: NULL Assignment Removes reactiveValues Key
**What goes wrong:** Assigning `NULL` to a reactiveValues field removes the key entirely, breaking code that checks `if (is.null(pagination_state$cursor))`
**Why it happens:** R's list semantics — `list$key <- NULL` deletes the key, different from `list$key <- NA`
**How to avoid:**
- For cursor: Use `NULL` as "page 1" sentinel — deletion is acceptable since NULL check works either way
- For counts: Use `0L` instead of `NULL` for numeric fields (`total_fetched`, `api_total`)
- Test both initial state (key doesn't exist) and reset state (key exists with NULL value)
**Warning signs:** `Error: object 'cursor' not found` when accessing `pagination_state$cursor`; `is.null()` checks fail unexpectedly

### Pitfall 4: Race Condition Between API Call and State Update
**What goes wrong:** API call succeeds but app errors before updating `pagination_state` — cursor stuck on old value, next Load More fetches duplicate page
**Why it happens:** State update happens after error-prone operations (DB writes, paper processing)
**How to avoid:**
- Use `tryCatch()` to ensure state updates even on partial failure
- Or update cursor immediately after successful API response, before DB operations
- Log cursor state changes for debugging
**Warning signs:** Repeated "No new papers found" after Load More; cursor never advances despite has_more=TRUE

### Pitfall 5: total_fetched Out of Sync with DB
**What goes wrong:** `total_fetched` shows stale count after papers deleted or bulk imported from other sessions
**Why it happens:** `total_fetched` only updated in `do_search_refresh()`, not reactive to DB changes
**How to avoid:**
- Update `total_fetched` whenever `paper_refresh()` increments (existing trigger for paper list re-read)
- Create reactive expression: `total_fetched <- reactive({ nrow(list_abstracts(con(), notebook_id())) })`
- Trade clarity for accuracy: accept slight staleness, update only on search/refresh actions
**Warning signs:** Result count doesn't match actual paper list length; count decreases after refresh (shouldn't happen with accumulate behavior)

## Code Examples

Verified patterns from existing codebase and official Shiny documentation:

### Initialize Pagination State
```r
# Source: Existing pattern from mod_search_notebook.R:361-364 (reactiveValues usage)
# Location: mod_search_notebook.R server function, after existing reactiveValues
pagination_state <- reactiveValues(
  cursor = NULL,          # NULL = start of results, string = continuation token
  has_more = FALSE,       # TRUE if next_cursor was non-NULL in last response
  total_fetched = 0L,     # Total papers in notebook (from DB count)
  api_total = 0L          # Total matching papers from OpenAlex meta.count
)
```

### Reset Cursor on Filter Change
```r
# Source: CONTEXT.md decision + observeEvent pattern from Mastering Shiny
# Location: save_search observer (mod_search_notebook.R:2127)
observeEvent(input$save_search, {
  nb_id <- notebook_id()
  req(nb_id)

  # ... existing query validation and filter collection ...

  # Update notebook (existing)
  update_notebook(con(), nb_id, search_query = query, search_filters = filters)

  # Reset pagination state (NEW)
  pagination_state$cursor <- NULL
  pagination_state$has_more <- FALSE

  removeModal()
  showNotification("Search updated", type = "message")

  # Trigger refresh (existing)
  search_refresh_trigger(search_refresh_trigger() + 1)
})
```

### Update State After API Call
```r
# Source: do_search_refresh() function (mod_search_notebook.R:2189)
# Location: Inside do_search_refresh(), after search_papers() call
do_search_refresh <- function() {
  # ... existing setup ...

  result <- tryCatch({
    search_papers(
      nb$search_query,
      email, api_key,
      from_year = filters$from_year,
      to_year = filters$to_year,
      per_page = abstracts_count,
      search_field = filters$search_field %||% "default",
      is_oa = filters$is_oa %||% FALSE,
      min_citations = filters$min_citations,
      exclude_retracted = filters$exclude_retracted %||% TRUE,
      work_types = filters$work_types,
      cursor = NULL  # Always NULL for Refresh (CONTEXT.md decision)
    )
  }, error = function(e) {
    # ... existing error handling ...
  })

  # Update pagination state after successful fetch (NEW)
  pagination_state$cursor <- result$next_cursor
  pagination_state$has_more <- !is.null(result$next_cursor)
  pagination_state$api_total <- result$count

  papers <- result$papers
  # ... existing paper processing ...

  # Update total_fetched after papers added to DB (NEW)
  pagination_state$total_fetched <- nrow(list_abstracts(con(), nb_id))

  # ... rest of function ...
}
```

### Display Result Count
```r
# Source: Shiny renderText pattern
# Location: New output in mod_search_notebook.R server
output$result_count <- renderText({
  fetched <- pagination_state$total_fetched
  total <- pagination_state$api_total

  if (total == 0) {
    ""
  } else if (fetched >= total) {
    paste(total, "results")
  } else {
    paste(fetched, "of", total, "results")
  }
})
```

### Prevent Reactive Loop with isolate()
```r
# Source: Mastering Shiny Chapter 15 (isolate documentation)
# Location: Any observer that reads and writes pagination_state
observeEvent(search_refresh_trigger(), {
  # Read cursor without creating reactive dependency
  current_cursor <- isolate(pagination_state$cursor)

  result <- search_papers(..., cursor = current_cursor)

  # Safe to update — no dependency was created
  pagination_state$cursor <- result$next_cursor
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Offset-based pagination (`page=2&per_page=25`) | Cursor-based pagination (opaque continuation tokens) | Phase 50 (2026-03-06) | Eliminates page drift when results change; enables deep pagination without performance degradation |
| `observe()` + manual `isolate()` | `observeEvent(trigger, handler)` | Shiny 1.6.0+ (2021) | Clearer reactive dependencies, less boilerplate, same behavior as `observe({trigger; isolate(handler)})` |
| Storing pagination in URL params | In-memory `reactiveValues()` | N/A (project decision) | Simpler implementation, transient state matches user expectations (fresh search on reload) |
| Client-side result accumulation (JS) | Server-side state tracking (R) | Phase 51 (this phase) | Consistent with Shiny reactive model, easier testing, no JS/R synchronization |

**Deprecated/outdated:**
- **Offset pagination:** OpenAlex deprecated in favor of cursor-based (Phase 50 updated all calls)
- **`updateReactiveValue()`:** Never existed — use direct assignment `rv$field <- value`
- **Global reactive state (non-namespaced):** Breaks module encapsulation — always scope reactiveValues inside module server function

## Open Questions

1. **Should cursor be persisted to DB for session recovery?**
   - What we know: In-memory state is simpler, matches transient nature of pagination
   - What's unclear: User expectation if they close/reopen app mid-pagination — restart from page 1 or continue?
   - Recommendation: Start with in-memory (low complexity). Add DB persistence only if users request it. Most academic search tools (PubMed, Google Scholar) reset pagination on reload.

2. **How should total_fetched react to paper deletions?**
   - What we know: CONTEXT.md says "deleting papers locally does NOT reset cursor", `total_fetched` should reflect actual DB count
   - What's unclear: Should deleting 5 papers show "20 of 100 results" (DB count) or "25 of 100 results" (fetched count)? Does count drop after deletion?
   - Recommendation: Use DB count (`nrow(list_abstracts())`) — matches actual notebook state, updates automatically when `paper_refresh()` triggers. Display changes immediately after deletion.

3. **Error handling when cursor becomes invalid (API state changed)?**
   - What we know: OpenAlex may invalidate cursors if search index rebuilds
   - What's unclear: How to detect stale cursor (400 error? specific message?), should we auto-reset to page 1 or show error toast?
   - Recommendation: Wrap Load More API call in `tryCatch()`, detect 400 errors mentioning "cursor", auto-reset `pagination_state$cursor <- NULL` and show warning toast "Search results updated, restarting from page 1". Test by manually corrupting cursor string.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat (latest stable) |
| Config file | None — tests in `tests/testthat/` directory |
| Quick run command | `testthat::test_file("tests/testthat/test-pagination-state.R")` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PAGE-01 | Refresh resets cursor to NULL | unit | `testthat::test_file("tests/testthat/test-pagination-state.R") -x` | ❌ Wave 0 |
| PAGE-05 | Cursor resets on filter changes | integration | `testthat::test_file("tests/testthat/test-pagination-state.R") -x` | ❌ Wave 0 |
| N/A | reactiveValues initialization | unit | `testthat::test_file("tests/testthat/test-pagination-state.R") -x` | ❌ Wave 0 |
| N/A | total_fetched syncs with DB count | unit | `testthat::test_file("tests/testthat/test-pagination-state.R") -x` | ❌ Wave 0 |

**Note:** Shiny reactive contexts require `shiny::testServer()` for testing observers and reactiveValues. Standard unit tests can verify helper functions only.

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/testthat/test-pagination-state.R")`
- **Per wave merge:** `testthat::test_dir("tests/testthat")`
- **Phase gate:** Full suite green + manual smoke test (start app, Edit Search, verify cursor reset)

### Wave 0 Gaps
- [ ] `tests/testthat/test-pagination-state.R` — covers PAGE-01, PAGE-05, reactiveValues initialization, state sync
- [ ] Shiny test server setup pattern (if not already in existing tests)

## Sources

### Primary (HIGH confidence)
- [Mastering Shiny Chapter 15: Reactive building blocks](https://mastering-shiny.org/reactivity-objects.html) - `reactiveValues()`, `isolate()` patterns
- [Mastering Shiny Chapter 16: Escaping the graph](https://mastering-shiny.org/reactivity-components.html) - `observeEvent()`, preventing infinite loops
- Existing codebase: `R/mod_search_notebook.R` lines 361-364 (reactiveValues pattern), 2127-2186 (save_search observer), 2189-2280 (do_search_refresh)
- Phase 50 implementation: `R/api_openalex.R` lines 290-305 (parse_search_response returns cursor)

### Secondary (MEDIUM confidence)
- [Shiny Event Handling Guide](https://www.datanovia.com/learn/tools/shiny-apps/server-logic/observe-events.html) - observeEvent vs observe patterns
- [Shiny Reactive Values Advanced Patterns](https://www.datanovia.com/learn/tools/shiny-apps/server-logic/reactive-values.html) - Performance and coordination
- [Using DT in Shiny](https://rstudio.github.io/DT/shiny.html) - Pagination state exposure via input$tableId_state
- [Pagination Widget for Shiny Apps](https://www.r-bloggers.com/2015/10/paging-widget-for-shiny-apps/) - Custom pagination patterns

### Tertiary (LOW confidence)
- [GitHub shiny-pager-ui](https://github.com/wleepang/shiny-pager-ui) - Widget returns page_current/pages_total (different from cursor-based approach)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All built-in Shiny primitives, existing project usage confirms patterns
- Architecture: HIGH - Verified patterns from Mastering Shiny + existing codebase (mod_search_notebook.R)
- Pitfalls: HIGH - Infinite loops well-documented in official docs, NULL behavior is R fundamental
- Integration: HIGH - Clear insertion points in existing code (save_search observer, do_search_refresh function)
- Testing: MEDIUM - testthat confirmed as project standard, but Shiny reactive testing requires testServer() which may not be in existing test suite

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (30 days — Shiny patterns are stable, reactiveValues behavior unchanged since Shiny 1.0)
