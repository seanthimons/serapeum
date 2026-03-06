# Architecture Research: Search Notebook UX Improvements

**Domain:** Shiny module UI restructuring with pagination and filtering
**Researched:** 2026-03-06
**Confidence:** HIGH

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    UI Layer (mod_search_notebook_ui)             │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Button Bar   │  │ Year Slider  │  │ Type Filters │          │
│  │ (Toolbar)    │  │ + Histogram  │  │ (Checkboxes) │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
├─────────┴──────────────────┴──────────────────┴──────────────────┤
│              Server Layer (mod_search_notebook_server)           │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   Reactive Data Flow                      │   │
│  │   papers_data() ─→ keyword_filter ─→ journal_filter      │   │
│  │                           ↓                               │   │
│  │                   filtered_papers()                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │ do_search_  │  │ Pagination  │  │ Filter      │            │
│  │ refresh()   │  │ State       │  │ Modules     │            │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
│         │                 │                 │                   │
├─────────┴─────────────────┴─────────────────┴───────────────────┤
│                    API Layer (api_openalex.R)                    │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐   │
│  │   search_papers() with cursor pagination support         │   │
│  └──────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│                    Data Layer (DuckDB)                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                       │
│  │abstracts │  │notebooks │  │ chunks   │                       │
│  └──────────┘  └──────────┘  └──────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

## Current Architecture (v10.0)

### Existing Components

| Component | Location | Responsibility | Current Implementation |
|-----------|----------|----------------|------------------------|
| Button bar | mod_search_notebook_ui (lines 68-102) | Action buttons in card header | Inline actionButton() calls with icon wrappers, no tooltips |
| Year slider | mod_search_notebook_ui (lines 129-153) | Year range filtering | sliderInput + plotOutput histogram side-by-side |
| Document type filters | Edit modal (lines 1892-1912) | Work type filtering | 6 checkboxInput widgets (article, review, preprint, book, dissertation, other) |
| Refresh button | do_search_refresh() (lines 2189-2323) | Replace all papers with new search | Calls search_papers(), inserts new papers, shows count |
| papers_data reactive | mod_search_notebook_server (lines 931-956) | Paper list with sorting | list_abstracts(con(), nb_id, sort_by) |
| Composable filter chain | keyword_filter + journal_filter modules | Filter papers by keyword/journal | Producer-consumer pattern |

### Current Data Flow: Refresh (Replace)

```
User clicks "Refresh"
    ↓
observeEvent(input$refresh_search)
    ↓
do_search_refresh() function
    ↓
get_notebook(con(), nb_id) → extract search_query + search_filters
    ↓
search_papers(query, filters, per_page = abstracts_count) [NO CURSOR]
    ↓
OpenAlex API → returns up to 200 papers (per_page limit)
    ↓
For each paper:
    - Check if exists: SELECT id FROM abstracts WHERE notebook_id = ? AND paper_id = ?
    - If new: create_abstract() + create_chunk()
    - Increment newly_added counter
    ↓
paper_refresh(paper_refresh() + 1) → triggers papers_data() re-run
    ↓
showNotification("Added X new papers (Y total in notebook)")
```

**Key constraint:** `search_papers()` does NOT support cursor pagination. It's a single-page fetch.

### Current Reactive Chain

```
papers_data()
    ↓ (reactive dependency)
keyword_filtered_papers() [mod_keyword_filter_server]
    ↓ (reactive dependency)
journal_filtered_papers() [mod_journal_filter_server]
    ↓ (alias)
filtered_papers()
    ↓ (renders)
output$paper_list (UI)
```

## Proposed Architecture (v11.0)

### New Components

