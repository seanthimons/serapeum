---
title: Add error handling to save_prompt_version()
status: todo
type: task
priority: critical
tags:
  - db
  - pr-review
  - server
  - ui
created_at: 2026-03-22T00:22:40Z
updated_at: 2026-03-25T21:44:01Z
parent: sera-yn90
---

**Source:** PR #221 review (round 1, finding #5)

`R/prompt_helpers.R:194-201` — `save_prompt_version()` calls `DBI::dbExecute()` without `tryCatch`. If the DB is locked or connection breaks, users get an unhandled exception in the settings modal.

**Fix:** Wrap in `tryCatch()` and return a meaningful error to the UI.

<!-- migrated from beads: `serapeum-1774459567682-196-b0cfacf1` | github: https://github.com/seanthimons/serapeum/issues/226 -->
