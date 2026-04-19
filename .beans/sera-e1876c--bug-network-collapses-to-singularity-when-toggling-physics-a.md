---
title: "bug: Network collapses to singularity when toggling physics after returning to tab"
status: completed
type: bug
priority: high
created_at: 2026-03-03T03:23:40Z
updated_at: 2026-03-04T17:37:49Z
---

## Problem

When returning to the citation network tab after navigating away (or after the network has been idle), toggling the physics switch causes the entire network to collapse into an extremely tight cluster / singularity. All nodes pile on top of each other, making the visualization unusable.

## Steps to Reproduce

1. Build a citation network (any size)
2. Navigate away from the network tab or let it sit idle
3. Return to the network tab
4. Toggle the physics switch
5. Network collapses into a tight ball

## Expected Behavior

Toggling physics should re-enable node repulsion and spread, not cause collapse. The network should maintain its general layout or re-stabilize to a readable state.

## Screenshot

![singularity](https://github.com/user-attachments/assets/placeholder)

*(Network collapsed to singularity after physics toggle)*

## Complexity / Impact

- **Complexity:** Low (likely a physics parameter or state restoration issue)
- **Impact:** High (completely breaks network usability)

## Files
- `R/mod_citation_network.R` — physics toggle handler and vis.js configuration

<!-- migrated from beads: `serapeum-1774459565716-111-e1876c73` | github: https://github.com/seanthimons/serapeum/issues/131 -->