| Component | Location | Responsibility | Implementation |
|-----------|----------|----------------|----------------|
| **Toolbar module** | mod_search_notebook_ui (refactored lines 68-102) | Restructured button bar with semantic colors | Reorder buttons: Import → Refresh → Load More → Export → Network → Edit. Apply Catppuccin semantic colors. |
| **Tooltip layer** | Toolbar buttons | Add contextual help | Use bslib tooltip() or custom title attributes on buttons |
| **Load More button** | Toolbar (new) | Append next page of results | Calls search_papers() with cursor, appends to existing papers |
| **Document type UI** | Edit modal (replace lines 1892-1912) | Expanded type filters with better UX | Replace 6 checkboxes with chip/pill UI or labeled checkboxGroupInput |
| **Year slider alignment fix** | mod_search_notebook_ui (lines 129-153) | Fix histogram/slider visual alignment | Adjust CSS or layout to align histogram bars with slider ticks |
| **Pagination state** | reactiveValues() in server | Track cursor for next page | `pagination_state <- reactiveValues(cursor = NULL, has_more = FALSE)` |

### Integration Points

#### 1. Button Bar Restructuring (mod_search_notebook_ui)

**Current:**
```r
# Lines 68-102
actionButton(ns("open_bulk_import"), ..., icon = icon_file_import())
# Export dropdown
actionButton(ns("seed_citation_network"), ..., icon = icon_share_nodes())
actionButton(ns("edit_search"), ..., icon = icon_edit())
actionButton(ns("refresh_search"), "Refresh", ..., icon = icon_rotate())
```

**Proposed:**
```r
# New order with tooltips and semantic colors
actionButton(ns("open_bulk_import"), NULL,
             class = "btn-sm btn-outline-success",
             icon = icon_file_import()) |>
  bslib::tooltip("Import DOIs from .bib or text"),

actionButton(ns("refresh_search"), NULL,
             class = "btn-sm btn-outline-primary",  # PRIMARY = lavender
             icon = icon_rotate()) |>
  bslib::tooltip("Replace results with new search"),

actionButton(ns("load_more"), NULL,  # NEW
             class = "btn-sm btn-outline-info",  # INFO = sapphire (distinct from primary)
             icon = icon_plus_circle()) |>
  bslib::tooltip("Load more papers from search"),

# Export dropdown (unchanged)

actionButton(ns("seed_citation_network"), NULL,
             class = "btn-sm btn-outline-info",
             icon = icon_share_nodes()) |>
  bslib::tooltip("Build citation network from papers"),

actionButton(ns("edit_search"), NULL,
             class = "btn-sm btn-outline-secondary",
             icon = icon_edit()) |>
  bslib::tooltip("Edit search query and filters")
```

**Color harmonization:**
- **Import** (success/green): New papers entering the system
- **Refresh** (primary/lavender): Main action for updating results
- **Load More** (info/sapphire): Secondary fetch action, visually distinct
- **Network** (info/sapphire): Informational/exploratory action
- **Edit** (secondary/gray): Utility action
- **Export** (default): Neutral utility

#### 2. Pagination State Management

**New reactive state:**
```r
# In mod_search_notebook_server
pagination_state <- reactiveValues(
  cursor = NULL,         # Next cursor from meta.next_cursor
  has_more = FALSE,      # Whether more results available
  total_fetched = 0      # Running count of API-fetched papers this session
)
```

**Updated after Refresh:**
```r
# In do_search_refresh()
resp <- search_papers_with_pagination(...)  # MODIFIED function
pagination_state$cursor <- resp$next_cursor
pagination_state$has_more <- !is.null(resp$next_cursor)
pagination_state$total_fetched <- length(resp$papers)
```

**Updated after Load More:**
```r
# New do_load_more() function
resp <- search_papers_with_pagination(..., cursor = pagination_state$cursor)
pagination_state$cursor <- resp$next_cursor
pagination_state$has_more <- !is.null(resp$next_cursor)
pagination_state$total_fetched <- pagination_state$total_fetched + length(resp$papers)
```

#### 3. OpenAlex API Cursor Pagination (api_openalex.R)

**Current:** `search_papers()` does NOT return cursor metadata.

**Proposed:** Add `search_papers_with_pagination()` function.

