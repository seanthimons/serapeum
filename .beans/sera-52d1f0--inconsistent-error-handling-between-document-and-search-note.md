---
title: Inconsistent error handling between document and search notebook presets
status: todo
type: task
priority: high
tags:
  - pr-review
  - server
created_at: 2026-03-20T17:09:35Z
updated_at: 2026-03-22T17:15:51Z
parent: sera-cpjh
---

**Source:** PR #156 review (round 1, item 4)

## Problem

Document notebook preset handlers use simple error handling:
```r
}, error = function(e) {
  sprintf("Error: %s", e$message)
})
```

Search notebook uses the more robust pattern:
```r
}, error = function(e) {
  if (inherits(e, "api_error")) {
    show_error_toast(e$message, e$details, e$severity)
  } else {
    err <- classify_api_error(e, "OpenRouter")
    show_error_toast(err$message, err$details, err$severity)
  }
  "Sorry, I encountered an error..."
})
```

## Suggested Fix

Apply the search notebook error pattern to document notebook preset handlers for consistent UX. Users get the same quality of error feedback regardless of which notebook type they're using.

<!-- migrated from beads: `serapeum-1774459567127-173-52d1f0f2` | github: https://github.com/seanthimons/serapeum/issues/202 -->
