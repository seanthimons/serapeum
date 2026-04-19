---
title: "bug: verbose API logging option not initialized on app startup"
status: todo
type: bug
priority: normal
tags:
  - db
  - server
  - ui
created_at: 2026-03-19T17:21:35Z
updated_at: 2026-03-25T21:44:14Z
---

## Description

`options(serapeum.verbose_api)` is only set when the user visits the Settings tab (inside `mod_settings_server`'s observer). If the DB has verbose logging enabled, it won't take effect until Settings is opened.

## Current behavior

1. User enables verbose logging in Settings → saved to DB
2. User restarts app
3. Verbose logging is inactive until they open Settings again

## Expected behavior

On app startup, after DB connection is established, read the `verbose_mode` setting from the DB and call `options(serapeum.verbose_api = ...)` so it takes effect immediately.

## Fix

Add initialization in `app.R` after `con_r()` is established:
```r
observe({
  con <- con_r()
  req(con)
  verbose <- get_setting(con, "verbose_mode")
  options(serapeum.verbose_api = isTRUE(as.logical(verbose)))
}) |> bindEvent(con_r(), once = TRUE)
```

## Context

Found during PR #156 review.

<!-- migrated from beads: `serapeum-1774459566305-138-916d1733` | github: https://github.com/seanthimons/serapeum/issues/166 -->
