---
title: "v15 Set B: Provider Abstraction, Split Models, AA Integration, Local Models & Latency Tracking"
type: feat
date: 2026-03-17
---

# v15 Set B: AI Infrastructure — Provider Abstraction, Split Models, AA Integration, Local Models & Latency Tracking

## Overview

Five interconnected capabilities that complete the v15 AI Infrastructure milestone. A new provider abstraction layer serves as the foundation — split models, local model support, and latency tracking all build on it. Artificial Analytics benchmarking data enriches model selection across all providers.

## Problem Statement

Currently all LLM calls are hardwired to OpenRouter via `R/api_openrouter.R`. There is no way to:
- Use local models (Ollama, LM Studio, vLLM) alongside cloud models
- Assign different models to different operation types (cheap fast operations vs quality synthesis)
- Compare model quality/speed/price with benchmark data
- Track and display latency per model and operation

The 15+ call sites in `R/rag.R`, `R/slides.R`, `R/mod_query_builder.R` all call `chat_completion(api_key, model, messages)` directly with a hardcoded OpenRouter base URL.

## Technical Approach

### Architecture

```
┌──────────────────────────────────────────────────┐
│                  Shiny Modules                    │
│  (rag, slides, query_builder, chat, etc.)        │
│                                                   │
│  Each module calls:                               │
│    provider_chat_completion(config, slot, msgs)   │
│    provider_get_embeddings(config, slot, texts)   │
└──────────────────────┬───────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────┐
│            R/api_provider.R                       │
│                                                   │
│  - Resolves slot → (provider_config, model_id)   │
│  - Routes to correct endpoint                     │
│  - Captures duration_ms                           │
│  - Handles NULL usage tokens                      │
│  - Logs cost via log_cost()                       │
└──────────────────────┬───────────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │OpenRouter│ │ Ollama   │ │ LM Studio│
    │ /api/v1  │ │ /v1      │ │ /v1      │
    └──────────┘ └──────────┘ └──────────┘
```

### Implementation Phases

#### Phase 1: Provider Abstraction Layer (`R/api_provider.R`)

**Goal:** Unified interface that wraps any OpenAI-compatible endpoint. All existing call sites migrate to the new interface.

**New file: `R/api_provider.R`**

Core functions:
```r
# Provider config constructor
create_provider_config(name, base_url, api_key = NULL, provider_type = "openai-compatible", timeout_chat = 120, timeout_embed = 60)

# Unified chat completion — routes through the resolved provider
provider_chat_completion(provider_config, model, messages)
# Returns: list(content, usage, model, id, duration_ms)

# Unified embeddings
provider_get_embeddings(provider_config, model, texts)
# Returns: list(embeddings, usage, model, duration_ms)

# Model discovery
provider_list_models(provider_config)
# Returns: data.frame(id, name, provider_name, provider_type)

# Health check
provider_check_health(provider_config)
# Returns: list(alive = TRUE/FALSE, server_type = "ollama"|"lmstudio"|"vllm"|"unknown", model_count = N)
```

**OpenRouter as default provider:**
```r
OPENROUTER_PROVIDER <- create_provider_config(
  name = "OpenRouter",
  base_url = "https://openrouter.ai/api/v1",
  api_key = NULL,  # set at runtime from settings
  provider_type = "openrouter"
)
```

**Latency instrumentation:** Every `provider_chat_completion()` and `provider_get_embeddings()` call wraps the HTTP request in `system.time()` and returns `duration_ms` in the result.

**NULL usage handling:** When `usage` is missing from the response (common with local models):
```r
usage <- list(
  prompt_tokens = resp$usage$prompt_tokens %||% 0L,
  completion_tokens = resp$usage$completion_tokens %||% 0L,
  total_tokens = resp$usage$total_tokens %||% 0L
)
```

**Zero-cost detection:** If a provider's model has no pricing data (all local models), `estimate_cost()` returns `0.0` without falling back to `DEFAULT_PRICING`.

