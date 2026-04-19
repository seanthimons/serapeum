---
title: Add error handling for file I/O in pdf_images.R
status: todo
type: task
priority: high
tags:
  - db
  - pr-review
created_at: 2026-03-21T00:48:33Z
updated_at: 2026-03-22T17:15:58Z
parent: sera-yn90
---

From PR #163 review (round 1), items #5-6:

- **`writeBin()` without error handling** (`R/pdf_images.R:53`, `R/pdf_extraction.R:265`) — Raw byte writes to disk can fail silently, producing corrupted/empty PNG files referenced in DB.
- **Missing `dir.create()` success verification** (`R/pdf_images.R:28`) — `dir.create(..., showWarnings = FALSE)` suppresses failure. No check that the directory actually exists before writing files into it.

Both are defensive I/O hardening for the figure save pipeline.

<!-- migrated from beads: `serapeum-1774459567437-186-afe99a61` | github: https://github.com/seanthimons/serapeum/issues/215 -->
