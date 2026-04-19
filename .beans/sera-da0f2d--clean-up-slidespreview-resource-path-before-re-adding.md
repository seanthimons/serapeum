---
title: Clean up slides_preview resource path before re-adding
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
created_at: 2026-03-22T00:22:41Z
updated_at: 2026-03-25T21:44:28Z
---

**Source:** PR #221 review (round 1, finding #6)

`R/mod_slides.R:1141, 1221, 1312` — `addResourcePath("slides_preview", ...)` is called without first removing the existing path. Each generation/heal cycle adds a new resource path pointing to potentially stale temp directories.

**Fix:** Call `removeResourcePath("slides_preview")` before each `addResourcePath()`.

<!-- migrated from beads: `serapeum-1774459567708-197-da0f2d9e` | github: https://github.com/seanthimons/serapeum/issues/227 -->