**Timeout configuration:** Provider configs carry their own timeout values. Defaults:
- Cloud providers: 120s chat, 60s embed
- Local providers: 300s chat, 600s embed (configurable per provider)

**Migration of call sites (15+ locations):**

| File | Current Call | New Call |
|------|-------------|---------|
| `R/rag.R` (13 calls) | `chat_completion(api_key, model, msgs)` | `provider_chat_completion(provider_cfg, model, msgs)` |
| `R/slides.R` (2 calls) | `chat_completion(api_key, model, msgs)` | `provider_chat_completion(provider_cfg, model, msgs)` |
| `R/mod_query_builder.R` (1 call) | `chat_completion(api_key, model, msgs)` | `provider_chat_completion(provider_cfg, model, msgs)` |
| `R/_ragnar.R` (1 call) | `get_embeddings(api_key, model, text)` | `provider_get_embeddings(provider_cfg, model, text)` |

**Backward compatibility approach:** The existing `chat_completion()` and `get_embeddings()` in `api_openrouter.R` become thin wrappers that create an OpenRouter provider config and delegate. This allows a gradual migration rather than a big-bang rewrite. Eventually the wrappers are removed once all call sites are updated.

**Tasks:**
- [x] Create `R/api_provider.R` with `create_provider_config()`, `provider_chat_completion()`, `provider_get_embeddings()`, `provider_list_models()`, `provider_check_health()`
- [x] Add duration_ms timing to every provider call
- [x] Handle NULL usage tokens gracefully (default to 0)
- [x] Update `estimate_cost()` in `R/cost_tracking.R` to return $0 when no pricing exists (instead of using DEFAULT_PRICING for local models)
- [x] Add `duration_ms` parameter to `log_cost()` in `R/cost_tracking.R`
- [x] Big-bang migration: all 15+ call sites migrated directly (no wrappers needed)
- [x] Migrate all 15+ call sites to use provider interface
- [x] Write tests for provider layer: 41 tests covering config creation, usage normalization, cost estimation, health check

**Success criteria:**
- All LLM calls route through the provider layer
- `duration_ms` is captured for every call
- NULL usage tokens don't crash `log_cost()`
- Existing functionality is unchanged (regression-free)

---

#### Phase 2: Latency Tracking (Migration + Display)

**Goal:** Persist `duration_ms` from Phase 1 and display latency analytics in Cost Tracker.

**Migration `012_add_duration_ms_to_cost_log.sql`:**
```sql
ALTER TABLE cost_log ADD COLUMN duration_ms INTEGER;
```

All existing rows will have `NULL` duration_ms. New rows will populate it.

**Update `log_cost()` in `R/cost_tracking.R`:**
```r
log_cost <- function(con, operation, model, prompt_tokens, completion_tokens,
                     total_tokens, estimated_cost, session_id, duration_ms = NULL) {
  # ... existing logic ...
  # Add duration_ms to INSERT
}
```

**New query functions in `R/cost_tracking.R`:**
```r
# Average latency per model (last N days), excluding NULLs
get_latency_by_model(con, days = 7)
# Returns: data.frame(model, avg_latency_ms, call_count)

# Average latency per operation type (last N days)
get_latency_by_operation(con, days = 7)
# Returns: data.frame(operation, avg_latency_ms, call_count)

# Latency trend (daily averages)
get_latency_trend(con, days = 30)
# Returns: data.frame(date, avg_latency_ms)
```

**All queries use `WHERE duration_ms IS NOT NULL`** to exclude pre-migration rows. Show "No latency data yet" when all values are NULL.

**New UI section in `R/mod_cost_tracker.R`:**
- Accordion section: "Latency"
- Value box: "Avg Latency" (last 7 days, across all models)
- Table: avg latency per model with call count
- Table: avg latency per operation with call count
- Sparkline or small bar chart: daily latency trend (last 30 days)

