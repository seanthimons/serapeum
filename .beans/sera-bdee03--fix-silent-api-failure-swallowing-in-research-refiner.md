---
title: "fix: silent API failure swallowing in research refiner"
status: completed
type: bug
priority: high
tags:
  - pr-review
created_at: 2026-03-20T15:54:38Z
updated_at: 2026-03-24T18:36:52Z
---

**Source:** PR #161 review (item #8)

## Problem

`research_refiner.R:25-28, 135-146` — failed OpenAlex API calls return empty lists with no warning or notification. Users see "0 candidates" with no indication the API was unreachable.

## Suggested fix

Emit `warning()` in the `tryCatch` error handler and/or surface a `showNotification(..., type = "warning")` so users know when candidate fetching failed vs. returned no results.

## Impact

Users cannot distinguish "no relevant papers" from "API is down" — leads to false conclusions about research gaps.

<!-- migrated from beads: `serapeum-1774459566723-156-bdee0399` | github: https://github.com/seanthimons/serapeum/issues/185 -->
