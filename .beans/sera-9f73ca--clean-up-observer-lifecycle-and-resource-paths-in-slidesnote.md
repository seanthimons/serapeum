---
title: Clean up observer lifecycle and resource paths in slides/notebook modules
status: todo
type: task
priority: high
tags:
  - pr-review
  - server
created_at: 2026-03-21T00:48:48Z
updated_at: 2026-03-22T17:15:49Z
parent: sera-cpjh
---

From PR #163 review (round 1), items #10-11:

- **Figure action observers not destroyed** (`R/mod_document_notebook.R:859-861`) — Setting `fig_action_observers[[old_id]] <- NULL` removes the reference but doesn't call `$destroy()`. Old observers persist in memory.
- **`addResourcePath` overwrites** (`R/mod_slides.R:514,594,686`) — `addResourcePath("slides_preview", ...)` called with different temp directories each generation. Old temp directories orphaned without cleanup.

<!-- migrated from beads: `serapeum-1774459567536-190-9f73ca6e` | github: https://github.com/seanthimons/serapeum/issues/219 -->
