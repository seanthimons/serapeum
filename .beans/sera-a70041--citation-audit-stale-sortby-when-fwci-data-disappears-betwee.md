---
title: "Citation audit: stale sort_by when FWCI data disappears between runs"
status: todo
type: task
priority: critical
tags:
  - pr-review
  - server
created_at: 2026-03-20T16:59:38Z
updated_at: 2026-03-25T21:43:56Z
parent: sera-c879
---

**Source:** PR #168 review (round 1, item #5)

If a user selects "FWCI" sort in the audit panel and then re-runs an audit on data without FWCI, `sort_by` retains the stale value. The switch statement falls through to the default case (no sort applied), silently returning unsorted results. Validate `sort_by` against available choices and reset to "collection_frequency" if invalid.

<!-- migrated from beads: `serapeum-1774459567005-168-a70041ae` | github: https://github.com/seanthimons/serapeum/issues/197 -->
