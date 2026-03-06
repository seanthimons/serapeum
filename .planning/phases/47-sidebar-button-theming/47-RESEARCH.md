# Phase 47: Sidebar & Button Theming - Research

**Researched:** 2026-03-05
**Domain:** R Shiny UI theming, Bootstrap 5 button styling, icon consistency
**Confidence:** HIGH

## Summary

Phase 47 applies the Phase 45 design system policy (semantic colors, icon wrappers, button variants) to all buttons, sidebar, and icons across Serapeum. This is a UI refactoring phase with no new features — only recoloring, icon wrapper migration, and layout adjustments based on locked user decisions.

The research covers: (1) R Shiny/bslib theming mechanics, (2) Bootstrap 5 button variant system and accessibility, (3) Font Awesome icon consistency patterns, (4) Catppuccin palette integration for custom button colors (peach, sky), and (5) responsive button layout patterns for title bars.

**Primary recommendation:** Follow the bslib bs_theme() semantic color mapping (primary/danger/success/warning/info/secondary) for all buttons, migrate ~80+ icon() calls to semantic wrappers, use custom CSS classes for non-standard Catppuccin colors (peach, sky) on sidebar buttons, and leverage Bootstrap 5's flexbox utilities for responsive two-row title bar wrapping.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Sidebar button hierarchy:**
- Reorder buttons (top to bottom): New Search Notebook → New Document Notebook → Import Papers → Discover from Paper → Explore Topics → Build a Query → Citation Network → Citation Audit
- Solid fill for both notebook creation buttons (Search and Document) — primary sidebar actions
- Rainbow outline colors for discovery/utility buttons — keep distinct colors per action for visual scanning. Reassign to avoid semantic conflicts (e.g., citation network should NOT be danger-red)
- Import Papers needs a distinct color beyond the standard 6 semantic colors (possibly Catppuccin peach, sky, or other palette colors as one-off custom classes)
- Subtle divider (thin line or extra spacing) between notebook creation buttons and discovery buttons
- Remove "Notebooks" title text at top of sidebar to reclaim vertical space
- THEM-02: Citation audit sidebar button must be readable in light mode (currently btn-outline-secondary with low contrast)

**Document notebook title bar:**
- Keep current icon+text styling for preset buttons (Overview, Key Points, Methodology, Lit Review, Slides)
- Wrap to two rows on tight screens — buttons reflow naturally, nothing hidden
- Move delete button closer to notebook title, extend chat window up for better vertical usage
- Embed Papers stays btn-outline-primary (lavender outline)
- Send stays btn-primary (solid lavender, main action)
- Export dropdown: researcher to evaluate if btn-outline-secondary is correct per semantic policy or should change

**Search notebook title bar:**
- Same styling rules as document notebook — consistent treatment across both types
- Same hierarchy: Send = primary (solid), presets = outline-primary, export = outline-secondary (pending evaluation)

**Full app button theming:**
- Search/execute buttons (discovery modules: seed discovery, query builder, topic explorer, search notebook "Search" button) change from btn-success (green) to btn-primary (lavender) — search is a primary action, not a confirmation
- "Add to Notebook" buttons in search results keep btn-outline-success (green) — adding is a positive/constructive action
- Stop/Cancel buttons (bulk import, citation network build) keep btn-warning (yellow) — caution/interruption fits
- Delete buttons keep btn-outline-danger or btn-danger as appropriate — destructive actions use red

**Icon wrapper migration:**
- Full app migration — replace ALL raw icon() calls with semantic wrappers across every module (~80+ replacements, ~10 files)
- Wrap everything including decorative/status icons (coins, brain, file-pdf, seedling, etc.) — catalog all icons and propose wrapper names
- Citation audit icon stays distinct (magnifying-glass-chart) — specialized analysis, not general search
- Loading via global environment — app.R already sources theme_catppuccin.R, wrappers are available everywhere

