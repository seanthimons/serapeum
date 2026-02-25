# Architecture Research — Dark Mode Integration

**Domain:** R/Shiny/bslib dark mode redesign
**Researched:** 2026-02-22
**Confidence:** HIGH

## Existing Architecture Overview

### Current Theme Implementation

```
┌─────────────────────────────────────────────────────────────────┐
│                      JavaScript Layer                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ localStorage theme persistence + dark_mode_toggle button │   │
│  │ Manual data-bs-theme attribute manipulation              │   │
│  └────────────────────┬─────────────────────────────────────┘   │
├───────────────────────┼──────────────────────────────────────────┤
│                  bslib Theme Layer                               │
│  ┌────────────────────┴─────────────────────────────────────┐   │
│  │ bs_theme(preset = "shiny", primary = "#6366f1", ...)     │   │
│  │ Generates Bootstrap 5 CSS with Sass variables            │   │
│  └────────────────────┬─────────────────────────────────────┘   │
├───────────────────────┼──────────────────────────────────────────┤
│                   CSS Layer                                      │
│  ┌────────────────────┴─────────────────────────────────────┐   │
│  │ Inline <style> in app.R (chat markdown, lit review)      │   │
│  │ www/custom.css (citation network, hover effects)         │   │
│  │ [data-bs-theme='dark'] selectors for component overrides│   │
│  └────────────────────┬─────────────────────────────────────┘   │
├───────────────────────┼──────────────────────────────────────────┤
│              Third-Party Widget Layer                            │
│  ┌────────────────────┴─────────────────────────────────────┐   │
│  │ visNetwork (citation graphs) — canvas-based rendering    │   │
│  │ No DT tables currently used                              │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Current Implementation |
|-----------|----------------|------------------------|
| **app.R theme** | Global theme definition | `bs_theme(preset = "shiny", primary = "#6366f1", "border-radius" = "0.5rem")` |
| **Inline styles** | Component-specific overrides | `<style>` tag in `tags$head()` for chat markdown, lit review table |
| **www/custom.css** | Feature-specific styling | Citation network container, legend, hover effects |
| **JavaScript toggle** | Manual theme switching | `setAttribute('data-bs-theme', next)` + localStorage persistence |
| **visNetwork** | Graph visualization | Configured via R options, canvas rendering not CSS-styleable |

## Recommended Dark Mode Architecture

### Integration Points with Existing bslib Theme

#### 1. Keep Existing JavaScript Toggle (No Changes Needed)

**Current pattern (working correctly):**
```javascript
// In app.R — already implemented
const html = document.documentElement;
const current = html.getAttribute('data-bs-theme');
const next = current === 'dark' ? 'light' : 'dark';
html.setAttribute('data-bs-theme', next);
localStorage.setItem('theme', next);
```

**Why keep it:** Bootstrap 5.3 uses `data-bs-theme` attribute on `<html>` for global dark mode. Serapeum's manual toggle is the standard approach when you don't need reactive server-side theme switching.

**Integration point:** No action required. Existing toggle will activate all CSS custom property changes.

#### 2. Enhance bs_theme() with Dark Mode Variables

**Current:**
```r
bs_theme(
  preset = "shiny",
  primary = "#6366f1",
  "border-radius" = "0.5rem"
)
```

**Recommended:**
```r
bs_theme(
  preset = "shiny",
  version = 5,  # Explicit Bootstrap 5 (required for dark mode)
  primary = "#6366f1",
  "border-radius" = "0.5rem"
) |>
  bs_add_rules(sass::sass_file("www/dark-mode-overrides.scss"))
