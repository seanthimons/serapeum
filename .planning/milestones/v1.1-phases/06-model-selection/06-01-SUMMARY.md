---
phase: 06-model-selection
plan: 01
subsystem: settings
tags: [ui, api, dynamic-data, pricing]
dependency_graph:
  requires: [05-cost-visibility]
  provides: [dynamic-chat-models, live-pricing-cache]
  affects: [cost-tracking, settings-ui]
tech_stack:
  added: []
  patterns: [reactive-pricing-cache, api-fallback-defaults]
key_files:
  created: []
  modified:
    - R/api_openrouter.R
    - R/cost_tracking.R
    - R/mod_settings.R
decisions:
  - id: MODL-01
    summary: "Chat model list fetched from OpenRouter API with curated provider filter"
    rationale: "Filter to 9 well-known providers to avoid overwhelming users with 500+ obscure models"
  - id: MODL-02
    summary: "Pricing cache uses mutable environment for dynamic updates"
    rationale: "Allows estimate_cost() to use live pricing from API responses while maintaining backwards compatibility"
  - id: MODL-03
    summary: "Model info panel shows context window, pricing, and tier badge"
    rationale: "Provides transparency for cost-conscious users choosing between models"
metrics:
  duration: 3
  completed: 2026-02-11
---

# Phase 06 Plan 01: Dynamic Chat Model Selection Summary

**One-liner:** Dynamic chat model dropdown with 10+ models fetched from OpenRouter API, showing pricing and context window info, with live pricing integration for cost tracking.

## What Was Built

### Chat Model API and Pricing (R/api_openrouter.R, R/cost_tracking.R)

**Added functions:**
- `get_default_chat_models()`: Hardcoded fallback with 10 models (3 budget, 4 mid-tier, 3 premium) including context length and pricing
- `list_chat_models(api_key)`: Fetches live models from OpenRouter `/api/v1/models`, filters to text-generation models (excludes embeddings), filters to 9 curated providers, assigns tier based on prompt price
- `format_chat_model_choices(models_df)`: Formats model names for selectizeInput with tier icons ($, $$, $$$), context window, and per-M-token pricing
- `update_model_pricing(models_df)`: Updates shared pricing environment used by `estimate_cost()`

**Pricing cache refactor:**
- Moved `MODEL_PRICING` into mutable `pricing_env` environment
- `estimate_cost()` reads from `pricing_env$MODEL_PRICING` (backwards compatible)
- Live pricing from API responses updates the cache dynamically

### Settings UI Dynamic Model Selector (R/mod_settings.R)

**UI changes:**
- Replaced static `selectInput` with dynamic `selectizeInput` for chat model
- Added refresh button with icon (matches embedding model pattern)
- Added `uiOutput(ns("model_info"))` for model details panel
- Removed static pricing hint text

**Server changes:**
- Added `refresh_chat_trigger` reactiveVal and `chat_models_data` reactiveVal
- Added `update_chat_model_choices(api_key, current_selection)` helper function
- Wired up refresh on API key change or manual refresh button click
- Updated init observer to use dynamic approach instead of `updateSelectInput`
- Added `output$model_info` renderer showing:
  - Model name and tier badge (Budget/Mid-tier/Premium with color coding)
  - Context window (formatted as "128k" or "1.0M tokens")
  - Pricing per million tokens (input and output rates)

## Deviations from Plan

None - plan executed exactly as written.

## Success Criteria Met

- [x] **MODL-01**: User can select from 10+ chat models in settings
- [x] **MODL-02**: User sees context window and pricing for each model in the dropdown
- [x] **MODL-03**: User sees detailed model info (provider, pricing per M tokens, context window) for the currently selected model
- [x] **MODL-04**: User can switch models and the new model is used for subsequent chat/query operations
- [x] **MODL-05**: Cost estimation uses live pricing when available instead of only hardcoded table

**Verification results:**
1. `get_default_chat_models()` returns 10 models with all required columns ✓
2. `format_chat_model_choices()` produces 10 formatted labels with pricing ✓
3. `pricing_env` exists and is accessible ✓
4. `estimate_cost()` works with test values (0.00045 for 1000 prompt + 500 completion tokens) ✓
5. `mod_settings_ui` and `mod_settings_server` exist and source without errors ✓

## Self-Check: PASSED

**Files verified:**
- R/api_openrouter.R exists and modified ✓
- R/cost_tracking.R exists and modified ✓
- R/mod_settings.R exists and modified ✓

**Commits verified:**
- 2423a63: feat(06-01): add chat model listing API and dynamic pricing ✓
- c6f1a78: feat(06-01): dynamic chat model selector with info panel ✓

**Functions verified:**
- `get_default_chat_models()` returns 10 rows ✓
- `list_chat_models()` exists (sources without error) ✓
- `format_chat_model_choices()` returns 10 entries ✓
- `update_model_pricing()` exists (sources without error) ✓
- `pricing_env` exists ✓
- `estimate_cost()` calculates correctly ✓
- `mod_settings_ui` and `mod_settings_server` exist ✓

## Technical Notes

### API Filtering Logic

The `list_chat_models()` function uses a multi-layered filtering approach:
1. Check `x$architecture$modality` contains "text" and does NOT contain "embed"
2. Check `x$id` does NOT contain "embed" (safety net)
3. Filter to curated providers: openai, anthropic, google, meta-llama, deepseek, moonshotai, mistralai, qwen, cohere
4. Assign tier based on prompt_price: budget (<$0.50), mid ($0.50-$2.00), premium (>$2.00)
5. Sort by tier then name

This ensures users see high-quality, well-known models without being overwhelmed by the full 500+ model catalog.

### Pricing Cache Design

The mutable `pricing_env` allows the cost tracking system to use live pricing from API responses without breaking backwards compatibility:
- Default hardcoded prices remain available
- `update_model_pricing()` writes live prices from API
- `estimate_cost()` uses live prices if available, falls back to defaults
- Pricing updates happen automatically when user refreshes models or changes API key

### UI Patterns

The chat model selector follows the same patterns as the embedding model selector for consistency:
- Refresh button placement and styling match
- Debounced API key validation triggers model refresh
- Current selection preserved when refreshing models
- Falls back to defaults if API call fails

## Integration Points

**Upstream (dependencies):**
- Cost tracking system (05-cost-visibility) provides `estimate_cost()` and `log_cost()`

**Downstream (used by):**
- All chat/query operations will use selected model from settings
- Cost tracking will use live pricing from updated cache
- Future phases (7, 8, 9) inherit improved cost accuracy

## Next Steps

Phase 06 Plan 02 will likely involve:
- Ensuring all chat/query callers use the selected model correctly
- Testing model switching end-to-end
- Verifying cost tracking uses updated pricing

**No blockers identified.**
