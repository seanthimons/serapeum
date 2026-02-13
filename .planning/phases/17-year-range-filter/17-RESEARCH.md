# Phase 17: Interactive Year Range Slider-Filter - Research

**Researched:** 2026-02-13
**Domain:** R/Shiny range slider with histogram visualization, reactive debouncing, DuckDB NULL handling
**Confidence:** HIGH

## Summary

Phase 17 implements an interactive year range slider with histogram preview for filtering academic papers across search notebooks and citation network visualizations. The implementation must handle papers with unknown publication years gracefully while preventing UI freezes during slider drag through reactive debouncing.

The R/Shiny ecosystem provides mature solutions for all requirements. Shiny's built-in `sliderInput()` with ionRangeSlider supports range selection with custom formatting. Histogram visualization can be rendered as a standalone plotly/ggplot2 chart positioned near the slider or overlaid using custom CSS with an HTML canvas element. Reactive debouncing via `shiny::debounce()` prevents downstream invalidation storms during drag operations. DuckDB's COALESCE and FILTER clause features enable robust NULL year handling with separate count queries for papers with unknown years.

The project explicitly excludes the `histoslider` package (adds React.js dependency, breaks local-first constraint). Instead, this phase uses standard Shiny patterns: a range slider for year selection, a separate small histogram plot showing distribution, and a checkbox for including/excluding papers with unknown years.

**Primary recommendation:** Use `sliderInput()` with two-element value for range selection, render histogram via `renderPlot()` with ggplot2 bars, debounce slider reactive with 300-500ms delay, use DuckDB COALESCE to handle NULLs in WHERE clause, and add checkbox for "Include papers with unknown year" that toggles NULL filtering.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | 1.8+ | Range slider widget via sliderInput() | Official R web framework, ionRangeSlider built-in |
| ggplot2 | 3.5+ | Histogram rendering for year distribution | Standard R plotting, integrates with Shiny renderPlot() |
| DuckDB | Latest | SQL with NULL handling via COALESCE/FILTER | Project database, robust NULL semantics |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| plotly | 4.10+ | Interactive histogram (alternative to ggplot2) | If hover tooltips on histogram bars desired |
| shinyWidgets | 0.8+ | Alternative sliders (noUiSliderInput) | Only if ionRangeSlider customization insufficient |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ggplot2 histogram | plotly::ggplotly() | plotly adds interactivity (hover tooltips) but increases bundle size and complexity |
| sliderInput() | shinyWidgets::noUiSliderInput() | noUiSlider has more JavaScript customization options, but sliderInput is simpler and already in use |
| **histoslider package** | **Standard sliderInput + separate ggplot2 histogram** | **histoslider adds React.js dependency (breaks local-first principle), standard approach uses only existing dependencies** |

**Installation:**
```r
# Core dependencies (already in project)
# install.packages("shiny")
# install.packages("ggplot2")

# Optional: for interactive histogram
# install.packages("plotly")
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── mod_search_notebook.R       # Add year filter UI + server logic
├── mod_citation_network.R      # Add year filter UI + server logic
└── db.R                        # Add year distribution query function
```

### Pattern 1: Range Slider with Debouncing
**What:** Two-handle range slider with reactive debouncing to prevent UI freezes
**When to use:** Any slider controlling expensive downstream operations (database queries, graph redraws)
**Example:**
```r
# Source: https://shiny.posit.co/r/reference/shiny/latest/sliderinput.html
# Source: https://shiny.posit.co/r/reference/shiny/1.7.2/debounce.html

# UI
sliderInput(
  ns("year_range"),
  "Publication Year",
  min = 1900,
  max = 2026,
  value = c(2015, 2026),  # Two-element vector = range slider
  step = 1,
  sep = "",               # No thousands separator for years
  ticks = FALSE           # Cleaner appearance for year ranges
)

# Server
year_range_raw <- reactive({ input$year_range })
year_range_debounced <- debounce(year_range_raw, 400)  # 400ms delay

# Use debounced version for filtering
filtered_papers <- reactive({
  range <- year_range_debounced()
  # ... database query with WHERE year BETWEEN range[1] AND range[2]
})
```

**Debounce timing:** 300-500ms strikes balance between responsiveness and performance. Lower values (100-200ms) feel snappier but trigger more invalidations; higher values (500-800ms) reduce load but feel sluggish.

