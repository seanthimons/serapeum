# Stack Research

**Domain:** Dark mode theming for R/Shiny/bslib applications
**Researched:** 2026-02-22
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| bslib | 0.10.0 | Bootstrap theming framework for Shiny | Official Posit/RStudio package for Bootstrap 5.3+ theming, provides `bs_theme()` for Sass variable customization, `input_dark_mode()` for client-side mode switching, and `session$setCurrentTheme()` for dynamic theme updates. Bootstrap 5.3.1 support enables pure CSS dark mode without Sass recompilation. |
| Bootstrap | 5.3.1+ | UI framework with CSS custom properties | Bootstrap 5.3+ introduced native color modes with `data-bs-theme` attribute, extensive CSS custom properties for dark mode (`--bs-body-bg`, `--bs-body-color`, etc.), and semantic color system (`{color}-bg-subtle`, `{color}-text-emphasis`, `{color}-border-subtle`). Automatically included via bslib. |
| colorspace | latest | WCAG contrast ratio validation | R package providing `contrast_ratio()` function implementing WCAG 2.1 and APCA 0.98G-4g algorithms. Computes contrast ratios with visualization support. Essential for verifying 4.5:1 (normal text) and 3:1 (large text) WCAG AA requirements. |
| sass | latest | Sass compilation for custom theming | Dependency of bslib, compiles Bootstrap Sass with custom variables. Required for `bs_add_variables()` and `bs_add_rules()` advanced theming. Automatically handles Bootstrap Sass mixins and variable resolution. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| N/A | N/A | No additional libraries required | bslib handles all Bootstrap theming needs. Custom CSS can be added via `bs_add_rules()`. visNetwork and commonmark will inherit Bootstrap color mode automatically via CSS custom properties. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `bs_theme_preview()` | Interactive theme builder | Launch with `bslib::bs_theme_preview()` to test theme changes in real time. Includes `bs_themer()` widget for live editing of colors, fonts, and spacing. Great for prototyping dark mode palettes before hardcoding. |
| `contrast_ratio()` | Contrast validation during development | Use `colorspace::contrast_ratio(bg, fg, algorithm = "WCAG", plot = TRUE)` to visualize contrast ratios. Returns numeric vector with ratios; >=4.5 for normal text, >=3 for large text (WCAG AA). |
| WebAIM Contrast Checker | Online fallback for ad-hoc checks | https://webaim.org/resources/contrastchecker/ for quick browser-based validation if colorspace is unavailable. |

## Implementation Patterns

### Pattern 1: Static Dark Mode Palette (Recommended Start)

**When:** Redesigning dark mode from scratch with intentional colors.

**How:**
```r
dark_theme <- bs_theme(
  version = 5,
  preset = "shiny",  # Start with Shiny preset for dashboard improvements
  bg = "#1a1a1a",    # Dark background
  fg = "#e0e0e0",    # Light foreground text
  primary = "#4a9eff",      # Accessible blue
  secondary = "#6c757d",    # Muted gray
  success = "#28a745",      # Green
  danger = "#dc3545",       # Red
  # Custom Sass variables via ...
  "card-bg" = "#2d2d2d",
  "border-color" = "#444444"
)
```

**Why:** Gives full control over palette, ensures consistent application of colors, works with existing `input_dark_mode()` toggle infrastructure.

### Pattern 2: Dynamic Theme Switching

**When:** Users need to toggle between light and dark modes.

**How:**
```r
# Already implemented in Serapeum via input_dark_mode()
# UI: input_dark_mode(id = "mode")
# Server: observeEvent(input$mode, { session$setCurrentTheme(theme_object) })
```

**Current state:** Serapeum has basic toggle but with poor contrast palette. Keep toggle mechanism, replace theme definitions.

### Pattern 3: Component-Level Dark Mode Customization

**When:** Specific components (visNetwork, commonmark HTML) need dark mode overrides.