**Info color migration:**
- Update catppuccin_dark_css() in R/theme_catppuccin.R: change --bs-info from MOCHA$blue to MOCHA$sapphire
- Update bs_theme() in app.R: add explicit info = LATTE$sapphire parameter (currently unset, falls back to Bootstrap default teal)

### Claude's Discretion

- Exact sidebar divider styling (border, margin, padding)
- Export dropdown button final color (outline-secondary vs alternative)
- Responsive breakpoint for two-row title bar wrap
- Custom CSS class implementation for non-standard sidebar button colors (e.g., peach, sky)
- Hover/focus state adjustments for new button colors
- Order of file changes during implementation

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| THEM-01 | Sidebar colors adapt correctly to both light and dark mode | Bootstrap 5 color modes + Catppuccin LATTE/MOCHA palette integration |
| THEM-02 | Citation audit button is readable in light mode | WCAG AA contrast standards (4.5:1 minimum), custom color or semantic reassignment |
| THEM-03 | Import papers button has distinct color from primary buttons | Catppuccin peach/sky as custom button variant via CSS |
| DSGN-03 | All buttons follow documented semantic color scheme | bs_theme() semantic mapping + Phase 45 policy |
| DSGN-04 | Icon usage is consistent — same action uses same icon everywhere | Icon wrapper functions + Font Awesome semantic naming |
| THEM-04 | Abstract notebook buttons uniform (all icons or all icon+text) with consistent hover states | Bootstrap btn-sm + icon+text pattern already established |
| THEM-05 | Button bar uses available title bar space effectively | Flexbox flex-wrap for responsive two-row layout |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bslib | >= 0.6.0 | Bootstrap 5 theming for R Shiny | Official RStudio package for customizing Bootstrap themes via R |
| Bootstrap | 5.3+ | CSS framework | Industry standard for responsive UI, built-in dark mode support |
| Font Awesome | 6.5.1 | Icon library | Comprehensive icon set with semantic naming, already integrated |
| shiny::icon() | Built-in | Icon rendering | Standard Shiny function for Font Awesome icons |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Catppuccin palette | N/A (color constants) | Pastel theme colors | Custom MOCHA/LATTE constants defined in theme_catppuccin.R |
| htmltools | Built-in with Shiny | HTML generation | Custom CSS classes and tag structures |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom CSS classes | Pure Bootstrap variants | Bootstrap doesn't have peach/sky semantic roles — custom CSS needed for sidebar rainbow |
| Icon wrapper functions | Raw icon() calls everywhere | Wrappers enforce consistency but require migration effort |

**Installation:**
No new packages required — all dependencies already in place.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── theme_catppuccin.R    # Color constants, icon wrappers, CSS generator
├── mod_*.R               # Shiny modules with button/icon calls
└── app.R                 # Main app with bs_theme() config

www/
├── custom.css            # Custom button variants (peach, sky)
└── swatch.html           # Design system validation sheet
```

### Pattern 1: bslib bs_theme() Semantic Color Mapping

**What:** Bootstrap 5 uses 6 semantic color roles (primary, secondary, success, danger, warning, info). bslib's bs_theme() lets you map Catppuccin palette colors to these roles for both light and dark modes.

**When to use:** All standard button variants (btn-primary, btn-success, etc.)

**Example:**
```r
# app.R
bs_theme(
  version = 5,
  bg = LATTE$base,
  fg = LATTE$text,
  primary = LATTE$lavender,      # Main actions
  secondary = LATTE$surface1,    # Less important
  success = LATTE$green,         # Confirmations
  danger = LATTE$red,            # Destructive
  warning = LATTE$yellow,        # Caution
  info = LATTE$sapphire          # Informational (MUST update from blue)
)
```

**Source:** [bslib::bs_theme documentation](https://rstudio.github.io/bslib/reference/bs_theme.html)

### Pattern 2: Custom CSS for Non-Standard Colors

**What:** Catppuccin has colors beyond Bootstrap's 6 semantic roles (peach, sky, blue). Create custom .btn-peach, .btn-sky classes for sidebar rainbow buttons.

**When to use:** Import Papers button, or other one-off color needs not covered by semantic roles

**Example:**
```css
/* www/custom.css */
/* Catppuccin Peach Button (Light Mode) */
.btn-peach {
  background-color: transparent;
  border-color: #fe640b; /* LATTE$peach */
  color: #fe640b;
}
.btn-peach:hover {
  background-color: #fe640b;
  border-color: #fe640b;
  color: #eff1f5; /* LATTE$base */
}