### Pattern 2: Histogram Visualization Separate from Slider
**What:** Small ggplot2 histogram rendered below/beside slider showing year distribution
**When to use:** When histoslider package is excluded (no React.js dependencies)
**Example:**
```r
# Source: https://shiny.posit.co/r/components/outputs/plot-plotly/
# Source: DuckDB GROUP BY documentation

# UI
div(
  sliderInput(ns("year_range"), "Publication Year", ...),
  plotOutput(ns("year_histogram"), height = "80px")
)

# Server
output$year_histogram <- renderPlot({
  # Get year distribution from database
  year_counts <- dbGetQuery(con, "
    SELECT
      COALESCE(year, 0) AS year_display,
      COUNT(*) AS count
    FROM abstracts
    WHERE notebook_id = ?
      AND year IS NOT NULL
    GROUP BY year
    ORDER BY year
  ", list(notebook_id))

  # Render compact histogram
  ggplot(year_counts, aes(x = year_display, y = count)) +
    geom_col(fill = "#6366f1", width = 0.8) +
    theme_minimal() +
    theme(
      axis.text = element_blank(),
      axis.title = element_blank(),
      panel.grid = element_blank(),
      plot.margin = margin(0, 0, 0, 0)
    )
})
```

**Why separate:** Avoids React.js dependency, keeps histogram reactive (updates when papers added/removed), allows custom styling with bslib theme colors.

### Pattern 3: NULL Year Handling with Checkbox Toggle
**What:** Checkbox to include/exclude papers with unknown years, separate display indicator
**When to use:** When database contains records with NULL year values
**Example:**
```r
# Source: https://duckdb.org/docs/stable/sql/data_types/nulls
# Source: https://database.guide/how-to-use-coalesce-to-handle-null-values-in-duckdb/

# UI
checkboxInput(
  ns("include_unknown_year"),
  "Include papers with unknown year",
  value = TRUE  # Default: include unknowns
)

# Server
filtered_papers <- reactive({
  range <- year_range_debounced()
  include_null <- input$include_unknown_year

  # Build WHERE clause based on checkbox state
  if (include_null) {
    # Include NULLs OR papers in range
    dbGetQuery(con, "
      SELECT * FROM abstracts
      WHERE notebook_id = ?
        AND (year IS NULL OR year BETWEEN ? AND ?)
    ", list(notebook_id, range[1], range[2]))
  } else {
    # Exclude NULLs, only papers in range
    dbGetQuery(con, "
      SELECT * FROM abstracts
      WHERE notebook_id = ?
        AND year BETWEEN ? AND ?
    ", list(notebook_id, range[1], range[2]))
  }
})

# Display count of unknown-year papers
output$unknown_year_count <- renderText({
  count <- dbGetQuery(con, "
    SELECT COUNT(*) AS n
    FROM abstracts
    WHERE notebook_id = ? AND year IS NULL
  ", list(notebook_id))

  sprintf("%d papers with unknown year", count$n)
})
```

**NULL display:** Show badge/icon next to papers with missing year in abstract list (e.g., "Year: Unknown" with muted styling).

### Pattern 4: Cross-Module State Sharing for Year Filter
**What:** Shared reactive state pattern for year range across search notebook and citation network modules
**When to use:** When multiple modules need to read/write same filter state
**Example:**
```r
# Source: https://mastering-shiny.org/scaling-modules.html
# Source: Project v2.0 timestamp-based reactive deduplication pattern

# app.R server
server <- function(input, output, session) {
  # Shared year range state (reactiveVal, not reactiveValues)
  year_range_state <- reactiveVal(c(2015, 2026))

  # Pass to modules as both reactive input AND setter function
  mod_search_notebook_server("search", con_r, current_notebook,
                             year_range_r = year_range_state,
                             set_year_range = year_range_state)

  mod_citation_network_server("network", con_r, config_r,
                              year_range_r = year_range_state,
                              set_year_range = year_range_state)
}

# Module pattern
mod_search_notebook_server <- function(id, con_r, notebook_id_r,
                                       year_range_r, set_year_range) {
  moduleServer(id, function(input, output, session) {
    # Local slider updates shared state
    observeEvent(year_range_debounced(), {
      set_year_range(year_range_debounced())
    })

    # Use shared state for filtering
    filtered_papers <- reactive({
      range <- year_range_r()
      # ... database query
    })
  })
}
```

