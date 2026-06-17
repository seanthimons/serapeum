---
title: Preserve caption_quality metadata in figure DB insert
status: todo
type: task
priority: normal
tags:
  - db
  - pr-review
created_at: 2026-03-21T00:48:36Z
updated_at: 2026-03-25T21:44:25Z
---

From PR #163 review (round 1), item #7:

`extract_figures_from_pdf()` computes a `caption_quality` column (`R/pdf_extraction.R:207-211`) but `extract_and_describe_figures()` (`R/pdf_images.R:341-352`) doesn't pass it to `db_insert_figure()`. The metadata is silently dropped.

<!-- migrated from beads: `serapeum-1774459567462-187-c83ec446` | github: https://github.com/seanthimons/serapeum/issues/216 -->