**Implementation:**
```r
#' Search for papers with cursor pagination support
#' @param cursor Cursor string from previous response (use "*" for first page)
#' @return List with $papers (parsed works) and $next_cursor (string or NULL)
search_papers_with_pagination <- function(query, email, api_key = NULL,
                                          from_year = NULL, to_year = NULL,
                                          per_page = 25, search_field = "default",
                                          is_oa = FALSE, min_citations = NULL,
                                          exclude_retracted = TRUE,
                                          work_types = NULL,
                                          cursor = "*") {
  # Build filters (same as search_papers)
  filters <- c("has_abstract:true")
  # ... [existing filter logic] ...

  filter_str <- paste(filters, collapse = ",")

  # Build request with cursor parameter
  req <- build_openalex_request("works", email, api_key)

  if (use_search_param && nchar(query) > 0) {
    req <- req |> req_url_query(search = query)
  }

  req <- req |> req_url_query(
    filter = filter_str,
    per_page = per_page,
    cursor = cursor  # NEW: cursor parameter
  )

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop_api_error(e, "OpenAlex")
  })

  body <- resp_body_json(resp)

  papers <- if (!is.null(body$results)) {
    lapply(body$results, parse_openalex_work)
  } else {
    list()
  }

  # Extract next_cursor from meta object
  next_cursor <- body$meta$next_cursor  # String like "ZjEwMD..." or NULL

  list(
    papers = papers,
    next_cursor = next_cursor,
    count = body$meta$count  # Total available (informational)
  )
}
```