**Important:** Use `reactiveVal()` (singular) not `reactiveValues()` (plural) for simpler state management. The same reactiveVal serves as both getter and setter.

### Anti-Patterns to Avoid
- **Not debouncing range slider:** Causes reactive storm, database query on every drag pixel
- **Using COALESCE in SELECT without WHERE:** Displays "0" for unknown years instead of "Unknown", confuses users
- **Combining range slider and histogram in single widget:** Requires histoslider package with React.js dependency
- **Global reactiveValues for cross-module state:** Creates tight coupling, prefer passing reactive getters/setters as module parameters
- **Updating slider value from server without isolate():** Creates infinite reactive loop

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Range slider widget | Custom HTML5 range input with two handles | `shiny::sliderInput()` with two-element value | ionRangeSlider handles touch events, accessibility, keyboard nav, and visual polish automatically |
| Histogram on slider background | Custom HTML canvas drawing, SVG overlay | Separate `ggplot2` plot positioned near slider | ggplot2 integrates with Shiny reactive system, updates automatically, themeable with bslib |
| Debouncing reactive values | Manual `invalidateLater()` + timestamp checks | `shiny::debounce()` | debounce() handles edge cases (rapid changes, session end, reactive graph complexity) |
| NULL year handling in SQL | Application-level filtering after query | DuckDB `COALESCE()` and `IS NULL` in WHERE | Database-level filtering is orders of magnitude faster for large datasets |

**Key insight:** Shiny's built-in slider already uses ionRangeSlider (mature JavaScript library), and debounce() is purpose-built for this exact use case. Custom solutions add complexity without benefit.

## Common Pitfalls

### Pitfall 1: Reactive Storm from Slider Drag
**What goes wrong:** App freezes during slider drag, database queries execute hundreds of times
**Why it happens:** Each pixel of drag invalidates reactive, triggering downstream observers
**How to avoid:**
1. Wrap raw slider reactive with `debounce(reactive({ input$year_range }), 400)`
2. Use debounced version for all downstream database queries and expensive operations
3. Test with browser dev tools Network tab to verify query count during drag
**Warning signs:** UI lag during drag, database connection pool exhaustion, CPU spike

### Pitfall 2: WHERE year BETWEEN Excludes NULLs Silently
**What goes wrong:** Papers with unknown years disappear when year filter applied, user doesn't realize
**Why it happens:** SQL `BETWEEN` operator doesn't match NULL values, no NULL-handling in query
**How to avoid:**
1. Add checkbox "Include papers with unknown year" (default: TRUE)
2. When checked, use `WHERE (year IS NULL OR year BETWEEN ? AND ?)`
3. Display count of NULL-year papers in UI so users know they exist
**Warning signs:** Paper count drops unexpectedly when slider adjusted, no indicator for missing data

### Pitfall 3: Histogram Doesn't Update When Papers Added
**What goes wrong:** User imports new papers, year slider histogram shows old distribution
**Why it happens:** Histogram query not reactive to notebook contents change
**How to avoid:**
1. Make histogram `renderPlot()` reactive to same triggers as paper list (notebook_refresh, import completion)
2. Include notebook_id in histogram query to ensure isolation
3. Consider using `invalidateLater()` with long interval (30s) as fallback
**Warning signs:** Histogram bars don't match actual paper counts, importing papers doesn't update histogram

### Pitfall 4: Citation Network Year Filter Breaks Graph Layout
**What goes wrong:** Year filter applied, citation network graph redraws with jumpy layout
**Why it happens:** Filtering nodes mid-session recalculates layout positions, not stable
**How to avoid:**
1. **Do NOT auto-refresh graph on year change** (requirement YEAR-05 explicitly deferred)
2. Add "Apply Filter" button that user clicks after adjusting year range
3. Show filtered node count in UI before applying to set expectations
**Warning signs:** Graph nodes jump around during year slider drag, user loses spatial context