**Tasks:**
- [ ] Create `migrations/012_add_duration_ms_to_cost_log.sql`
- [ ] Update `log_cost()` to accept and persist `duration_ms`
- [ ] Add `get_latency_by_model()`, `get_latency_by_operation()`, `get_latency_trend()` query functions
- [ ] Add "Latency" accordion section to `mod_cost_tracker.R` UI
- [ ] Handle NULL duration gracefully in all latency queries and displays
- [ ] Write tests for latency query functions

**Success criteria:**
- Migration 012 applies cleanly on existing databases
- Every new LLM call logs duration_ms
- Cost Tracker shows latency breakdown by model and operation
- Pre-migration rows with NULL duration don't break calculations

---

#### Phase 3: Split Models (3 Slots)

**Goal:** Expand from 2 model slots (chat + embedding) to 3 (fast + quality + embedding) with operation routing.

**Add `slot` classification to `COST_OPERATION_META` in `R/cost_tracking.R`:**

```r
COST_OPERATION_META <- list(
  chat                  = list(label = "Chat",                  slot = "quality", icon_fun = bsicons::bs_icon, icon_name = "chat-dots-fill",   accent_class = "text-primary"),
  embedding             = list(label = "Embedding",             slot = "embedding", ...),
  query_build           = list(label = "Query Build",           slot = "fast", ...),
  slide_generation      = list(label = "Slide Generation",      slot = "quality", ...),
  slide_healing         = list(label = "Slide Healing",         slot = "quality", ...),
  conclusion_synthesis  = list(label = "Conclusion Synthesis",  slot = "quality", ...),
  overview              = list(label = "Overview",              slot = "quality", ...),
  overview_summary      = list(label = "Overview Summary",      slot = "quality", ...),
  overview_keypoints    = list(label = "Key Points",            slot = "quality", ...),
  research_questions    = list(label = "Research Questions",    slot = "quality", ...),
  lit_review_table      = list(label = "Lit Review Table",      slot = "quality", ...),
  methodology_extractor = list(label = "Methodology Extractor", slot = "quality", ...),
  gap_analysis          = list(label = "Gap Analysis",          slot = "quality", ...),
  query_reformulation   = list(label = "Query Reformulation",   slot = "fast", ...),
  openalex_search       = list(label = "OpenAlex Search",       slot = NA, ...),   # Not LLM — OA API
  openalex_fetch        = list(label = "OpenAlex Fetch",        slot = NA, ...),   # Not LLM — OA API
  openalex_topics       = list(label = "OpenAlex Topics",       slot = "fast", ...)
)
```

> **Note:** `openalex_search` and `openalex_fetch` are OpenAlex HTTP calls, not LLM operations. They get `slot = NA` and are excluded from model routing. `openalex_topics` uses LLM for topic extraction so it IS routed as `fast`.

**Model slot resolution helper:**
```r
# In R/api_provider.R
resolve_model_for_operation <- function(config, operation) {
  slot <- COST_OPERATION_META[[operation]]$slot
  if (is.na(slot)) stop("Operation '", operation, "' is not an LLM operation")

  model <- switch(slot,
    fast      = config$defaults$fast_model %||% config$defaults$quality_model,
    quality   = config$defaults$quality_model,
    embedding = config$defaults$embedding_model
  )

  if (is.null(model) || model == "") {
    stop("No model configured for slot '", slot, "'. Please configure a ", slot, " model in Settings.")
  }

  model
}
```

**Fast slot fallback:** When `fast_model` is NULL or empty, falls back to `quality_model`. This is a **silent fallback at configuration time** (not at request time). The settings UI shows: "Fast model: (using Quality model)" when no fast model is explicitly set.

**⚠️ Runtime fallback (provider down):** If the fast model's provider is unreachable at request time, the operation **fails with an error** rather than silently falling back to a potentially expensive quality model. Rationale: silent cost escalation is worse than an error in a cost-tracking app.

