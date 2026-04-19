---
title: Cached .txt download files not refreshed if abstract is edited
status: todo
type: task
priority: high
tags:
  - db
  - pr-review
created_at: 2026-03-23T16:57:16Z
updated_at: 2026-03-23T16:57:16Z
parent: sera-dv61
---

**Source:** PR #237 review (round 1)
**Severity:** LOW
**File:** `R/mod_document_notebook.R:664`

The `!file.exists(txt_path)` guard prevents overwriting cached text files. If a document's abstract were edited in the DB, the on-disk `.txt` file would remain stale. Acceptable if abstract editing is not a current workflow.

**Suggested fix:** Compare content or always overwrite (the write is cheap for small text files).

<!-- migrated from beads: `serapeum-1774459567942-207-ec047862` | github: https://github.com/seanthimons/serapeum/issues/239 -->
