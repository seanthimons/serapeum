---
title: "tech-debt: Connection leak in search_chunks_hybrid — ragnar store never closed"
status: completed
type: task
priority: high
tags:
  - tech-debt
created_at: 2026-02-18T17:08:25Z
updated_at: 2026-02-22T18:43:34Z
---

## Problem

`search_chunks_hybrid()` in `R/db.R` opens a ragnar store via `get_ragnar_store()` but never closes it after the query completes. Each RAG query leaks a DuckDB connection.

## Context

Identified during v3.0 milestone audit (phase 22 integration check). The store is opened on each call to `search_chunks_hybrid()` but `DBI::dbDisconnect(store@con, shutdown=TRUE)` is never called on the query path.

## Fix

Add `on.exit(DBI::dbDisconnect(store@con, shutdown = TRUE))` after the `get_ragnar_store()` call in `search_chunks_hybrid()`, or use a `tryCatch`/`finally` pattern.

## Files

- `R/db.R` — `search_chunks_hybrid()` function
- `R/_ragnar.R` — `get_ragnar_store()` returns store object

<!-- migrated from beads: `serapeum-1774459565401-97-7a93b476` | github: https://github.com/seanthimons/serapeum/issues/117 -->
