---
title: Improve inline_figure_data_uris error reporting for missing files
status: todo
type: task
priority: normal
tags:
  - pr-review
  - ui
created_at: 2026-03-21T00:48:43Z
updated_at: 2026-03-25T21:44:25Z
---

From PR #163 review (round 1), item #9:

`inline_figure_data_uris()` in `R/slides.R:816-827` warns when a figure file is missing but leaves the `uuid.png` reference in the QMD. Quarto then fails to render with an unhelpful "file not found" error. Should either remove the broken reference or surface a clear user-facing notification.

<!-- migrated from beads: `serapeum-1774459567511-189-f7e3e630` | github: https://github.com/seanthimons/serapeum/issues/218 -->
