---
title: "dev: Move to renv for package namespace management"
status: completed
type: task
priority: high
tags:
  - gsd
created_at: 2026-02-13T23:00:48Z
updated_at: 2026-02-14T03:20:16Z
---

## Problem

The project loads packages inconsistently — some functions are called without namespace qualification (e.g., `ggplot()` instead of `ggplot2::ggplot()`), which causes runtime errors when packages aren't loaded via `library()` in the right scope. This was hit during Phase 17 when the year histogram used bare `ggplot()` calls without `ggplot2::` prefixes, causing "could not find function" errors at runtime.

Using `renv` would lock down the dependency manifest and encourage proper namespace management. It would also make the project reproducible across machines without relying on globally installed packages.

## Solution

1. Initialize `renv` with `renv::init()` to snapshot current dependencies
2. Audit all `library()` calls in `app.R` and module files — consolidate to `app.R` or switch to `pkg::fn()` style
3. Add `renv.lock` to version control
4. Update README with `renv::restore()` setup instructions

## Related

Related to #78 — renv would also support faster fresh initializations by locking reproducible dependency state.

## Files

- `R/mod_search_notebook.R`
- `app.R`

_Source: GSD todo_

<!-- migrated from beads: `serapeum-1774459564905-73-2b7c28a9` | github: https://github.com/seanthimons/serapeum/issues/90 -->
