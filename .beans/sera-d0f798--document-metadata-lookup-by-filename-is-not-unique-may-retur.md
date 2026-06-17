---
title: Document metadata lookup by filename is not unique — may return wrong author/year
status: todo
type: task
priority: high
tags:
  - pr-review
  - server
created_at: 2026-03-23T19:10:23Z
updated_at: 2026-03-23T19:10:23Z
parent: sera-dv61
---

**Source:** PR #241 Copilot review + Claude review round 1
**Severity:** MEDIUM
**File:** `R/_ragnar.R:1192-1199`

`enrich_retrieval_results()` queries `documents` by `filename` only:
```r
row <- DBI::dbGetQuery(con,
  "SELECT authors, year FROM documents WHERE filename = ? LIMIT 1",
  list(doc_filename))
```

Since `documents.filename` is not unique across notebooks, this can pull authors/year from the wrong document when multiple notebooks contain identical filenames.

**Suggested fix:** Include `notebook_id` in the lookup (requires threading notebook_id through to this function), or use the document `id` encoded in the chunk's `source_id` field instead of filename.

<!-- migrated from beads: `serapeum-1774459568198-218-d0f79861` | github: https://github.com/seanthimons/serapeum/issues/251 -->
