---
title: Missing isolate() on fig_refresh counter reads in observers
status: todo
type: task
priority: critical
tags:
  - pr-review
  - server
  - ui
created_at: 2026-03-20T20:06:31Z
updated_at: 2026-03-25T21:43:59Z
parent: sera-cpjh
---

**Source:** PR #163 review (round 1, item 4)

In `mod_document_notebook.R` (lines 956, 962, 1016), `fig_refresh(fig_refresh() + 1)` inside observers creates an unintended reactive dependency on `fig_refresh`. Should be `fig_refresh(isolate(fig_refresh()) + 1)` to avoid potential re-render cascades when many figures are present.

<!-- migrated from beads: `serapeum-1774459567317-181-3e76410d` | github: https://github.com/seanthimons/serapeum/issues/210 -->
