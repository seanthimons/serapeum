---
title: Figure action observers not destroyed on re-extraction
status: todo
type: task
priority: high
tags:
  - pr-review
  - server
created_at: 2026-03-20T20:06:35Z
updated_at: 2026-03-22T17:15:48Z
parent: sera-cpjh
---

**Source:** PR #163 review (round 1, item 6)

In `mod_document_notebook.R:859-861`, setting `fig_action_observers[[old_id]] <- NULL` removes the reference but doesn't call `$destroy()` on the observer object. Old observers persist in memory watching dead input IDs. Not functionally broken, but memory grows with each re-extraction cycle.

**Suggested fix:** Store observer objects (not just `TRUE`) and call `$destroy()` before nulling.

<!-- migrated from beads: `serapeum-1774459567364-183-474943aa` | github: https://github.com/seanthimons/serapeum/issues/212 -->
