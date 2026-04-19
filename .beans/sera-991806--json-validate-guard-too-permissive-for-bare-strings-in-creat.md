---
title: JSON validate() guard too permissive for bare strings in create_abstract()
status: todo
type: task
priority: high
tags:
  - db
  - pr-review
created_at: 2026-03-23T18:59:33Z
updated_at: 2026-03-23T19:01:27Z
parent: sera-dv61
---

**Source:** PR #241 review (round 1)
**Severity:** MEDIUM
**File:** `R/db.R:611-612`

`jsonlite::validate(authors)` returns TRUE for valid JSON primitives like `'"Smith"'`. If a single author name is somehow wrapped in quotes, it would pass through without array encoding.

**Suggested fix:** Tighten to also check for array/object prefix: `grepl("^\s*[\[\{]", authors) && jsonlite::validate(authors)`.

<!-- migrated from beads: `serapeum-1774459568035-211-9918067e` | github: https://github.com/seanthimons/serapeum/issues/244 -->
