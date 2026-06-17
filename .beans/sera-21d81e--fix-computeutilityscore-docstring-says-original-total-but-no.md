---
title: "fix: compute_utility_score docstring says \"original total\" but normalizes to 1.0"
status: todo
type: bug
priority: normal
tags:
  -  low
  - server
created_at: 2026-03-19T20:14:08Z
updated_at: 2026-03-25T21:44:16Z
---

## Severity: Low

## Description

In `R/utils_scoring.R`, the roxygen docstring for `compute_utility_score` says weights are "re-normalized to sum to the original total," but the implementation normalizes them to sum to 1.0.

## Fix

Update the docstring to say "re-normalized to sum to 1.0".

## Found in

PR #161 review (unresolved Copilot comment #3)

<!-- migrated from beads: `serapeum-1774459566601-151-21d81e7d` | github: https://github.com/seanthimons/serapeum/issues/180 -->
