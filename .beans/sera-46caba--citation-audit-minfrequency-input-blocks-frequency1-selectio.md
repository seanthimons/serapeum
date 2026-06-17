---
title: "Citation audit: min_frequency input blocks frequency=1 selection"
status: todo
type: task
priority: critical
tags:
  - pr-review
  - server
created_at: 2026-03-20T16:59:36Z
updated_at: 2026-03-25T21:43:56Z
parent: sera-c879
---

**Source:** PR #168 review (round 1, item #4)

In `mod_citation_audit.R:529`, the `numericInput` for min frequency has `min = 2`, preventing users from typing `1` to see all papers. Combined with `value = 2` default, papers appearing in only one seed are permanently hidden with no way to reveal them. Change to `min = 1`.

<!-- migrated from beads: `serapeum-1774459566982-167-46cabadb` | github: https://github.com/seanthimons/serapeum/issues/196 -->
