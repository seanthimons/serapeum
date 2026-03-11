# Phase 56: Year Slider Alignment Fix - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the visual misalignment between the year range slider and the histogram bars in the search notebook. Replace ggplot2 histogram with HTML bars for pixel-perfect alignment. Add defensive year bounds and hide the filter when no papers exist. Scope is search notebook only — citation network year filter is untouched.

</domain>

<decisions>
## Implementation Decisions

### Histogram-slider alignment
- Replace ggplot2 plotOutput histogram with server-side renderUI emitting styled HTML div bars
- HTML bars go full width, edge to edge, matching the slider track width
- Visual only — no hover tooltips or interactivity on bars
- Remove plotOutput and renderPlot for year_histogram entirely

### Year floor defensiveness
- Slider min/max is fully data-driven from actual paper years in notebook (no hardcoded floor)
- Trust the data — if earliest paper is 1850, slider goes to 1850
- Hide the entire year filter panel (slider + histogram + unknown year checkbox) when no papers exist
- Search notebook only — citation network year filter is out of scope

### Dark mode histogram
- Use Bootstrap CSS variable `--bs-primary` (Catppuccin lavender) for bar color — auto-switches with dark mode
- Solid opacity bars (no transparency), replacing the current alpha=0.7 ggplot behavior
- No R-side theme detection needed — CSS handles light/dark automatically

### Claude's Discretion
- Exact HTML structure for histogram bars (flexbox vs inline-block)
- Bar height scaling approach (linear vs log)
- CSS class naming conventions
- Transition/animation on bar rendering (if any)

</decisions>

<specifics>
## Specific Ideas

- Issue #143 screenshot shows clear horizontal misalignment between histogram bars and slider track
- The root cause is ggplot2's plotOutput having different internal padding than Shiny's sliderInput
- HTML div bars eliminate the R-plot-to-browser alignment problem entirely

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `get_year_distribution(con, notebook_id)`: Returns data.frame with year/count columns — feeds the histogram
- `get_year_bounds(con, notebook_id)`: Returns list(min_year, max_year) with COALESCE defaults
- `get_unknown_year_count(con, notebook_id)`: Returns count of NULL-year papers
- `LATTE$lavender` / `MOCHA$lavender`: Catppuccin color constants in theme_catppuccin.R (no longer needed for histogram with CSS vars)

### Established Patterns
- `renderUI` used extensively in search notebook for dynamic content
- 400ms debounce on year_range slider (keep as-is)
- `bg = "transparent"` pattern for ggplot renders (will be removed with plotOutput)
- Bootstrap CSS variables used throughout for theme-adaptive styling

### Integration Points
- `mod_search_notebook.R` lines 230-254: Year filter panel UI (slider + plotOutput + unknown year)
- `mod_search_notebook.R` lines 1119-1155: Server-side year bounds update + histogram render
- `R/db.R` lines 1657-1704: Three year-related DB query functions

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 56-year-slider-alignment-fix*
*Context gathered: 2026-03-11*
