---
title: "Refiner: missing req() guards on inputs"
status: todo
type: task
priority: high
tags:
  - server
  - tech-debt
  - ui
  - v18
created_at: 2026-03-20T16:39:33Z
updated_at: 2026-03-22T17:15:42Z
parent: sera-dast
---

From PR #161 review items #12 and #13.

- **#12:** Missing `req()` guard on `input$source_type` (`mod_research_refiner.R:353`) — first render may have NULL input.
- **#13:** Missing `req(con_r())` in add_seed observer (`mod_research_refiner.R:221`) — calls `con_r()` without guarding; outer `tryCatch` catches the error but masks the real issue.

Both are minor robustness improvements.

<!-- migrated from beads: `serapeum-1774459566890-163-3c2b5576` | github: https://github.com/seanthimons/serapeum/issues/192 -->