**Settings migration (2 slots → 3 slots):**
- Runtime migration in `mod_settings_server`: on load, if `fast_model` setting is NULL and `quality_model` is NULL but `chat_model` exists, copy `chat_model` → `quality_model`
- No SQL migration needed — settings are key-value pairs, just add new keys

```r
# In mod_settings_server, during init:
migrate_model_slots <- function(con) {
  quality <- get_db_setting(con, "quality_model")
  if (is.null(quality)) {
    chat <- get_db_setting(con, "chat_model")
    if (!is.null(chat)) {
      save_db_setting(con, "quality_model", chat)
      # fast_model left NULL — will fallback to quality_model
    }
  }
}
```

**Settings UI changes in `R/mod_settings.R`:**
Replace current 2 dropdowns with 3:
```
┌─────────────────────────────────────────────┐
│ Model Configuration                          │
├─────────────────────────────────────────────┤
│ ⚡ Fast Model      [dropdown] (optional)    │
│   For: query building, reformulation         │
│   Tip: Use a cheap/fast model to save costs  │
│                                              │
│ 🎯 Quality Model   [dropdown] (required)    │
│   For: chat, synthesis, analysis             │
│                                              │
│ 📐 Embedding Model [dropdown] (required)    │
│   For: document indexing and retrieval        │
└─────────────────────────────────────────────┘
```

When fast model is empty, show helper text: "Using Quality model as fallback"

**Tasks:**
- [ ] Add `slot` field to every entry in `COST_OPERATION_META`
- [ ] Create `resolve_model_for_operation(config, operation)` helper
- [ ] Add runtime settings migration: `chat_model` → `quality_model`
- [ ] Update `mod_settings.R` UI: replace 2 dropdowns with 3 (fast, quality, embedding)
- [ ] Update `mod_settings_server` to save/load `fast_model`, `quality_model`, `embedding_model`
- [ ] Update `effective_config` reactive to include all 3 slots in `defaults` list
- [ ] Update all call sites to use `resolve_model_for_operation()` to get the correct model for each operation
- [ ] Update `format_chat_model_choices()` to work for fast and quality pickers
- [ ] Write tests for slot resolution, fallback behavior, settings migration

**Success criteria:**
- 3 model dropdowns in Settings
- Each operation routes to the correct slot
- Fast slot falls back to quality when not configured
- Existing users' `chat_model` setting migrates cleanly to `quality_model`

---

#### Phase 4: Provider Management & Local Model Support

**Goal:** Users can add custom OpenAI-compatible endpoints (Ollama, LM Studio, vLLM) and assign their models to any slot.

**Provider storage — dedicated table (migration 013):**

```sql
-- migrations/013_create_providers.sql
CREATE TABLE IF NOT EXISTS providers (
  id VARCHAR PRIMARY KEY,
  name VARCHAR NOT NULL,
  base_url VARCHAR NOT NULL,
  api_key VARCHAR,
  provider_type VARCHAR NOT NULL DEFAULT 'openai-compatible',
  timeout_chat INTEGER DEFAULT 300,
  timeout_embed INTEGER DEFAULT 600,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed OpenRouter as the built-in default provider
INSERT INTO providers (id, name, base_url, provider_type, is_default, timeout_chat, timeout_embed)
VALUES ('openrouter', 'OpenRouter', 'https://openrouter.ai/api/v1', 'openrouter', TRUE, 120, 60)
ON CONFLICT DO NOTHING;
```

> **Decision:** Dedicated table over JSON blob. Reasons: cleaner queries when aggregating models across providers, easier to extend with per-provider settings, and simpler CRUD operations.

