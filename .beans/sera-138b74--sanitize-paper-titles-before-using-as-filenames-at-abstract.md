---
title: Sanitize paper titles before using as filenames at abstract import time
status: todo
type: task
priority: high
tags:
  - pr-review
  - pre-existing
  - server
created_at: 2026-03-23T16:57:21Z
updated_at: 2026-03-23T16:57:21Z
parent: sera-dv61
---

**Source:** PR #237 review (round 1) — pre-existing issue
**Severity:** MEDIUM
**File:** `R/mod_search_notebook.R:3113`

`paste0(abs$title, ".txt")` stores raw paper titles as filenames without sanitization. Academic paper titles routinely contain characters that are invalid in Windows filenames (`:`, `/`, `?`, `*`, `"`, `<`, `>`, `|`). This causes silent file creation failures on Windows and broken download URLs.

Discovered during PR #237 review — this predates the PR.

**Suggested fix:** Create a `sanitize_filename()` helper and apply it at import time:
```r
sanitize_filename <- function(name) gsub('[/:*?"<>|\\]', "_", name)
# In mod_search_notebook.R:3113
paste0(sanitize_filename(abs$title), ".txt")
```
Also backfill existing documents with unsanitized filenames via a migration or one-time cleanup.

<!-- migrated from beads: `serapeum-1774459567961-208-138b744f` | github: https://github.com/seanthimons/serapeum/issues/240 -->
