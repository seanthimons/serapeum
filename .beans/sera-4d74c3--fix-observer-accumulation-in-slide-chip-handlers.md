---
title: Fix observer accumulation in slide chip handlers
status: todo
type: task
priority: critical
tags:
  - pr-review
  - server
  - ui
created_at: 2026-03-20T17:40:18Z
updated_at: 2026-03-25T21:43:58Z
parent: sera-cpjh
---

**Source:** PR #162 review (round 1, item #8)

**File:** `R/mod_slides.R` lines 502-509

**Problem:** Loop creates 10 `observeEvent()` calls each time the modal opens. Reopening the modal accumulates observers without cleanup.

**Fix:** Use a single delegated event handler or add cleanup via `session$onSessionEnded()` / modal close callback.

<!-- migrated from beads: `serapeum-1774459567199-176-4d74c384` | github: https://github.com/seanthimons/serapeum/issues/205 -->
