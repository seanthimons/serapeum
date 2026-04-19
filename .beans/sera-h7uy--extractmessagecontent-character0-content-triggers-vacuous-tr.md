---
title: "extract_message_content: character(0) content triggers vacuous truth in all()"
status: completed
type: bug
priority: high
created_at: 2026-04-07T17:17:10Z
updated_at: 2026-04-08T16:22:36Z
---

all(nchar(character(0)) == 0) returns TRUE in R (vacuous truth). If content is a zero-length character vector, function falls into reasoning branch and may return NULL. Add length(content) == 0 guard. GitHub #279

## Resolution

Fixed in 248a55b

<!-- migrated from beads: `serapeum-h7uy` -->
