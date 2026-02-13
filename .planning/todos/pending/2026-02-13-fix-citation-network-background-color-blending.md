---
created: 2026-02-13T19:12:54.184Z
title: Fix citation network background color blending
area: ui
files:
  - www/custom.css:5
  - R/mod_citation_network.R:408
---

## Problem

The dark navy background (`#1a1a2e`) on the citation network container blends with the dark ends of viridis/magma/plasma/inferno/turbo palettes, making older-year nodes hard to distinguish from the background. Attempted fix with light gray (`#f0f0f0`) on both CSS container and visNetwork `background` parameter, but Bootstrap dark mode overrides and vis.js canvas rendering made the CSS changes ineffective — dark strip persisted at top of container.

Bundle with tooltip overflow issue [#79](https://github.com/seanthimons/serapeum/issues/79) since both are citation network CSS/rendering fixes in the same module.

## Solution

Needs investigation into how vis.js canvas background interacts with Bootstrap dark mode in Shiny. Options:
1. Use visNetwork's `background` param + matching CSS with correct specificity chain
2. Inject inline style via JavaScript after canvas renders
3. Use a neutral near-black (`#1c1c1c`) instead of navy to keep dark theme but remove hue blending
4. Test with `htmlwidgets::onRender()` to set canvas background post-render
