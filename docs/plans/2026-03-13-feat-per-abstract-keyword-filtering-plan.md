---
title: "feat: Per-Abstract Keyword Ban/Keep Filtering"
type: feat
date: 2026-03-13
issue: https://github.com/seanthimons/serapeum/issues/151
milestone: v13.0 Search & Discovery
brainstorm: docs/brainstorms/2026-03-13-per-abstract-keyword-filtering.md
---

# feat: Per-Abstract Keyword Ban/Keep Filtering

## Overview

Extend the existing keyword ban/keep system so that keywords on individual abstract cards have the same 3-state toggle (neutral → include → exclude) as the global keyword panel. When toggled from an abstract card, the keyword promotes into the global chip bin as the single source of truth — immediately filtering existing papers and affecting future display.

## Problem Statement

Users encounter irrelevant keywords on individual abstracts that never appear in the top-30 global panel. Today the only way to act on these is manual paper removal (one by one) or hoping the keyword happens to be in the top 30. A keyword like "nanotechnology" might pollute results but never crack the top 30, leaving the user with no filtering lever.

## Proposed Solution

Make per-abstract keyword badges interactive with the same toggle cycle as the global panel. A click on any keyword — whether in the global panel or on an abstract card — writes to the same `keyword_states` store. The global panel expands beyond 30 to always display user-acted keywords.

## Technical Approach

### Architecture

#### Module Boundary Change

**Current:** `mod_keyword_filter_server()` returns a single reactive (`filtered_papers`). `keyword_states` is fully encapsulated.

**Proposed:** Return a named list (following the `mod_journal_filter_server` pattern at `mod_search_notebook.R:960-961`):

```r
# mod_keyword_filter.R — new return signature
return(list(
  filtered_papers = reactive(filtered_papers()),
  set_keyword_state = function(keyword, state) {
    keyword_states[[keyword]] <- state
  },
  get_keyword_state = function(keyword) {
    keyword_states[[keyword]] %||% "neutral"
  }
))
```

**Parent wiring change** in `mod_search_notebook.R`:

```r
# Before (line 947):
keyword_filtered_papers <- mod_keyword_filter_server("keyword_filter", papers_data, remaining_count)

# After:
keyword_filter_result <- mod_keyword_filter_server("keyword_filter", papers_data, remaining_count)
keyword_filtered_papers <- keyword_filter_result$filtered_papers
```

#### Delegated Click Handler (No Observer Explosion)

Instead of creating one `observeEvent` per keyword per abstract, use a single delegated handler via `Shiny.setInputValue()`:

```r
# In abstract detail rendering (mod_search_notebook.R):
onclick_js <- sprintf(
  "Shiny.setInputValue('%s', {keyword: '%s', nonce: Math.random()})",
  ns("abstract_kw_click"),
  htmltools::htmlEscape(keyword, attribute = TRUE)
)

tags$span(
  class = badge_class,
  style = "cursor: pointer;",
  onclick = onclick_js,
  badge_icon,
  keyword
)
```

```r
# Single observer in mod_search_notebook_server:
observeEvent(input$abstract_kw_click, {
  kw <- input$abstract_kw_click$keyword
  current <- keyword_filter_result$get_keyword_state(kw)
  new_state <- switch(current,
    "neutral" = "include",
    "include" = "exclude",
    "exclude" = "neutral",
    "include"
  )
  keyword_filter_result$set_keyword_state(kw, new_state)
})
```

This avoids per-keyword observers entirely. One observer handles all abstract keyword clicks regardless of how many papers/keywords exist.

#### Expanded Global Panel (Top-30 + User-Acted)

Modify `all_keywords()` in `mod_keyword_filter.R` to include promoted keywords:

```r
all_keywords <- reactive({
  # ... existing top-30 computation ...
  top_30 <- head(kw_df, 30)

  # Add any user-acted keywords not in top-30
  all_states <- reactiveValuesToList(keyword_states)
  acted_keywords <- names(all_states)[all_states != "neutral"]
  promoted <- setdiff(acted_keywords, top_30$keyword)

  if (length(promoted) > 0) {
    # Get counts for promoted keywords (may be 0 if papers were deleted)
    promoted_df <- data.frame(
      keyword = promoted,
      count = vapply(promoted, function(k) {
        sum(grepl(k, papers_keywords, fixed = TRUE))
      }, integer(1)),
      stringsAsFactors = FALSE
    )
    top_30 <- rbind(top_30, promoted_df)
  }

  top_30
})
```

#### Fix Clear Filters

Update the clear handler to iterate ALL keyword states, not just the top-30:

```r
# mod_keyword_filter.R — clear_filters handler
observeEvent(input$clear_filters, {
  all_states <- reactiveValuesToList(keyword_states)
  for (kw in names(all_states)) {
    keyword_states[[kw]] <- "neutral"
  }
})
```

### Implementation Phases

#### Phase 1: Module API Extension

**Files:** `R/mod_keyword_filter.R`, `R/mod_search_notebook.R`

- [x] Change `mod_keyword_filter_server` return value from single reactive to named list with `filtered_papers`, `set_keyword_state`, `get_keyword_state`
- [x] Update parent wiring in `mod_search_notebook_server` to destructure the list (`keyword_filter_result$filtered_papers`)
- [x] Verify existing keyword toggle behavior is unchanged (regression check)

#### Phase 2: Per-Abstract Badge Rendering

**Files:** `R/mod_search_notebook.R`

