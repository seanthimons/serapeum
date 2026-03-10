# Phase 53: Toolbar Restructuring - Research

**Researched:** 2026-03-10
**Domain:** Bootstrap 5 layout utilities, R Shiny UI patterns, Catppuccin color system
**Confidence:** HIGH

## Summary

This phase restructures the search notebook toolbar from a single-row horizontal button strip into a 3x2 grid layout with icon+text labels, semantic color harmony, and logical workflow grouping. The research confirms that Bootstrap 5's flexbox utilities (d-flex, gap, row-gap, column-gap) are the recommended approach for button toolbars, preferred over CSS Grid for component-level layouts. The existing Catppuccin color system already maps btn-outline-primary to lavender and btn-outline-secondary to gray through bslib's bs_theme() customization. Number formatting for the remaining count will use base R's prettyNum() or a simple custom function rather than adding the numform package dependency.

**Primary recommendation:** Use Bootstrap 5 flexbox utilities (d-flex, flex-column, gap-1) for the 3x2 button grid layout. Relocate result count to keyword panel summary line with simple K/M formatting. Adjust panel widths from c(4, 8) to c(5, 7) to reduce paper title truncation.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- All 6 buttons get icon + descriptive text (2-3 words)
- Labels: **Import**, **Edit Search**, **Citation Network**, **Export** (dropdown kept), **Refresh**, **Load More**
- Export keeps its dropdown (BibTeX / CSV) — single button, not split
- 3x2 grid replaces the current single-row horizontal toolbar
- Row 1 (input/discovery): Import | Edit Search | Citation Network
- Row 2 (output/data): Export | Refresh | Load More
- Equal-width buttons per row — each button takes 1/3 of the row
- Full-width grid stretches across the entire card header
- Row gap: tight (4px / gap-1) — feels like a single toolbar block
- Column gap: small (gap-1 or gap-2) — slight separation between buttons in the same row
- Lavender (primary outline) for meaningful actions: Import, Citation Network, Export, Load More
- Gray (secondary outline) for support actions: Edit Search, Refresh
- If lavender + gray looks odd in practice, fallback to all-lavender — flag for UAT
- Remove "Papers" span entirely from card_header
- The 3x2 button grid IS the card header content — no label needed
- Remove "X of Y results" from the toolbar completely
- Add remaining count to keywords panel subheader: "92 papers | 30 keywords | **1.6M remaining**"
- Pretty-format the remaining count (e.g., 1.6M, 234K)
- Bold the remaining count for visibility
- Change col_widths from c(4, 8) to c(5, 7)
- Gives paper titles more room (fewer truncations, no horizontal scrollbar)
- Flag for UAT — verify abstract pane isn't cramped at 7/12
- Sort radio buttons (Newest, Most cited, Impact, Most refs) stay below the button grid in card_body
- Current layout is lopsided with 4 options not filling the width — Claude figures out balanced layout

### Claude's Discretion
- Exact CSS for equal-width button grid (CSS Grid vs flexbox)
- Sort controls layout balancing (evenly spaced, justified, centered)
- Card header padding adjustments to fit the grid cleanly
- Column gap exact value (gap-1 vs gap-2) based on visual result
- Pretty-format threshold for remaining count (when to use K vs M)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope (panel split was folded in as a one-line related change)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TOOL-01 | All toolbar buttons display icon+text labels (no icon-only buttons) | Icon wrapper functions exist in R/theme_catppuccin.R; buttons currently use icon-only pattern that needs text label addition |
| TOOL-02 | Buttons reordered by workflow: Import → Edit → Seed Network → Export → Refresh → Load More | Current order is Import, Export, Citation Network, Edit, Refresh, Load More — requires reordering in UI code |
| TOOL-03 | Buttons harmonized with Catppuccin semantic color system (primary=lavender, info=sapphire) | Catppuccin theme already maps btn-outline-primary to lavender, btn-outline-secondary to gray via bs_theme() |
| TOOL-04 | Visual grouping with separators between action groups (import/edit, discovery, export, data) | 3x2 grid layout with row-gap provides natural grouping (row 1 = input/discovery, row 2 = output/data) |
| TOOL-06 | "Papers" label removed from toolbar area | Current code has span("Papers") at line 80 in mod_search_notebook.R that must be removed |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bootstrap 5 | 5.3 | Grid/flexbox utilities | Integrated with bslib, provides gap utilities and flexbox classes |
| bslib | Latest CRAN | Card components, theme customization | R Shiny's official Bootstrap integration, used throughout project |
| Catppuccin | Mocha/Latte | Color palette | Project's established design system (Phase 30+), semantic color mappings already configured |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| base R | 4.5.1+ | Number formatting (prettyNum, formatC) | Simple K/M abbreviations without external dependencies |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bootstrap flexbox (d-flex, gap) | CSS Grid (display: grid) | CSS Grid is better for page-level layouts; flexbox is recommended for component-level toolbars and button groups |
| Custom number formatting | numform package (f_denom) | numform provides robust abbreviations but adds dependency; simple custom function is sufficient for this use case |

