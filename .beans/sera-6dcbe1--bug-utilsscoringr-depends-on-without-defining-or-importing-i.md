---
title: "bug: utils_scoring.R depends on %||% without defining or importing it"
status: completed
type: bug
priority: high
tags:
  -  medium
created_at: 2026-03-19T20:14:05Z
updated_at: 2026-03-23T20:06:15Z
---

## Severity: Medium

## Description

`R/utils_scoring.R` uses the `%||%` operator (line 127: `weights$w6 %||% 0`) without defining it. The operator is defined in `R/config.R`. This creates two problems:

1. `utils_scoring.R` is not self-contained — it silently depends on load order
2. `tests/testthat/test-utils_scoring.R` only sources `utils_scoring.R`, so tests will error in isolation when hitting the `%||%` call

## Fix

Either:
- Define `%||%` at the top of `utils_scoring.R` (guarded with `if (!exists("%||%"))`)
- Replace with base R: `if (is.null(weights$w6)) 0 else weights$w6`
- Source `config.R` in the test file

## Found in

PR #161 review (unresolved Copilot comments #4 + #7)

<!-- migrated from beads: `serapeum-1774459566579-150-6dcbe15e` | github: https://github.com/seanthimons/serapeum/issues/179 -->
