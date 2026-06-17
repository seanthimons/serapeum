---
title: "bug: seed remove-button observers accumulate without teardown"
status: todo
type: bug
priority: normal
tags:
  -  low
  - server
  - ui
created_at: 2026-03-19T20:14:19Z
updated_at: 2026-03-25T21:44:17Z
parent: sera-dast
---

## Severity: Low

## Description

In `R/mod_research_refiner.R`, `observeEvent()` handlers for seed remove buttons (`remove_seed_{i}`) are created inside an `observe({ lapply(...) })` block that reruns every time `seed_papers()` changes. Previous handlers are not destroyed, so duplicate observers accumulate over time. After repeated add/remove cycles, this causes stale observers and potential erratic behavior.

## Fix

Options:
- Use a single delegated observer pattern (similar to keyword click handling in `mod_search_notebook.R`)
- Track created observer indices and only create new ones for indices not yet observed
- Use `observer$destroy()` on previously created observers before recreating

## Found in

PR #161 review (unresolved Copilot comment #5)

<!-- migrated from beads: `serapeum-1774459566653-153-20e7b380` | github: https://github.com/seanthimons/serapeum/issues/182 -->
