---
title: Adjust network physics to restore rotation for smaller networks
status: completed
type: feature
priority: high
tags:
  - gsd
created_at: 2026-03-03T01:52:32Z
updated_at: 2026-03-04T17:37:47Z
---

## Problem

Larger citation networks exhibited a beautiful orbital rotation/drift effect driven by the forceAtlas2Based solver continuing to run after stabilization. The physics toggle was added to freeze this for multi-seed networks where it gets chaotic, but it also kills the effect for smaller single-seed networks where the rotation looks great.

Currently physics behavior is identical regardless of seed count — parameters only scale by node/edge count. There's no way to preserve the ambient rotation for small networks while freezing large ones.

## Solution

Differentiate post-stabilization physics behavior based on network size or seed count:

- **Single-seed / small networks**: Keep physics enabled after stabilization (let nodes drift/orbit)
- **Multi-seed / large networks**: Auto-freeze after stabilization completes

Key levers to tune:
- `damping` (currently 0.4) — lower = more persistent motion
- `gravitationalConstant` — affects orbital energy
- Whether to call `visPhysics(enabled = FALSE)` after stabilization event
- Could add a vis.js `stabilizationIterationsDone` event handler that conditionally freezes based on seed count
- Consider an "ambient mode" toggle in the legend panel as a user-facing control

## Files
- `R/mod_citation_network.R:567-605`

_Source: GSD todo (area: ui)_

<!-- migrated from beads: `serapeum-1774459565693-110-5b393049` | github: https://github.com/seanthimons/serapeum/issues/130 -->
