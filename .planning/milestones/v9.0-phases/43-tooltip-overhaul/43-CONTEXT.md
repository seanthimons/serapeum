# Phase 43: Tooltip Overhaul - Context

**Gathered:** 2026-03-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix tooltip containment and dark mode readability in the citation network graph. Tooltips must not escape the graph container or overlap the side panel, and must be clearly readable in dark mode with sufficient contrast. Addresses long-standing issues #79 (containment) and #127 (dark mode contrast).

</domain>

<decisions>
## Implementation Decisions

### Tooltip content
- Display: title, year, first author + "et al." for multi-author papers, citation count
- Fix raw HTML tags currently being displayed as plain text — render as actual HTML
- Fixed max width (e.g., 300px) with text wrapping for long titles
- Citation count is already present in tooltips — keep it

### Tooltip positioning
- Keep default visNetwork tooltip positioning behavior
- When tooltip would overflow the graph container edge, flip to the opposite side of the node
- Tooltips must be contained within the visNetwork graph canvas area — must not overlap the side panel or controls
- Custom JS tooltip via `htmlwidgets::onRender()` is acceptable — CSS overflow/z-index approaches have failed previously

### Dark mode styling
- Match Catppuccin Mocha palette for tooltip colors (surface/text colors consistent with the app's dark theme)
- Dark mode fix only — light mode tooltips are fine as-is
- Subtle border (Catppuccin overlay color) + soft drop shadow to distinguish tooltip from graph background
- Rounded corners matching the app's existing card/component border-radius

### Claude's Discretion
- Exact tooltip offset distance from nodes
- Animation/fade timing (if any)
- Specific Catppuccin color tokens for tooltip background/text/border
- Whether to show tooltips on edges (citation links) in addition to nodes

</decisions>

<specifics>
## Specific Ideas

- Previous CSS overflow/z-index approaches failed for containment — go straight to custom JS tooltip implementation
- Use `htmlwidgets::onRender()` JS callback or `visEvents(hoverNode = ...)` for custom tooltip logic
- Key files: `R/mod_citation_network.R` (tooltip rendering, visNetwork config), `R/theme_catppuccin.R` (dark mode CSS)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 43-tooltip-overhaul*
*Context gathered: 2026-03-03*