/* Dark Mode Override */
[data-bs-theme="dark"] .btn-peach {
  border-color: #fab387; /* MOCHA$peach */
  color: #fab387;
}
[data-bs-theme="dark"] .btn-peach:hover {
  background-color: #fab387;
  border-color: #fab387;
  color: #1e1e2e; /* MOCHA$base */
}
```

**Source:** [Bootstrap 5 custom button colors guide](https://thelinuxcode.com/how-to-change-button-color-in-bootstrap-5-and-keep-it-consistent-accessible-and-scalable/)

### Pattern 3: Icon Wrapper Functions

**What:** Define semantic icon wrapper functions (icon_save(), icon_delete(), etc.) that call shiny::icon() with consistent Font Awesome icon names. Centralizes icon choices and makes global changes easy.

**When to use:** Replace all raw icon() calls across the codebase

**Example:**
```r
# R/theme_catppuccin.R (already exists, extend as needed)
icon_save <- function(...) shiny::icon("floppy-disk", ...)
icon_delete <- function(...) shiny::icon("trash", ...)
icon_search <- function(...) shiny::icon("magnifying-glass", ...)

# Usage in modules
actionButton("save_btn", "Save", icon = icon_save())
actionButton("delete_btn", "Delete", class = "btn-danger", icon = icon_delete())
```

**Benefit:** Change "trash" to "trash-can" globally by editing one wrapper function instead of 20+ files.

**Source:** Font Awesome icon consistency is a best practice — wrappers enforce [semantic naming conventions](https://docs.fontawesome.com/web/add-icons/upload-icons/icon-design/)

### Pattern 4: Responsive Button Layout with Flexbox

**What:** Use Bootstrap 5 flexbox utilities (d-flex, flex-wrap) to allow button bars to wrap to two rows on narrow screens instead of hiding buttons or horizontal scrolling.

**When to use:** Document/search notebook title bars with 5+ preset buttons

**Example:**
```r
# Title bar with wrapping button group
div(
  class = "d-flex flex-wrap gap-2 mb-2",
  actionButton(ns("btn_overview"), "Overview",
               class = "btn-sm btn-outline-primary", icon = icon("layer-group")),
  actionButton(ns("btn_lit_review"), "Lit Review",
               class = "btn-sm btn-outline-primary", icon = icon("table-cells")),
  actionButton(ns("btn_slides"), "Slides",
               class = "btn-sm btn-outline-primary", icon = icon("file-powerpoint")),
  # ... more buttons naturally wrap to second row on small screens
)
```

**Source:** [Bootstrap 5 flexbox responsive utilities](https://getbootstrap.com/docs/5.3/utilities/flex/)

### Anti-Patterns to Avoid

- **Hardcoding hex colors in HTML/R code:** Always use Bootstrap semantic classes or CSS custom properties (--bs-primary, etc.) so light/dark mode switching works automatically
- **Using btn-success for search actions:** Success = confirmation/completion. Search is a primary action → use btn-primary (lavender)
- **Inconsistent icon names:** Don't use "search" in one place and "magnifying-glass" in another for the same action — breaks visual consistency
- **Skipping WCAG contrast checks:** Catppuccin is designed for aesthetics first; verify all button+background combinations meet 4.5:1 ratio for normal text

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Custom button color variants | Inline style="background: #abc;" | Bootstrap semantic classes + custom CSS classes | Bootstrap handles hover/focus/disabled states automatically; inline styles break dark mode |
| Icon consistency enforcement | Manual code review of 80+ icon() calls | Wrapper functions (icon_save(), etc.) | One change updates all usages; compile-time error if wrapper doesn't exist |
| Light/dark mode color switching | JavaScript to swap hex values | Bootstrap [data-bs-theme] CSS + bs_theme() | Bootstrap 5.3+ has built-in dark mode support; js approach is fragile and duplicates effort |
| Responsive button layouts | Media queries for button visibility | Flexbox flex-wrap | Flexbox reflows naturally; hiding buttons loses functionality |
| WCAG contrast validation | Eyeballing colors | WebAIM Contrast Checker or automated tools | 4.5:1 ratio is not visually intuitive; tools catch failures |

**Key insight:** Bootstrap 5 semantic color system + Catppuccin palette constants + icon wrappers = centralized theming with automatic dark mode support. Custom solutions break when user toggles theme or window resizes.

## Common Pitfalls

### Pitfall 1: Forgetting to Update --bs-info in catppuccin_dark_css()

**What goes wrong:** User locked decision is to move info from blue to sapphire. If you only update bs_theme(info = LATTE$sapphire) for light mode but forget to change MOCHA$blue → MOCHA$sapphire in catppuccin_dark_css(), dark mode info buttons/badges will be the wrong color.

**Why it happens:** Two separate codepaths for light (bs_theme()) and dark (custom CSS string) mode.

**How to avoid:** Always update BOTH places when changing semantic colors: (1) bs_theme() arguments, (2) catppuccin_dark_css() CSS overrides.

**Warning signs:** Swatch sheet shows correct info color in light mode but wrong color in dark mode.

### Pitfall 2: Low Contrast on btn-outline-secondary in Light Mode

**What goes wrong:** THEM-02 requirement — citation audit button is currently btn-outline-secondary with low contrast in light mode. LATTE$surface1 (#bcc0cc) border on LATTE$base (#eff1f5) background is ~1.3:1 contrast, well below WCAG AA 4.5:1 minimum.

**Why it happens:** Secondary is designed for muted, less-important actions — low contrast is intentional for de-emphasis. But citation audit deserves better visibility.

**How to avoid:** Either (a) reassign to a different semantic color (btn-outline-info with sapphire = 3.8:1, still low but better), (b) use a custom class with higher contrast border, or (c) change to solid fill btn-info.

**Warning signs:** User can barely see the button in light mode; accessibility tools flag contrast failure.

### Pitfall 3: Icon Migration Breaks Without Wrapper Definitions

**What goes wrong:** You replace icon("magnifying-glass") with icon_search() but forget to define icon_search() wrapper, causing runtime error.

**Why it happens:** 80+ icon replacements across 10 files is tedious; easy to miss defining new wrappers for decorative icons (coins, brain, seedling, etc.) that don't have semantic actions.

**How to avoid:** Before migration, catalog ALL unique icon names used in codebase (grep for icon\(["\']). Create wrappers for all 30-40 unique icons FIRST, then replace calls.

**Warning signs:** Shiny app crashes on startup with "could not find function 'icon_X'".

### Pitfall 4: Custom CSS Classes Not Scoped to Both Themes

**What goes wrong:** You define .btn-peach in custom.css with LATTE colors but forget [data-bs-theme="dark"] override. Peach button looks great in light mode but invisible (light text on light bg) in dark mode.

**Why it happens:** Testing only in one theme mode.

**How to avoid:** For every custom class, write BOTH light and dark mode rules. Test by toggling dark mode switch after implementation.

**Warning signs:** Buttons disappear or have illegible text when switching themes.

### Pitfall 5: Responsive Wrap Breaks Button Alignment

**What goes wrong:** Using d-flex flex-wrap on title bar buttons without gap-2 spacing causes buttons to jam together when they wrap to second row.

**Why it happens:** Flexbox wrapping alone doesn't add spacing between wrapped rows.

**How to avoid:** Always pair flex-wrap with gap-2 (or gap-1 for tighter spacing) to maintain consistent spacing in both horizontal and wrapped layouts.

**Warning signs:** Buttons look good in wide window but squish together when narrowed.

## Code Examples

Verified patterns from official sources and existing codebase:

### Semantic Color Reassignment (Search Buttons)

```r
# BEFORE: Search action incorrectly using success (green) semantic
actionButton(ns("search_btn"), "Search",
             class = "btn-success", icon = icon("magnifying-glass"))

