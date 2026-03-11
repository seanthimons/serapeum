# Phase 55: Document Type Filter UX - Research

**Researched:** 2026-03-11
**Domain:** Shiny UI/UX, OpenAlex work types taxonomy, reactive filtering patterns
**Confidence:** HIGH

## Summary

Phase 55 expands document type filtering from 6 hardcoded checkboxes to the full OpenAlex work types taxonomy, using clickable chip toggles with distinctive badge styling. Research confirms OpenAlex supports a comprehensive taxonomy of work types (expanding beyond the original 6), provides distribution counts for type filtering, and allows both API-level and client-side filtering.

The existing codebase already demonstrates the required patterns: keyword filter module implements three-state chip toggles (neutral/include/exclude), reactive filter chains compose cleanly (papers_data → keyword_filtered_papers → journal_filtered_papers), and Catppuccin color palette provides semantic color families for badge categorization. The type distribution panel can be moved above chip toggles using existing renderUI patterns, and client-side filtering inserts naturally between keyword and journal filter steps.

**Primary recommendation:** Implement as two-state chip toggles (ON/OFF) reusing keyword badge interaction patterns, add client-side type filtering reactive between keyword and journal filters, expand get_type_badge() from 9 to 16+ types with Catppuccin color families, increase API page size from 25 to 100, and move type_distribution renderUI above chip grid with all types visible (including zero-count).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Replace 6 checkboxes with compact clickable chip toggles (badge-style, similar to keyword badges)
- Two-state: ON (included) / OFF (excluded) — no three-state rotation
- Default state: common types ON (article, review, preprint, book), rare types OFF (erratum, paratext, grant, supplementary-materials, etc.)
- Add "Select All / Deselect All" text links above the chip grid
- Chip colors match the badge colors used in search results (visual consistency)
- Move distribution panel ABOVE the chip toggles (currently below)
- Data source: current loaded papers (not a separate API call)
- Display-only — no interactive bar clicking
- Collapsible via `<details>` element, expanded by default
- Show ALL 16 types including zero-count types (user sees what's missing)
- Pre-filter counts: reflects all loaded papers regardless of type filter state
- Color-coded by category (3-4 color families within Catppuccin palette):
  - Primary research (e.g., article, book, book-chapter, dissertation): one color family
  - Reviews/editorials (e.g., review, editorial, letter, peer-review): another family
  - Preprints/reports (e.g., preprint, report, standard): another family
  - Metadata/other (e.g., erratum, paratext, grant, supplementary-materials, dataset): gray/neutral family
- Similar types share hues with subtle variation
- Labels: Title case, human-friendly (e.g., "Book Chapter", "Peer Review", not "book-chapter")
- Same badge colors used in both Edit Search chip toggles and search result cards
- Both API-level AND client-side filtering (belt-and-suspenders)
- API filter: pass `work_types` to `search_openalex_works()` on fresh search/refresh
- Client-side filter: applied in `papers_data()` reactive AFTER keyword filter, BEFORE journal filter
- Save & Refresh: re-filters loaded papers locally (no fresh API search triggered by type change alone)
- Next actual search/refresh uses the saved type filters at API level
- Increase API page size from 25 to 100 papers per request
- Compensates for client-side type filtering reducing visible results
- 100 is OpenAlex's max per_page

### Claude's Discretion
- Exact Catppuccin color assignments for each of the 16 types
- Chip toggle CSS implementation (reuse keyword badge pattern or new)
- Distribution bar chart styling (bar heights, colors, spacing)
- How to group the 16 types for default on/off split (which types are "common" vs "rare")
- Responsive layout of chip grid (flow-wrap vs fixed columns)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DTYPE-01 | Full 16-type OpenAlex taxonomy exposed as filter options | OpenAlex work types taxonomy verified with 16+ documented types; existing checkbox pattern replaceable with chip grid |
| DTYPE-02 | Distribution panel showing type counts moved above filter checkboxes | Existing type_distribution renderUI (line 2087) can be reordered; pre-filter counts pattern exists in keyword filter module |
| DTYPE-03 | Type badge styling for each document type in search results | Existing get_type_badge() at line 874 handles 9 types; expandable to 16+ with Catppuccin color families |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Shiny | (project renv) | Reactive UI framework | Core app framework, reactive filtering patterns |
| bslib | (project renv) | Bootstrap 5 theming | Badge styling, Bootstrap semantic classes |
| htmltools | (project renv) | HTML tag generation | Chip toggle UI elements (span, actionLink) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsonlite | (project renv) | JSON serialization | Store filter state in search_filters column |
| testthat | (project renv) | Unit testing | Validate filter logic and type mapping |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| actionLink chips | Custom JavaScript toggles | actionLink is pure Shiny (no JS needed), simpler maintenance |
| Client-side filtering | API-only filtering | Client-side allows instant toggle feedback, API-only requires full re-search |
| reactiveValues for chip state | input$ checkboxes | reactiveValues pattern already proven in keyword filter module |

**Installation:**
```r
# All dependencies already in project renv
renv::restore()
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── mod_search_notebook.R     # Edit Search modal, chip toggle UI, type filter reactive
├── mod_keyword_filter.R      # Reference pattern for chip toggle interaction
├── theme_catppuccin.R        # Color palette constants for badge families
└── api_openalex.R            # work_types API parameter already supported
```

### Pattern 1: Two-State Chip Toggle
**What:** Clickable badge that toggles between ON (selected type included) and OFF (type excluded from results)
**When to use:** Document type filtering with 16 options requiring compact display
**Example:**
```r
# Reuse keyword filter actionLink pattern
actionLink(
  ns(paste0("type_chip_", type_slug)),
  span(
    class = if (is_on) "badge bg-primary" else "badge bg-secondary",
    style = "cursor: pointer;",
    paste0(type_label, " (", count, ")")
  ),
  title = if (is_on) "Click to exclude this type" else "Click to include this type"
)

# Observer pattern from mod_keyword_filter.R:165
observeEvent(input[[paste0("type_chip_", type_slug)]], {
  current_state <- type_states[[type_slug]]
  type_states[[type_slug]] <- !current_state  # Two-state toggle
}, ignoreInit = TRUE)
```

### Pattern 2: Reactive Filter Chain Insertion
**What:** Add type filter as new reactive step between keyword and journal filtering
**When to use:** Client-side filtering that preserves existing filter chain performance
**Example:**
```r
# Current pattern (mod_search_notebook.R:866-871)
papers_data <- reactive({ ... })
keyword_filtered_papers <- mod_keyword_filter_server("keyword_filter", papers_data, remaining_count)
journal_filtered_papers <- mod_journal_filter_server("journal_filter", keyword_filtered_papers, con)

# NEW: Insert type filter between keyword and journal
keyword_filtered_papers <- mod_keyword_filter_server("keyword_filter", papers_data, remaining_count)
type_filtered_papers <- reactive({
  papers <- keyword_filtered_papers()
  selected_types <- get_selected_work_types()  # From chip states
  if (is.null(selected_types)) return(papers)  # All types selected
  papers[papers$work_type %in% selected_types, ]
})
journal_filtered_papers <- mod_journal_filter_server("journal_filter", type_filtered_papers, con)
```

### Pattern 3: Pre-Filter Distribution Counts
**What:** Distribution panel shows counts from papers_data() before any type filtering
**When to use:** Stable reference UI that doesn't change as user toggles chips
**Example:**
```r
# Move type_distribution renderUI ABOVE chip grid
# Count from papers_data() not type_filtered_papers
output$type_distribution <- renderUI({
  papers <- papers_data()  # Pre-filter counts
  if (nrow(papers) == 0) return(NULL)

  type_counts <- table(papers$work_type)

  # Include ALL 16 types, even zero-count
  all_types <- c("article", "review", "preprint", "book", "book-chapter",
                 "dissertation", "dataset", "report", "peer-review", "editorial",
                 "letter", "erratum", "paratext", "grant", "supplementary-materials", "standard")

  tags$details(
    open = "open",  # Expanded by default
    tags$summary("Type Distribution"),
    # Bar chart for each type including zeros
  )
})
```

### Pattern 4: Catppuccin Color Families for Badges
**What:** Group 16 types into 4 color families with semantic meaning
**When to use:** Badge styling in both chip toggles and search result cards
**Example:**
```r
# Expand get_type_badge() from 9 to 16+ types
get_type_badge <- function(work_type) {
  # Primary research: lavender/blue family
  if (work_type %in% c("article", "book", "book-chapter", "dissertation")) {
    return(list(class = "bg-primary", label = format_type_label(work_type)))
  }
  # Reviews/editorials: sapphire/info family
  if (work_type %in% c("review", "editorial", "letter", "peer-review")) {
    return(list(class = "bg-info", label = format_type_label(work_type)))
  }
  # Preprints/reports: yellow/warning family
  if (work_type %in% c("preprint", "report", "standard")) {
    return(list(class = "bg-warning text-body", label = format_type_label(work_type)))
  }
  # Metadata/other: gray/neutral family
  return(list(class = "bg-body-tertiary text-body", label = format_type_label(work_type)))
}

format_type_label <- function(slug) {
  # Convert "book-chapter" to "Book Chapter"
  tools::toTitleCase(gsub("-", " ", slug))
}
```

### Anti-Patterns to Avoid
- **Three-state rotation (neutral/include/exclude):** User constraint specifies two-state only; three-state adds complexity for 16 toggles
- **Interactive distribution bars:** User constraint specifies display-only; clicking bars would conflict with chip toggle interaction
- **Post-filter counts in distribution panel:** User constraint specifies pre-filter counts for stable reference
- **Triggering fresh API search on type toggle:** User constraint specifies Save & Refresh for local re-filtering; API call only on next actual search
- **Hardcoding 6 types:** Defeats the purpose of this phase; must expose all 16+ OpenAlex types

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Chip toggle interaction | Custom JavaScript toggle buttons | Shiny actionLink + observeEvent pattern | Already proven in keyword filter module (mod_keyword_filter.R:165-177), no JS needed, reactive state automatic |
| Badge color mapping | Manual switch statements per Bootstrap version | Bootstrap 5 semantic classes (bg-primary, bg-info, etc.) | bslib handles version compatibility, Catppuccin theme already mapped to semantic roles (theme_catppuccin.R:79-120) |
| Work type taxonomy | Hardcoded list of 6 types | OpenAlex documented types + dynamic handling | Handles new types gracefully, avoids tech debt when OpenAlex adds types |
| Reactive filter chain | Manual observe() with complex dependencies | Reactive expressions returning filtered data.frames | Shiny's reactive graph optimizes invalidation automatically, clearer dependency tracking |
| JSON filter state serialization | String concatenation or custom format | jsonlite::toJSON() / fromJSON() | Already used for search_filters column (mod_search_notebook.R:990-994), prevents escaping bugs |

**Key insight:** Shiny's reactive framework and the existing keyword filter pattern solve 90% of the implementation. The "new" work is just expanding type coverage and inserting one reactive step into the filter chain.

## Common Pitfalls

### Pitfall 1: Observer Memory Leaks with Dynamic Chip Grid
**What goes wrong:** Creating 16 observeEvent() handlers without cleanup causes memory leaks as filter state changes
**Why it happens:** Each renderUI creates new actionLink inputs with same IDs, but observers persist across re-renders
**How to avoid:** Use observer teardown pattern from mod_keyword_filter.R:148-179
**Warning signs:** Shiny app memory usage growing over time, duplicate event firings
**Prevention:**
```r
# Store observers in list and destroy before recreating
keyword_observers <- list()

observe({
  # Destroy previous observers
  for (obs in keyword_observers) {
    obs$destroy()
  }
  keyword_observers <<- list()

  # Recreate observers for current chips
  keyword_observers <<- lapply(all_types, function(type_slug) {
    observeEvent(input[[paste0("type_chip_", type_slug)]], {
      # Toggle logic
    }, ignoreInit = TRUE)
  })
})
```

### Pitfall 2: Reactive Invalidation Cascade with Client-Side Filtering
**What goes wrong:** Adding type filter reactive causes excessive re-computation of downstream reactives (journal filter, year histogram, paper cards)
**Why it happens:** Shiny's reactive graph invalidates all dependents when any input changes; without debouncing or proper req() guards, chip toggles trigger full re-renders
**How to avoid:** Use req() to prevent execution with invalid inputs, insert type filter at correct chain position (AFTER keyword, BEFORE journal), avoid triggering papers_data() invalidation
**Warning signs:** UI lag when clicking chips, duplicate API calls, flash of empty results
**Prevention:**
```r
type_filtered_papers <- reactive({
  papers <- keyword_filtered_papers()
  req(nrow(papers) > 0)  # Short-circuit if no papers

  selected_types <- get_selected_work_types()
  if (is.null(selected_types)) return(papers)  # No filtering needed

  papers[papers$work_type %in% selected_types, ]
})
```

### Pitfall 3: Bootstrap Badge Class Inconsistency Between BS4 and BS5
**What goes wrong:** Badge styles break if bslib switches Bootstrap versions (bg-primary works in BS5, badge-primary in BS4)
**Why it happens:** Bootstrap 5 changed badge class naming conventions; hardcoding BS5 classes breaks backward compatibility
**How to avoid:** Use bslib semantic classes that work across versions, test with both BS4 and BS5 themes
**Warning signs:** Badges lose color or styling after bslib update, inconsistent appearance across deployments
**Prevention:**
```r
# bslib handles version compatibility for semantic classes
# Use bg-primary, bg-info, bg-warning, bg-secondary (BS5 syntax)
# bslib translates to badge-primary, badge-info, etc. for BS4 if needed
span(class = "badge bg-primary", "Article")  # Works in both BS4 and BS5 with bslib
```

### Pitfall 4: Type Distribution Panel Counts Not Matching Filtered Results
**What goes wrong:** User sees 50 articles in distribution panel but only 30 in results after toggling chips
**Why it happens:** Distribution panel uses papers_data() (pre-filter) while results use type_filtered_papers (post-filter); confusing if not clearly labeled
**How to avoid:** Clearly label distribution panel as "All Loaded Papers" or "Pre-Filter Counts"; use collapsed-by-default details element if distribution causes confusion
**Warning signs:** User confusion about "missing" papers, support questions about count mismatches
**Prevention:**
```r
tags$details(
  open = "open",
  tags$summary(class = "text-muted small", "Type Distribution (All Loaded Papers)"),
  div(class = "small text-muted mb-2", "Counts shown reflect all papers before type filtering"),
  # Bar chart
)
```

### Pitfall 5: OpenAlex API Page Size Increase Without Rate Limit Adjustment
**What goes wrong:** Increasing page size from 25 to 100 quadruples data per request; if API client doesn't handle rate limits properly, searches fail
**Why it happens:** OpenAlex rate limiting is per-request not per-paper; larger page sizes hit same rate limit but fetch more data
**How to avoid:** Verify api_openalex.R's build_openalex_request() retry logic (Phase 50) handles 429 responses correctly at 100 papers/page
**Warning signs:** Search failures with "Too Many Requests" errors, inconsistent pagination behavior
**Prevention:**
```r
# Verify retry logic in api_openalex.R:385-399 handles 429 with backoff
# Test with per_page = 100 before deploying
req <- req |> req_url_query(
  filter = filter_str,
  per_page = 100,  # Increased from 25
  cursor = if (is.null(cursor)) "*" else cursor
)
```

## Code Examples

Verified patterns from existing codebase:

### Chip Toggle Pattern (from mod_keyword_filter.R:104-144)
```r
# Two-state toggle chip with actionLink
actionLink(
  ns(input_id),
  span(
    class = if (is_on) "badge bg-success" else "badge bg-secondary",
    style = "cursor: pointer;",
    badge_icon,
    paste0(label, " (", count, ")")
  ),
  title = paste0("Click to toggle '", label, "'")
)
```

### Observer Teardown Pattern (from mod_keyword_filter.R:148-179)
```r
keyword_observers <- list()

observe({
  # Destroy previous observers
  for (obs in keyword_observers) {
    obs$destroy()
  }
  keyword_observers <<- list()

  # Recreate observers
  keyword_observers <<- lapply(items, function(item) {
    observeEvent(input[[item$id]], {
      # Toggle logic
    }, ignoreInit = TRUE)
  })
})
```

### Filter Chain Pattern (from mod_search_notebook.R:866-871)
```r
# Base data
papers_data <- reactive({ ... })

# Keyword filter (first stage)
keyword_filtered_papers <- mod_keyword_filter_server("keyword_filter", papers_data, remaining_count)

# Journal filter (second stage)
journal_filter_result <- mod_journal_filter_server("journal_filter", keyword_filtered_papers, con)
journal_filtered_papers <- journal_filter_result$filtered_papers

# INSERT TYPE FILTER HERE (between keyword and journal)
```

### Type Badge Mapping (from mod_search_notebook.R:874-890)
```r
get_type_badge <- function(work_type) {
  if (is.null(work_type) || is.na(work_type) || work_type == "") {
    return(list(class = "bg-body-tertiary text-body", label = "unknown"))
  }
  switch(work_type,
    "article" = list(class = "bg-secondary", label = "article"),
    "review" = list(class = "bg-info", label = "review"),
    "preprint" = list(class = "bg-warning text-body", label = "preprint"),
    # ... expand to 16+ types
    list(class = "bg-body-tertiary text-body", label = work_type)  # default
  )
}
```

### Select All/Deselect All Pattern
```r
# Text links above chip grid
div(
  class = "d-flex justify-content-end gap-2 mb-2",
  actionLink(ns("select_all_types"), "Select All", class = "small text-muted"),
  span(class = "text-muted", "|"),
  actionLink(ns("deselect_all_types"), "Deselect All", class = "small text-muted")
)

observeEvent(input$select_all_types, {
  for (type_slug in all_types) {
    type_states[[type_slug]] <- TRUE
  }
})

observeEvent(input$deselect_all_types, {
  for (type_slug in all_types) {
    type_states[[type_slug]] <- FALSE
  }
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 6 hardcoded checkboxes | 16-type chip toggles with distribution preview | Phase 55 (v11.0) | Exposes full OpenAlex taxonomy, better discoverability |
| Checkboxes below distribution | Chips below distribution, distribution above | Phase 55 | Distribution becomes preview/reference before filtering |
| Type filter in API only | API + client-side belt-and-suspenders | Phase 55 | Instant toggle feedback without re-search |
| Page size 25 | Page size 100 | Phase 55 | Compensates for client-side filtering reducing visible results |

**Deprecated/outdated:**
- Hardcoded 6-type list: OpenAlex expanded taxonomy in 2024, now supports 16+ types including peer-review, standard, grant, etc.
- checkbox pattern for 16 options: Too much vertical space; chip toggles proven superior in keyword filter UX

## Open Questions

1. **Exact OpenAlex type taxonomy enumeration**
   - What we know: ArXiv analysis (2024) documents 16+ types including article, review, preprint, book, book-chapter, dissertation, dataset, report, peer-review, editorial, letter, erratum, paratext, grant, supplementary-materials, standard
   - What's unclear: Does OpenAlex guarantee stable type slugs? Could new types appear?
   - Recommendation: Use dynamic handling with fallback to default badge (bg-body-tertiary) for unknown types; test with live API to confirm current taxonomy

2. **Default ON/OFF split for 16 types**
   - What we know: User constraint specifies "common types ON (article, review, preprint, book), rare types OFF (erratum, paratext, grant, supplementary-materials)"
   - What's unclear: Where do book-chapter, dissertation, dataset, report, peer-review, editorial, letter, standard fall in common vs rare split?
   - Recommendation:
     - Common (default ON): article, review, preprint, book, book-chapter, dissertation (6 types)
     - Rare (default OFF): dataset, report, peer-review, editorial, letter, erratum, paratext, grant, supplementary-materials, standard (10 types)
     - Rationale: Researchers primarily search for substantive scholarly outputs (articles, books, dissertations, reviews), not metadata records or supplementary materials

3. **Client-side filter performance with large result sets**
   - What we know: Client-side filtering happens in reactive chain; page size increase to 100 means more client-side processing
   - What's unclear: Performance impact of filtering 1000+ papers (10 pages loaded) on type toggle
   - Recommendation: Test with 1000-paper dataset; if slow, add debounce to chip toggle observers (400ms delay like year_range, mod_search_notebook.R:1060)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | none — tests/testthat/ discovery-based |
| Quick run command | `testthat::test_file("tests/testthat/test-api-openalex.R")` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DTYPE-01 | 16-type taxonomy chip toggles render in Edit Search modal | unit | `testthat::test_file("tests/testthat/test-type-filter-ui.R") -x` | ❌ Wave 0 |
| DTYPE-01 | get_selected_work_types() returns correct type list based on chip states | unit | `testthat::test_file("tests/testthat/test-type-filter-logic.R") -x` | ❌ Wave 0 |
| DTYPE-02 | type_distribution renderUI shows all 16 types with counts | unit | `testthat::test_file("tests/testthat/test-type-distribution.R") -x` | ❌ Wave 0 |
| DTYPE-02 | Distribution counts reflect papers_data() not type_filtered_papers | unit | `testthat::test_file("tests/testthat/test-type-distribution.R") -x` | ❌ Wave 0 |
| DTYPE-03 | get_type_badge() maps all 16 types to correct color families | unit | `testthat::test_file("tests/testthat/test-type-badge.R") -x` | ❌ Wave 0 |
| DTYPE-03 | Type badges render consistently in search results and chips | manual-only | Manual inspection of Edit Search modal and search result cards | N/A |

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/testthat/test-type-badge.R")`
- **Per wave merge:** `testthat::test_dir("tests/testthat")`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-type-filter-ui.R` — covers DTYPE-01 chip rendering
- [ ] `tests/testthat/test-type-filter-logic.R` — covers DTYPE-01 reactive state logic
- [ ] `tests/testthat/test-type-distribution.R` — covers DTYPE-02 distribution panel
- [ ] `tests/testthat/test-type-badge.R` — covers DTYPE-03 badge mapping
- [ ] Framework install: Already present (testthat tests exist in tests/testthat/)

## Sources

### Primary (HIGH confidence)
- Existing codebase patterns:
  - `R/mod_keyword_filter.R` — chip toggle pattern (lines 104-144, observer teardown 148-179)
  - `R/mod_search_notebook.R` — filter chain (866-871), type badge (874-890), type distribution (2087+)
  - `R/theme_catppuccin.R` — color palette constants (MOCHA/LATTE lists, semantic mapping 79-120)
  - `R/api_openalex.R` — work_types API parameter (358-362)
- User decisions: `.planning/phases/55-document-type-filter-ux/55-CONTEXT.md` — all implementation constraints locked

### Secondary (MEDIUM confidence)
- [Analysis of Publication and Document Types in OpenAlex](https://arxiv.org/html/2406.15154v1) — 16+ work types enumerated including article, review, preprint, book, book-chapter, dissertation, dataset, report, peer-review, editorial, letter, erratum, paratext, grant, supplementary-materials, standard (2024 study)
- [Shiny Reactive Programming Best Practices](https://www.datanovia.com/learn/tools/shiny-apps/fundamentals/reactive-programming.html) — minimize dependencies, use req(), separate concerns (2026)
- [Shiny Action Link Documentation](https://shiny.posit.co/r/components/inputs/action-link/) — actionLink API for chip toggles

### Tertiary (LOW confidence)
- [OpenAlex work types documentation](https://developers.openalex.org/api-entities/works) — referenced but full taxonomy list not extracted from documentation (WebFetch unable to enumerate all types)
- [bslib theming guide](https://unleash-shiny.rinterface.com/beautify-with-bootstraplib) — Bootstrap 5 badge class conventions (bg-primary vs badge-primary)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in project renv, no new dependencies
- Architecture: HIGH — keyword filter pattern proven, reactive chain insertion point clear
- Pitfalls: HIGH — observer teardown, reactive invalidation, and Bootstrap compatibility issues documented from existing codebase
- OpenAlex taxonomy: MEDIUM — 16+ types verified from 2024 academic analysis, but official OpenAlex docs not fully enumerated
- Default ON/OFF split: MEDIUM — user constraint gives examples but not complete mapping; recommendation based on scholarly output vs metadata distinction

**Research date:** 2026-03-11
**Valid until:** 2026-04-11 (30 days — stable domain, OpenAlex taxonomy unlikely to change frequently)

---
*Phase: 55-document-type-filter-ux*
*Research complete: ready for planning*
