---
phase: quick-260421-eoy
plan: 01
subsystem: api
tags: [models, openrouter, embeddings, rerank, cisa, compliance, db-cache]
dependency_graph:
  requires: []
  provides:
    - Expanded KNOWN_EMBED_DIMS (15 models, gemini-embedding-001 fixed to 3072)
    - CISA_BLOCKED_PROVIDERS constant + filter_cisa_providers() helper
    - Updated default embedding (12), rerank (3) model lists
    - DB-cached detect_embedding_dimension() with 3-tier lookup
    - migration 022: embedding_dim_cache table
    - compliance.cisa_filter config toggle
  affects:
    - R/mod_settings.R (consumes list_chat_models, list_embedding_models, list_rerank_models)
    - Any caller of detect_embedding_dimension()
tech_stack:
  added:
    - embedding_dim_cache DuckDB table (migration 022)
  patterns:
    - Three-tier lookup pattern: hardcoded constant -> DB cache -> live probe with write-back
    - CISA compliance filter via provider prefix blocklist
key_files:
  created:
    - migrations/022_create_embedding_dim_cache.sql
  modified:
    - R/api_provider.R
    - R/api_openrouter.R
    - R/api_rerank.R
    - config.example.yml
    - tests/testthat/test-api-provider.R
    - tests/testthat/test-api-rerank.R
decisions:
  - "Ada-002 removed from KNOWN_EMBED_DIMS (legacy, plan specifies 15 models not 16)"
  - "con parameter added as second named arg in detect_embedding_dimension() to preserve existing positional call at mod_settings.R:1088"
  - "Rerank test assertions updated to reflect new 3-model defaults"
metrics:
  duration: "~25 minutes"
  completed: "2026-04-21"
  tasks_completed: 2
  files_modified: 6
  files_created: 1
---

# Quick Task 260421-eoy: Update OpenRouter Model Lists Summary

**One-liner:** Expanded embedding defaults from 5 to 12 models, fixed gemini-embedding-001 dimension (768 -> 3072), added CISA provider filter toggle, and wired DB-cached dimension probing via new migration 022.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Update model defaults, KNOWN_EMBED_DIMS, CISA filter | 38ae572 | api_provider.R, api_openrouter.R, api_rerank.R, config.example.yml |
| 2 | DB-cached embedding dimension detection + migration 022 | 1271788 | migrations/022_create_embedding_dim_cache.sql, api_provider.R, test-api-provider.R |
| fix | Update rerank tests for new 3-model defaults | a72447c | test-api-rerank.R |

## What Was Built

### R/api_provider.R

- `KNOWN_EMBED_DIMS` expanded from 9 to 15 entries. Critical bug fix: `google/gemini-embedding-001` corrected from `768L` to `3072L` (MRL truncation was mistakenly used as default).
- `CISA_BLOCKED_PROVIDERS` constant: 9 Chinese provider prefixes per DOJ Data Security Rule (April 2025). China is the only country of concern with AI providers on OpenRouter.
- `filter_cisa_providers()`: prefix-based filter that works on both model IDs (`deepseek/model`) and bare provider names.
- `detect_embedding_dimension()` updated to 3-tier lookup: hardcoded table (instant) -> `embedding_dim_cache` DB table (fast, tryCatch-wrapped for pre-migration DBs) -> live provider probe with write-back.

### R/api_openrouter.R

- `get_default_embedding_models()` replaced: 5 models -> 12 models covering OpenAI, Google, BAAI, Qwen, NVIDIA, Mistral, Perplexity.
- `list_embedding_models()` gains `cisa_filter = FALSE` parameter; filters returned df by provider prefix.
- `list_chat_models()` gains `cisa_filter = FALSE` parameter; expands `allowed_providers` by 6 (nvidia, minimax, z-ai, stepfun, xiaomi, perplexity); applies CISA filter via `setdiff()` on provider list.

### R/api_rerank.R

- `get_default_rerank_models()` updated: 2 models -> 3 models; adds `cohere/rerank-v3.5`; corrects `cohere/rerank-4-pro` price from `$0.005` to `$0.0025`.

### migrations/022_create_embedding_dim_cache.sql

- New table `embedding_dim_cache` with `model_id VARCHAR PRIMARY KEY`, `dimensions INTEGER NOT NULL`, `probed_at TIMESTAMP`.

### config.example.yml

- Added `compliance.cisa_filter: false` section with explanatory comments.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ada-002 count discrepancy**
- **Found during:** Task 1 verification
- **Issue:** RESEARCH.md KNOWN_EMBED_DIMS block shows 16 entries (includes legacy `openai/text-embedding-ada-002`) but plan must_haves says 15 models. Plan is the authoritative spec.
- **Fix:** Excluded `openai/text-embedding-ada-002` from KNOWN_EMBED_DIMS; it's legacy and not in the default embedding model list anyway.
- **Files modified:** R/api_provider.R

**2. [Rule 1 - Bug] Existing rerank tests broke on model count change**
- **Found during:** Full test suite run after Task 2
- **Issue:** `test-api-rerank.R` had two tests asserting the old 2-model structure (row count == 2, v3.5 NOT present). Both now fail after our intentional 3-model update.
- **Fix:** Updated assertions to expect 3 rows and verify v3.5 is present; replaced "does not include v3.5" test with corrected pricing assertion.
- **Files modified:** tests/testthat/test-api-rerank.R
- **Commit:** a72447c

## Pre-existing Failures (Out of Scope)

The following test failures exist on the base branch and are unrelated to this task:
- `test-config.R:17` — load_config finds real config.yml in working dir
- `test-db-leak.R` — missing schema columns
- `test-ragnar-helpers.R` — `there is no package called 'serapeum'`
- `test-ragnar-integration.R` — pre-existing fixture issues

These match the 13 pre-existing failures noted in STATE.md.

## Known Stubs

None. All data flows are wired: model lists serve real data from OpenRouter API or hardcoded defaults. The `cisa_filter` parameter is passed through but callers (mod_settings.R) need to wire the config toggle to activate it — that is future work outside this task's scope, not a stub.

## Threat Flags

No new trust boundaries introduced beyond those in the plan's threat model. The `CISA_BLOCKED_PROVIDERS` constant is hardcoded (not user-modifiable), the `embedding_dim_cache` stores only model_id + integer, and the filter is opt-in (default false).

## Self-Check: PASSED

- migrations/022_create_embedding_dim_cache.sql: FOUND
- R/api_provider.R: FOUND (KNOWN_EMBED_DIMS=15, detect_embedding_dimension with 3 tiers)
- R/api_openrouter.R: FOUND (12 default embedding models, cisa_filter params)
- R/api_rerank.R: FOUND (3 rerank models, corrected pricing)
- config.example.yml: FOUND (compliance.cisa_filter: false)
- Commit 38ae572: Task 1
- Commit 1271788: Task 2
- Commit a72447c: Rerank test fix
- All 138 api-provider tests: PASS
- Shiny smoke test: PASS (app started on port 3838)
