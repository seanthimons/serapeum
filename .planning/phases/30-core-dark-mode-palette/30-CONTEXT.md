# Phase 30: Core Dark Mode Palette - Context

**Gathered:** 2026-02-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish the foundational dark mode color system for Serapeum using the Catppuccin palette. This covers background tones, text contrast, accent colors, semantic color mappings, the centralized overrides file, and fixing the visNetwork white background (issue #89). Component-level styling and UI polish are Phase 31.

</domain>

<decisions>
## Implementation Decisions

### Background tone
- Use **Catppuccin Mocha** (darkest variant) as the dark mode palette
- Use **Catppuccin Latte** as the light mode palette (replacing current light theme for consistency)
- Scope: Mocha/Latte applied to app content area only — browser scrollbars and selection highlights use browser defaults

### Accent palette
- Primary accent: **Lavender** (#b4befe) in Mocha, Latte equivalent in light mode
- Links: **Sapphire** (#74c7ec) to differentiate from primary buttons
- Secondary actions (secondary buttons, de-emphasized links): use **Subtext** colors (subtext0/subtext1)

### Surface layering
- Claude's discretion on layering approach (subtle steps vs distinct layers) based on Catppuccin Mocha conventions

### Borders
- Claude's discretion on border treatment based on readability needs

### Semantic colors
- Standard Catppuccin Mocha mapping: Green (#a6e3a1)=success, Red (#f38ba8)=danger, Yellow (#f9e2af)=warning, Blue (#89b4fa)=info
- **Catppuccin palette purity wins** over strict WCAG AA compliance if they conflict
- Semantic colors used as **background fills with dark text** (not colored text on dark surface)
- Toast notifications: **full colored background** with dark text, not subtle accent borders

### visNetwork citation graph
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

</decisions>

<specifics>
## Specific Ideas

- Full Catppuccin ecosystem: Mocha for dark, Latte for light — both modes should feel like they belong to the same palette family
- Graph tooltip currently shows raw HTML tags (`<b>`, `<br>`) — this is a pre-existing bug tracked separately, NOT in this phase
- User selects viridis color scale from dropdown in settings — the dark mode solution must work across all available scales

</specifics>

<deferred>
## Deferred Ideas

- **Colorblind mode** — alternate color mappings for protanopia/deuteranopia/tritanopia. New capability, its own phase.
- **Tooltip HTML rendering bug** — raw `<b>`/`<br>` tags showing in graph tooltips and paper details panel. Pre-existing bug, not dark-mode-specific. Check TODO.md.

</deferred>

---

*Phase: 30-core-dark-mode-palette*
*Context gathered: 2026-02-22*