**Sources:**
- [Paging | OpenAlex technical documentation](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/paging)
- [openalex-api-tutorials/notebooks/getting-started/paging.ipynb](https://github.com/ourresearch/openalex-api-tutorials/blob/main/notebooks/getting-started/paging.ipynb)

#### 4. Reactive Data Flow: Refresh vs Load More

**Refresh (Replace):**
```
User clicks "Refresh"
    ↓
observeEvent(input$refresh_search)
    ↓
do_search_refresh()
    ↓
search_papers_with_pagination(..., cursor = "*")  # First page
    ↓
For each paper:
    - If new: insert into DB
    ↓
pagination_state$cursor <- resp$next_cursor
pagination_state$has_more <- !is.null(resp$next_cursor)
    ↓
paper_refresh(paper_refresh() + 1)  # Trigger UI update
    ↓
showNotification("Added X new papers (Y total)")
```

**Load More (Append):**
```
User clicks "Load More"
    ↓
observeEvent(input$load_more)
    ↓
req(pagination_state$has_more)  # Disable if no more pages
    ↓
do_load_more()
    ↓
search_papers_with_pagination(..., cursor = pagination_state$cursor)
    ↓
For each paper:
    - If new: insert into DB
    ↓
pagination_state$cursor <- resp$next_cursor
pagination_state$has_more <- !is.null(resp$next_cursor)
    ↓
paper_refresh(paper_refresh() + 1)  # Append to existing list
    ↓
showNotification("Loaded X more papers (Y total)")
```

**Key difference:** Refresh resets cursor to `"*"`. Load More uses existing `pagination_state$cursor`.

#### 5. Document Type Filter Expansion

**Current:** 6 checkboxInput widgets in edit modal (lines 1892-1912).

**Proposed:** Keep existing checkboxInput pattern BUT enhance visibility and usability.

**Options:**

**Option A: Styled checkbox group with badges**
```r
div(
  class = "d-flex flex-wrap gap-2 mb-3",
  div(
    checkboxInput(ns("edit_type_article"), NULL, value = TRUE, width = "auto"),
    tags$label(
      `for` = ns("edit_type_article"),
      class = "badge bg-secondary",
      "Articles"
    )
  ),
  div(
    checkboxInput(ns("edit_type_review"), NULL, value = TRUE, width = "auto"),
    tags$label(
      `for` = ns("edit_type_review"),
      class = "badge bg-info",
      "Reviews"
    )
  ),
  # ... repeat for other types
)
```

**Option B: Keep current layout, add distribution preview**
```r
# Existing checkboxInput widgets (unchanged)
div(
  class = "d-flex flex-wrap gap-3",
  checkboxInput(ns("edit_type_article"), "Articles", ...),
  checkboxInput(ns("edit_type_review"), "Reviews", ...),
  # ... other types
),
# Distribution panel already exists (lines 1993-2023)
# MOVE this collapsible panel ABOVE the checkboxes for better UX
```

**Recommendation:** Option B (minimal change). Distribution panel shows live counts per type, helping users decide which to include.

**Modified component:** Move `output$type_distribution` from bottom of modal to ABOVE checkboxes in lines 1892-1912.

#### 6. Year Slider + Histogram Alignment Fix

**Current:** sliderInput + plotOutput side-by-side (lines 129-153).

**Issue:** Histogram bars may not align with slider tick positions due to CSS margin/padding differences.

**Solution:** Wrap in a container with explicit width control.

**Proposed:**
```r
div(
  class = "mb-2",
  # Year slider
  div(
    style = "margin-bottom: -10px;",  # Reduce gap
    sliderInput(
      ns("year_range"),
      "Publication Year",
      min = 1900,
      max = 2026,
      value = c(1900, 2026),
      step = 1,
      sep = "",
      ticks = FALSE,
      width = "100%"  # Explicit width
    )
  ),
  # Histogram (same width as slider)
  plotOutput(ns("year_histogram"), height = "60px", width = "100%"),
  # Unknown year checkbox
  div(
    class = "d-flex justify-content-between align-items-center mt-1",
    checkboxInput(ns("include_unknown_year"), "Include unknown year", value = TRUE),
    textOutput(ns("unknown_year_count"), inline = TRUE) |>
      tagAppendAttributes(class = "text-muted small")
  )
)
```

**CSS adjustment (if needed):**
```css
/* In www/custom.css or inline */
#search_notebook-year_range .irs {
  margin-bottom: 0;
}
#search_notebook-year_histogram {
  margin-top: 0;
}
```

#### 7. Tooltip Attachment to Buttons

**Current:** `title` attributes used in some places (lines 75, 92, 96, 100), but not bslib tooltips.

**Proposed:** Use `bslib::tooltip()` for richer tooltips with dark mode support.

**Implementation:**
```r
# Wrap each actionButton with bslib::tooltip()
actionButton(ns("refresh_search"), NULL, ...) |>
  bslib::tooltip("Replace results with new search", placement = "bottom")
```

**Fallback for dynamic buttons (rendered in output$):**
Use `title` attribute with `data-bs-toggle="tooltip"` and initialize via JavaScript.

**For dynamic tooltips:**
```r
# In uiOutput() render
output$send_btn_ui <- renderUI({
  actionButton(ns("send"), NULL, icon = icon_paper_plane(), ...) |>
    tagAppendAttributes(
      `data-bs-toggle` = "tooltip",
      `data-bs-placement` = "top",
      title = "Send message to AI"
    )
})

# Add Bootstrap tooltip initialization JS (once per module)
tags$script(HTML("
  $(document).ready(function() {
    $('[data-bs-toggle=\"tooltip\"]').tooltip();
  });
"))
```

## Build Order

### Phase Dependencies

1. **Phase 1: API Pagination Foundation** (BLOCKING)
   - Add `search_papers_with_pagination()` to `api_openalex.R`
   - Test cursor pagination with OpenAlex API
   - Returns `list(papers, next_cursor, count)`
   - **Why first:** Required by both Refresh and Load More logic

2. **Phase 2: Pagination State Management** (DEPENDS ON: Phase 1)
   - Add `pagination_state` reactiveValues to `mod_search_notebook_server`
   - Modify `do_search_refresh()` to use new API function and track cursor
   - Add `do_load_more()` function
   - **Why second:** Sets up state layer before UI changes

3. **Phase 3: Load More Button** (DEPENDS ON: Phase 2)
   - Add "Load More" button to toolbar
   - Wire `observeEvent(input$load_more)` to `do_load_more()`
   - Conditional rendering: disable if `!pagination_state$has_more`
   - **Why third:** Implements append-mode pagination

4. **Phase 4: Button Bar Restructuring** (DEPENDS ON: Phase 3)
   - Reorder buttons: Import → Refresh → Load More → Export → Network → Edit
   - Apply semantic colors (primary, info, success, secondary)
   - Add icon wrappers (already exist in `theme_catppuccin.R`)
   - **Why fourth:** Toolbar layout finalized with all buttons present

5. **Phase 5: Tooltip Layer** (DEPENDS ON: Phase 4)
   - Add `bslib::tooltip()` to static buttons
   - Add title attributes + JS initialization for dynamic buttons
   - Test in light and dark mode
   - **Why fifth:** Visual polish after structure is stable

6. **Phase 6: Document Type Filter UX** (INDEPENDENT)
   - Move type distribution panel above checkboxes in edit modal
   - Optional: Add badge styling to checkbox labels
   - **Why sixth:** Independent of pagination, can proceed in parallel

7. **Phase 7: Year Slider Alignment Fix** (INDEPENDENT)
   - Adjust CSS margin/padding between slider and histogram
   - Test across browser sizes
   - **Why seventh:** Independent cosmetic fix

### Parallel vs Sequential

**Sequential (must be in order):**
- Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

**Parallel (can run concurrently):**
- Phase 6 (document type) can start anytime after Phase 1
- Phase 7 (year slider) can start anytime

**Critical path:** Phase 1 → Phase 2 → Phase 3 (pagination foundation)

## Cursor State Management Pattern

### Storage Location

**Recommendation:** Store cursor in `pagination_state` reactiveValues, NOT in database.

**Rationale:**
- Cursor is session-specific (different users may have different page positions)
- Cursor expires (OpenAlex cursors are time-limited)
- Refreshing search resets cursor (starts at `"*"`)
- No cross-session persistence needed

**Alternative (NOT recommended):** Store cursor in `notebooks.search_filters` JSON.
- **Cons:** Cursor becomes stale across sessions, breaks on page load, complicates state management.

### Cursor Lifecycle

```
Session starts
    ↓
pagination_state$cursor = NULL
pagination_state$has_more = FALSE
    ↓
User creates/opens search notebook
    ↓
User clicks "Refresh"
    ↓
cursor = "*" (first page)
    ↓
API response: next_cursor = "ZjEwMD..."
    ↓
pagination_state$cursor = "ZjEwMD..."
pagination_state$has_more = TRUE
    ↓
User clicks "Load More"
    ↓
cursor = pagination_state$cursor ("ZjEwMD...")
    ↓
API response: next_cursor = "YWJj..." or NULL
    ↓
pagination_state$cursor = "YWJj..." or NULL
pagination_state$has_more = !is.null(next_cursor)
    ↓
User clicks "Refresh" again
    ↓
cursor = "*" (reset to first page)
pagination_state$cursor = NULL  # Reset state
```

### UI State: Load More Button

**Conditional rendering:**
```r
output$load_more_btn <- renderUI({
  if (!pagination_state$has_more) {
    return(NULL)  # Hide button when no more pages
  }

  actionButton(ns("load_more"), NULL,
               class = "btn-sm btn-outline-info",
               icon = icon_plus_circle()) |>
    bslib::tooltip(paste0("Load more papers (", pagination_state$total_fetched, " fetched so far)"))
})
```

**Alternative:** Always show button, but disable when `!has_more`.
```r
actionButton(ns("load_more"), NULL,
             class = "btn-sm btn-outline-info",
             icon = icon_plus_circle(),
             disabled = if (!pagination_state$has_more) "disabled" else NULL)
```

**Recommendation:** Conditional rendering (hide when unavailable) for cleaner UI.

## New vs Modified Components

### New Components

1. **search_papers_with_pagination()** (api_openalex.R)
   - New function
   - Returns `list(papers, next_cursor, count)`

2. **do_load_more()** (mod_search_notebook_server)
   - New function
   - Mirrors `do_search_refresh()` but with cursor continuation

3. **pagination_state** (mod_search_notebook_server)
   - New reactiveValues()
   - Fields: `cursor`, `has_more`, `total_fetched`

4. **Load More button** (mod_search_notebook_ui)
   - New actionButton in toolbar
   - Conditional rendering based on `has_more`

5. **Tooltip layer** (mod_search_notebook_ui)
   - New: `bslib::tooltip()` wrappers on buttons

### Modified Components

1. **do_search_refresh()** (mod_search_notebook_server)
   - CHANGE: Call `search_papers_with_pagination()` instead of `search_papers()`
   - ADD: Update `pagination_state$cursor` and `has_more`
   - KEEP: Existing paper insertion logic

2. **Button bar** (mod_search_notebook_ui, lines 68-102)
   - REORDER: Import → Refresh → Load More → Export → Network → Edit
   - CHANGE: Apply semantic color classes (btn-outline-primary, btn-outline-info, etc.)
   - KEEP: Existing icon wrappers

3. **Year slider section** (mod_search_notebook_ui, lines 129-153)
   - CHANGE: Adjust margin/padding for histogram alignment
   - KEEP: Existing sliderInput and plotOutput logic

4. **Document type filters** (mod_search_notebook_ui, lines 1892-1912)
   - MOVE: Type distribution panel above checkboxes
   - OPTIONAL: Add badge styling to labels
   - KEEP: Existing checkboxInput widgets and reactive logic

## Color Harmonization with Existing Semantic Wrappers

### Current Semantic Policy (from theme_catppuccin.R and PROJECT.md)

| Role | Color | Mocha Hex | Latte Hex | Usage |
|------|-------|-----------|-----------|-------|
| PRIMARY | Lavender | #b4befe | #7287fd | Main actions (Search, Save, Add) |
| INFO | Sapphire | #74c7ec | #209fb5 | Informational actions (Tooltips, Help) |
| SUCCESS | Green | #a6e3a1 | #40a02b | Confirmations (Paper Added, Export Complete) |
| WARNING | Yellow | #f9e2af | #df8e1d | Cautions (API Key Missing, Rate Limit) |
| DANGER | Red | #f38ba8 | #d20f39 | Destructive (Delete, Remove, Clear) |
| SECONDARY | Surface | #313244 / #45475a | #ccd0da / #bcc0cc | Less important (Cancel, Close) |

### Sidebar Custom Colors (v10.0)

- **Active sidebar items:** Peach (#fab387 Mocha, #fe640b Latte)
- **Sidebar background:** Sky (#89dceb Mocha, #04a5e5 Latte)

### Button Color Assignments

| Button | Current | Proposed | Rationale |
|--------|---------|----------|-----------|
| Import | btn-outline-success | **btn-outline-success** (KEEP) | Adding papers to system = success/growth |
| Refresh | btn-outline-secondary | **btn-outline-primary** (CHANGE) | Primary action for search notebooks |
| **Load More** | N/A | **btn-outline-info** | Secondary fetch, distinct from primary refresh |
| Export | btn-outline-primary | **default** (dropdown neutral) | Utility action, not primary |
| Network | btn-outline-info | **btn-outline-info** (KEEP) | Exploratory/informational action |
| Edit | btn-outline-secondary | **btn-outline-secondary** (KEEP) | Utility action |

**Key changes:**
- **Refresh:** secondary → primary (lavender) — main action deserves primary color
- **Load More:** NEW → info (sapphire) — visually distinct from refresh
- **Export:** No change (dropdown button, neutral)

## Tooltips and Accessibility

### Tooltip Content Guidelines

- **Refresh:** "Replace results with new search" (clarifies destructive-refresh behavior)
- **Load More:** "Load more papers from search" (clarifies append behavior)
- **Import:** "Import DOIs from .bib or text"
- **Export:** (dropdown already labeled)
- **Network:** "Build citation network from papers"
- **Edit:** "Edit search query and filters"

### Dark Mode Compatibility

**bslib::tooltip()** supports dark mode automatically via Bootstrap 5.3+ theming.

**Custom title attributes:** Work in both modes but lack styling. Use bslib tooltips for consistency.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Storing Cursor in Database

**What people might do:** Add `cursor` column to `notebooks` table to persist across sessions.

**Why it's wrong:**
- Cursors expire (time-limited by OpenAlex)
- Different users should have independent page positions
- Refreshing search invalidates cursor
- Adds unnecessary complexity to database schema

**Do this instead:** Store cursor in `reactiveValues()` — session-scoped, no persistence needed.

### Anti-Pattern 2: Merging Refresh and Load More Logic

**What people might do:** Single button that "loads more unless first page."

**Why it's wrong:**
- User loses explicit control over replace vs append
- Accidental data loss (user expects append, gets replace)
- Unclear UI affordance

**Do this instead:** Two distinct buttons with clear labels and tooltips.

### Anti-Pattern 3: Tooltip Overload

**What people might do:** Add tooltips to every UI element.

**Why it's wrong:**
- Clutters interface
- Self-explanatory controls don't need tooltips
- Over-reliance on tooltips = poor labeling

**Do this instead:** Tooltips only for:
- Icon-only buttons (no text label)
- Actions with non-obvious side effects (Refresh = replace not append)
- Contextual help (e.g., FWCI metric explanation)

## Scaling Considerations

| Scale | Considerations |
|-------|----------------|
| 0-100 papers/notebook | Current pagination strategy works fine. Load More rarely needed. |
| 100-1000 papers/notebook | Load More becomes essential. Cursor pagination prevents API limits. |
| 1000+ papers/notebook | Consider adding "Load All" option with progress modal (like bulk import). Infinite scroll NOT recommended (breaks Shiny reactive assumptions). |

**Current max per request:** 200 papers (OpenAlex `per_page` limit).

**10,000-result limit:** OpenAlex basic pagination (offset-based) caps at 10,000 results. Cursor pagination bypasses this limit.

**Recommendation for v11.0:** Implement Load More with manual click, not infinite scroll. Infinite scroll adds complexity (intersection observers, debouncing) and breaks Shiny's reactive model.

## Integration Testing Strategy

### Test Cases

1. **Refresh replaces papers**
   - Create notebook with 25 papers
   - Click Refresh
   - Verify: cursor reset, new papers added, duplicates skipped

2. **Load More appends papers**
   - Create notebook, click Refresh
   - Verify Load More button appears
   - Click Load More
   - Verify: new papers appended, cursor advanced, no duplicates

3. **Load More disabled at end**
   - Navigate to last page (cursor returns NULL)
   - Verify Load More button hidden

4. **Document type filter works**
   - Select only "Articles" in edit modal
   - Refresh search
   - Verify: API filter includes `type:article`

5. **Year slider alignment**
   - Load search with papers spanning 2000-2025
   - Verify: histogram bars align with slider range

6. **Tooltips render in dark mode**
   - Toggle dark mode
   - Hover over buttons
   - Verify: tooltips visible and readable

## Sources

- [OpenAlex API Paging Documentation](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/paging)
- [OpenAlex Cursor Pagination Tutorial](https://github.com/ourresearch/openalex-api-tutorials/blob/main/notebooks/getting-started/paging.ipynb)
- Serapeum codebase: `R/mod_search_notebook.R`, `R/api_openalex.R`, `R/theme_catppuccin.R`
- Catppuccin Design System: `.planning/PROJECT.md` (DSGN-01 Semantic Color Policy)

---
*Architecture research for: Search Notebook UX Improvements (v11.0)*
*Researched: 2026-03-06*