### Pitfall 5: Slider Min/Max Hard-Coded to 2026
**What goes wrong:** App still works in 2027, but slider max is 2026, can't filter new papers
**Why it happens:** Hard-coded `max = 2026` in sliderInput definition
**How to avoid:**
1. Calculate min/max from database: `SELECT MIN(year), MAX(year) FROM abstracts WHERE notebook_id = ?`
2. Use `COALESCE(MAX(year), 2026)` to handle empty notebooks or all-NULL years
3. Update slider bounds via `updateSliderInput()` when notebook content changes
**Warning signs:** Newest papers don't appear even when slider at max, hard-coded year in code

### Pitfall 6: Multiple Independent Debounced Reactives
**What goes wrong:** Year range has two handles (min, max), debouncing them separately causes lag
**Why it happens:** Two reactiveVal objects debounce on independent timers
**How to avoid:**
1. Treat year range as single reactive returning two-element vector: `reactive({ input$year_range })`
2. Debounce the single reactive, not individual min/max components
3. Downstream code extracts `range[1]` and `range[2]` from debounced reactive
**Warning signs:** Adjusting one handle updates immediately, adjusting both has inconsistent timing

## Code Examples

Verified patterns from official sources:

### Complete Year Filter UI Component
```r
# Source: https://shiny.posit.co/r/reference/shiny/latest/sliderinput.html
# Location: R/mod_search_notebook.R (add to card_body)

div(
  class = "year-filter-panel mb-3",

  # Year range slider
  sliderInput(
    ns("year_range"),
    "Publication Year",
    min = 1900,
    max = 2026,
    value = c(2015, 2026),
    step = 1,
    sep = "",      # No comma separator for years
    ticks = FALSE  # Cleaner visual
  ),

  # Compact histogram below slider
  plotOutput(ns("year_histogram"), height = "60px"),

  # Checkbox + unknown year count
  div(
    class = "d-flex justify-content-between align-items-center mt-2",
    checkboxInput(
      ns("include_unknown_year"),
      "Include papers with unknown year",
      value = TRUE
    ),
    textOutput(ns("unknown_year_count"), inline = TRUE) |>
      tagAppendAttributes(class = "text-muted small")
  )
)
```

### Server Logic with Debouncing
```r
# Source: https://shiny.posit.co/r/reference/shiny/1.7.2/debounce.html
# Location: R/mod_search_notebook.R (module server function)

mod_search_notebook_server <- function(id, con_r, notebook_id_r, ...) {
  moduleServer(id, function(input, output, session) {

    # Calculate slider bounds from database
    observe({
      nb_id <- notebook_id_r()
      req(nb_id)

      bounds <- dbGetQuery(con_r(), "
        SELECT
          COALESCE(MIN(year), 1900) AS min_year,
          COALESCE(MAX(year), 2026) AS max_year
        FROM abstracts
        WHERE notebook_id = ?
          AND year IS NOT NULL
      ", list(nb_id))

      # Update slider range dynamically
      updateSliderInput(
        session,
        "year_range",
        min = bounds$min_year,
        max = bounds$max_year,
        value = c(bounds$min_year, bounds$max_year)
      )
    })

    # Debounce slider to prevent reactive storm
    year_range_raw <- reactive({ input$year_range })
    year_range <- debounce(year_range_raw, 400)  # 400ms delay

    # Histogram rendering
    output$year_histogram <- renderPlot({
      nb_id <- notebook_id_r()
      req(nb_id)

      year_counts <- dbGetQuery(con_r(), "
        SELECT
          year,
          COUNT(*) AS count
        FROM abstracts
        WHERE notebook_id = ?
          AND year IS NOT NULL
        GROUP BY year
        ORDER BY year
      ", list(nb_id))

      if (nrow(year_counts) == 0) {
        return(ggplot() + theme_void())
      }

      ggplot(year_counts, aes(x = year, y = count)) +
        geom_col(fill = "#6366f1", width = 0.8, alpha = 0.7) +
        theme_minimal() +
        theme(
          axis.text = element_blank(),
          axis.title = element_blank(),
          axis.ticks = element_blank(),
          panel.grid = element_blank(),
          plot.margin = margin(0, 0, 0, 0),
          plot.background = element_rect(fill = "transparent", color = NA)
        )
    })

    # Unknown year count display
    output$unknown_year_count <- renderText({
      nb_id <- notebook_id_r()
      req(nb_id)

      count <- dbGetQuery(con_r(), "
        SELECT COUNT(*) AS n
        FROM abstracts
        WHERE notebook_id = ? AND year IS NULL
      ", list(nb_id))

      if (count$n > 0) {
        sprintf("(%d unknown)", count$n)
      } else {
        ""
      }
    })

    # Filter papers by year range
    filtered_papers <- reactive({
      nb_id <- notebook_id_r()
      req(nb_id)

      range <- year_range()  # Use debounced version
      include_null <- input$include_unknown_year

      # Build WHERE clause
      if (include_null) {
        query <- "
          SELECT * FROM abstracts
          WHERE notebook_id = ?
            AND (year IS NULL OR year BETWEEN ? AND ?)
        "
        params <- list(nb_id, range[1], range[2])
      } else {
        query <- "
          SELECT * FROM abstracts
          WHERE notebook_id = ?
            AND year BETWEEN ? AND ?
        "
        params <- list(nb_id, range[1], range[2])
      }

      dbGetQuery(con_r(), query, params)
    })

    # ... rest of module logic uses filtered_papers()
  })
}
```