# AFTER: Search is primary action → lavender
actionButton(ns("search_btn"), "Search",
             class = "btn-primary", icon = icon_search())
```

**Files to update:** R/mod_seed_discovery.R:242, R/mod_query_builder.R:176, R/mod_topic_explorer.R:56

### Sidebar Button Reordering with Custom Class

```r
# app.R sidebar section
div(
  class = "d-grid gap-2 mb-2",

  # Notebook creation buttons (solid fill, primary actions)
  actionButton("new_search_nb", "New Search Notebook",
               class = "btn-primary", icon = icon_search()),
  actionButton("new_document_nb", "New Document Notebook",
               class = "btn-primary", icon = icon_paper()),

  # Divider (subtle spacing)
  div(class = "mt-2 mb-1"),

  # Import Papers (custom peach color for distinctiveness)
  actionButton("import_papers", "Import Papers",
               class = "btn-peach", icon = icon_upload()),

  # Discovery/utility buttons (rainbow outline colors)
  actionButton("discover_paper", "Discover from Paper",
               class = "btn-outline-success", icon = icon("seedling")),
  actionButton("explore_topics", "Explore Topics",
               class = "btn-outline-warning", icon = icon("compass")),
  actionButton("build_query", "Build a Query",
               class = "btn-outline-info", icon = icon("wand-magic-sparkles")),

  # Citation tools (reassign from danger to avoid semantic conflict)
  actionButton("new_network", "Citation Network",
               class = "btn-outline-primary", icon = icon("diagram-project")),
  actionButton("citation_audit", "Citation Audit",
               class = "btn-outline-info", icon = icon("magnifying-glass-chart"))
)
```

**Note:** .btn-peach CSS must be added to www/custom.css (see Pattern 2 above)

### Icon Wrapper Migration Example

```r
# BEFORE: Raw icon() calls scattered across file
actionButton(ns("save"), "Save", icon = icon("floppy-disk"))
actionButton(ns("delete"), "Delete", icon = icon("trash"))
downloadButton(ns("export"), "Export", icon = icon("file-export"))

