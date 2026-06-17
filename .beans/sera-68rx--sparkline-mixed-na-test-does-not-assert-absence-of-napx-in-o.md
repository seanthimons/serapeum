---
title: Sparkline mixed-NA test does not assert absence of NApx in output
status: completed
type: task
priority: high
created_at: 2026-04-07T17:17:18Z
updated_at: 2026-04-08T16:22:20Z
---

Mixed-NA test confirms non-null and correct class but misses CSS defect. Add expect_false(grepl('NApx', as.character(result))). GitHub #281

## Resolution

Fixed in 248a55b

<!-- migrated from beads: `serapeum-68rx` -->
