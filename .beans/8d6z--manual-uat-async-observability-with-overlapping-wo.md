---
# 8d6z
title: 'manual UAT: async observability with overlapping workers'
status: todo
type: task
priority: normal
tags:
    - diagnostics
created_at: 2026-06-04T16:50:43Z
updated_at: 2026-06-04T16:50:43Z
---

Follow-up manual validation for zp44. With async_observability_enabled on and 2 mirai daemons, launch overlapping async actions and confirm queued tasks show awaiting > 0, high wait_ms, progress/completed/cancelled/error states, and no secrets/raw document text in data/diagnostics/async_tasks.jsonl.
