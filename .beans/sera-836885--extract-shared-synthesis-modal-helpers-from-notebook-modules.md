---
title: Extract shared synthesis modal helpers from notebook modules
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
  - ui
created_at: 2026-03-20T17:09:32Z
updated_at: 2026-03-25T21:44:20Z
---

**Source:** PR #156 review (round 1, item 3)

## Problem

`show_synthesis_modal()` and `update_synthesis_status()` are identical copy-paste between `R/mod_document_notebook.R` (lines 947-967) and `R/mod_search_notebook.R` (lines 472-492). If the modal layout or JS message name changes, both must be updated in sync.

## Suggested Fix

Extract both helpers to a shared utility (e.g., `R/utils_synthesis.R`) or a small helper module that both notebook modules can call. The functions take `ns` and `session` from the calling context, so they'd need those passed as parameters.

<!-- migrated from beads: `serapeum-1774459567101-172-836885dc` | github: https://github.com/seanthimons/serapeum/issues/201 -->