# AFTER: Semantic wrappers
actionButton(ns("save"), "Save", icon = icon_save())
actionButton(ns("delete"), "Delete", icon = icon_delete())
downloadButton(ns("export"), "Export", icon = icon_export())
```

**Benefit:** Change "floppy-disk" to "save" icon globally by editing icon_save() once instead of 15+ files.

### Title Bar Responsive Wrap

```r
# Document notebook title bar (R/mod_document_notebook.R)
div(
  class = "d-flex justify-content-between align-items-start mb-2",

  # Left side: Notebook title + delete button (closer proximity)
  div(
    class = "d-flex align-items-center gap-2",
    h4(class = "mb-0", "My Research Notes"),
    actionButton(ns("delete_nb"), icon = icon_delete(),
                 class = "btn-sm btn-outline-danger", title = "Delete notebook")
  ),

  # Right side: Preset buttons (wrap on small screens)
  div(
    class = "d-flex flex-wrap gap-2",
    actionButton(ns("btn_overview"), "Overview",
                 class = "btn-sm btn-outline-primary", icon = icon("layer-group")),
    actionButton(ns("btn_lit_review"), "Lit Review",
                 class = "btn-sm btn-outline-primary", icon = icon("table-cells")),
    actionButton(ns("btn_slides"), "Slides",
                 class = "btn-sm btn-outline-primary", icon = icon("file-powerpoint"))
    # ... wraps to second row naturally on narrow screens
  )
)
```

**Source:** Existing pattern in mod_document_notebook.R lines 65-119, enhanced with flex-wrap

### Info Color Migration (Two Codepaths)

```r
# PART 1: Update light mode (app.R)
bs_theme(
  # ... other args
  info = LATTE$sapphire  # Changed from LATTE$blue (which is unset, defaults to Bootstrap teal)
)