**Installation:**
```bash
# No new dependencies required
# Bootstrap 5 utilities come with bslib
# Catppuccin theme already configured in R/theme_catppuccin.R
```

## Architecture Patterns

### Recommended Button Grid Structure
```r
# 3x2 button grid using flexbox rows
card_header(
  # Row 1: Input/Discovery
  div(
    class = "d-flex gap-2 mb-1",
    actionButton(ns("open_bulk_import"), "Import",
                 class = "btn-sm btn-outline-primary flex-fill",
                 icon = icon_file_import()),
    actionButton(ns("edit_search"), "Edit Search",
                 class = "btn-sm btn-outline-secondary flex-fill",
                 icon = icon_edit()),
    actionButton(ns("seed_citation_network"), "Citation Network",
                 class = "btn-sm btn-outline-primary flex-fill",
                 icon = icon_share_nodes())
  ),
  # Row 2: Output/Data
  div(
    class = "d-flex gap-2",
    # Export dropdown button group
    div(
      class = "btn-group btn-group-sm flex-fill",
      tags$button(
        class = "btn btn-outline-primary dropdown-toggle w-100",
        `data-bs-toggle` = "dropdown",
        icon_download(), " Export"
      ),
      tags$ul(
        class = "dropdown-menu",
        tags$li(downloadLink(ns("download_bibtex"), class = "dropdown-item", icon_file_code(), " BibTeX (.bib)")),
        tags$li(downloadLink(ns("download_csv"), class = "dropdown-item", icon_file_csv(), " CSV (.csv)"))
      )
    ),
    actionButton(ns("refresh_search"), "Refresh",
                 class = "btn-sm btn-outline-secondary flex-fill",
                 icon = icon_rotate()),
    actionButton(ns("load_more"), "Load More",
                 class = "btn-sm btn-outline-primary flex-fill",
                 icon = icon_angles_down())
  )
)
```

### Pattern 1: Flexbox Rows for Button Grid
**What:** Use two div containers with d-flex and gap-2, stacked vertically with mb-1 margin on first row
**When to use:** Component-level toolbars where equal-width buttons are needed in consistent rows
**Why flexbox over grid:** Bootstrap 5 flexbox utilities are recommended for "component-level alignment and spacing (toolbars, navs, chips)" while CSS Grid is for page-level layouts

### Pattern 2: Number Formatting for Remaining Count
**What:** Custom helper function to format numbers with K/M suffixes
**When to use:** Displaying large numbers in limited UI space (e.g., "1.6M remaining")
**Example:**
```r
# Source: Custom implementation (no external package needed)
format_large_number <- function(n) {
  if (is.null(n) || is.na(n)) return("0")
  if (n >= 1e6) {
    return(paste0(round(n / 1e6, 1), "M"))
  } else if (n >= 1e3) {
    return(paste0(round(n / 1e3, 1), "K"))
  } else {
    return(as.character(n))
  }
}
```

### Pattern 3: Keyword Panel Summary Update
**What:** Extend existing summary line to include remaining count
**When to use:** Adding supplemental metrics to existing panel subheaders
**Example:**
```r
# Existing pattern in R/mod_keyword_filter.R line 70-78
output$summary <- renderUI({
  papers <- papers_data()
  keywords <- all_keywords()
  remaining <- total_results() - nrow(papers)  # New calculation

  div(
    class = "mb-2 text-muted small",
    paste0(
      nrow(papers), " papers | ",
      nrow(keywords), " keywords | ",
      tags$strong(format_large_number(remaining), " remaining")
    )
  )
})
```

