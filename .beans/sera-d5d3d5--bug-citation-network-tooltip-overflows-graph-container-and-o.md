---
title: "bug: Citation network tooltip overflows graph container and overlaps side panel"
status: completed
type: bug
priority: high
created_at: 2026-02-12T19:07:06Z
updated_at: 2026-03-04T17:37:34Z
---

## Description

In the citation network visualization (Phase 12), visNetwork hover tooltips escape the graph area boundary and overlap the paper details side panel when a node near the right edge is hovered.

## Steps to Reproduce

1. Open Citation Network view
2. Build a network (any settings)
3. Click a node to open the side panel (paper details)
4. Hover over a node near the right edge of the graph
5. Tooltip renders on top of / underneath the side panel

## Expected Behavior

Tooltips should stay contained within the graph area and not overlap the side panel.

## Attempted Fixes

- `overflow: hidden` on container — clips tooltip but doesn't fully solve edge cases
- `position: fixed` with high z-index — breaks tooltip positioning entirely
- `overflow: visible` — tooltip escapes graph boundary

## Technical Context

- visNetwork renders tooltips as absolutely-positioned divs inside the vis-network canvas
- The graph (col-8) and side panel (col-4) are in a `layout_columns` row
- CSS stacking context and overflow clipping interact poorly with visNetwork's tooltip system

## Possible Approaches

- Custom tooltip implementation via `htmlwidgets::onRender()` JS callback instead of native vis.js tooltips
- Use `visEvents(hoverNode = ...)` to show a Shiny-rendered tooltip div positioned manually
- Investigate vis.js tooltip configuration options for containment

## Labels

- `bug`
- `ui`
- `citation-network`

<!-- migrated from beads: `serapeum-1774459564705-64-d5d3d5cb` | github: https://github.com/seanthimons/serapeum/issues/79 -->
