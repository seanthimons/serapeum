---
title: "build_latency_sparkline: NA bar heights produce invalid CSS"
status: completed
type: bug
priority: high
created_at: 2026-04-07T17:17:14Z
updated_at: 2026-04-08T16:22:20Z
---

Individual NA rows survive max_ms guard, producing NApx in sprintf. Add bar_heights[is.na(bar_heights)] <- 0 after line 319. GitHub #280

## Resolution

Fixed in 248a55b

<!-- migrated from beads: `serapeum-8kef` -->