**Provider CRUD functions in `R/db.R`:**
```r
save_provider(con, id, name, base_url, api_key, provider_type, timeout_chat, timeout_embed)
get_providers(con)          # Returns all providers as data.frame
get_provider(con, id)       # Returns single provider as list
delete_provider(con, id)    # Fails if id == "openrouter" (default is undeletable)
```

**Model aggregation:**
```r
# In R/api_provider.R
get_all_available_models <- function(providers, model_type = c("chat", "embedding")) {
  # For each provider, call provider_list_models()
  # Merge results, prefixing display names with provider name
  # e.g., "[Ollama] llama3.2" vs "[OpenRouter] meta-llama/llama-3.2"
  # Returns data.frame(model_id, display_name, provider_id, provider_name, ...)
}
```

**Settings UI — new "Providers" section:**
```
┌─────────────────────────────────────────────┐
│ Providers                                    │
├─────────────────────────────────────────────┤
│ ✅ OpenRouter (built-in)        [API Key: ••••]  │
│                                              │
│ 🟢 Ollama (localhost:11434)     [Test] [Edit] [×] │
│    Models: llama3.2, mistral, nomic-embed    │
│                                              │
│ ⚪ LM Studio (localhost:1234)   [Test] [Edit] [×] │
│    Status: Offline                           │
│                                              │
│ [+ Add Provider]                             │
└─────────────────────────────────────────────┘
```

**Add Provider modal/dialog:**
- Name (text input)
- Base URL (text input, placeholder: `http://localhost:11434/v1`)
- API Key (password input, optional)
- [Test Connection] button → calls `provider_check_health()`, shows model count
- [Save] button

**Edit Provider:** Same modal, pre-filled. API key field shows "••••••" with a "Change" button.

**Delete Provider:** Confirmation dialog. If any slot currently uses a model from this provider, warn: "The following slots use models from this provider: [Fast]. Deleting will clear those slot assignments."

**Model pickers update:**
- All 3 slot dropdowns now show models from all configured providers
- Models grouped by provider in the dropdown (using optgroup or similar selectize grouping)
- Provider health status shown: green dot = online, red = offline/unreachable
- Model discovery runs when: (a) Settings page opens, (b) user clicks "Refresh Models", (c) a new provider is added

**Embedding dimension handling:**
- When user selects an embedding model, detect its dimension:
  1. Check if dimension is known from AA data or hardcoded table
  2. If unknown, make a test embedding call with a short string, measure `length(vector)`
  3. Store dimension in settings: `save_db_setting(con, "embedding_dimension", dim)`
- When dimension changes from what ragnar indexes were built with:
  - Show warning: "Your indexes were built with [old model] (1536 dims). The selected model [new model] produces [768] dims. You'll need to re-index your notebooks for retrieval to work."
  - Extend the existing stale index detection (from commit `7abf01a`) to also check dimension mismatch
  - Do NOT auto-re-index — let user trigger it

**Local model specifics:**
- Zero cost: `estimate_cost()` checks `pricing_env$MODEL_PRICING` for the model. If not found AND provider is local (not OpenRouter), return $0. If not found AND provider is OpenRouter, use `DEFAULT_PRICING` as today.
- Missing usage tokens: Already handled in Phase 1 (default to 0)
- No API key required: `api_key` field is optional in provider config

**Async model discovery (avoiding UI freeze):**
- Use `promises`/`future` for provider health checks and model listing
- Show spinner per-provider while checking
- 3-second timeout on `/v1/models` probe — if a provider doesn't respond in 3s, mark as "Offline" and skip

**Tasks:**
- [ ] Create `migrations/013_create_providers.sql` with OpenRouter seed
- [ ] Add provider CRUD functions to `R/db.R`
- [ ] Implement `get_all_available_models()` with provider grouping
- [ ] Add "Providers" section to `mod_settings.R` UI with add/edit/delete/test
- [ ] Update model slot dropdowns to show models from all providers, grouped by provider
- [ ] Implement embedding dimension detection and mismatch warning
- [ ] Extend stale index detection to check embedding dimension
- [ ] Handle zero-cost detection for local providers in `estimate_cost()`
- [ ] Add async model discovery with timeout and offline status
- [ ] Write tests for provider CRUD, model aggregation, dimension detection, zero-cost logic