**How:**
```r
dark_theme <- bs_theme(...) |>
  bs_add_rules(
    ".vis-network { background-color: var(--bs-body-bg); }",
    ".markdown-body { color: var(--bs-body-color); background: var(--bs-body-bg); }",
    # Reference Bootstrap CSS variables for automatic light/dark adaptation
  )
```

**Why:** CSS custom properties (`--bs-*`) automatically update when `data-bs-theme` changes, so rules adapt to both modes. Avoids hardcoded colors in custom CSS.

## Theming API Reference

### bs_theme() Parameters for Dark Mode

| Parameter | Type | Purpose | Dark Mode Value Example |
|-----------|------|---------|-------------------------|
| `bg` | color string | Background color | `"#1a1a1a"` (near-black) |
| `fg` | color string | Foreground/text color | `"#e0e0e0"` (light gray) |
| `primary` | color string | Links, primary buttons | `"#4a9eff"` (accessible blue) |
| `secondary` | color string | Secondary buttons, muted UI | `"#6c757d"` |
| `...` | Sass variables | Any Bootstrap Sass variable | `"card-bg" = "#2d2d2d"` |

### Bootstrap 5.3 CSS Custom Properties

Dark mode values are defined in `_variables-dark.scss` and exposed as CSS custom properties:

| Variable | Purpose | Example Dark Value |
|----------|---------|-------------------|
| `--bs-body-bg` | Main background | `#212529` |
| `--bs-body-color` | Main text color | `#adb5bd` |
| `--bs-emphasis-color` | High-contrast text | `#fff` |
| `--bs-secondary-color` | Muted text | `rgba(173, 181, 189, 0.75)` |
| `--bs-tertiary-bg` | Card/panel backgrounds | `#2c3034` |
| `--bs-border-color` | Border colors | `#495057` |
| `--bs-link-color` | Link color | `#6ea8fe` |
| `--bs-primary-bg-subtle` | Subtle primary background | `shade-color($primary, 80%)` |
| `--bs-primary-text-emphasis` | Primary emphasis text | `tint-color($primary, 40%)` |

**Usage in custom CSS:** Reference these variables to inherit dark mode automatically:
```css
.custom-component {
  background-color: var(--bs-body-bg);
  color: var(--bs-body-color);
  border: 1px solid var(--bs-border-color);
}
```

### bslib Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `bs_theme()` | Create theme object | `bs_theme(version = 5, bg = "#1a1a1a", fg = "#e0e0e0")` |
| `bs_add_rules()` | Add custom CSS/Sass | `theme |> bs_add_rules(".class { color: var(--bs-primary); }")` |
| `bs_add_variables()` | Add Sass variables after declarations | `theme |> bs_add_variables("my-var" = "$primary", .where = "declarations")` |
| `input_dark_mode()` | UI toggle for dark mode | `input_dark_mode(id = "mode", mode = NULL)` (NULL = respect system preference) |
| `toggle_dark_mode()` | Programmatic mode switch | `toggle_dark_mode(mode = "dark", session = session)` |
| `session$setCurrentTheme()` | Dynamic theme update | `session$setCurrentTheme(new_theme)` (must be same Bootstrap version) |
| `bs_theme_preview()` | Interactive theme builder | `bs_theme_preview()` or `bs_theme_preview(theme)` |

## WCAG Contrast Validation Workflow

### Using colorspace Package

```r
library(colorspace)

# Check text on background
contrast_ratio("#e0e0e0", "#1a1a1a", algorithm = "WCAG", plot = TRUE)
# Returns: 12.63 (PASS - exceeds 4.5 minimum)

# Check link color
contrast_ratio("#4a9eff", "#1a1a1a", algorithm = "WCAG")
# Returns: 6.2 (PASS)

# Batch check theme colors
bg <- "#1a1a1a"
colors <- c(fg = "#e0e0e0", primary = "#4a9eff", secondary = "#6c757d")
sapply(colors, function(col) contrast_ratio(col, bg, algorithm = "WCAG"))
```