### Pattern 4: Sort Radio Button Balancing
**What:** Use flexbox with justify-content-around or justify-content-between for 4 inline radio buttons
**When to use:** Distributing inline form controls evenly across container width
**Example:**
```r
# Wrap existing radioButtons in flexbox container
div(
  class = "d-flex justify-content-around mb-2",
  radioButtons(
    ns("sort_by"),
    NULL,
    choices = c(
      "Newest" = "year",
      "Most cited" = "cited_by_count",
      "Impact (FWCI)" = "fwci",
      "Most refs" = "referenced_works_count"
    ),
    selected = "year",
    inline = TRUE
  )
)
```

### Anti-Patterns to Avoid
- **Single-row horizontal toolbar with justify-content-between:** Creates uneven spacing when buttons have different label lengths; 3x2 grid with flex-fill provides visual consistency
- **Icon-only buttons without tooltips:** Accessibility and discoverability issue; phase requires icon+text labels for all buttons
- **Hard-coded pixel values for gaps:** Use Bootstrap gap utilities (gap-1, gap-2) for responsive, theme-consistent spacing
- **Adding numform package dependency:** Simple K/M formatting doesn't justify new dependency; custom function is sufficient
- **CSS Grid for button toolbar:** Grid is overkill for this component-level layout; flexbox is the Bootstrap 5 standard

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Button group equal widths | Manual width calculations or flexbox hacks | Bootstrap's `.flex-fill` utility class | Built-in responsive behavior, works with gap utilities, maintains equal widths across breakpoints |
| Gap spacing between buttons | Margin utilities (me-2, ms-2) | Gap utilities (gap-1, gap-2, row-gap, column-gap) | Gap utilities work seamlessly with flexbox/grid, avoid margin collapse issues, cleaner markup |
| Number abbreviation (K/M/B) | Regular expression parsing or complex rounding logic | Simple conditional function with division and rounding | K/M thresholds are straightforward (1000, 1000000); no edge cases justify external library |
| Color theming | Inline style or custom CSS classes | Bootstrap semantic classes with Catppuccin theme overrides | Already configured in bs_theme() — btn-outline-primary maps to lavender via CSS custom properties |

**Key insight:** Bootstrap 5's flexbox utilities and gap system solve 90% of toolbar layout challenges without custom CSS or JavaScript. The existing Catppuccin theme integration means semantic color changes (primary, secondary, info) automatically apply the correct palette colors.

## Common Pitfalls

### Pitfall 1: Dropdown Button Group Not Filling Grid Cell
**What goes wrong:** Export dropdown button group doesn't expand to fill 1/3 of the row width, creating visual imbalance
**Why it happens:** Dropdown button groups (.btn-group) don't automatically inherit flex-fill behavior; the wrapper div needs flex-fill, and the dropdown-toggle button needs w-100
**How to avoid:** Apply flex-fill to the .btn-group wrapper, then add w-100 class to the dropdown-toggle button itself
**Warning signs:** Export button narrower than adjacent buttons; gap appears after Export button

### Pitfall 2: Gap Utilities on Button Elements Instead of Container
**What goes wrong:** Applying gap-2 to individual buttons has no effect; spacing doesn't appear
**Why it happens:** Gap utilities only work on flexbox/grid containers, not on flex items themselves
**How to avoid:** Apply gap-2 to the parent div with d-flex, not to the child buttons
**Warning signs:** Buttons touching each other despite gap class present; browser DevTools shows gap property on wrong element

### Pitfall 3: Removing Result Count Without Adding to Keywords Panel
**What goes wrong:** User loses visibility into how many results remain to be loaded
**Why it happens:** Result count removal is explicit requirement, but relocation to keywords panel is separate step that could be missed
**How to avoid:** Implement both changes atomically in same commit; verify keywords panel summary includes remaining count before removing from toolbar
**Warning signs:** UAT feedback about missing result count information; users uncertain whether Load More will fetch more results