**Success criteria:**
- Users can add Ollama/LM Studio/vLLM providers via Settings
- Models from all providers appear in all 3 slot dropdowns
- Local model calls work with zero cost and missing usage tokens
- Embedding dimension mismatches produce a clear warning
- Offline providers don't freeze the UI

---

#### Phase 5: Artificial Analytics Integration

**Goal:** Enrich model selection with AA benchmarking data (quality scores, speed, price) and power smart defaults.

**Data source:** Artificial Analytics API v2
- Endpoint: `GET https://artificialanalysis.ai/api/v2/data/llms/models`
- Auth: API key in `x-api-key` header (free tier: 1000 req/day)
- No API key required for bundled snapshot usage

**New file: `R/api_artificialanalysis.R`**
```r
# Fetch latest AA data from API
fetch_aa_models(api_key = NULL)
# Returns: data.frame with columns below

# Load bundled snapshot (no network needed)
load_bundled_aa_data()
# Reads from data/support/aa_models.json

# Get AA data (bundled or refreshed)
get_aa_models(con)
# Checks DB cache first, falls back to bundled
```

**AA data schema (stored in `data/support/aa_models.json` and cached in DB):**

| Field | Source | Usage |
|-------|--------|-------|
| `aa_model_id` | AA API `id` | Primary key |
| `aa_model_name` | AA API `name` | Display / matching |
| `aa_model_slug` | AA API `slug` | URL-safe identifier |
| `creator_name` | AA API `model_creator.name` | Matching |
| `intelligence_index` | AA API `evaluations.artificial_analysis_intelligence_index` | Quality score for model picker |
| `coding_index` | AA API `evaluations.artificial_analysis_coding_index` | Secondary score |
| `tokens_per_second` | AA API `median_output_tokens_per_second` | Speed display |
| `ttft_seconds` | AA API `median_time_to_first_token_seconds` | Latency display |
| `price_input_1m` | AA API `pricing.price_1m_input_tokens` | Price comparison |
| `price_output_1m` | AA API `pricing.price_1m_output_tokens` | Price comparison |
| `price_blended_1m` | AA API `pricing.price_1m_blended_3_to_1` | Quick price display |

**Bundled snapshot:** Ship `data/support/aa_models.json` with the app. Updated periodically by maintainer. This ensures the app works offline.

**DB caching:** Store refreshed AA data in a `aa_model_cache` setting (JSON blob via `save_db_setting`). Include a `refreshed_at` timestamp. The "Refresh" button fetches from API and updates the cache.

**Model ID matching (AA ↔ OpenRouter):**
AA and OpenRouter use different model ID schemes. Matching strategy:
1. Normalize both: lowercase, strip provider prefixes, strip version suffixes
2. Match on `creator_name/model_name` pattern (e.g., "Meta" + "Llama 3.1 405B" → `meta-llama/llama-3.1-405b`)
3. Maintain a small manual mapping table for edge cases (`data/support/aa_model_mapping.json`)
4. Models without AA data show "—" for scores (common for local models)

**Model picker enrichment:**
Update `format_chat_model_choices()` to include AA data:
```
Claude 3.5 Sonnet          🧠 89  ⚡ 82 tok/s  💰 $3.00/M
Llama 3.1 70B              🧠 72  ⚡ 45 tok/s  💰 $0.40/M
[Ollama] llama3.2          🧠 —   ⚡ —         💰 Free
```

Columns: quality index, speed (tokens/sec), blended price. Sortable by each column in the selectize dropdown.

**Smart defaults algorithm:**
When a slot has no model selected, recommend based on AA data + user's configured providers:

