---
title: "Search notebook: error toast appears behind synthesis modal on API failure"
status: todo
type: task
priority: critical
tags:
  - pr-review
  - server
  - ui
created_at: 2026-03-20T17:09:28Z
updated_at: 2026-03-25T21:43:57Z
parent: sera-cpjh
---

**Source:** PR #156 review (round 1, item 2)

## Problem

In `R/mod_search_notebook.R`, when a synthesis preset (overview, conclusions, research questions) hits an API error, `show_error_toast()` fires while the synthesis modal is still open. The toast renders behind/under the modal, and the modal briefly shows "Processing response..." before `removeModal()` runs a few lines later.

Affected lines: ~3320-3342, 3374-3384, 3426-3436.

## Suggested Fix

Either:
- Call `removeModal()` before `show_error_toast()` inside the error handler
- Restructure to use `tryCatch(finally = removeModal())` so the modal is always removed first

## Context

The document notebook (`mod_document_notebook.R`) doesn't have this issue because its error handler is simpler (`sprintf("Error: %s", e$message)`) and doesn't call `show_error_toast()`.

<!-- migrated from beads: `serapeum-1774459567077-171-1e54cc18` | github: https://github.com/seanthimons/serapeum/issues/200 -->