### Pitfall 4: Sort Radio Buttons Not Filling Width
**What goes wrong:** 4 inline radio buttons cluster on left side of container, leaving whitespace on right
**Why it happens:** Bootstrap's radioButtons(inline = TRUE) uses .form-check-inline which has default left alignment
**How to avoid:** Wrap radioButtons in flexbox container with justify-content-around or justify-content-between
**Warning signs:** Sort controls look cramped or left-aligned; uneven spacing between options

### Pitfall 5: Icon+Text Button Labels Breaking Layout
**What goes wrong:** Adding text to previously icon-only buttons causes grid cells to overflow or wrap unexpectedly
**Why it happens:** Button text increases minimum width; without flex-shrink and text truncation, buttons don't compress to fit grid
**How to avoid:** Use flex-fill on buttons to enable shrinking; test with longest label text ("Citation Network") to verify all buttons fit in row
**Warning signs:** Buttons wrapping to second line on smaller viewports; horizontal scrollbar on card header

### Pitfall 6: Color Contrast Failure with Custom Theme
**What goes wrong:** Lavender outline buttons don't meet WCAG AA contrast requirements in light mode
**Why it happens:** Catppuccin Latte lavender (#7287fd) may have insufficient contrast against white background
**How to avoid:** Verify contrast ratios in both Mocha (dark) and Latte (light) themes; Catppuccin palette is designed for accessibility, but outline buttons have lower contrast than filled buttons
**Warning signs:** Buttons appear faded in light mode; accessibility audit flags contrast issues

## Code Examples

Verified patterns from existing codebase and official Bootstrap 5 documentation:

### Equal-Width Button Grid (3x2 Layout)
```r
# Source: Bootstrap 5 Flex utilities + existing button pattern
card_header(
  # Row 1: Input/Discovery
  div(
    class = "d-flex gap-2 mb-1",
    actionButton(ns("open_bulk_import"), "Import",
                 class = "btn-sm btn-outline-primary flex-fill",
                 icon = icon_file_import()),
    actionButton(ns("edit_search"), "Edit Search",
                 class = "btn-sm btn-outline-secondary flex-fill",
                 icon = icon_edit()),
    actionButton(ns("seed_citation_network"), "Citation Network",
                 class = "btn-sm btn-outline-primary flex-fill",
                 icon = icon_share_nodes())
  ),
  # Row 2: Output/Data
  div(
    class = "d-flex gap-2",
    div(
      class = "btn-group btn-group-sm flex-fill",
      tags$button(
        class = "btn btn-outline-primary dropdown-toggle w-100",
        `data-bs-toggle` = "dropdown",
        icon_download(), " Export"
      ),
      tags$ul(
        class = "dropdown-menu",
        tags$li(downloadLink(ns("download_bibtex"), class = "dropdown-item", icon_file_code(), " BibTeX (.bib)")),
        tags$li(downloadLink(ns("download_csv"), class = "dropdown-item", icon_file_csv(), " CSV (.csv)"))
      )
    ),
    actionButton(ns("refresh_search"), "Refresh",
                 class = "btn-sm btn-outline-secondary flex-fill",
                 icon = icon_rotate()),
    actionButton(ns("load_more"), "Load More",
                 class = "btn-sm btn-outline-primary flex-fill",
                 icon = icon_angles_down())
  )
)
```

### Number Formatting Helper
```r
# Source: Custom implementation (base R)
format_large_number <- function(n) {
  if (is.null(n) || is.na(n)) return("0")
  if (n >= 1e6) {
    paste0(round(n / 1e6, 1), "M")
  } else if (n >= 1e3) {
    paste0(round(n / 1e3, 1), "K")
  } else {
    as.character(n)
  }
}

# Usage in keyword panel summary
output$summary <- renderUI({
  papers <- papers_data()
  keywords <- all_keywords()
  remaining <- total_results() - nrow(papers)

  div(
    class = "mb-2 text-muted small",
    HTML(paste0(
      nrow(papers), " papers | ",
      nrow(keywords), " keywords | ",
      "<strong>", format_large_number(remaining), " remaining</strong>"
    ))
  )
})
```

### Sort Controls Balanced Layout
```r
# Source: Bootstrap 5 Flex utilities
div(
  class = "d-flex justify-content-around mb-2",
  radioButtons(
    ns("sort_by"),
    NULL,
    choices = c(
      "Newest" = "year",
      "Most cited" = "cited_by_count",
      "Impact (FWCI)" = "fwci",
      "Most refs" = "referenced_works_count"
    ),
    selected = "year",
    inline = TRUE
  )
)
```

### Panel Width Adjustment
```r
# Source: Existing pattern in mod_search_notebook.R line 74-75
# Change from:
layout_columns(
  col_widths = c(4, 8),
  # ...
)

# To:
layout_columns(
  col_widths = c(5, 7),
  # ...
)
```

### Icon Wrapper Functions (Already Exist)
```r
# Source: R/theme_catppuccin.R (lines 130-180)
# All icon functions already defined and used project-wide
icon_file_import()  # Import button
icon_edit()         # Edit Search button
icon_share_nodes()  # Citation Network button
icon_download()     # Export button
icon_rotate()       # Refresh button
icon_angles_down()  # Load More button
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Icon-only toolbar buttons | Icon+text labels for all buttons | Phase 53 | Improved discoverability and accessibility (TOOL-01) |
| Single horizontal row with justify-content-between | 3x2 grid layout with flexbox rows | Phase 53 | Visual consistency, workflow grouping (TOOL-04) |
| Result count in toolbar | Result count in keywords panel summary | Phase 53 | Cleaner toolbar, contextual placement (TOOL-06) |
| Mixed button colors (success, info, primary, secondary) | Lavender (primary) + Gray (secondary) only | Phase 53 | Semantic color harmony (TOOL-03) |
| Random workflow order | Workflow-sequential order (Import → Edit → Seed → Export → Refresh → Load More) | Phase 53 | Cognitive load reduction (TOOL-02) |

**Deprecated/outdated:**
- **d-flex justify-content-between for toolbars with many buttons:** Creates uneven spacing when button labels vary in length; replaced by flexbox rows with flex-fill
- **Margin utilities (me-2, ms-2) for button spacing:** Bootstrap 5 gap utilities are cleaner and avoid margin collapse issues
- **Icon-only buttons without text labels:** Accessibility best practice now requires visible text labels, not just tooltips

## Open Questions

1. **Gap-1 vs gap-2 for column spacing**
   - What we know: gap-1 = 0.25rem (4px), gap-2 = 0.5rem (8px)
   - What's unclear: Which provides better visual separation for 3-column button rows?
   - Recommendation: Start with gap-2 (8px) as it matches the gap-2 already used in current single-row toolbar (line 82); flag for UAT adjustment if too wide

2. **Remaining count display threshold**
   - What we know: Should use K for thousands, M for millions
   - What's unclear: Should "1600 remaining" display as "1.6K" or "1600"? When exactly to switch to K?
   - Recommendation: Use K for values >= 1000, M for values >= 1,000,000; always abbreviate to reduce visual clutter

3. **Sort controls justification vs spacing**
   - What we know: 4 inline radio buttons currently look lopsided
   - What's unclear: Should they be evenly spaced (justify-content-around) or justified to edges (justify-content-between)?
   - Recommendation: Use justify-content-around for balanced appearance; justify-content-between would push first/last options to edges which looks unnatural for form controls

4. **Light mode contrast for lavender outline buttons**
   - What we know: Catppuccin Latte lavender is #7287fd
   - What's unclear: Does btn-outline-primary meet WCAG AA contrast (4.5:1) against white background?
   - Recommendation: Verify contrast in light mode during implementation; Bootstrap outline buttons typically use darker borders than fills, which should provide adequate contrast

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat (latest CRAN version) |
| Config file | none — see Wave 0 |
| Quick run command | `Rscript -e "testthat::test_dir('tests/testthat', filter = 'toolbar')"` |
| Full suite command | `Rscript -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TOOL-01 | All toolbar buttons have icon+text labels | manual-only | Smoke test: Start app, verify all 6 buttons show icon+text | ❌ Wave 0 |
| TOOL-02 | Buttons ordered: Import, Edit Search, Citation Network, Export, Refresh, Load More | manual-only | Smoke test: Verify button order in rendered UI | ❌ Wave 0 |
| TOOL-03 | Primary buttons use lavender (btn-outline-primary), support buttons use gray (btn-outline-secondary) | manual-only | Smoke test: Inspect button classes in browser DevTools | ❌ Wave 0 |
| TOOL-04 | 3x2 grid with visual row separation (row-gap) | manual-only | Smoke test: Verify two rows with tight vertical spacing | ❌ Wave 0 |
| TOOL-06 | "Papers" label removed from card header | unit | `Rscript -e "testthat::test_file('tests/testthat/test-toolbar-restructuring.R')"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Smoke test — start app, verify toolbar renders without errors
- **Per wave merge:** Smoke test — verify toolbar layout, button labels, colors
- **Phase gate:** Manual UAT following UAT.md checklist (button order, color harmony, remaining count display, panel widths)

### Wave 0 Gaps
- [ ] `tests/testthat/test-toolbar-restructuring.R` — covers TOOL-06 (verify "Papers" span removed from UI code)
- [ ] Smoke test procedure — covers TOOL-01 through TOOL-04 (UI rendering verification)
- [ ] Framework install: Already exists (testthat in tests/ directory)

*(Most requirements are UI/visual and require manual verification; unit test for "Papers" label removal is the only automatable check)*

## Sources

### Primary (HIGH confidence)
- [Bootstrap 5.3 Spacing Utilities](https://getbootstrap.com/docs/5.3/utilities/spacing/) - Gap utilities (gap-1 through gap-5, row-gap, column-gap)
- [Bootstrap 5.3 Grid System](https://getbootstrap.com/docs/5.3/layout/grid/) - Equal-width columns, flexbox foundation, responsive behavior
- [bslib Cards Documentation](https://rstudio.github.io/bslib/articles/cards/) - card_header usage and styling
- Existing codebase: R/theme_catppuccin.R (Catppuccin color mappings, icon wrapper functions)
- Existing codebase: R/mod_search_notebook.R (current toolbar implementation, format_result_count helper)
- Existing codebase: R/mod_keyword_filter.R (keyword panel summary pattern)

### Secondary (MEDIUM confidence)
- [CSS Grid vs Flexbox 2026 Guide - TheLinuxCode](https://thelinuxcode.com/css-grid-vs-flexbox-in-2026-practical-differences-mental-models-and-real-layout-patterns/) - Flexbox for component-level toolbars, Grid for page layouts
- [Bootstrap 5 Flex Practical Utilities - TheLinuxCode](https://thelinuxcode.com/bootstrap-5-flex-practical-flex-utilities-for-real-layout-glue/) - flex-fill, justify-content utilities for toolbars
- [Bootstrap 5 Buttons Documentation](https://getbootstrap.com/docs/5.3/components/buttons/) - Outline button variants
- [Bootstrap 5 Checks and Radios](https://getbootstrap.com/docs/5.3/forms/checks-radios/) - Inline radio button layout
- [R numform Package Documentation](https://rdrr.io/cran/numform/man/f_denom.html) - f_denom for number abbreviations (not used, but researched as alternative)

### Tertiary (LOW confidence)
- [W3Schools Bootstrap 5 Flex](https://www.w3schools.com/bootstrap5/bootstrap_flex.php) - Basic flexbox tutorials
- [GeeksforGeeks Bootstrap 5 Spacing Gap](https://www.geeksforgeeks.org/bootstrap/bootstrap-5-spacing-gap/) - Gap utility examples

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Bootstrap 5 and bslib are already integrated; Catppuccin theme is established
- Architecture: HIGH - Official Bootstrap 5 documentation confirms flexbox approach; existing patterns provide clear implementation model
- Pitfalls: MEDIUM-HIGH - Common flexbox pitfalls are well-documented; dropdown button group flex-fill issue is project-specific but predictable
- Number formatting: HIGH - Base R functions (round, paste0) are sufficient; no edge cases anticipated
- Color theming: HIGH - Catppuccin mappings already verified in R/theme_catppuccin.R

**Research date:** 2026-03-10
**Valid until:** 2026-04-10 (30 days — stable technologies, Bootstrap 5.3 is mature)
