---
title: "feat: AA integration + split chat/synthesis models + latency tracking"
status: completed
type: feature
priority: high
created_at: 2026-03-06T20:29:46Z
updated_at: 2026-03-22T16:54:10Z
---

## Overview

Add per-request latency tracking, Artificial Analysis API integration for model quality benchmarks, and split the single chat model into separate chat vs synthesis model settings.

**Design doc**: [`docs/plans/2026-03-06-aa-integration-split-models-latency-tracking.md`](docs/plans/2026-03-06-aa-integration-split-models-latency-tracking.md)

## Problem

- **No quality benchmarking** — model tier assignment is purely price-based
- **No latency/TPS tracking** — users can't see how fast models respond
- **Single model for all tasks** — the same model handles casual chat AND complex synthesis

## Phases

### Phase 1: Database migration
- `response_time_ms` and `tokens_per_second` columns on `cost_log`
- `aa_model_cache` table for AA benchmark data

### Phase 2: Per-request latency backend
- Instrument `chat_completion()` and `get_embeddings()` with timing
- Extend `log_cost()` to accept and store `response_time_ms`
- Update all 13 `log_cost()` call sites

### Phase 3: Latency display in cost tracker
- Performance value box (avg TPS, avg response time)
- "Time (s)" and "TPS" columns in Recent Requests table

### Phase 4: Artificial Analysis API client
- Fetch/cache model quality benchmarks from artificialanalysis.ai
- Hardcoded AA → OpenRouter model ID mapping
- 24-hour cache with graceful degradation

### Phase 5: Split chat vs synthesis model
- Two Settings dropdowns: Chat Model + Synthesis Model
- Synthesis dropdown filtered to quality-capable models (AA intelligence_index >= 40, or tier-based fallback)
- 7 synthesis functions route through `get_model_for_task(config, "synthesis")`

## Files affected

| File | Action |
|------|--------|
| `migrations/011_add_response_time_and_aa_cache.sql` | Create |
| `R/api_openrouter.R` | Edit |
| `R/cost_tracking.R` | Edit |
| `R/rag.R` | Edit |
| `R/mod_query_builder.R` | Edit |
| `R/slides.R` | Edit |
| `R/mod_cost_tracker.R` | Edit |
| `R/api_artificial_analysis.R` | Create |
| `R/mod_settings.R` | Edit |
| `R/theme_catppuccin.R` | Edit |

<!-- migrated from beads: `serapeum-1774459565959-122-db0e0534` | github: https://github.com/seanthimons/serapeum/issues/144 -->