- **Fast slot:** Among models available from configured providers, pick the one with lowest `price_blended_1m` that has `intelligence_index >= 50` (basic competence threshold). Local models preferred (free). If no AA data, prefer models with "mini" or "flash" in the name.
- **Quality slot:** Among available models, pick the one with highest `intelligence_index` where `price_blended_1m <= $10/M` (sanity cap). If no AA data, prefer models with known quality reputations (hardcoded fallback list).
- **Embedding slot:** Keep current default (`openai/text-embedding-3-small`) unless user has a local embedding model.

Smart defaults are **suggestions shown in the dropdown placeholder**, not auto-applied. User must explicitly select.

**Model info panel enrichment:**
The existing model info display (if any) gets AA data: full benchmark scores, speed metrics, pricing breakdown, context length.

**Refresh flow:**
1. User clicks "Refresh AA Data" button (separate from model refresh)
2. If AA API key configured → fetch from API
3. If no API key → show message: "Add an Artificial Analytics API key to get the latest data, or use the bundled snapshot."
4. On success → update DB cache, refresh model pickers
5. On failure → keep existing cache, show error toast
6. Attribution: Display "Data from Artificial Analytics" with link per their TOS

**Tasks:**
- [ ] Create `R/api_artificialanalysis.R` with `fetch_aa_models()`, `load_bundled_aa_data()`, `get_aa_models()`
- [ ] Create initial `data/support/aa_models.json` bundled snapshot
- [ ] Create `data/support/aa_model_mapping.json` for edge-case ID matching
- [ ] Implement model ID matching logic (AA ↔ OpenRouter)
- [ ] Add AA data columns to model picker display via `format_chat_model_choices()`
- [ ] Implement smart defaults algorithm for each slot
- [ ] Add "Refresh AA Data" button to Settings
- [ ] Add AA API key setting (optional, for refresh)
- [ ] Add AA attribution line per TOS
- [ ] Enrich model info panel with AA benchmark data
- [ ] Write tests for AA data loading, model matching, smart defaults

**Success criteria:**
- Model pickers show quality/speed/price from AA data
- Smart defaults suggest reasonable models for each slot
- Bundled snapshot works offline
- Refresh button fetches latest data
- Models without AA data display gracefully (show "—")

---

## Alternative Approaches Considered

| Approach | Why Rejected |
|----------|-------------|
| Ollama-specific integration | OpenAI-compatible covers Ollama + LM Studio + vLLM with zero additional code |
| Per-operation model assignment (16 dropdowns) | Overwhelms Settings UI. Fast/quality/embedding is the right granularity |
| Auto-routing based on latency | Adds complexity without clear user value. Log + display first, intelligence later |
| Provider configs as JSON blob in settings | Harder to query, extend, and validate. Dedicated table is cleaner |
| Auto-re-index when embedding model changes | Too aggressive. Users should control when re-indexing happens |
| Silent fallback to paid model when local is down | Unexpected cost is the worst UX failure in a cost-tracking app |

## Acceptance Criteria

### Functional Requirements

- [ ] All LLM calls route through the provider abstraction layer
- [ ] Users can add/edit/delete custom OpenAI-compatible providers
- [ ] Three model slots (fast, quality, embedding) with per-operation routing
- [ ] Fast slot falls back to quality model when not configured
- [ ] Local models work with zero cost and missing usage tokens
- [ ] AA data displayed in model pickers (quality, speed, price)
- [ ] Smart defaults suggest models for unconfigured slots
- [ ] Latency tracked and displayed in Cost Tracker
- [ ] Embedding dimension mismatch warning when switching models
- [ ] Existing users' settings migrate cleanly (chat_model → quality_model)

### Non-Functional Requirements

- [ ] Offline-capable: bundled AA data, local providers work without internet
- [ ] No UI freezes: async provider health checks with 3s timeout
- [ ] Backward compatible: existing databases migrate cleanly via numbered migrations
- [ ] Provider secrets not exposed in UI (masked API keys)

