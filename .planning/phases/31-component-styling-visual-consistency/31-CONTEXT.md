# Phase 31: Component Styling & Visual Consistency - Context

**Gathered:** 2026-02-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Ensure all components use Bootstrap CSS variables and achieve visual consistency across the app. This includes migrating hardcoded hex colors to CSS variables or Catppuccin constants, fixing dark mode rendering for all Bootstrap components (cards, buttons, forms, modals, toasts, badges), harmonizing interactive states for WCAG compliance, applying consistent spacing/typography, and resolving issue #123 UI touch ups. The Catppuccin palette foundation from Phase 30 is established — this phase applies it across all components.

</domain>

<decisions>
## Implementation Decisions

### Hardcoded color migration
- Replace all remaining #6366f1 (old indigo primary) references with LATTE$lavender or var(--bs-primary) as appropriate
- In R code that generates HTML/CSS inline: use LATTE$/MOCHA$ constants from theme_catppuccin.R
- In static CSS files: prefer var(--bs-*) Bootstrap variables which auto-switch with theme
- For ggplot2 chart colors (e.g., year histogram in search notebook): use LATTE$lavender directly since ggplot doesn't read CSS variables
- For viridis palette strings in citation network: keep as-is (viridis is a data visualization palette, not a UI color)

### Component dark mode coverage
- Audit all modules for dark mode rendering: modals, cards, badges, form inputs, dropdowns, toasts, progress bars
- Bootstrap 5.3 components that inherit from CSS variables should "just work" after Phase 30 — verify, don't rewrite
- Custom-styled components (badges with inline style=, custom hover effects) need explicit dark mode attention
- The dissertation badge (bg-purple with inline style) needs dark mode variant
- Shiny notification toasts are already handled by catppuccin_dark_css() — verify they render correctly

### Interactive states (hover, focus, disabled)
- All hover/focus states must meet WCAG AA contrast (3:1 for large text, 4.5:1 for normal)
- Use Bootstrap's built-in focus ring (--bs-focus-ring-*) rather than custom focus styles
- Disabled states should use Mocha overlay0 (#6c7086) for muted appearance in dark mode
- Hover backgrounds should use rgba with low opacity (existing pattern from hover-bg-light)

### Spacing and typography consistency
- Follow 8pt grid for spacing (0.5rem = 4px, 1rem = 8px base in Bootstrap)
- Audit for inconsistent padding/margins across views
- Typography: ensure heading hierarchy (h1-h6) is consistent across all modules
- Line-height: use Bootstrap defaults (1.5 for body text)

### About page harmonization (UIPX-05)
- About page should use the same card-based layout patterns as other views
- Match padding and spacing with settings page
- Ensure all links and badges use theme-aware colors

### Claude's Discretion
- Exact order of component audit (can prioritize by visual impact)
- Whether to create a dedicated dark-mode-fixes.css or extend catppuccin_dark_css()
- Minor spacing adjustments within the 8pt grid framework
- Whether to refactor inline styles to CSS classes (if scope is small)

</decisions>

<specifics>
## Specific Ideas

- Issue #123 is a screenshot showing UI touch ups needed — review the screenshot for specific items
- The cost tracker module still uses #6366f1 for chart colors — needs Catppuccin lavender
- Search notebook year histogram uses #6366f1 fill — needs Catppuccin lavender
- Extend catppuccin_dark_css() in theme_catppuccin.R for any new dark overrides (keep centralized per DARK-05)
- All dark mode CSS should flow through the existing bs_add_rules() injection pattern, not scattered inline styles

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 31-component-styling-visual-consistency*
*Context gathered: 2026-02-22*
