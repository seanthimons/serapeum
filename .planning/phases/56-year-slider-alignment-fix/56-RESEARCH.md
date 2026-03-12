# Phase 56: Year Slider Alignment Fix - Research

**Researched:** 2026-03-11
**Domain:** R Shiny UI alignment, CSS-based visualization, Bootstrap theming
**Confidence:** HIGH

## Summary

Phase 56 fixes visual misalignment between the year range slider and histogram in the search notebook year filter panel. The root cause is ggplot2's plotOutput having different internal padding than Shiny's sliderInput, creating horizontal offset between histogram bars and slider track.

The solution replaces ggplot2 histogram rendering with server-side `renderUI` emitting styled HTML div bars. This eliminates the R-plot-to-browser alignment problem entirely since both slider and histogram are now native HTML elements sharing the same container width. Bootstrap CSS variables (`--bs-primary`) provide automatic dark mode switching without R-side theme detection.

**Primary recommendation:** Replace `plotOutput("year_histogram")` with `uiOutput("year_histogram")` and replace `renderPlot()` with `renderUI()` emitting div bars styled with CSS variables for pixel-perfect alignment and automatic dark mode support.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Histogram-slider alignment:**
- Replace ggplot2 plotOutput histogram with server-side renderUI emitting styled HTML div bars
- HTML bars go full width, edge to edge, matching the slider track width
- Visual only — no hover tooltips or interactivity on bars
- Remove plotOutput and renderPlot for year_histogram entirely

**Year floor defensiveness:**
- Slider min/max is fully data-driven from actual paper years in notebook (no hardcoded floor)
- Trust the data — if earliest paper is 1850, slider goes to 1850
- Hide the entire year filter panel (slider + histogram + unknown year checkbox) when no papers exist
- Search notebook only — citation network year filter is out of scope

**Dark mode histogram:**
- Use Bootstrap CSS variable `--bs-primary` (Catppuccin lavender) for bar color — auto-switches with dark mode
- Solid opacity bars (no transparency), replacing the current alpha=0.7 ggplot behavior
- No R-side theme detection needed — CSS handles light/dark automatically

### Claude's Discretion

