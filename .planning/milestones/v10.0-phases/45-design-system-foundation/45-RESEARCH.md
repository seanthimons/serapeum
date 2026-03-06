# Phase 45: Design System Foundation - Research

**Researched:** 2026-03-04
**Domain:** R/Shiny Design Systems, bslib theming, Bootstrap 5 semantic color systems, static HTML documentation
**Confidence:** HIGH

## Summary

Phase 45 establishes the design system foundation for Serapeum by documenting semantic color and icon policies and producing a visual swatch sheet for validation before any UI code changes in Phase 47. The research confirms that R/Shiny's bslib package provides robust Bootstrap 5 theming capabilities via semantic color variables (primary, danger, success, warning, info, secondary), and that htmltools can generate static HTML documentation files. The Catppuccin palette is already integrated (via `R/theme_catppuccin.R`), providing well-defined Mocha (dark) and Latte (light) color constants.

**Primary recommendation:** Document semantic color→action mappings and icon wrapper functions as structured comments in `R/theme_catppuccin.R`, then generate a standalone HTML swatch sheet using htmltools that displays both Catppuccin flavors side-by-side with all button variants, icons, badges, sidebar examples, and form elements. Save to `www/swatch.html` for browser-based visual validation.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Semantic color mapping
- **Primary** (main actions: Search, Save, Add to Notebook) = Catppuccin **blue** (Mocha #89b4fa / Latte #1e66f5)
- **Danger** (destructive: delete, remove, clear) = Catppuccin **red** (Mocha #f38ba8 / Latte #d20f39)
- **Success** (confirmations: paper added, export complete) = Catppuccin **green** (Mocha #a6e3a1 / Latte #40a02b)
- **Warning** (cautions: API key missing, rate limit) = Catppuccin **yellow** (Mocha #f9e2af / Latte #df8e1d)
- **Info** (informational: tooltips, help text) = Catppuccin **sapphire** (Mocha #74c7ec / Latte #209fb5)
- **Secondary** (cancel, close, less important) = Catppuccin **surface0/surface1** colors
- **Sidebar active items** = inherit from primary (blue), no separate accent color
- **Peach** = candidate accent for highlights/badges — include in swatch sheet for visual evaluation before committing (concern: may look too similar to warning/yellow)

#### Icon system design
- Standardize on **Font Awesome** (already used via `shiny::icon()`)
- Create **semantic wrapper functions** (e.g., `icon_save()`, `icon_delete()`, `icon_search()`) mapping to specific FA icons
- Wrappers live in **R/theme_catppuccin.R** alongside color definitions — all design system code in one file
- Icons are **color-neutral** — wrappers only standardize which icon to use. Color comes from the button/context they're placed in, not the icon itself.

#### Swatch sheet format
- **Static HTML file** (not a Shiny module) — viewable without running the app
- **Side-by-side layout**: Latte (light) on left, Mocha (dark) on right for simultaneous comparison
- **Comprehensive scope**: buttons (all variants), badges, sidebar items, alerts, form inputs, cards, icons
- **Both raw palette and semantic**: top section shows all Catppuccin colors with hex values, bottom section shows semantic components using those colors

#### Button variant policy
- **Primary actions**: solid fill (blue background, white text) — strong visual hierarchy
- **Secondary actions**: outline style (border + text, transparent background) — clear hierarchy below primary
- **Destructive actions**: danger-colored (red), no confirmation dialog needed — color is the warning. Reserve confirmation for irreversible bulk actions only.
- **Three sizes**: small (`btn-sm` for table rows, inline actions), default (standard actions), large (hero/CTA)

### Claude's Discretion
- Exact hover/focus/disabled state treatments
- Alert component styling details
- Card border and shadow treatments
- Form input focus ring colors
- Badge sizing and placement conventions

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DSGN-01 | Global color/theme policy document defines button semantics (primary/secondary/danger/success/warning), icon-action mappings, and sidebar theming rules | bslib semantic color variables + structured documentation in R/theme_catppuccin.R + icon wrapper functions |
| DSGN-02 | Visual swatch sheet rendered in both light and dark mode showing all button variants, icon mappings, sidebar colors, and badge styles — validated before any code changes | htmltools static HTML generation + side-by-side Catppuccin Latte/Mocha rendering |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bslib | Latest (already in project) | Bootstrap 5 theming for R/Shiny | Official RStudio Bootstrap theming library, provides `bs_theme()` for semantic color customization via CSS variables |
| htmltools | Latest (already in project) | HTML generation and static file output | Official RStudio HTML generation library, used by Shiny, supports `save_html()` for standalone HTML files |
| Font Awesome | via shiny::icon() | Icon library | Most widely used icon library in 2026, already integrated in Serapeum, 7800+ icons with semantic naming |
| Catppuccin | Already integrated | Color palette | Already implemented in `R/theme_catppuccin.R` with MOCHA/LATTE constants and `catppuccin_dark_css()` function |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Bootstrap 5 CSS Variables | via bslib | Direct CSS variable overrides | For fine-tuning semantic colors beyond bs_theme() parameters (e.g., hover states, focus rings) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Static HTML swatch | Quarto document | Quarto adds build complexity and requires external tooling vs htmltools which is already a dependency |
| Font Awesome | Hugeicons, Lineicons | Alternative icon libraries with more modern designs, but Font Awesome is already integrated and has wider R/Shiny ecosystem support |
| In-code documentation | Separate markdown file | Separate docs get out of sync; keeping policy in `R/theme_catppuccin.R` as structured comments ensures single source of truth |

**Installation:**
No additional packages needed — bslib, htmltools, and Font Awesome (via Shiny) are already project dependencies.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── theme_catppuccin.R        # Design system source of truth
│   ├── MOCHA/LATTE constants (existing)
│   ├── catppuccin_dark_css() (existing)
│   ├── [NEW] Semantic color policy (structured comments)
│   ├── [NEW] Icon wrapper functions (icon_save, icon_delete, etc.)
│   └── [NEW] generate_swatch_html() function
www/
└── swatch.html               # [NEW] Static validation sheet
```

### Pattern 1: Semantic Color Documentation via Structured Comments
**What:** Document color→action mappings as structured comments in `R/theme_catppuccin.R` immediately above color constants
**When to use:** Always for design system documentation that must stay in sync with code
**Example:**
```r
# Semantic Color Mapping (DSGN-01)
#
# PRIMARY (blue): Main actions — Search, Save, Add to Notebook
#   - Mocha: #89b4fa | Latte: #1e66f5
#   - Usage: Solid buttons (.btn-primary), active sidebar items
#
# DANGER (red): Destructive actions — Delete, Remove, Clear
#   - Mocha: #f38ba8 | Latte: #d20f39
#   - Usage: Danger buttons (.btn-danger), no confirmation needed
#
# SUCCESS (green): Confirmations — Paper Added, Export Complete
#   - Mocha: #a6e3a1 | Latte: #40a02b
#   - Usage: Success alerts, completion badges
#
# [... continue for warning, info, secondary ...]

MOCHA <- list(
  blue = "#89b4fa",
  red = "#f38ba8",
  # [existing code continues...]
)
```
**Source:** Best practice from [Color in Design Systems (Medium)](https://medium.com/eightshapes-llc/color-in-design-systems-a1c80f65fa3)

### Pattern 2: Icon Wrapper Functions
**What:** Create semantic wrapper functions that return `icon()` calls with standardized Font Awesome names
**When to use:** Whenever an action needs an icon — use wrapper instead of raw `icon()` call
**Example:**
```r
# Icon System (DSGN-01)
#
# Wrappers standardize icon-to-action mappings. Icons are color-neutral —
# color comes from button/badge context, not the icon itself.

#' Save action icon (floppy disk)
icon_save <- function(...) icon("floppy-disk", ...)

#' Delete/Remove action icon (trash can)
icon_delete <- function(...) icon("trash", ...)

#' Search action icon (magnifying glass)
icon_search <- function(...) icon("magnifying-glass", ...)

#' Add/Create action icon (plus)
icon_add <- function(...) icon("plus", ...)

#' Download action icon (down arrow)
icon_download <- function(...) icon("download", ...)

#' Settings/Config icon (gear)
icon_settings <- function(...) icon("gear", ...)

#' Info/Help icon (circle with i)
icon_info <- function(...) icon("info-circle", ...)

#' Warning icon (triangle with exclamation)
icon_warning <- function(...) icon("triangle-exclamation", ...)

#' Close/Cancel icon (X)
icon_close <- function(...) icon("xmark", ...)
```
**Source:** Semantic wrapper pattern from design systems best practices

### Pattern 3: Static Swatch HTML Generation
**What:** Use htmltools to generate a standalone HTML file with embedded Catppuccin CSS
**When to use:** For visual validation artifacts that need browser rendering without running the Shiny app
**Example:**
```r
# Generate swatch sheet (DSGN-02)
generate_swatch_html <- function(output_path = "www/swatch.html") {
  # Build HTML structure using htmltools::tags
  swatch_ui <- tags$html(
    tags$head(
      tags$title("Serapeum Design System Swatch Sheet"),
      tags$style(HTML(paste0("
        /* Catppuccin Mocha embedded */
        .theme-mocha {
          background: #1e1e2e;
          color: #cdd6f4;
          --primary: #89b4fa;
          --danger: #f38ba8;
          /* [... all semantic colors ...] */
        }
        .theme-latte {
          background: #eff1f5;
          color: #4c4f69;
          --primary: #1e66f5;
          --danger: #d20f39;
          /* [... all semantic colors ...] */
        }
        .btn-primary { background: var(--primary); }
        /* [... button styles ...] */
      ")))
    ),
    tags$body(
      tags$div(
        class = "container-fluid",
        tags$div(
          class = "row",
          # Left: Latte (light)
          tags$div(class = "col-6 theme-latte",
            tags$h1("Catppuccin Latte (Light)"),
            # [... buttons, badges, cards, forms ...]
          ),
          # Right: Mocha (dark)
          tags$div(class = "col-6 theme-mocha",
            tags$h1("Catppuccin Mocha (Dark)"),
            # [... buttons, badges, cards, forms ...]
          )
        )
      )
    )
  )

  # Save to static file
  htmltools::save_html(swatch_ui, file = output_path)
  message("Swatch sheet saved to ", output_path)
}
```
**Source:** [htmltools documentation](https://rstudio.github.io/htmltools/reference/renderDocument.html) and [GitHub examples](https://github.com/rstudio/htmltools)

### Anti-Patterns to Avoid
- **Separate color policy doc:** Don't create a standalone markdown file — it will drift out of sync. Keep policy as structured comments in `R/theme_catppuccin.R`.
- **Inline icon() calls:** Don't use `icon("floppy-disk")` directly in modules — use `icon_save()` wrapper so icon choice can be changed globally.
- **Shiny-based swatch:** Don't make the swatch a Shiny module — static HTML is faster to load, doesn't require server, and can be committed to git for diff tracking.
- **Hard-coding hex values:** Don't duplicate color hex values in UI code — always reference MOCHA/LATTE constants or bslib semantic variables.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Semantic color management | Custom CSS variables system | bslib `bs_theme()` + Bootstrap 5 semantic colors | bslib handles light/dark mode switching, CSS variable generation, and Bootstrap component integration automatically |
| HTML generation | String concatenation or sprintf | htmltools tag functions | htmltools provides HTML escaping, attribute validation, and dependency management |
| Icon library | Custom SVG sprite system | Font Awesome via shiny::icon() | 7800+ icons with semantic names, already integrated, widely supported |
| Dark mode switching | Manual CSS classes | Bootstrap `[data-bs-theme="dark"]` + bslib | Bootstrap 5's built-in dark mode system is battle-tested and handles edge cases |

**Key insight:** bslib and Bootstrap 5 provide industrial-strength theming infrastructure that handles semantic colors, dark mode, CSS variables, and accessibility. Custom systems will miss edge cases (focus rings, disabled states, form validation colors, etc.).

## Common Pitfalls

### Pitfall 1: Color Policy Documentation Drift
**What goes wrong:** Color policy documented separately from code (e.g., in a markdown file) falls out of sync when colors are updated in `R/theme_catppuccin.R`
**Why it happens:** Separate documentation requires manual updates in two places, easy to forget
**How to avoid:** Keep policy as structured comments in `R/theme_catppuccin.R` immediately adjacent to MOCHA/LATTE constants
**Warning signs:** Comments in code reference colors that don't match current palette values

### Pitfall 2: Icon Inconsistency Without Wrappers
**What goes wrong:** Same action uses different icons across modules (e.g., "save" uses `icon("floppy-disk")` in one place and `icon("save")` in another)
**Why it happens:** Direct `icon()` calls in modules → no central definition
**How to avoid:** Always use semantic wrapper functions (`icon_save()`, `icon_delete()`) instead of raw `icon()` calls
**Warning signs:** Grep for `icon("` finds many direct calls with inconsistent names for same actions

### Pitfall 3: Swatch Sheet Missing Edge Cases
**What goes wrong:** Swatch looks good but misses hover states, disabled buttons, or focus rings → visual bugs discovered in Phase 47 during implementation
**Why it happens:** Incomplete component catalog in swatch sheet
**How to avoid:** Swatch must show ALL states: default, hover, active, disabled, focus for each component type
**Warning signs:** User validation finds "this looks wrong in dark mode" during Phase 47 implementation

### Pitfall 4: Hard-Coding Semantic Colors
**What goes wrong:** UI code uses `style = "color: #89b4fa"` instead of `class = "text-primary"` → breaks when switching themes or colors
**Why it happens:** Developer doesn't know about Bootstrap semantic color classes
**How to avoid:** Always use Bootstrap semantic classes (`.btn-primary`, `.text-danger`, `.bg-success`) or bslib theme variables, never hard-code hex values
**Warning signs:** Grep for Catppuccin hex values (`#89b4fa`, `#f38ba8`) in mod_*.R files outside of theme_catppuccin.R

### Pitfall 5: Peach vs Yellow Visual Ambiguity
**What goes wrong:** Peach accent (#fab387 Mocha / #fe640b Latte) looks too similar to warning yellow (#f9e2af Mocha / #df8e1d Latte) → user can't distinguish badges/highlights from warnings
**Why it happens:** Both colors are warm and in orange/yellow spectrum
**How to avoid:** Swatch sheet MUST show peach and yellow side-by-side with actual use cases (badges, highlights) for user to validate contrast
**Warning signs:** User flags "hard to tell the difference" during swatch validation

## Code Examples

Verified patterns from official sources:

### Customizing bslib Semantic Colors
```r
# Source: https://rstudio.github.io/bslib/reference/bs_theme.html
library(bslib)

# Map Catppuccin colors to Bootstrap semantic variables
theme <- bs_theme(
  version = 5,
  # Primary = blue (main actions)
  primary = "#89b4fa",  # Mocha blue
  # Danger = red (destructive)
  danger = "#f38ba8",   # Mocha red
  # Success = green (confirmations)
  success = "#a6e3a1",  # Mocha green
  # Warning = yellow (cautions)
  warning = "#f9e2af",  # Mocha yellow
  # Info = sapphire (informational)
  info = "#74c7ec",     # Mocha sapphire
  # Secondary = surface colors
  secondary = "#45475a" # Mocha surface1
)

# Apply to Shiny page
ui <- page_fillable(theme = theme, ...)
```

### Icon Wrapper Function with Font Awesome
```r
# Source: https://shiny.posit.co/r/reference/shiny/1.0.0/icon.html
library(shiny)

# Semantic wrapper - save action
icon_save <- function(...) {
  icon("floppy-disk", ...)
}

# Usage in button
actionButton("save_btn", "Save", icon = icon_save())

# Usage with additional classes
icon_save(class = "fa-lg text-success")
```

### Bootstrap 5 Button Variants
```r
# Source: https://getbootstrap.com/docs/5.3/components/buttons/
library(shiny)

# Solid primary button (main action)
actionButton("search", "Search Papers", class = "btn-primary")

# Outline secondary button (less important)
actionButton("cancel", "Cancel", class = "btn-outline-secondary")

# Danger button (destructive)
actionButton("delete", "Delete Paper", class = "btn-danger")

# Small button for inline actions
actionButton("edit", "Edit", class = "btn-sm btn-outline-primary")
```

### Static HTML Generation with htmltools
```r
# Source: https://github.com/rstudio/htmltools
library(htmltools)

# Create HTML document
doc <- tags$html(
  tags$head(
    tags$title("Swatch Sheet"),
    tags$style(HTML("body { font-family: sans-serif; }"))
  ),
  tags$body(
    tags$h1("Color Palette"),
    tags$div(
      class = "color-swatch",
      style = "background: #89b4fa; padding: 20px; color: white;",
      "Primary Blue: #89b4fa"
    )
  )
)

# Save to file
save_html(doc, file = "www/swatch.html")
```

### Catppuccin Style Guide Semantic Colors
```r
# Source: https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md
#
# Official Catppuccin semantic mappings:
# - Links/Interactive: Blue
# - Success: Green
# - Warnings: Yellow
# - Errors: Red
# - Tags/Pills: Blue backgrounds
#
# Serapeum mapping (CONTEXT.md decisions):
SEMANTIC_COLORS <- list(
  primary = "blue",      # Main actions
  danger = "red",        # Destructive
  success = "green",     # Confirmations
  warning = "yellow",    # Cautions
  info = "sapphire",     # Informational (distinct from primary blue)
  secondary = "surface1" # Less important
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bootstrap 3/4 Sass variables | Bootstrap 5 CSS variables | Bootstrap 5.0 (2021) | Enables runtime theme switching without recompilation, lighter client bundles |
| Hard-coded color hex values | Semantic color tokens (primary/danger/success) | Design systems 2020+ | Color changes propagate automatically, easier to maintain consistency |
| Inline icon choices | Semantic icon wrapper functions | Design systems 2023+ | Icons can be changed globally, ensures action-icon consistency |
| Separate style guides | Living component libraries | 2024+ | Documentation stays in sync with code, single source of truth |
| Generic .btn-primary | Semantic action naming (e.g., icon_save) | 2025+ | Code self-documents intent, easier to audit consistency |

**Deprecated/outdated:**
- **bslib::bs_theme(bootswatch = ...)**: Pre-built themes are convenient but lock you into their full palette. Custom themes via semantic color arguments provide more control while staying accessible.
- **shinyWidgets color pickers**: Not needed for fixed Catppuccin palette. User instructions explicitly state "Custom color themes / user-defined palettes" are out of scope.

## Open Questions

1. **Sidebar active item styling**
   - What we know: User decision states "Sidebar active items = inherit from primary (blue), no separate accent color"
   - What's unclear: Does this mean `.nav-link.active` should use `--bs-primary` or literal Catppuccin blue hex?
   - Recommendation: Use `--bs-primary` CSS variable for consistency with button semantics. If sidebar needs different styling, document as exception in Phase 47.

2. **Badge hierarchy**
   - What we know: Badges are in swatch scope, peach is candidate accent color
   - What's unclear: Do badges follow button semantics (primary/danger/success) or have separate hierarchy?
   - Recommendation: Propose in swatch: badges use same semantic colors as buttons (primary badge = blue, danger badge = red). Include peach badge as "accent/highlight" variant for user evaluation.

3. **Form validation color conflicts**
   - What we know: Bootstrap uses green (success) and red (danger) for form validation states
   - What's unclear: If form success uses Catppuccin green, could conflict with "confirmation" usage
   - Recommendation: Form validation should inherit Bootstrap semantic colors automatically. Document that "success = green" applies to both form validation and confirmation actions — they're semantically aligned.

## Validation Architecture

> **Note:** The `.planning/config.json` file was checked — `workflow.nyquist_validation` is **not set**, defaulting to **false**. Validation Architecture section skipped per agent instructions.

## Sources

### Primary (HIGH confidence)
- [bslib::bs_theme() reference](https://rstudio.github.io/bslib/reference/bs_theme.html) - Semantic color customization via Bootstrap 5 variables
- [bslib Theming Guide](https://rstudio.github.io/bslib/articles/theming/index.html) - Dark mode strategies, `bs_theme()` examples
- [Bootstrap 5.3 Buttons](https://getbootstrap.com/docs/5.3/components/buttons/) - Button variants, sizing, semantic color classes
- [htmltools GitHub](https://github.com/rstudio/htmltools) - HTML generation and `save_html()` for static files
- [Catppuccin Style Guide](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md) - Official semantic color mappings
- [Catppuccin Palette](https://catppuccin.com/palette/) - Complete color specifications for all four flavors

### Secondary (MEDIUM confidence)
- [Font Awesome Documentation](https://docs.fontawesome.com/web/add-icons/upload-icons/icon-design/) - Icon design guidelines and accessibility
- [Design Systems Color Guide](https://www.designsystems.com/color-guides/) - Color palette best practices
- [EightShapes: Color in Design Systems](https://medium.com/eightshapes-llc/color-in-design-systems-a1c80f65fa3) - Semantic color naming conventions
- [CSS-Tricks Dark Mode Guide](https://css-tricks.com/a-complete-guide-to-dark-mode-on-the-web/) - Dark mode implementation patterns

### Tertiary (LOW confidence)
- None — all research findings verified with official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** - bslib, htmltools, Font Awesome all officially documented and already in project dependencies
- Architecture: **HIGH** - Patterns verified with official bslib/htmltools/Bootstrap docs and existing `R/theme_catppuccin.R` code
- Pitfalls: **MEDIUM** - Based on design systems best practices and common Bootstrap theming mistakes, not Serapeum-specific experience

**Research date:** 2026-03-04
**Valid until:** 2026-04-03 (30 days) — Bootstrap 5 and bslib are stable, Catppuccin palette is fixed
