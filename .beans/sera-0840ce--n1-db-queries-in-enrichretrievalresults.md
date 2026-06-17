---
title: N+1 DB queries in enrich_retrieval_results()
status: todo
type: task
priority: critical
tags:
  - db
  - performance
  - pr-review
  - server
created_at: 2026-03-23T18:59:29Z
updated_at: 2026-03-25T21:44:03Z
parent: sera-dv61
---

**Source:** PR #241 review (round 1)
**Severity:** MEDIUM
**File:** `R/_ragnar.R:1165-1200`

The loop makes individual `SELECT` queries per row (one for abstracts, one for documents). For a retrieval with 20+ chunks, this fires 20+ separate queries.

**Suggested fix:** Batch into a single query per source type using `WHERE id IN (...)` for abstracts and `WHERE filename IN (...)` for documents, then join results back to the dataframe.

<!-- migrated from beads: `serapeum-1774459567984-209-0840ce02` | github: https://github.com/seanthimons/serapeum/issues/242 -->