- Exact HTML structure for histogram bars (flexbox vs inline-block)
- Bar height scaling approach (linear vs log)
- CSS class naming conventions
- Transition/animation on bar rendering (if any)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| YEAR-01 | Year slider and histogram visually aligned (CSS fix for #143) | HTML div bars eliminate ggplot2 padding mismatch; Bootstrap CSS variables enable automatic dark mode theming; renderUI pattern well-documented in Shiny ecosystem |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | (existing) | renderUI for HTML histogram | Standard dynamic UI pattern in Shiny; already used extensively in search notebook |
| Bootstrap 5.3 | (via bslib) | CSS custom properties (`--bs-primary`) | bslib provides Bootstrap 5.3 with built-in dark mode support; CSS variables auto-switch with `data-bs-theme` |
| htmltools | (existing) | tags$div for bar construction | Standard Shiny HTML tag builder; already used throughout project |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ggplot2 | (remove) | Previously used for histogram rendering | REMOVING from year filter — replaced by HTML divs |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| HTML div bars | Keep ggplot2 plotOutput | ggplot2 creates alignment mismatch; div bars guarantee pixel-perfect alignment with slider |
| Bootstrap CSS vars | R-side theme detection | CSS variables switch automatically with `data-bs-theme`; R detection would require reactive theme state and conditional color logic |
| Linear height scaling | Logarithmic scaling | Linear is simpler and sufficient for histogram visualization; log scaling adds complexity without clear value for this use case |

**Installation:**
No new packages required — uses existing Shiny, htmltools, and Bootstrap 5.3 (via bslib).

## Architecture Patterns

### Recommended Code Structure
```
R/mod_search_notebook.R
├── UI section (lines ~230-254)
│   └── Replace plotOutput with uiOutput
├── Server section (lines ~1119-1179)
│   └── Replace renderPlot with renderUI
└── DB helpers (already exist in R/db.R)
    ├── get_year_distribution()
    ├── get_year_bounds()
    └── get_unknown_year_count()
```

### Pattern 1: renderUI for HTML Histogram
**What:** Server-side reactive HTML generation using `renderUI()` with styled div bars
**When to use:** When pixel-perfect alignment with other HTML elements (like sliders) is required
**Example:**
```r
# Source: Shiny documentation + project CONTEXT.md decisions
output$year_histogram <- renderUI({
  nb_id <- notebook_id()
  req(nb_id)
  paper_refresh()  # React to paper changes

  year_counts <- get_year_distribution(con(), nb_id)

  if (nrow(year_counts) == 0) {
    return(div(style = "height: 60px;"))  # Empty placeholder
  }

  # Normalize heights (0-100% scale)
  max_count <- max(year_counts$count)
  year_counts$height <- (year_counts$count / max_count) * 100

  # Generate div bars
  div(
    class = "year-histogram-container",
    style = "display: flex; align-items: flex-end; height: 60px; gap: 1px;",
    lapply(seq_len(nrow(year_counts)), function(i) {
      div(
        style = paste0(
          "flex: 1; ",
          "height: ", year_counts$height[i], "%; ",
          "background-color: var(--bs-primary); ",
          "border-radius: 2px 2px 0 0;"
        ),
        title = paste0(year_counts$year[i], ": ", year_counts$count[i], " papers")
      )
    })
  )
})
```

### Pattern 2: Bootstrap CSS Variables for Dark Mode
**What:** Use `var(--bs-primary)` instead of hardcoded colors
**When to use:** Anytime colors need to adapt to light/dark mode automatically
**Example:**
```css
/* Light mode: --bs-primary = #7287fd (LATTE$lavender) */
/* Dark mode: --bs-primary = #b4befe (MOCHA$lavender) */
/* Automatically switches based on [data-bs-theme="dark"] */

background-color: var(--bs-primary);
```

### Pattern 3: Conditional Panel Visibility
**What:** Hide entire year filter panel when no papers exist
**When to use:** Prevent UI clutter for empty states
**Example:**
```r
# UI section: Wrap year filter panel in conditionalPanel
conditionalPanel(
  condition = "output.has_papers",
  # Year range filter panel
  div(
    class = "mb-2",
    sliderInput(...),
    uiOutput(ns("year_histogram"), ...),
    div(...)  # unknown year checkbox
  )
)

# Server section: Add reactive flag
output$has_papers <- reactive({
  papers <- papers_data()
  !is.null(papers) && nrow(papers) > 0
})
outputOptions(output, "has_papers", suspendWhenHidden = FALSE)
```

### Anti-Patterns to Avoid
- **Using plotOutput for alignment-critical visualizations:** ggplot2 adds internal padding that doesn't match HTML sliders; use renderUI with div bars instead
- **Hardcoding theme colors in R:** R-side theme detection requires reactive state and conditional logic; Bootstrap CSS variables handle this automatically
- **Setting arbitrary year floor (like 1900):** Trust the data; if earliest paper is 1850, slider should go to 1850

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dark mode color switching | Reactive theme detection in R | Bootstrap CSS variables (`var(--bs-primary)`) | CSS variables switch automatically with `data-bs-theme` attribute; no R logic needed |
| Histogram bar rendering | Custom ggplot2 alignment fixes | HTML div bars with flexbox | ggplot2 internal padding is unpredictable; div bars guarantee pixel-perfect alignment |
| Year bounds calculation | Manual min/max from filtered papers | Existing `get_year_bounds()` DB helper | Already tested and handles NULL years correctly with COALESCE defaults |

**Key insight:** The alignment problem exists because ggplot2 plot rendering and HTML sliders live in different layout systems. Don't try to force them to align — convert the plot to native HTML using the same layout system as the slider.

## Common Pitfalls

### Pitfall 1: Flexbox Gap Breaking in Older Browsers
**What goes wrong:** CSS `gap` property in flexbox not supported in older browsers
**Why it happens:** `gap` became widely supported in 2021 but may fail in legacy browser environments
**How to avoid:** Use `gap: 1px` for visual separation but design to degrade gracefully if gap is ignored
**Warning signs:** Histogram bars appearing tightly packed together in test environments

### Pitfall 2: CSS Variable Inheritance Breaking Encapsulation
**What goes wrong:** `var(--bs-primary)` might not work inside certain Shiny containers that reset CSS scope
**Why it happens:** Some Shiny components use shadow DOM or isolated CSS scopes
**How to avoid:** Test in both light and dark modes; if CSS variable doesn't work, fall back to inline style with theme-specific colors
**Warning signs:** Histogram bars showing default blue in dark mode instead of Catppuccin lavender

### Pitfall 3: Slider Width Mismatch with Histogram Container
**What goes wrong:** Slider and histogram have different widths even though they're in the same parent div
**Why it happens:** sliderInput wraps content in additional divs with its own width styling
**How to avoid:** Ensure both `sliderInput` and `uiOutput` are direct children of the same parent div with no width constraints; set histogram container to `width: 100%` to match slider's natural width
**Warning signs:** Histogram extends beyond slider track or appears narrower than slider

### Pitfall 4: Empty State Height Collapse
**What goes wrong:** When no papers exist, histogram container collapses to 0 height, creating visual jump when papers load
**Why it happens:** Flexbox with no children has 0 intrinsic height
**How to avoid:** Return placeholder div with fixed `height: 60px` when no data; alternatively, hide entire year filter panel using `conditionalPanel`
**Warning signs:** Year filter section jumping/resizing when papers first load

## Code Examples

Verified patterns from existing codebase and official sources:

### Current ggplot2 Histogram (TO BE REPLACED)
```r
# Source: R/mod_search_notebook.R lines 1158-1179
output$year_histogram <- renderPlot({
  nb_id <- notebook_id()
  req(nb_id)
  paper_refresh()  # React to paper changes

  year_counts <- get_year_distribution(con(), nb_id)

  if (nrow(year_counts) == 0) {
    # Empty plot
    ggplot2::ggplot() + ggplot2::theme_void()
  } else {
    # Minimal histogram
    ggplot2::ggplot(year_counts, ggplot2::aes(x = year, y = count)) +
      ggplot2::geom_col(fill = LATTE$lavender, width = 0.8, alpha = 0.7) +
      ggplot2::theme_void() +
      ggplot2::theme(
        plot.background = ggplot2::element_blank(),
        panel.background = ggplot2::element_blank(),
        plot.margin = ggplot2::margin(0, 0, 0, 0)
      )
  }
}, bg = "transparent")
```

### HTML Div Histogram (REPLACEMENT)
```r
# Source: Project CONTEXT.md decisions + Shiny renderUI documentation
output$year_histogram <- renderUI({
  nb_id <- notebook_id()
  req(nb_id)
  paper_refresh()  # React to paper changes

  year_counts <- get_year_distribution(con(), nb_id)

  if (nrow(year_counts) == 0) {
    # Empty placeholder maintaining height
    return(div(style = "height: 60px; width: 100%;"))
  }

  # Normalize heights (linear scaling 0-100%)
  max_count <- max(year_counts$count)
  year_counts$height_pct <- (year_counts$count / max_count) * 100

  # Flexbox container with bars
  div(
    class = "year-histogram-bars",
    style = "display: flex; align-items: flex-end; height: 60px; width: 100%; gap: 1px;",
    lapply(seq_len(nrow(year_counts)), function(i) {
      div(
        class = "histogram-bar",
        style = paste0(
          "flex: 1; ",
          "height: ", year_counts$height_pct[i], "%; ",
          "background-color: var(--bs-primary); ",  # Auto-switches with dark mode
          "border-radius: 2px 2px 0 0;"
        )
      )
    })
  )
})
```

### Existing DB Helper (ALREADY AVAILABLE)
```r
# Source: R/db.R lines 1657-1704
get_year_distribution <- function(con, notebook_id) {
  result <- dbGetQuery(con, "
    SELECT year, COUNT(*) AS count
    FROM abstracts
    WHERE notebook_id = ? AND year IS NOT NULL
    GROUP BY year
    ORDER BY year
  ", list(notebook_id))

  if (nrow(result) == 0) {
    return(data.frame(year = integer(), count = integer(), stringsAsFactors = FALSE))
  }

  result
}

get_year_bounds <- function(con, notebook_id) {
  result <- dbGetQuery(con, "
    SELECT
      COALESCE(MIN(year), 2000) AS min_year,
      COALESCE(MAX(year), 2026) AS max_year
    FROM abstracts
    WHERE notebook_id = ? AND year IS NOT NULL
  ", list(notebook_id))

  list(
    min_year = result$min_year[1],
    max_year = result$max_year[1]
  )
}
```

### Bootstrap CSS Variables Reference
```css
/* Source: Bootstrap 5.3 documentation (getbootstrap.com) */

/* Light mode (default) */
:root, [data-bs-theme="light"] {
  --bs-primary: #0d6efd;  /* Bootstrap default */
  /* Overridden by Catppuccin theme to #7287fd (LATTE$lavender) */
}

/* Dark mode */
[data-bs-theme="dark"] {
  --bs-primary: #6ea8fe;  /* Bootstrap dark default */
  /* Overridden by Catppuccin theme to #b4befe (MOCHA$lavender) */
}

/* Usage in inline styles */
background-color: var(--bs-primary);  /* Automatically switches */
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ggplot2 for all visualizations | HTML/CSS for alignment-critical UI elements | Bootstrap 5+ era (2021+) | Better pixel-perfect alignment with native HTML controls; automatic dark mode via CSS variables |
| R-side theme detection | CSS custom properties with data-bs-theme | Bootstrap 5.3 (May 2023) | Eliminates reactive theme state in R; CSS handles switching automatically |
| Hardcoded color values | CSS variables (--bs-primary, etc.) | Bootstrap 5.0+ (May 2021) | Colors update automatically with theme; no R logic needed |

**Deprecated/outdated:**
- **ggplot2 plotOutput for UI-aligned visualizations:** Use renderUI with div bars when pixel-perfect alignment with HTML controls (sliders, inputs) is required
- **Manual theme color switching in R:** Bootstrap CSS variables handle this automatically since v5.0

## Open Questions

1. **Bar gap size optimization**
   - What we know: CSS flexbox `gap` property provides visual separation
   - What's unclear: Optimal gap size (1px vs 2px) for readability at 60px container height
   - Recommendation: Start with `gap: 1px` (minimal separation); adjust in UAT if bars appear too tightly packed

2. **Height scaling approach**
   - What we know: Linear scaling (0-100%) is simplest; log scaling emphasizes small values
   - What's unclear: Whether year distributions have extreme outliers that would benefit from log scaling
   - Recommendation: Start with linear scaling per Claude's discretion; switch to log only if UAT reveals unreadable bars due to one dominant year

3. **Flexbox vs inline-block layout**
   - What we know: Flexbox `flex: 1` auto-distributes space evenly; inline-block requires manual width calculation
   - What's unclear: Whether inline-block would provide better browser compatibility
   - Recommendation: Use flexbox per modern CSS standards; degrade gracefully if `gap` not supported (bars just appear tighter)

## Validation Architecture

> Nyquist validation enabled in `.planning/config.json`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat (existing) |
| Config file | None — tests run via `testthat::test_dir("tests/testthat")` |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-year-filter.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| YEAR-01 | Year slider and histogram visually aligned | manual-only | N/A — alignment is visual; automated test would require screenshot comparison | N/A |

**Note:** Alignment validation is inherently visual and requires manual UAT. Automated testing would require Playwright screenshot comparison, which is out of scope for this cosmetic fix. Recommend manual verification in both light and dark modes.

### Sampling Rate
- **Per task commit:** Manual visual check in running app (light + dark mode)
- **Per wave merge:** Manual visual check in running app (light + dark mode)
- **Phase gate:** Manual UAT before `/gsd:verify-work` — verify alignment in both themes

### Wave 0 Gaps
None — existing test infrastructure covers backend year query functions (`get_year_distribution`, `get_year_bounds`). UI alignment is manual-only validation.

## Sources

### Primary (HIGH confidence)
- [Bootstrap 5.3 CSS Variables](https://getbootstrap.com/docs/5.3/customize/css-variables/) - CSS custom properties documentation, semantic color variables, dark mode support
- [Shiny renderUI](https://shiny.posit.co/r/reference/shiny/1.3.1/renderui.html) - Dynamic UI rendering pattern
- [ggplot2 theme margin](https://ggplot2.tidyverse.org/reference/element.html) - Theme elements and margin control
- Existing codebase (R/mod_search_notebook.R, R/db.R, R/theme_catppuccin.R) - Current implementation and available helpers

### Secondary (MEDIUM confidence)
- [Shiny HTML Tags](https://shiny.posit.co/r/articles/build/html-tags/) - Customize UI with HTML
- [Shiny CSS Guide](https://shiny.posit.co/r/articles/build/css/) - Using custom CSS in apps
- [Bootstrap Color Modes](https://getbootstrap.com/docs/5.3/customize/color-modes/) - Dark mode implementation
- [ggplot2 Margins Guide](https://r-charts.com/ggplot2/margins/) - Margin removal techniques

### Tertiary (LOW confidence)
None — all findings verified with official documentation or existing codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Uses existing Shiny, Bootstrap, htmltools; no new dependencies
- Architecture: HIGH - renderUI pattern well-documented; Bootstrap CSS variables verified in official docs
- Pitfalls: MEDIUM - Flexbox compatibility assumed based on modern browser support; CSS variable inheritance potential edge case

**Research date:** 2026-03-11
**Valid until:** 2026-04-11 (30 days - stable web standards, no fast-moving dependencies)