**WCAG 2.1 Requirements:**
- Normal text (< 18pt): 4.5:1 minimum (AA), 7:1 (AAA)
- Large text (>= 18pt or 14pt bold): 3:1 minimum (AA), 4.5:1 (AAA)
- UI components and graphics: 3:1 minimum

**APCA Alternative:** Newer algorithm under development. `algorithm = "APCA"` returns polarity-aware values (~60 ≈ WCAG 4.5).

### Manual Checking

For spot checks without R:
- WebAIM: https://webaim.org/resources/contrastchecker/
- Accessible Colors: https://accessible-colors.com/

## Integration with Existing Serapeum Components

### visNetwork Citation Graphs

**Current state:** Canvas-based network visualization.

**Dark mode approach:**
```r
# In mod_citation_network.R
visNetwork(nodes, edges) %>%
  visOptions(
    highlightNearest = TRUE,
    nodesIdSelection = TRUE
  ) %>%
  # Set background to match Bootstrap body-bg
  # Use JavaScript to read CSS variable:
  htmlwidgets::onRender("
    function(el, x) {
      var bg = getComputedStyle(document.documentElement)
        .getPropertyValue('--bs-body-bg').trim();
      el.style.backgroundColor = bg;
    }
  ")
```

**Alternative:** Set background statically in theme via `bs_add_rules()`:
```r
bs_add_rules(".vis-network { background-color: var(--bs-body-bg) !important; }")
```

### commonmark Markdown Rendering

**Current state:** Chat messages rendered via `commonmark::markdown_html()`.

**Dark mode approach:**
- Bootstrap 5.3 typography utilities automatically adapt to `data-bs-theme`
- Wrap rendered HTML in container with Bootstrap classes:
  ```r
  tags$div(
    class = "markdown-body",
    HTML(commonmark::markdown_html(text))
  )
  ```
- Add CSS rules for markdown elements:
  ```r
  bs_add_rules("
    .markdown-body {
      color: var(--bs-body-color);
      background: transparent;
    }
    .markdown-body code {
      background-color: var(--bs-tertiary-bg);
      color: var(--bs-emphasis-color);
    }
  ")
  ```

**No additional libraries needed** — Bootstrap CSS variables handle adaptation.

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Hardcoded color values in custom CSS | Breaks when switching light/dark modes | Bootstrap CSS custom properties (`var(--bs-body-bg)`) |
| Manual `@media (prefers-color-scheme: dark)` queries | Conflicts with bslib's `data-bs-theme` approach | Let bslib handle mode detection via `input_dark_mode()` |
| Bootstrap 4 or earlier | No native dark mode support, requires Sass recompilation for theme changes | Bootstrap 5.3+ via `bs_theme(version = 5)` |
| Third-party dark mode libraries (e.g., darkmode.js) | Unnecessary with Bootstrap 5.3 built-in support | `input_dark_mode()` + `bs_theme()` |
| Linear contrast ratios for validation | WCAG uses logarithmic luminance calculation | `colorspace::contrast_ratio(algorithm = "WCAG")` |
| Custom theme switching with different Bootstrap versions | bslib throws error when `session$setCurrentTheme()` changes Bootstrap version | Ensure all themes use same `version = 5` |

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| bslib `bs_theme()` | Manual Bootstrap Sass compilation | Never for Shiny apps — bslib is the official theming layer |
| Bootstrap 5.3 CSS variables | Sass variable overrides only | When you need compile-time logic (e.g., color calculations with `tint-color()`, `shade-color()`) — but can combine both approaches |
| colorspace package | Online contrast checkers | For one-off checks during design phase; use colorspace for automated validation in tests |
| `input_dark_mode()` | Custom toggle with `session$setCurrentTheme()` | When you need additional logic beyond simple light/dark toggle (e.g., multiple theme presets) |

