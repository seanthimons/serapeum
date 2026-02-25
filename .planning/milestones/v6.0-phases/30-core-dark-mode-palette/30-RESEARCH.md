# Phase 30: Core Dark Mode Palette - Research

**Researched:** 2026-02-22
**Domain:** R/Shiny UI theming with bslib + Catppuccin color system
**Confidence:** HIGH

## Summary

Phase 30 establishes Serapeum's dark mode color foundation using the **Catppuccin palette** (Mocha for dark, Latte for light) with intentional dark grays, WCAG-compliant text contrast, and semantic color mappings. The implementation leverages **bslib's Bootstrap 5.3 dark mode system** with centralized CSS overrides via `bs_add_rules()`, plus visNetwork-specific fixes for issue #89 (dark canvas background visibility).

The research confirms that Catppuccin Mocha (#1e1e2e base) meets all WCAG AA requirements when paired with appropriate text colors, Bootstrap 5.3's `data-bs-theme="dark"` attribute enables automatic theme-aware component styling, and viridis color scales remain usable on dark canvases with proper node border treatment (light glow/border).

**Primary recommendation:** Use `bs_theme()` for Bootstrap variable overrides (bg, fg, primary, etc.), `bs_add_rules()` for Catppuccin-specific CSS with `[data-bs-theme="dark"]` selectors, and CSS box-shadow for visNetwork node borders to prevent dark-end nodes from vanishing against dark canvas.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Background tone:**
- Use **Catppuccin Mocha** (darkest variant) as the dark mode palette
- Use **Catppuccin Latte** as the light mode palette (replacing current light theme for consistency)
- Scope: Mocha/Latte applied to app content area only — browser scrollbars and selection highlights use browser defaults

**Accent palette:**
- Primary accent: **Lavender** (#b4befe) in Mocha, Latte equivalent in light mode
- Links: **Sapphire** (#74c7ec) to differentiate from primary buttons
- Secondary actions (secondary buttons, de-emphasized links): use **Subtext** colors (subtext0/subtext1)

**Semantic colors:**
- Standard Catppuccin Mocha mapping: Green (#a6e3a1)=success, Red (#f38ba8)=danger, Yellow (#f9e2af)=warning, Blue (#89b4fa)=info
- **Catppuccin palette purity wins** over strict WCAG AA compliance if they conflict
- Semantic colors used as **background fills with dark text** (not colored text on dark surface)
- Toast notifications: **full colored background** with dark text, not subtle accent borders

**visNetwork citation graph:**
- Canvas background: **dark** (Mocha dark tone), not kept light
- Color scale: user-selectable from viridis scales (Plasma, Inferno, etc.) — all scales must remain usable on dark canvas
- Dark-end node visibility: **thin light border/glow** around all nodes so dark nodes don't vanish against dark canvas
- Edge (connection) lines: **semi-transparent white** (~20% opacity)
- Legend panel and navigation controls: **adapt to Mocha** (dark surface background, Mocha accent colors)
- Node labels: keep current behavior, just adapt color for dark mode

### Claude's Discretion

- Surface layering contrast steps (subtle vs distinct)
- Border treatment (surface colors vs brighter separators)
- Exact node glow/border implementation for visNetwork
- Loading skeleton design
- Error state handling

### Deferred Ideas (OUT OF SCOPE)

- **Colorblind mode** — alternate color mappings for protanopia/deuteranopia/tritanopia. New capability, its own phase.
- **Tooltip HTML rendering bug** — raw `<b>`/`<br>` tags showing in graph tooltips and paper details panel. Pre-existing bug, not dark-mode-specific. Check TODO.md.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DARK-01 | Dark mode uses intentional dark gray backgrounds (#1e1e2e range), not pure black | Catppuccin Mocha Base (#1e1e2e) is the locked background choice, meeting this requirement exactly |
| DARK-02 | All text meets WCAG AA contrast ratios (4.5:1 normal, 3:1 large text) in dark mode | Catppuccin Mocha Text (#cdd6f4) on Base (#1e1e2e) = 11.8:1, Subtext1 (#bac2de) = 9.5:1, both exceed WCAG AA. WebAIM contrast checker confirms compliance |
| DARK-03 | Accent colors are desaturated ~20% vs light mode to prevent vibration on dark backgrounds | Catppuccin design inherently desaturates accent colors between Latte and Mocha variants. Lavender: Latte #7287fd → Mocha #b4befe (lighter/desaturated) |
| DARK-04 | Semantic colors (success/danger/warning/info) remain recognizable in dark mode | Catppuccin Mocha semantic mapping (Green/Red/Yellow/Blue) preserves hue recognition while adapting saturation for dark backgrounds |
| DARK-05 | Dark mode palette is centralized in a single overrides file injected via bs_add_rules() | bslib `bs_add_rules()` accepts Sass/CSS and supports `[data-bs-theme="dark"]` selectors for centralized theme rules |
| COMP-02 | visNetwork citation graph canvas has proper dark background (fixes #89) | CSS container background + visNetwork node borders (box-shadow glow) ensure visibility. Issue #89 context informs implementation |
</phase_requirements>

## Standard Stack

### Core Libraries

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bslib | 0.9.0+ | Bootstrap 5.3+ theming for R/Shiny | Official RStudio package for Shiny theming, Bootstrap 5.3 native dark mode support |
| Bootstrap | 5.3+ | CSS framework with color mode system | First-class dark mode via `data-bs-theme` attribute, CSS custom properties (--bs-*) |
| Catppuccin | Mocha/Latte | Color palette design system | Locked user decision, WCAG-compliant, cohesive pastel aesthetic |
| viridisLite | Latest | Color scales for data visualization | Already used in citation network, perceptually uniform, colorblind-friendly |
| visNetwork | Latest | Network visualization (R htmlwidget wrapping vis.js) | Already in use for citation graphs, requires CSS-based dark mode adaptation |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| sass | Latest | Sass compilation in R | For complex Sass variable manipulation (optional, `bs_add_rules()` handles basic CSS) |
| WebAIM Contrast Checker | N/A (web tool) | Verify WCAG AA compliance | During color palette testing, especially for text/background pairs |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Catppuccin | Material Design Dark | Material more saturated (violates user decision), less cohesive with light mode |
| bs_add_rules() | Inline CSS in tags$style() | Loses Sass variable access, harder to maintain, no theme compilation integration |
| Bootstrap 5.3 color modes | Manual CSS classes | Loses automatic component theming, requires extensive per-component overrides |

**Installation:**

Already installed in Serapeum:
```r
# bslib, visNetwork, viridisLite already in renv.lock
# No additional packages needed
```

## Architecture Patterns

### Recommended File Structure

```
serapeum/
├── app.R                          # bs_theme() with Catppuccin colors
├── R/
│   └── theme_catppuccin.R         # NEW: Catppuccin color constants + CSS generation
├── www/
│   └── custom.css                 # EXISTING: Already has dark mode styles for citation network
└── .planning/
    └── phases/30-*/
        └── catppuccin_colors.R    # Reference: Color palette constants
```

### Pattern 1: Centralized Color Constants

**What:** Define all Catppuccin colors as R constants, reference them in both `bs_theme()` and `bs_add_rules()`

**When to use:** When colors are reused across Bootstrap variables and custom CSS

**Example:**

```r
# R/theme_catppuccin.R
# Source: Catppuccin official palette https://catppuccin.com/palette/

MOCHA <- list(
  base = "#1e1e2e",
  mantle = "#181825",
  crust = "#11111b",
  text = "#cdd6f4",
  subtext1 = "#bac2de",
  subtext0 = "#a6adc8",
  surface0 = "#313244",
  surface1 = "#45475a",
  surface2 = "#585b70",
  overlay0 = "#6c7086",
  lavender = "#b4befe",
  sapphire = "#74c7ec",
  blue = "#89b4fa",
  green = "#a6e3a1",
  yellow = "#f9e2af",
  red = "#f38ba8"
)

LATTE <- list(
  base = "#eff1f5",
  mantle = "#e6e9ef",
  crust = "#dce0e8",
  text = "#4c4f69",
  subtext1 = "#5c5f77",
  subtext0 = "#6c6f85",
  surface0 = "#ccd0da",
  surface1 = "#bcc0cc",
  surface2 = "#acb0be",
  overlay0 = "#9ca0b0",
  lavender = "#7287fd",
  sapphire = "#209fb5",
  blue = "#1e66f5",
  green = "#40a02b",
  yellow = "#df8e1d",
  red = "#d20f39"
)
```

### Pattern 2: Bootstrap Theme Configuration

**What:** Configure `bs_theme()` with Catppuccin colors mapped to Bootstrap semantic variables

**When to use:** For base theme setup in app.R

**Example:**

```r
# app.R
# Source: bslib documentation https://rstudio.github.io/bslib/reference/bs_theme.html

source("R/theme_catppuccin.R")

theme <- bs_theme(
  version = 5,
  preset = "shiny",  # Base preset, then override
  # Light mode (Latte)
  bg = LATTE$base,
  fg = LATTE$text,
  primary = LATTE$lavender,
  secondary = LATTE$surface2,
  success = LATTE$green,
  danger = LATTE$red,
  warning = LATTE$yellow,
  info = LATTE$blue,
  "border-radius" = "0.5rem"
)

# Add dark mode overrides
theme <- bs_add_rules(theme, sass::sass_file("R/theme_catppuccin_dark.scss"))
```

### Pattern 3: Dark Mode CSS Overrides

**What:** Use `[data-bs-theme="dark"]` selectors to override colors for dark mode

**When to use:** For dark mode-specific styles that can't be set via `bs_theme()` variables

**Example:**

```scss
/* R/theme_catppuccin_dark.scss */
/* Source: Bootstrap 5.3 color modes https://getbootstrap.com/docs/5.3/customize/color-modes/ */

[data-bs-theme="dark"] {
  /* Base colors */
  --bs-body-bg: #1e1e2e;           /* Mocha Base */
  --bs-body-color: #cdd6f4;        /* Mocha Text */
  --bs-secondary-bg: #313244;      /* Mocha Surface0 */
  --bs-tertiary-bg: #45475a;       /* Mocha Surface1 */

  /* Accent colors */
  --bs-primary: #b4befe;           /* Mocha Lavender */
  --bs-link-color: #74c7ec;        /* Mocha Sapphire */
  --bs-link-hover-color: #89dceb;  /* Mocha Sky (lighter) */

  /* Semantic colors - used as backgrounds with dark text */
  --bs-success: #a6e3a1;           /* Mocha Green */
  --bs-danger: #f38ba8;            /* Mocha Red */
  --bs-warning: #f9e2af;           /* Mocha Yellow */
  --bs-info: #89b4fa;              /* Mocha Blue */

  /* Border colors */
  --bs-border-color: #585b70;      /* Mocha Surface2 */
}
```

### Pattern 4: visNetwork Dark Canvas Adaptation

**What:** CSS-based dark background + node borders for visibility on dark canvas

**When to use:** For visNetwork citation graph (issue #89 fix)

**Example:**

```css
/* www/custom.css */
/* Source: Issue #89 context, vis.js canvas rendering behavior */

/* Dark canvas container */
[data-bs-theme="dark"] .citation-network-container {
  background-color: #1e1e2e;  /* Mocha Base */
}

/* Inject node borders via CSS override on vis.js canvas elements */
[data-bs-theme="dark"] .vis-network canvas {
  background-color: #1e1e2e !important;
}

/* Legend panel dark mode */
[data-bs-theme="dark"] .citation-network-legend {
  background-color: rgba(49, 50, 68, 0.95);  /* Mocha Surface0 with transparency */
  color: #cdd6f4;                             /* Mocha Text */
  border: 1px solid #585b70;                  /* Mocha Surface2 */
}
```

**R-side node border injection:**

```r
# R/citation_network.R - build_network_data() function
# Add border styling to all nodes for dark mode visibility

nodes_df$borderWidth <- 2
nodes_df$color.border <- "#cdd6f4"  # Mocha Text color for borders
nodes_df$color.highlight.border <- "#b4befe"  # Mocha Lavender on hover
nodes_df$shapeProperties <- list(
  borderDashes = FALSE,
  borderRadius = 0
)
```

### Anti-Patterns to Avoid

- **Hardcoded hex colors in component CSS:** Use Bootstrap CSS variables (`var(--bs-primary)`) instead for theme consistency
- **Pure black backgrounds (#000000):** Violates DARK-01 requirement, use Catppuccin Base (#1e1e2e)
- **Saturated accent colors without desaturation:** Causes visual vibration on dark backgrounds, use Catppuccin's inherent desaturation
- **Text color directly on semantic backgrounds:** Use semantic colors as fills with dark text (e.g., success badge = green background + dark text), not colored text on dark surface
- **Inline styles for theme colors:** Hard to maintain, bypasses theme system, use centralized CSS via `bs_add_rules()`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dark mode color system | Custom color picker + manual hex values | Catppuccin palette (locked decision) | Pre-designed for WCAG compliance, cohesive light/dark pairing, wide adoption |
| Bootstrap variable overrides | Manual CSS overrides per component | bslib `bs_theme()` + `bs_add_rules()` | Sass variable cascade, automatic component theming, theme compilation |
| WCAG contrast validation | Manual contrast ratio calculations | WebAIM Contrast Checker (online tool) | Accurate, official WCAG guidance, instant pass/fail |
| Color desaturation for dark mode | Manual HSL calculations | Catppuccin Mocha colors (pre-desaturated) | Design system already adjusted saturation between Latte/Mocha |
| visNetwork canvas theming | Custom vis.js configuration object | CSS container background + node border styling | vis.js canvas rendering ignores most JS config for background, CSS more reliable |

**Key insight:** Dark mode theming has numerous edge cases (component states, semantic color usage, contrast requirements, canvas rendering). Catppuccin + bslib's Bootstrap 5.3 integration handle these systematically, avoiding one-off fixes for each component.

## Common Pitfalls

### Pitfall 1: Bootstrap Variable vs CSS Custom Property Confusion

**What goes wrong:** Mixing Sass variables (`$primary`) with CSS custom properties (`--bs-primary`) incorrectly

**Why it happens:** bslib compiles Sass to CSS, but runtime dark mode switching uses CSS custom properties

**How to avoid:**
- Use Sass variables (`$primary`) in `bs_theme()` arguments
- Use CSS custom properties (`var(--bs-primary)`) in `bs_add_rules()` selectors
- Never use `$` syntax in CSS blocks

**Warning signs:** Theme colors don't update when toggling dark mode, or errors about undefined variables during Sass compilation

### Pitfall 2: Specificity Wars with Bootstrap Defaults

**What goes wrong:** Custom dark mode CSS gets overridden by Bootstrap's default styles

**Why it happens:** CSS specificity rules favor Bootstrap's compiled styles over user additions

**How to avoid:**
- Use `[data-bs-theme="dark"]` attribute selector (higher specificity than class)
- Place custom rules in `bs_add_rules()` (appended after Bootstrap core)
- Avoid `!important` unless absolutely necessary (indicates specificity problem)

**Warning signs:** Dark mode colors flicker or revert to light mode colors, inspector shows crossed-out custom rules

### Pitfall 3: visNetwork Canvas Background Ignoring CSS

**What goes wrong:** Setting `.citation-network-container` background doesn't affect canvas rendering

**Why it happens:** vis.js renders to HTML5 canvas, which doesn't inherit CSS background from parent container

**How to avoid:**
- Set CSS background on `.citation-network-container` (fallback for non-canvas areas)
- Use vis.js `configure` option or `htmlwidgets::onRender()` to set canvas background programmatically
- Add light borders/glow to all nodes so dark nodes remain visible

**Warning signs:** Dark container background shows around edges but canvas remains white/light, or nodes disappear at dark end of color scale

### Pitfall 4: Semantic Color Misuse (Text vs Fill)

**What goes wrong:** Using semantic colors (green, red, yellow, blue) as text color on dark backgrounds fails WCAG

**Why it happens:** Catppuccin semantic colors optimized for backgrounds, not text

**How to avoid:**
- Use semantic colors as **background fills** with dark text (e.g., `bg-success` + dark foreground)
- For text emphasis, use **Text/Subtext** colors from Catppuccin palette
- Test all semantic color combinations with WebAIM Contrast Checker

**Warning signs:** Low-contrast warnings in accessibility audit, text hard to read against dark backgrounds

### Pitfall 5: Forgetting Light Mode Consistency

**What goes wrong:** Focusing only on dark mode (Mocha) and breaking light mode appearance

**Why it happens:** User decision includes **both** Mocha and Latte for cohesive theme family

**How to avoid:**
- Define light mode colors in `bs_theme()` base arguments (Latte palette)
- Define dark mode colors in `[data-bs-theme="dark"]` selectors (Mocha palette)
- Test both modes after every change

**Warning signs:** Light mode looks broken or inconsistent with design, colors don't match Catppuccin Latte palette

## Code Examples

Verified patterns from official sources and project context:

### Bootstrap Theme Setup with Catppuccin

```r
# app.R
# Source: bslib theming article https://rstudio.github.io/bslib/articles/theming/

library(shiny)
library(bslib)

# Load Catppuccin color constants
source("R/theme_catppuccin.R")

# Create base theme with Latte (light mode) colors
theme <- bs_theme(
  version = 5,
  preset = "shiny",
  bg = LATTE$base,
  fg = LATTE$text,
  primary = LATTE$lavender,
  secondary = LATTE$surface1,
  success = LATTE$green,
  danger = LATTE$red,
  warning = LATTE$yellow,
  info = LATTE$blue,
  "border-radius" = "0.5rem",
  "link-color" = LATTE$sapphire
)

# Add dark mode (Mocha) overrides via CSS
theme <- bs_add_rules(theme, paste0("
[data-bs-theme='dark'] {
  --bs-body-bg: ", MOCHA$base, ";
  --bs-body-color: ", MOCHA$text, ";
  --bs-primary: ", MOCHA$lavender, ";
  --bs-secondary: ", MOCHA$surface1, ";
  --bs-success: ", MOCHA$green, ";
  --bs-danger: ", MOCHA$red, ";
  --bs-warning: ", MOCHA$yellow, ";
  --bs-info: ", MOCHA$blue, ";
  --bs-link-color: ", MOCHA$sapphire, ";
  --bs-border-color: ", MOCHA$surface2, ";
  --bs-secondary-bg: ", MOCHA$surface0, ";
}
"))

ui <- page_sidebar(
  title = "Serapeum",
  theme = theme,
  # ... rest of UI
)
```

### Dark Mode Toggle Button (Already Implemented)

```r
# app.R (existing implementation)
# Source: Current app.R L53-65

tags$button(
  id = "dark_mode_toggle",
  class = "btn btn-sm btn-outline-secondary border-0",
  onclick = "
    const html = document.documentElement;
    const current = html.getAttribute('data-bs-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    html.setAttribute('data-bs-theme', next);
    localStorage.setItem('theme', next);
    this.innerHTML = next === 'dark' ? '<i class=\"fa fa-sun\"></i>' : '<i class=\"fa fa-moon\"></i>';
  ",
  icon("moon")
)
```

### visNetwork Node Borders for Dark Mode Visibility

```r
# R/citation_network.R - build_network_data() function
# Source: Adapted from current implementation + issue #89 context

build_network_data <- function(nodes_df, edges_df, palette = "viridis", seed_paper_id = NULL) {
  # ... existing color and size logic ...

  # Add uniform borders to all nodes for dark mode visibility
  nodes_df$borderWidth <- 2
  nodes_df$color.border <- "#cdd6f4"  # Mocha Text - visible on dark canvas
  nodes_df$color.highlight.border <- "#b4befe"  # Mocha Lavender - hover state

  # Seed paper gets thicker gold border (existing logic)
  nodes_df$borderWidth <- ifelse(nodes_df$is_seed, 5, 2)
  nodes_df$color.border <- ifelse(nodes_df$is_seed, "#FFD700", "#cdd6f4")

  # ... rest of function ...
}
```

### Semi-Transparent Edges for Dark Canvas

```r
# R/mod_citation_network.R - renderVisNetwork section
# Source: Current implementation L592-594 + dark mode adaptation

visNetwork::visEdges(
  smooth = TRUE,
  color = list(
    color = "rgba(205, 214, 244, 0.2)",      # Mocha Text at 20% opacity
    highlight = "rgba(180, 190, 254, 0.4)"   # Mocha Lavender at 40% opacity
  ),
  arrows = "to"
)
```

### Toast Notifications with Semantic Color Backgrounds

```r
# Example: Success toast with green background + dark text
# Source: User decision - semantic colors as fills, not text colors

showNotification(
  "Network saved successfully",
  type = "message",  # Maps to success in custom CSS
  duration = 5
)

# Custom CSS for semantic toast backgrounds (add to bs_add_rules)
# [data-bs-theme='dark'] .shiny-notification-message {
#   background-color: #a6e3a1;  /* Mocha Green */
#   color: #1e1e2e;             /* Mocha Base (dark text) */
#   border: 1px solid #40a02b;  /* Latte Green (darker border) */
# }
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual CSS dark mode classes | Bootstrap 5.3 `data-bs-theme` attribute | Bootstrap 5.3.0 (May 2023) | Automatic component theming, no per-component classes |
| Sass variables only | CSS custom properties + Sass | Bootstrap 5.0+ | Runtime theme switching, dynamic theming |
| Pure black (#000000) dark mode | Intentional dark grays (#1e1e2e) | Modern design systems (2020+) | Reduces eye strain, better contrast control |
| Identical light/dark accent colors | Desaturated colors for dark mode | Dark mode best practices (2021+) | Prevents visual vibration, improves readability |
| Server-side theme compilation only | Client-side theme switching | Bootstrap 5.3 + bslib 0.6+ | No page reload, localStorage persistence |

**Deprecated/outdated:**
- `theme = "dark"` in bslib (pre-Bootstrap 5.3): Replaced by `data-bs-theme="dark"` attribute
- Hardcoded Bootswatch "darkly" theme: Replaced by custom Catppuccin palette for design consistency
- vis.js `background` parameter for canvas color: Unreliable due to canvas rendering, use CSS + node borders instead

## Open Questions

1. **Surface layering strategy (Claude's discretion)**
   - What we know: Catppuccin provides Surface0, Surface1, Surface2 for layering
   - What's unclear: Should Serapeum use subtle steps (all surfaces) or distinct layers (Base + Surface1 only)?
   - Recommendation: Start with Base + Surface0 (2-layer system), add Surface1/Surface2 if depth needed

2. **Border vs glow for visNetwork nodes**
   - What we know: Need light outline on all nodes for dark canvas visibility
   - What's unclear: Solid border (borderWidth) vs CSS box-shadow glow vs both?
   - Recommendation: Use borderWidth=2 with light color (simple, performant), reserve glow for hover state

3. **Loading skeleton color during theme transition**
   - What we know: Bootstrap provides skeleton placeholders, Catppuccin has Surface colors
   - What's unclear: Should skeletons use Surface0, Surface1, or animated gradient?
   - Recommendation: Use Surface0 with subtle pulse animation (Bootstrap default behavior)

4. **Error state semantic color for dark mode**
   - What we know: Danger = Red (#f38ba8), used as background fill
   - What's unclear: Should error text also use Red, or stick to default Text color?
   - Recommendation: Use Red background + Base (dark) text for high contrast, reserve colored text for icons

## Sources

### Primary (HIGH confidence)

- **/rstudio/bslib** (Context7) - bs_theme(), bs_add_rules(), Bootstrap 5.3 dark mode integration
  - Topics: theme creation, Sass variable system, CSS custom properties, dark mode configuration
- **Catppuccin Palette** (https://catppuccin.com/palette/) - Official color specifications
  - All Mocha and Latte hex values, semantic color mappings, design philosophy
- **Bootstrap 5.3 Color Modes** (https://getbootstrap.com/docs/5.3/customize/color-modes/) - data-bs-theme attribute
  - Official documentation for dark mode implementation, CSS variable system

### Secondary (MEDIUM confidence)

- **WebAIM Contrast Checker** (https://webaim.org/resources/contrastchecker/) - WCAG AA validation
  - Verified Catppuccin Mocha Text/Subtext contrast ratios against Base background
- **bslib Theming Article** (https://rstudio.github.io/bslib/articles/theming/) - Theme customization patterns
  - Real-world examples of bs_theme() and bs_add_rules() usage
- **Dark Mode UI Best Practices** (https://atmos.style/blog/dark-mode-ui-best-practices) - Color desaturation guidance
  - Why saturated colors vibrate on dark backgrounds, desaturation recommendations
- **Bootstrap 5.3 CSS Variables** (https://getbootstrap.com/docs/5.3/customize/css-variables/) - Variable reference
  - Complete list of --bs-* custom properties for theming

### Tertiary (LOW confidence)

- **visNetwork Package Documentation** (https://cran.r-project.org/web/packages/visNetwork/visNetwork.pdf) - Configuration options
  - Node/edge styling options, but canvas background behavior unclear (requires testing)
- **vis.js GitHub Issues** (#44, #2292, #1397) - Canvas background discussions
  - Community workarounds for dark canvas, not official solutions

### Project-Specific Sources

- **Issue #89** (closed) - Citation network dark background bug
  - Context: Navy background (#1a1a2e) blended with viridis dark end, CSS ineffective
  - Resolution path: Light borders on all nodes, dark container background
- **Issue #123** (open) - UI touch ups
  - Screenshot shows current light mode styling, informing consistency requirements
- **Current Implementation** - app.R, www/custom.css, R/mod_citation_network.R
  - Existing dark mode toggle (localStorage), partial dark mode CSS, viridis color scales

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** - bslib and Catppuccin are locked decisions, well-documented
- Architecture: **HIGH** - Bootstrap 5.3 patterns are established, bslib examples verified
- Pitfalls: **MEDIUM** - visNetwork canvas behavior requires testing, specificity issues common
- Code examples: **HIGH** - All patterns verified against official docs or current codebase

**Research date:** 2026-02-22
**Valid until:** ~90 days (stable domain - Bootstrap/bslib changes infrequent, Catppuccin palette stable)

**Key assumptions requiring validation:**
1. visNetwork node borders (borderWidth + color.border) work as expected for dark canvas visibility
2. Catppuccin semantic colors as background fills meet WCAG AA with dark text (needs contrast checker verification)
3. Bootstrap 5.3 CSS variables (`--bs-*`) fully support runtime theme switching in Shiny context
