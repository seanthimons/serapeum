---
title: "Citation network: missing size_by in initial network metadata"
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
created_at: 2026-03-20T16:59:40Z
updated_at: 2026-03-25T21:44:19Z
parent: sera-c879
---

**Source:** PR #168 review (round 1, item #6)

When the network is first built (task result handler in `mod_citation_network.R`), metadata does not include `size_by`. The observer adds it only on change. If the user never changes sizing, metadata lacks this field, creating inconsistency with saved state. Add `size_by = "citations"` to initial metadata.

<!-- migrated from beads: `serapeum-1774459567030-169-d1d8264b` | github: https://github.com/seanthimons/serapeum/issues/198 -->