## Version Compatibility

| Package | Version | Compatible With | Notes |
|---------|---------|-----------------|-------|
| bslib | 0.10.0 | Bootstrap 5.3.1, sass (any recent), shiny 1.6+ | Requires Shiny 1.6+ for `session$setCurrentTheme()`. Bootstrap 5.3+ required for `input_dark_mode()`. |
| Bootstrap | 5.3.1+ | bslib 0.6.0+ | Dark mode support added in Bootstrap 5.3.0. bslib 0.8.0+ upgraded default to 5.3.1. |
| colorspace | latest | R 4.0+ | No shiny/bslib dependencies; pure color calculation library. |
| sass | latest | bslib (any), R 4.0+ | Automatically installed as bslib dependency. Direct use only needed for advanced Sass compilation. |

**Key constraint:** `session$setCurrentTheme()` cannot change Bootstrap version dynamically. All themes must use `version = 5`.

## Installation

```r
# Core theming (already in Serapeum)
install.packages("bslib")  # Includes sass as dependency

# Contrast validation
install.packages("colorspace")
```

**No additional packages needed.** Serapeum already has bslib and all required dependencies.

## Recommended Implementation Sequence

1. **Validation setup:** Install `colorspace`, create contrast checking function
2. **Palette design:** Use `bs_theme_preview()` to prototype dark mode colors
3. **Theme definition:** Create dark theme object with validated colors via `bs_theme()`
4. **Component integration:** Add `bs_add_rules()` for visNetwork, commonmark, any custom components
5. **Testing:** Verify contrast ratios programmatically, test toggle behavior
6. **Polish:** Adjust semantic colors (success, danger, etc.) for dark mode readability

## Sources

**HIGH confidence (official documentation):**
- [bslib Theming Guide](https://rstudio.github.io/bslib/articles/theming/index.html) — bs_theme() parameters, Sass variables, best practices
- [bs_theme() Reference](https://rstudio.github.io/bslib/reference/bs_theme.html) — Function parameters, Bootstrap version support
- [input_dark_mode() Reference](https://rstudio.github.io/bslib/reference/input_dark_mode.html) — Dark mode toggle parameters, server values
- [Bootstrap 5.3 Color Modes](https://getbootstrap.com/docs/5.3/customize/color-modes/) — CSS custom properties, data-bs-theme attribute, semantic colors
- [Bootstrap 5.3 Colors](https://getbootstrap.com/docs/5.3/customize/color/) — Color system, Sass variables, theming maps
- [colorspace contrast_ratio()](https://colorspace.r-forge.r-project.org/reference/contrast_ratio.html) — WCAG validation, parameters, algorithms
- [bslib Changelog 0.10.0](https://rstudio.github.io/bslib/news/index.html) — Latest version features, brand.yml support, dark mode improvements
- [bslib Custom Components](https://rstudio.github.io/bslib/articles/custom-components/index.html) — Making components dynamically themeable

**MEDIUM confidence (official blogs/community resources):**
- [Shiny Theming Overview](https://shiny.posit.co/r/articles/build/themes/) — Integration patterns
- [bslib 0.9.0 Release](https://shiny.posit.co/blog/posts/bslib-0.9.0/) — Brand theming features
- [Bootstrap 5.3.0 Release](https://blog.getbootstrap.com/2023/05/30/bootstrap-5-3-0/) — Dark mode announcement, new features

**MEDIUM confidence (web search):**
- [visNetwork GitHub Issue #151](https://github.com/datastorm-open/visNetwork/issues/151) — Background color customization
- [visNetwork Introduction](https://cran.r-project.org/web/packages/visNetwork/vignettes/Introduction-to-visNetwork.html) — Styling options

---
*Stack research for: Dark mode theming in R/Shiny/bslib applications*
*Researched: 2026-02-22*