# PART 2: Update dark mode (R/theme_catppuccin.R in catppuccin_dark_css())
catppuccin_dark_css <- function() {
  paste0('
    /* ... other rules ... */

    /* Semantic colors */
    --bs-info: ', MOCHA$sapphire, ';  /* Changed from MOCHA$blue */
    --bs-info-rgb: ', hex_to_rgb(MOCHA$sapphire), ';

    /* ... other rules ... */
  ')
}
```

**Critical:** Must update BOTH locations or light/dark modes will be inconsistent.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bootstrap 4 with custom dark mode JS | Bootstrap 5.3+ [data-bs-theme] attribute | Jan 2024 (Bootstrap 5.3 release) | Built-in dark mode support, CSS-only switching |
| Scattered icon("name") calls | Centralized icon wrapper functions | Phase 45 (Mar 2026) | Consistency enforcement, easy global changes |
| Search = btn-success (green) | Search = btn-primary (lavender) | Phase 47 (pending) | Semantic accuracy: search is primary action, not confirmation |
| info = blue | info = sapphire | Phase 45 (Mar 2026) | Distinct informational color, reserves blue for future use |

**Deprecated/outdated:**
- Manual JavaScript theme toggle: Bootstrap 5.3+ has bslib::input_dark_mode() and [data-bs-theme] attribute
- Hardcoded hex colors in R/HTML: Use Bootstrap semantic classes (btn-primary) or CSS custom properties (--bs-primary)

## Open Questions

1. **Should Export dropdown be btn-outline-secondary or btn-outline-primary?**
   - What we know: Currently btn-outline-secondary (muted gray). User marked for evaluation.
   - What's unclear: Is export a "secondary" action (less important) or "primary" utility (frequently used)?
   - Recommendation: Keep btn-outline-secondary — export is less frequent than Send/Generate presets. Users won't confuse it with primary actions. If contrast fails in light mode, switch to btn-outline-info (sapphire).

2. **What color should Citation Network sidebar button use?**
   - What we know: Currently btn-outline-danger (red). User says avoid danger semantic (implies destructive). Rainbow approach wants distinct colors per action.
   - What's unclear: Which color best represents "citation network" — info (sapphire, analytical), primary (lavender, core feature), or custom sky (exploratory)?
   - Recommendation: btn-outline-primary (lavender) — citation network is a core analytical feature, not a utility. Reserves sapphire/info for informational actions and sky for future use.

3. **How many new icon wrappers are needed?**
   - What we know: 20 wrappers defined in Phase 45. Codebase has ~80+ icon() calls across 10+ files.
   - What's unclear: How many UNIQUE icon names are in use? Decorative icons (seedling, compass, coins, brain) need wrappers too.
   - Recommendation: Run grep icon\(["\'] across codebase, extract unique icon names, create wrappers for all (~30-40 total). Mark decorative wrappers with comments so they're not confused with action icons.

4. **Should sidebar divider be a border or margin/padding?**
   - What we know: User wants "subtle divider" between notebook creation buttons and discovery buttons. Claude's discretion.
   - What's unclear: Visual preference — thin border-top (1px solid var(--bs-border-color)) vs extra margin (mt-3)?
   - Recommendation: Use margin (mt-2 mb-1 on a div) instead of border — cleaner visual separation without adding visual weight. Test in both light/dark mode to ensure spacing is noticeable but not jarring.

## Validation Architecture

> Validation is enabled (workflow.nyquist_validation not set to false)

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x (R test framework) |
| Config file | tests/testthat.R (existing) |
| Quick run command | `Rscript -e "testthat::test_file('tests/testthat/test_theme.R')"` |
| Full suite command | `Rscript -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THEM-01 | Sidebar colors adapt to light/dark mode | manual-only | Visual inspection in running app | N/A — theming is visual |
| THEM-02 | Citation audit button readable in light mode | manual-only | WCAG contrast checker on running app | N/A — requires color values |
| THEM-03 | Import papers button has distinct color | manual-only | Visual inspection in running app | N/A — theming is visual |
| DSGN-03 | All buttons follow semantic color scheme | manual-only | Code review of btn-* classes | N/A — code inspection |
| DSGN-04 | Icon usage is consistent | unit | `Rscript -e "testthat::test_file('tests/testthat/test_icon_wrappers.R')"` | ❌ Wave 0 |
| THEM-04 | Notebook buttons uniform styling | manual-only | Visual inspection in running app | N/A — theming is visual |
| THEM-05 | Button bar uses available space | manual-only | Responsive test at multiple screen widths | N/A — layout is visual |

### Sampling Rate
- **Per task commit:** Manual visual inspection in running app (light + dark mode)
- **Per wave merge:** Manual WCAG contrast check on changed buttons
- **Phase gate:** Full visual regression testing of all modules before /gsd:verify-work

### Wave 0 Gaps
- [ ] `tests/testthat/test_icon_wrappers.R` — covers DSGN-04 (verifies no raw icon() calls remain, all wrappers defined)
- [ ] Framework install: Already installed — no action needed

**Note:** Phase 47 is primarily a visual theming phase. Most validation is manual (visual inspection, contrast checking, responsive testing). Only icon wrapper consistency is automatable via unit test.

## Sources

### Primary (HIGH confidence)
- [bslib::bs_theme() reference](https://rstudio.github.io/bslib/reference/bs_theme.html) — R Shiny Bootstrap theming API
- [Bootstrap 5.3 Color Modes](https://getbootstrap.com/docs/5.3/customize/color-modes/) — Official dark mode documentation
- [Bootstrap 5.3 Buttons](https://getbootstrap.com/docs/5.3/components/buttons/) — Button variants and sizing
- [Bootstrap 5.3 Button Groups](https://getbootstrap.com/docs/5.3/components/button-group/) — Group sizing and spacing
- [Font Awesome 6 Icons](https://fontawesome.com/v6/icons) — Icon reference and search
- [Catppuccin Palette](https://catppuccin.com/palette/) — Official color hex values for MOCHA/LATTE
- Existing codebase: R/theme_catppuccin.R (MOCHA/LATTE constants, icon wrappers, catppuccin_dark_css() function)
- Existing codebase: www/swatch.html (design system validation sheet from Phase 45)

### Secondary (MEDIUM confidence)
- [Bootstrap custom button colors guide](https://thelinuxcode.com/how-to-change-button-color-in-bootstrap-5-and-keep-it-consistent-accessible-and-scalable/) — Custom CSS class patterns
- [Bootstrap 5 flexbox utilities](https://getbootstrap.com/docs/5.3/utilities/flex/) — Responsive layout patterns
- [Font Awesome Icon Design Guidelines](https://docs.fontawesome.com/web/add-icons/upload-icons/icon-design/) — Consistency best practices
- [Shiny responsive layouts guide](https://shiny.posit.co/blog/posts/responsive-shiny-layouts/) — Flexbox in Shiny context
- [Catppuccin Bootstrap 5 theme](https://github.com/mfabing/catpuccin_bootstrap5) — Example of Catppuccin + Bootstrap integration

### Tertiary (LOW confidence)
- WebAIM Contrast Checker — Tool for WCAG validation, not documentation
- Generic CSS Grid/Flexbox tutorials — General knowledge, not Shiny-specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — bslib and Bootstrap 5 are well-documented official libraries
- Architecture: HIGH — Patterns verified from official docs + existing working code in Phase 45
- Pitfalls: MEDIUM — Based on common theming mistakes + CONTEXT.md user decisions, not field experience with this exact app
- Icon catalog: MEDIUM — Grepped 100 icon calls, but full count/uniqueness requires complete scan

**Research date:** 2026-03-05
**Valid until:** 2026-04-05 (30 days — Bootstrap/bslib stable, Catppuccin palette static)
