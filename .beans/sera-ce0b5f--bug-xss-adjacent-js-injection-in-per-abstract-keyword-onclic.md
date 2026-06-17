---
title: "bug: XSS-adjacent JS injection in per-abstract keyword onclick handler"
status: completed
type: bug
priority: high
tags:
  -  medium
created_at: 2026-03-19T20:14:14Z
updated_at: 2026-03-23T20:06:18Z
---

## Severity: Medium

## Description

In `R/mod_search_notebook.R`, per-abstract keyword badges embed keyword values in a single-quoted JS string via `onclick`. Keywords are HTML-escaped with `htmltools::htmlEscape(..., attribute = TRUE)`, but this does not escape JS string metacharacters (`'`, `\`). A keyword containing a single quote could break out of the JS string context.

While this is a local-first app (low real-world risk), it's still a code quality issue worth fixing.

## Fix

After HTML escaping, also escape for JS string context:
```r
k_js <- gsub("\\\\", "\\\\\\\\", k_lower)
k_js <- gsub("'", "\\\\'", k_js)
```

Or use `jsonlite::toJSON(k_lower, auto_unbox = TRUE)` to produce a properly escaped JS string literal.

## Found in

PR #161 review

<!-- migrated from beads: `serapeum-1774459566628-152-ce0b5f17` | github: https://github.com/seanthimons/serapeum/issues/181 -->
