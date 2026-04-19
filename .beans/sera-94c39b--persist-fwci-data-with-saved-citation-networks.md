---
title: Persist FWCI data with saved citation networks
status: todo
type: feature
priority: high
tags:
  - pr-review
  - server
  - ui
created_at: 2026-03-19T17:43:59Z
updated_at: 2026-03-22T17:16:05Z
parent: sera-c879
---

**Source:** PR #168 review (Copilot comment)

FWCI data from OpenAlex is available on network nodes at build time, but the network persistence layer doesn't store it. After saving and reloading a network, FWCI-based sizing and tooltip lines are lost.

**Fix:** Include `fwci` in the network node serialization/deserialization pipeline so FWCI sizing and tooltips survive save/load cycles.

**Files:** `R/db.R` (network save/load), `R/citation_network.R` (node schema)

<!-- migrated from beads: `serapeum-1774459566373-141-94c39b9b` | github: https://github.com/seanthimons/serapeum/issues/170 -->
