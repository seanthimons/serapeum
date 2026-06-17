---
# zp44
title: 'feat: async task observability'
status: completed
type: feature
priority: high
tags:
    - diagnostics
created_at: 2026-06-04T16:21:44Z
updated_at: 2026-06-04T16:50:58Z
---

Add opt-in async task observability for document/search re-indexing, bulk DOI import, and citation network/audit. Includes structured JSONL telemetry, settings diagnostics UI, mirai status capture, event redaction, and focused tests. Related: sera-da61dc, but this does not close API-query visibility unless that broader request is satisfied.