```

**Why:** bslib doesn't expose CSS custom properties directly via `bs_theme()`. Instead, use `bs_add_rules()` to inject Sass/CSS that references Bootstrap variables and creates dark mode overrides.

**Integration point:** Modify `app.R` theme definition. New file: `www/dark-mode-overrides.scss`.

#### 3. CSS Custom Properties Location Strategy

**Where CSS lives:**

| Scope | Location | Purpose |
|-------|----------|---------|
| **Global dark mode palette** | `www/dark-mode-overrides.scss` | Redefine Bootstrap CSS vars under `[data-bs-theme='dark']` |
| **Component-specific dark styles** | Inline `<style>` in `app.R` (existing) | Chat markdown tables, lit review frozen column |
| **Feature-specific dark styles** | `www/custom.css` (existing, extend) | Citation network, hover effects, widget containers |

**Rationale:**
- Global palette centralized in Sass file → easy to maintain, can use Bootstrap mixins
- Inline styles already used for component overrides → keep pattern for consistency
- custom.css already has dark mode selectors → extend existing file, don't fragment

**Integration point:** Create new `www/dark-mode-overrides.scss`, extend existing `www/custom.css`.

#### 4. Component-Level Dark Mode Override Pattern

**Current pattern (already working):**
```css
/* www/custom.css */
[data-bs-theme="dark"] .citation-network-legend {
  background-color: rgba(30, 30, 46, 0.95);
  color: #e0e0e0;
}
```

**Recommended pattern (use Bootstrap CSS vars):**
```css
/* www/custom.css or www/dark-mode-overrides.scss */
[data-bs-theme="dark"] .citation-network-legend {
  background-color: var(--bs-dark-bg-subtle);
  color: var(--bs-emphasis-color);
  border-color: var(--bs-border-color);
}
```

**Why:** Using Bootstrap CSS vars (`--bs-*`) ensures consistency with global theme and makes palette adjustments easier (change once, apply everywhere).

**Integration point:** Refactor existing `[data-bs-theme="dark"]` selectors in `www/custom.css` to use Bootstrap CSS vars.

### Third-Party Widget Styling (visNetwork)

#### Challenge: Canvas Elements Don't Respond to CSS

visNetwork uses HTML5 Canvas for graph rendering. CSS custom properties don't affect canvas content — you must configure colors via JavaScript options.

**Current approach (already implemented):**
```r
# In mod_citation_network.R
visNetwork(nodes, edges) |>
  visNodes(
    color = list(
      background = node_colors,  # Computed in R
      border = "#2b3035",        # Hardcoded
      highlight = list(background = "#ffc107", border = "#333")
    )
  ) |>
  visEdges(color = list(color = "#999", highlight = "#333"))
```

**Problem:** Hardcoded colors don't respond to theme changes. `#2b3035` is dark mode color, won't work in light mode.

**Recommended solution:**

1. **Detect current theme on network render:**
```r
# In mod_citation_network.R server function
observe({
  # Get current theme from JavaScript
  session$sendCustomMessage("getCurrentTheme", list(
    id = session$ns("current_theme")
  ))
})

# Use theme-aware colors
current_theme <- reactive(input$current_theme)  # From JS message

node_border_color <- reactive({
  if (current_theme() == "dark") "#999" else "#333"
})
```

2. **Alternative (simpler): Container background only**

Wrap visNetwork in a themed container (already done):
```css
/* www/custom.css — already exists */
.citation-network-container {
  background-color: #e8e8ee;  /* Light mode */
}

[data-bs-theme="dark"] .citation-network-container {
  background-color: #1e1e2e;  /* Dark mode */
}
```

**Recommendation:** Keep container background approach (already working). For node/edge colors, use neutral grays that work in both modes, or make palette selection (already implemented) more opinionated per theme.

**Integration point:** Adjust visNetwork color defaults in `R/citation_network.R` to neutral values. Rely on container background for theme consistency.

## Data Flow for Theme Switching

### User Interaction Flow

```
[User clicks toggle]
    ↓
[JavaScript: setAttribute('data-bs-theme', 'dark')]
    ↓
[localStorage.setItem('theme', 'dark')]
    ↓
[CSS cascade applies [data-bs-theme="dark"] selectors]
    ↓
[Bootstrap CSS vars update (--bs-body-bg, --bs-body-color, etc.)]
    ↓
[Component styles using CSS vars auto-update]
    ↓
[visNetwork canvas: NO auto-update — container background changes only]
```

### Page Load Flow

```
[DOMContentLoaded]
    ↓
[JavaScript: const saved = localStorage.getItem('theme')]
    ↓
[If saved exists: setAttribute('data-bs-theme', saved)]
    ↓
[Update toggle button icon (sun/moon)]
    ↓
[CSS cascade applies saved theme]
```

**Integration point:** No changes needed. Existing flow works correctly.

## Architectural Patterns

### Pattern 1: Bootstrap CSS Custom Properties

**What:** Use Bootstrap 5.3 CSS variables for all color/spacing references instead of hardcoded hex values.

