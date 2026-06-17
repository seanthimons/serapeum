---
title: addResourcePath overwrites on repeated slide generation
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
created_at: 2026-03-20T20:06:33Z
updated_at: 2026-03-25T21:44:24Z
---

**Source:** PR #163 review (round 1, item 5)

`addResourcePath("slides_preview", ...)` is called at `mod_slides.R:514,594,686` with different temp directories on each generation. Old directories are orphaned. Should call `removeResourcePath()` before re-adding, or use unique resource path names.

<!-- migrated from beads: `serapeum-1774459567339-182-a7f75a05` | github: https://github.com/seanthimons/serapeum/issues/211 -->
