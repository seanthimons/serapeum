# Phase 31: Component Styling & Visual Consistency - Research

**Researched:** 2026-02-22
**Domain:** Bootstrap 5.3 dark mode component styling in R/Shiny/bslib
**Confidence:** HIGH

## Current State Audit

### Hardcoded Colors Found

| File | Line | Color | Context | Fix |
|------|------|-------|---------|-----|
| mod_cost_tracker.R | 186 | #6366f1 | barplot col (base R) | LATTE$lavender |
| mod_search_notebook.R | 846 | #6366f1 | ggplot geom_col fill | LATTE$lavender |
| mod_search_notebook.R | 666 | #6f42c1 | dissertation badge inline style | Use Bootstrap class or Catppuccin |
| mod_citation_network.R | 341 | viridis hex string | Data viz palette display | KEEP (viridis is data palette, not UI) |

### var(--bs-light) Usage

Two files use `var(--bs-light)`:
- mod_document_notebook.R:127 — chat area background
- mod_search_notebook.R:280 — search area background

In Bootstrap 5.3 dark mode, `--bs-light` stays light-colored. These should use `var(--bs-tertiary-bg)` instead for theme-aware behavior.

### About Page Issues (UIPX-05)

- `btn-outline-dark` GitHub button class inverts poorly in dark mode (dark outline on dark bg)
- Package logos use external URLs — no dark mode issue but broken images show no alt fallback
- Layout is mostly clean — uses Bootstrap utility classes correctly
- Needs: theme-aware GitHub button, consistent card patterns with settings page

### Component Dark Mode Coverage

**Bootstrap components that auto-adapt** (via CSS variables from Phase 30):
- Cards (--bs-card-bg, --bs-card-border-color)
- Buttons (btn-primary, btn-outline-primary inherit --bs-primary)
- Form inputs (handled in catppuccin_dark_css())
- Modals (inherit --bs-body-bg, --bs-body-color)
- Alerts (inherit semantic colors)
- Progress bars (inherit semantic colors)

**Components needing manual attention:**
- `bg-light` class — stays light in dark mode; use `bg-body-secondary` or `bg-body-tertiary` instead
- `bg-purple` custom class with inline style — needs dark mode variant
- `text-dark` class — may have low contrast in dark mode
- `btn-outline-dark` — inverts poorly (dark border on dark background)
- Base R plots (barplot in cost tracker) — need theme-aware colors
- ggplot charts — need LATTE$lavender instead of hardcoded indigo

### Interactive States

Bootstrap 5.3 handles focus rings via `--bs-focus-ring-color` which inherits from `--bs-primary-rgb`. Since Phase 30 set `--bs-primary-rgb` to Mocha Lavender in dark mode, focus rings should auto-adapt.

Hover states using `hover-bg-light` class already work (set in custom.css).

### Spacing/Typography

The app uses Bootstrap utility classes consistently (py-2, px-2, mb-2, etc.). No major spacing inconsistencies found during audit. Typography uses Bootstrap defaults.

## Implementation Approach

### Plan Structure (2 plans, 2 waves)

**Plan 01 (Wave 1): Hardcoded color migration + component dark mode fixes**
- Replace #6366f1 in cost tracker and search notebook with LATTE$lavender
- Replace #6f42c1 dissertation badge with theme-aware solution
- Replace var(--bs-light) with var(--bs-tertiary-bg)
- Fix btn-outline-dark on about page
- Add dark mode overrides to catppuccin_dark_css() for any remaining components
- Extend centralized CSS for bg-light overrides

**Plan 02 (Wave 2): About page harmonization + spacing/typography audit**
- Harmonize about page layout with app patterns
- Audit spacing consistency across views
- Verify interactive states meet WCAG
- Final verification of all components in both themes

### Technical Patterns

1. **R plot colors**: Use LATTE$ constants directly (base R plots don't read CSS variables)
2. **ggplot colors**: Use LATTE$ constants (same reason)
3. **CSS class fixes**: Replace `bg-light` with `bg-body-secondary`, `text-dark` with `text-body`
4. **Inline styles**: Replace hardcoded hex with var(--bs-*) or remove if Bootstrap class exists
5. **Centralization**: All new dark overrides go into catppuccin_dark_css() per DARK-05

## Key Risks

- **Low risk**: Bootstrap 5.3 components mostly auto-adapt via CSS variables
- **Medium risk**: base R plots (barplot) can't use CSS variables — need R-side theme detection or fixed Latte color
- **Low risk**: External logo images on about page may not load — just cosmetic

---
*Phase: 31-component-styling-visual-consistency*
*Researched: 2026-02-22*