**When to use:** Any component style that should respond to theme changes.

**Trade-offs:**
- **Pro:** Automatic theme consistency, easier palette changes, fewer selectors
- **Pro:** Works with Bootstrap's semantic color system (primary, success, danger, etc.)
- **Con:** Requires Bootstrap 5.3+ (already using it)
- **Con:** Not all properties have CSS vars (borders, some shadows)

**Example:**
```scss
// BEFORE (hardcoded)
.my-card {
  background: #ffffff;
  color: #333333;
  border: 1px solid #dee2e6;
}

[data-bs-theme="dark"] .my-card {
  background: #1e1e2e;
  color: #e0e0e0;
  border: 1px solid #495057;
}

// AFTER (CSS vars)
.my-card {
  background: var(--bs-body-bg);
  color: var(--bs-body-color);
  border: 1px solid var(--bs-border-color);
}
// Dark mode: no additional selector needed!
```

### Pattern 2: Sass Mixin for Complex Dark Mode Rules

**What:** Use Bootstrap's `color-mode()` Sass mixin for scoped dark mode styles.

**When to use:** Component-level overrides that need to reference Sass variables (not just CSS vars).

**Trade-offs:**
- **Pro:** Can use Sass color functions (lighten, darken, mix)
- **Pro:** Cleaner syntax than manual `[data-bs-theme="dark"]` selectors
- **Con:** Requires Sass compilation (bslib already does this)
- **Con:** Not needed for simple color swaps (Pattern 1 is simpler)

**Example:**
```scss
// In www/dark-mode-overrides.scss
@include color-mode(dark) {
  .citation-network-legend {
    background-color: rgba($dark, 0.95);
    box-shadow: 0 2px 8px rgba($black, 0.3);
  }
}

// Compiles to:
[data-bs-theme=dark] .citation-network-legend {
  background-color: rgba(33, 37, 41, 0.95);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
}
```

### Pattern 3: Progressive Enhancement for Third-Party Widgets

**What:** Style widget *containers* with dark mode CSS, accept that canvas content may not fully adapt.

**When to use:** Canvas-based widgets (visNetwork, plotly, etc.) where you don't control rendering.

**Trade-offs:**
- **Pro:** Simple, no JavaScript plumbing required
- **Pro:** Provides visual consistency via background/border theming
- **Con:** Widget content may not match theme perfectly
- **Con:** Requires careful color choices for widget content (neutral grays)

**Example:**
```css
/* Container responds to theme */
.citation-network-container {
  background-color: var(--bs-light-bg-subtle);
  border: 1px solid var(--bs-border-color);
}

[data-bs-theme="dark"] .citation-network-container {
  background-color: var(--bs-dark-bg-subtle);
}

/* Widget uses neutral colors that work in both themes */
visNetwork(nodes, edges) |>
  visNodes(color = list(border = "#6c757d"))  /* Bootstrap gray-600 */
```

## Build Order Considerations

### Phase Dependencies

**Sequential (must be ordered):**

1. **Global palette redesign** (`www/dark-mode-overrides.scss`)
   - Define new dark mode CSS variable values
   - Test with existing components before touching component CSS
   - Dependency: None (can start immediately)

2. **Component-level refactoring** (`www/custom.css`, inline styles)
   - Replace hardcoded colors with CSS vars
   - Dependency: Global palette must be defined first
   - Rationale: Need stable var values to reference

3. **Third-party widget adjustments** (visNetwork colors)
   - Adjust node/edge defaults to neutral values
   - Dependency: Can happen in parallel with (2), but test after global palette
   - Rationale: Need to see widget against new background colors

**Parallel (can happen simultaneously):**

- **UI polish** (badges, toasts, modals) — independent of dark mode palette
- **Testing/QA** — can start as soon as global palette exists

### Suggested Build Order

```
Phase 1: Foundation
├─ Create www/dark-mode-overrides.scss
├─ Define Bootstrap CSS var overrides for dark mode
├─ Inject via bs_add_rules() in app.R
└─ Test: Does toggle switch affect background/text colors?

Phase 2: Component Integration
├─ Refactor www/custom.css to use CSS vars
├─ Refactor inline <style> in app.R to use CSS vars
├─ Test each component: citation network, chat UI, settings
└─ Dependency: Phase 1 complete

Phase 3: Widget Adjustments
├─ Review visNetwork color defaults
├─ Replace hardcoded theme-specific colors with neutrals
├─ Test: Graph readable in both light/dark modes?
└─ Dependency: Phase 1 complete (can overlap with Phase 2)

Phase 4: Polish & QA
├─ Contrast ratio testing (WCAG AA compliance)
├─ Color palette consistency review
├─ Test all modules in both modes
└─ Dependency: Phases 1-3 complete
```