- [x] Replace static `span(class = "badge bg-secondary me-1", k)` at `mod_search_notebook.R:1787` with state-aware actionable badges
- [x] Add `onclick` JavaScript handler using `Shiny.setInputValue` with keyword name payload
- [x] Reflect current keyword state (neutral/include/exclude) via badge color and icon, reading from `keyword_filter_result$get_keyword_state()`
- [x] Use same badge classes as global panel: `bg-secondary` (neutral), `bg-success` + `icon_add` (include), `bg-danger` + `icon_minus` (exclude)
- [x] Add tooltip text matching the global panel pattern ("Click to include", "Click to exclude", "Click to clear filter")

#### Phase 3: Delegated Click Handler

**Files:** `R/mod_search_notebook.R`

- [x] Add single `observeEvent(input$abstract_kw_click, ...)` in `mod_search_notebook_server`
- [x] On click: read current state via `get_keyword_state`, compute next state, call `set_keyword_state`
- [x] Trigger detail view re-render so the clicked badge updates visually (the badge color should reflect the new state)
- [x] Verify that setting keyword state triggers the `keyword_filtered_papers` reactive chain (papers list re-filters)

#### Phase 4: Expanded Global Panel

**Files:** `R/mod_keyword_filter.R`

- [x] Modify `all_keywords()` reactive to union top-30 with any keyword in `keyword_states` that has a non-neutral state
- [x] Promoted keywords appear after the top-30, ordered by count descending
- [x] Fix `clear_filters` handler to iterate `reactiveValuesToList(keyword_states)` instead of just `all_keywords()$keyword`
- [x] Update summary line ("N keywords") to reflect actual displayed count including promoted

#### Phase 5: Edge Cases & Polish

**Files:** `R/mod_keyword_filter.R`, `R/mod_search_notebook.R`

- [x] **Case normalization**: Normalize keywords to lowercase for state storage and matching. Display the original casing from the abstract.
- [x] **Special character safety**: Escape keyword names in the `onclick` JavaScript handler (`htmltools::htmlEscape` with `attribute = TRUE`)
- [x] **Detail view when paper filtered out**: Keep detail view open (it reads from `papers_data()`, not `filtered_papers()`). Paper disappears from list but detail remains viewable. User closes manually.
- [x] **Pagination survival**: When `all_keywords()` recomputes after loading more papers, promoted keywords persist because they're stored in `keyword_states` which is not reset by paper set changes
- [x] **Promoted keyword with zero papers**: If all papers for a promoted keyword are deleted, the keyword remains in the global panel as long as it has a non-neutral state. Count shows `(0)`. Clearing the filter removes it.

## Acceptance Criteria

### Functional Requirements

- [ ] Per-abstract keyword badges are clickable with 3-state toggle (neutral → include → exclude → neutral)
- [ ] Clicking a per-abstract keyword updates the global chip bin state
- [ ] The global chip bin shows top-30 *plus* any user-acted keywords beyond the top 30
- [ ] Banning a keyword from an abstract card immediately hides matching papers from the list
- [ ] Including a keyword from an abstract card immediately filters to only matching papers
- [ ] State changes from the abstract card are reflected in the global panel (and vice versa)
- [ ] "Clear filters" resets ALL keyword states including promoted keywords
- [ ] The "N included | N excluded" summary reflects promoted keyword actions
- [ ] Keywords with special characters (hyphens, parentheses, Unicode) work correctly

### Non-Functional Requirements

- [ ] No per-keyword observers on abstract cards (delegated handler pattern)
- [ ] No regression in existing global keyword toggle behavior
- [ ] Detail view remains functional when the viewed paper is filtered out by keyword action

## Dependencies & Risks

**Dependencies:**
- None — this feature is self-contained within the keyword filter and search notebook modules

**Risks:**

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Observer explosion on large paper sets | Low | High | Delegated `Shiny.setInputValue` handler avoids per-keyword observers entirely |
| Case sensitivity causing inconsistent filtering | Medium | Medium | Normalize to lowercase for matching and state storage |
| Positional input ID collision between global and abstract badges | Low | High | Global panel uses `kw_N` IDs; abstract badges use delegated handler with no individual IDs |
| `keyword_states` grows unbounded | Low | Low | Only non-neutral keywords are promoted; clear resets all |
| Detail view confusion when paper filtered out | Medium | Low | Paper stays in detail view; user closes manually. Matches existing behavior when other filters hide papers |

## Known Limitations (Deferred)

- **No session persistence**: Keyword states (including promoted keywords) are lost on browser refresh. This matches current behavior and is acceptable for v1. Database persistence is a potential follow-up.
- **No cross-filter interaction indicator**: No message like "3 papers match keyword filter but hidden by year range." Would require filter chain awareness that doesn't currently exist.

## References

- **Brainstorm**: `docs/brainstorms/2026-03-13-per-abstract-keyword-filtering.md`
- **Global keyword filter module**: `R/mod_keyword_filter.R` (309 lines)
- **Per-abstract rendering**: `R/mod_search_notebook.R:1775-1791`
- **Filter chain**: `R/mod_search_notebook.R:947-1245`
- **Journal filter list pattern (precedent)**: `R/mod_search_notebook.R:960-961`
- **Icon helpers**: `R/theme_catppuccin.R` (`icon_add`, `icon_minus`, `icon_key`)
- **Existing observer pattern**: `R/mod_keyword_filter.R:147-179`
