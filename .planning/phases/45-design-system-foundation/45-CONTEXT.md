# Phase 45: Design System Foundation - Context

**Gathered:** 2026-03-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Define semantic color/icon policy and validate with a visual swatch sheet before any UI code changes. This phase documents the design system rules and produces a visual reference — Phase 47 (Sidebar & Button Theming) applies these rules to the actual app UI.

</domain>

<decisions>
## Implementation Decisions

### Semantic color mapping
- **Primary** (main actions: Search, Save, Add to Notebook) = Catppuccin **blue** (Mocha #89b4fa / Latte #1e66f5)
- **Danger** (destructive: delete, remove, clear) = Catppuccin **red** (Mocha #f38ba8 / Latte #d20f39)
- **Success** (confirmations: paper added, export complete) = Catppuccin **green** (Mocha #a6e3a1 / Latte #40a02b)
- **Warning** (cautions: API key missing, rate limit) = Catppuccin **yellow** (Mocha #f9e2af / Latte #df8e1d)
- **Info** (informational: tooltips, help text) = Catppuccin **sapphire** (Mocha #74c7ec / Latte #209fb5)
- **Secondary** (cancel, close, less important) = Catppuccin **surface0/surface1** colors
- **Sidebar active items** = inherit from primary (blue), no separate accent color
- **Peach** = candidate accent for highlights/badges — include in swatch sheet for visual evaluation before committing (concern: may look too similar to warning/yellow)

### Icon system design
- Standardize on **Font Awesome** (already used via `shiny::icon()`)
- Create **semantic wrapper functions** (e.g., `icon_save()`, `icon_delete()`, `icon_search()`) mapping to specific FA icons
- Wrappers live in **R/theme_catppuccin.R** alongside color definitions — all design system code in one file
- Icons are **color-neutral** — wrappers only standardize which icon to use. Color comes from the button/context they're placed in, not the icon itself.

### Swatch sheet format
- **Static HTML file** (not a Shiny module) — viewable without running the app
- **Side-by-side layout**: Latte (light) on left, Mocha (dark) on right for simultaneous comparison
- **Comprehensive scope**: buttons (all variants), badges, sidebar items, alerts, form inputs, cards, icons
- **Both raw palette and semantic**: top section shows all Catppuccin colors with hex values, bottom section shows semantic components using those colors

### Button variant policy
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

</decisions>

<specifics>
## Specific Ideas

- Peach accent needs visual evaluation in the swatch — user concerned it may look too similar to warning yellow. Include both peach and yellow side-by-side in the swatch so the difference (or lack thereof) is immediately visible.
- The swatch sheet is a gate: user validates it before any UI code changes happen in Phase 47.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 45-design-system-foundation*
*Context gathered: 2026-03-04*
