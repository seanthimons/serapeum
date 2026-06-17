---
title: "bug: mailto email not redacted in verbose OpenAlex logging"
status: completed
type: bug
priority: high
created_at: 2026-03-19T17:21:29Z
updated_at: 2026-03-24T18:36:38Z
---

## Description

In `R/api_openalex.R`, `perform_openalex()` redacts `api_key` from verbose log output (line 11), but the `mailto` email parameter is still logged in plaintext.

## Current behavior

When verbose API logging is enabled, the full request URL — including the user's email in the `mailto` query param — is printed via `message()`.

## Expected behavior

Both `api_key` and `mailto` should be redacted before logging.

## Fix

Add a second `gsub()` to redact `mailto`:
```r
gsub("mailto=[^&]+", "mailto=<REDACTED>", ...)
```

## Context

Found during PR #156 review. Low risk since logging is local-only and opt-in, but good hygiene.

<!-- migrated from beads: `serapeum-1774459566281-137-795944b2` | github: https://github.com/seanthimons/serapeum/issues/165 -->