## Anti-Patterns

### Anti-Pattern 1: Duplicate Color Definitions

**What people do:** Define dark mode colors in multiple places (Sass vars, CSS vars, inline styles).

**Why it's wrong:** Changes require updating multiple files. Easy to miss one and create inconsistency.

**Do this instead:**
- Define dark mode palette ONCE in `www/dark-mode-overrides.scss`
- All other CSS references Bootstrap CSS vars (`--bs-body-bg`, etc.)
- Inline styles use CSS vars, not hardcoded colors

### Anti-Pattern 2: Theme-Specific Class Names

**What people do:** Add `.dark-mode` classes to elements and toggle them with JavaScript.

**Why it's wrong:** Fights against Bootstrap's built-in `data-bs-theme` system. Creates maintenance burden.

**Do this instead:**
- Use `[data-bs-theme="dark"]` CSS selectors
- Let Bootstrap's attribute cascade handle theme switching
- No JavaScript class manipulation needed

### Anti-Pattern 3: Server-Side Theme Switching for Static Themes

**What people do:** Use `session$setCurrentTheme()` to switch themes reactively.

**Why it's wrong:** Adds server round-trip latency. Overkill for simple light/dark toggle.

**Do this instead:**
- Client-side toggle (already implemented) for instant feedback
- `session$setCurrentTheme()` only needed for dynamic theme *generation* (e.g., user-customized palettes)

### Anti-Pattern 4: Styling Canvas Content with CSS

**What people do:** Try to use `[data-bs-theme="dark"]` selectors to change visNetwork node colors.

**Why it's wrong:** Canvas elements don't respond to CSS. Wasted effort.

**Do this instead:**
- Style *container* background/borders with CSS
- Pass theme-aware colors via JavaScript options (or use neutral defaults)
- Accept that canvas content has limited theme integration

## Integration Points Summary

### New Files Needed

| File | Purpose | Contents |
|------|---------|----------|
| `www/dark-mode-overrides.scss` | Global dark mode palette | Bootstrap CSS var redefinitions under `[data-bs-theme="dark"]` |

### Modified Files

| File | Changes | Why |
|------|---------|-----|
| `app.R` | Add `bs_add_rules(sass::sass_file("www/dark-mode-overrides.scss"))` | Inject dark mode Sass |
| `www/custom.css` | Replace hardcoded colors with CSS vars | Theme-responsive component styles |
| `R/citation_network.R` | Adjust visNetwork color defaults to neutrals | Better light/dark compatibility |

### No Changes Needed

| Component | Reason |
|-----------|--------|
| JavaScript toggle | Already correctly using `data-bs-theme` attribute |
| localStorage persistence | Already working |
| Shiny modules | CSS changes only, no R code changes required |

## Sources

**HIGH Confidence:**
- [Bootstrap v5.3 Color Modes Documentation](https://getbootstrap.com/docs/5.3/customize/color-modes/) — Official Bootstrap docs on CSS custom properties and `data-bs-theme`
- [bslib Theming Guide](https://rstudio.github.io/bslib/articles/theming/index.html) — Official bslib docs on `bs_theme()` and `bs_add_rules()`
- [bslib Dark Mode Implementation](https://github.com/rstudio/bslib/blob/main/R/input-dark-mode.R) — Source code for bslib's dark mode toggle

**MEDIUM Confidence:**
- [visNetwork Shiny Integration](https://datastorm-open.github.io/visNetwork/shiny.html) — Official docs on visNetwork styling options
- [DataTables Dark Mode](https://datatables.net/manual/styling/dark-mode) — Official DT dark mode docs (not currently used, but reference for future)

**LOW Confidence:**
- WebSearch results on htmlwidgets dark mode — general guidance, not Serapeum-specific

---
*Architecture research for: Serapeum v6.0 Dark Mode Redesign*
*Researched: 2026-02-22*
