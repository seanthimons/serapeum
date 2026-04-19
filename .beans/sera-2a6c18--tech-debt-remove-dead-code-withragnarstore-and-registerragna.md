---
title: "tech-debt: Remove dead code — with_ragnar_store() and register_ragnar_cleanup()"
status: completed
type: task
priority: high
tags:
  - tech-debt
created_at: 2026-02-18T17:08:30Z
updated_at: 2026-02-22T18:43:39Z
---

## Problem

Two functions in `R/_ragnar.R` are unused after the v3.0 ragnar overhaul:

- `with_ragnar_store()` — wrapper that was replaced by direct `get_ragnar_store()` calls
- `register_ragnar_cleanup()` — cleanup registration that is no longer called anywhere

## Context

Identified during v3.0 milestone audit. These functions were part of the original ragnar integration but were superseded by the per-notebook store architecture.

## Fix

Delete both functions from `R/_ragnar.R`.

## Files

- `R/_ragnar.R`

<!-- migrated from beads: `serapeum-1774459565449-99-2a6c1805` | github: https://github.com/seanthimons/serapeum/issues/119 -->