### Quality Gates

- [ ] All existing tests still pass after provider migration
- [ ] New tests for: provider layer, slot resolution, latency queries, AA data loading, model matching
- [ ] Shiny smoke test passes after each phase
- [ ] Settings page renders correctly with 0, 1, and 3+ providers

## Dependencies & Prerequisites

- **Set A completion:** Stale index detection (commit `7abf01a`) is needed for dimension mismatch extension
- **Migration 011** must be the current highest migration before starting
- **httr2** package (already used) for HTTP requests to providers
- **promises/future** packages for async provider discovery (may need to add)

## Risk Analysis & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| AA API changes format or goes down | Model picker loses quality data | Bundled snapshot as fallback; cache in DB |
| Local model responses vary from OpenAI spec | Provider calls fail silently | Defensive parsing with `%||%` defaults; health check validates before use |
| 15+ call site migration introduces regressions | Core features break | Backward-compatible wrappers allow incremental migration; test each call site |
| Embedding dimension mismatch corrupts retrieval | Search returns garbage | Validate dimensions at index time; warn on model switch; extend stale detection |
| Settings page becomes overwhelming with 3 slots + providers | Users confused | Group into accordion sections; progressive disclosure; smart defaults reduce need to configure |
| R/Shiny single-threaded blocks on slow provider | UI freezes | Async discovery with 3s timeout; mark offline providers clearly |

## Open Questions Resolved

| Question | Resolution |
|----------|-----------|
| AA API endpoint/format? | `GET /api/v2/data/llms/models`, free tier 1000 req/day, well-documented |
| Provider storage: settings vs table? | Dedicated `providers` table (migration 013) |
| Re-index on embedding model switch? | Warning + manual re-index, extend stale detection |
| Fast slot fallback? | Yes, to quality model at config time. Runtime failures error out (no silent cost escalation) |
| OA operations in fast/quality? | `openalex_search`/`openalex_fetch` get `slot = NA` (not LLM). `openalex_topics` is `fast` |

## References & Research

### Internal References
- `R/api_openrouter.R` — current LLM client, 15+ call sites to migrate
- `R/cost_tracking.R:29-47` — `COST_OPERATION_META` definition
- `R/cost_tracking.R:86` — `estimate_cost()` pricing logic
- `R/cost_tracking.R:171` — `log_cost()` function
- `R/db.R:686-698` — `save_db_setting`/`get_db_setting` pattern
- `R/db_migrations.R:45` — migration apply pattern
- `R/mod_settings.R:101-115` — current model dropdowns
- `R/mod_settings.R:692-716` — settings save logic
- `R/mod_cost_tracker.R:352` — cost tracker server
- `migrations/011_create_oa_usage_log.sql` — current highest migration
- Commit `7abf01a` — stale index detection (extend for dimension mismatch)
- `data/support/` — bundled data pattern (`.rds` files)

### External References
- [Artificial Analytics API v2](https://artificialanalysis.ai/documentation) — model benchmarking data
- [OpenRouter API /v1/models](https://openrouter.ai/docs/api/api-reference/models/get-models) — model metadata (no quality scores)
- [Ollama OpenAI Compatibility](https://docs.ollama.com/api/openai-compatibility) — endpoint support matrix
- [LM Studio OpenAI Compatibility](https://lmstudio.ai/docs/developer/openai-compat) — endpoint support
- [vLLM OpenAI-Compatible Server](https://docs.vllm.ai/en/stable/serving/openai_compatible_server/) — endpoint support

### Related Work
- Brainstorm: `docs/brainstorms/2026-03-17-v15-set-b-brainstorm.md`
- Set A plan: `docs/plans/2026-03-17-feat-v15-set-a-oa-usage-tracking-retrieval-quality-plan.md`
- GitHub issues: #144 (Split Models), #8 (Local Model Support)
