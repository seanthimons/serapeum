---
title: Add session cleanup for addResourcePath in document notebook and misc LOW items
status: todo
type: task
priority: normal
tags:
  - db
  - pr-review
  - server
  - test
created_at: 2026-03-20T17:40:33Z
updated_at: 2026-03-25T21:44:22Z
---

**Source:** PR #162 review (round 1, items #12, #14-19)

**Files:**
- `R/mod_document_notebook.R:607` — No `session$onSessionEnded()` cleanup for resource paths
- `R/config.R:61`, `R/slides.R:32` — Duplicate `%||%` operator definition
- `tests/testthat/test-local-provider-integration.R:18` — Hardcoded LM Studio port
- `tests/testthat/test-api-provider.R:274-291` — Test creates provider table manually instead of using migrations
- `R/mod_cost_tracker.R:18-20` — `format_cost_currency()` precision loss for OA credits
- `R/mod_slides.R:360` — Silent fallback model without notification

Low-priority cleanup items to address in a future pass.

<!-- migrated from beads: `serapeum-1774459567271-179-612569c3` | github: https://github.com/seanthimons/serapeum/issues/208 -->
