---
title: Add error handling around get_chunks_for_documents() in slide generation
status: todo
type: task
priority: critical
tags:
  - db
  - pr-review
  - server
  - ui
created_at: 2026-03-22T00:22:43Z
updated_at: 2026-03-25T21:44:02Z
parent: sera-yn90
---

**Source:** PR #221 review (round 1, finding #7)

`R/mod_slides.R:1072` — `get_chunks_for_documents(con(), doc_ids)` is called without `tryCatch`. If the DB call throws, the progress notification at line 1071 stays visible forever.

**Fix:** Wrap in `tryCatch()` and clean up the notification on error.

<!-- migrated from beads: `serapeum-1774459567731-198-e5be9755` | github: https://github.com/seanthimons/serapeum/issues/228 -->