### DuckDB Year Distribution Query
```r
# Source: https://duckdb.org/docs/stable/sql/query_syntax/groupby
# Source: https://duckdb.org/docs/stable/sql/data_types/nulls
# Location: R/db.R (new function)

#' Get year distribution for a notebook
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @return Data frame with columns: year, count
get_year_distribution <- function(con, notebook_id) {
  dbGetQuery(con, "
    SELECT
      year,
      COUNT(*) AS count
    FROM abstracts
    WHERE notebook_id = ?
      AND year IS NOT NULL
    GROUP BY year
    ORDER BY year
  ", list(notebook_id))
}

#' Get count of papers with unknown year
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @return Integer count
get_unknown_year_count <- function(con, notebook_id) {
  result <- dbGetQuery(con, "
    SELECT COUNT(*) AS n
    FROM abstracts
    WHERE notebook_id = ? AND year IS NULL
  ", list(notebook_id))

  result$n
}
```

### Citation Network Year Filter (Without Auto-Refresh)
```r
# Source: Project requirement YEAR-05 (auto-refresh explicitly OUT OF SCOPE)
# Location: R/mod_citation_network.R

# UI: Add year filter to controls bar
div(
  class = "citation-network-controls mb-3 p-3 bg-light rounded",
  layout_columns(
    col_widths = c(2, 2, 2, 3, 3),

    # ... existing controls (direction, depth, node_limit)

    # Year range filter (NEW)
    div(
      sliderInput(
        ns("year_filter"),
        tags$span("Year Range",
                  title = "Filter nodes by publication year. Adjust range then click 'Apply Filter' to update graph."),
        min = 1900,
        max = 2026,
        value = c(1900, 2026),
        step = 1,
        sep = "",
        ticks = FALSE
      ),
      checkboxInput(ns("include_unknown_year_network"),
                    "Include unknown",
                    value = TRUE)
    ),

    # Apply filter button (prevents auto-refresh jank)
    div(
      actionButton(
        ns("apply_year_filter"),
        "Apply Filter",
        class = "btn-outline-primary",
        icon = icon("filter")
      ),
      # Show filtered count before applying
      uiOutput(ns("filter_preview"))
    )
  )
)

# Server: Filter nodes on button click, not slider drag
filtered_nodes <- eventReactive(input$apply_year_filter, {
  range <- input$year_filter
  include_null <- input$include_unknown_year_network

  # Filter nodes data frame
  if (include_null) {
    network_nodes() |>
      filter(is.na(year) | (year >= range[1] & year <= range[2]))
  } else {
    network_nodes() |>
      filter(!is.na(year) & year >= range[1] & year <= range[2])
  }
})

output$filter_preview <- renderUI({
  count <- nrow(filtered_nodes())
  total <- nrow(network_nodes())

  div(
    class = "small text-muted mt-2",
    sprintf("Will show %d of %d nodes", count, total)
  )
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual debouncing with invalidateLater() | `shiny::debounce()` function | Shiny 1.0+ (2017) | Built-in debounce is more reliable, handles edge cases |
| histoslider package for histogram sliders | Separate slider + ggplot2 histogram | 2020+ (React.js concerns) | Avoids heavy JavaScript dependencies, more control |
| SQL COALESCE in SELECT for display | COALESCE in WHERE + IS NULL checks | Always best practice | Explicit NULL handling, clearer user intent |
| Global reactive state via session$userData | Module parameters with reactive getters/setters | Shiny modules best practices (2019+) | Better encapsulation, testable modules |
| Auto-refresh on slider change | Explicit "Apply" button for expensive operations | UX best practice (2020+) | User control, prevents janky experiences |

**Deprecated/outdated:**
- **histoslider package:** Last updated 2022-07-22, adds React.js dependency, conflicts with local-first principle
- **Direct reactive binding to expensive operations:** Always debounce user input reactives (sliders, text inputs) before triggering database queries or graph rendering
- **Treating NULL as 0 in year queries:** Confuses users, hides data quality issues

## Open Questions

1. **Should year histogram be interactive (plotly) or static (ggplot2)?**
   - What we know: plotly adds hover tooltips showing exact counts, ggplot2 is simpler and faster
   - What's unclear: Do users benefit from tooltips on histogram bars, or is visual distribution sufficient?
   - Recommendation: Start with ggplot2 for simplicity; upgrade to plotly only if user feedback requests interactivity

2. **Should citation network year filter be in controls bar or side panel?**
   - What we know: Controls bar already has direction/depth/node_limit sliders (4 controls total)
   - What's unclear: Is 5th control (year filter) too crowded, or does grouping all filters improve discoverability?
   - Recommendation: Add to controls bar for consistency with search notebook pattern, test for visual crowding

3. **Should unknown-year papers display "Year: Unknown" badge or empty year field?**
   - What we know: Empty field is ambiguous (missing data vs. not loaded), badge is explicit but adds UI clutter
   - What's unclear: User preference for explicit indicators vs. clean interface
   - Recommendation: Use muted badge "Year: Unknown" in abstract list, empty in compact views (citation network nodes)

4. **Should slider bounds be global (all years in notebook) or filtered (after keyword/journal filters)?**
   - What we know: Global bounds show full data range, filtered bounds show currently visible range
   - What's unclear: Which mental model matches user expectations when multiple filters active?
   - Recommendation: Use global bounds (simpler, matches current sort/filter UI pattern where year is one of many filters)

## Sources

### Primary (HIGH confidence)
- Shiny sliderInput documentation: https://shiny.posit.co/r/reference/shiny/latest/sliderinput.html
- Shiny debounce documentation: https://shiny.posit.co/r/reference/shiny/1.7.2/debounce.html
- DuckDB NULL values: https://duckdb.org/docs/stable/sql/data_types/nulls
- DuckDB GROUP BY clause: https://duckdb.org/docs/stable/sql/query_syntax/groupby
- DuckDB FILTER clause: https://duckdb.org/docs/stable/sql/query_syntax/filter
- DuckDB COALESCE function: https://database.guide/how-to-use-coalesce-to-handle-null-values-in-duckdb/
- Shiny modules communication: https://mastering-shiny.org/scaling-modules.html

### Secondary (MEDIUM confidence)
- Shiny range slider examples: https://shiny.posit.co/r/components/inputs/slider-range/
- Shiny plotly integration: https://shiny.posit.co/r/components/outputs/plot-plotly/
- ionRangeSlider library (underlying widget): https://github.com/IonDen/ion.rangeSlider
- Module communication patterns: https://rtask.thinkr.fr/communication-between-modules-and-its-whims/
- Date filter UI patterns: https://evolvingweb.com/blog/most-popular-date-filter-ui-patterns-and-how-decide-each-one

### Tertiary (LOW confidence)
- histoslider package documentation: https://cran.r-project.org/web/packages/histoslider/histoslider.pdf (excluded from implementation due to React.js dependency)
- shinyWidgets sliderTextInput: https://dreamrs.github.io/shinyWidgets/reference/sliderTextInput.html (not needed, standard sliderInput sufficient)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Shiny documentation, DuckDB official docs, existing project patterns
- Architecture: HIGH - Verified debounce pattern from Shiny docs, NULL handling from DuckDB docs, cross-module state from project v2.0
- Pitfalls: HIGH - Debounce reactive storm documented in Shiny community, NULL BETWEEN behavior is standard SQL, auto-refresh jank is requirement YEAR-05

**Research date:** 2026-02-13
**Valid until:** ~60 days (stable domain; Shiny slider patterns mature, DuckDB NULL semantics stable)
