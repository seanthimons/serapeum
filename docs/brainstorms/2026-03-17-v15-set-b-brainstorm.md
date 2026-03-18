---
date: 2026-03-17
topic: v15-set-b-ai-infrastructure
---

# v15 Set B: AA Integration, Split Models, Latency Tracking & Local Model Support

## What We're Building

Four interconnected capabilities that complete the v15 AI Infrastructure milestone, layered on a new provider abstraction.

### Provider Abstraction Layer

Currently all LLM calls are hardwired to OpenRouter via `R/api_openrouter.R`. We need a provider layer (`R/api_provider.R`) that wraps any OpenAI-compatible endpoint behind a unified interface. This is the foundation for everything else in Set B.

**Unified interface:**
- `provider_chat_completion(provider_config, model, messages)` → content, usage, timing
- `provider_get_embeddings(provider_config, model, texts)` → vectors, usage, timing
- `provider_list_models(provider_config)` → model catalog

**Provider config:** A provider is defined by `base_url` + optional `api_key` + `provider_type` (openrouter | openai-compatible). OpenRouter is the default provider. Users can add custom endpoints (Ollama at `http://localhost:11434/v1`, LM Studio, vLLM, etc.).

**Latency instrumentation lives here** — every call through the provider layer captures `duration_ms` automatically, logged to `cost_log` alongside tokens and cost.

### #144: Split Models (3 Slots)

Expand from 2 model slots to 3:

| Slot | Purpose | Current | Default |
|------|---------|---------|---------|
| **Fast** | Cheap operations: query reformulation, query building, search variant generation | N/A (uses chat model) | Budget-tier model from AA data |
| **Quality** | User-facing synthesis: chat, slides, presets, gap analysis, lit review | `chat_model` setting | Mid/premium-tier model |
| **Embedding** | Vector embeddings for ragnar indexing and retrieval | `embedding_model` setting | `openai/text-embedding-3-small` |

**Operation routing:** Each of the 16+ operation types in `COST_OPERATION_META` is tagged as `fast` or `quality`. Modules read the appropriate slot. No per-operation model assignment — that's overengineering.

**Operations classified as `fast`:** query_reformulation, query_build, openalex_search, openalex_topics.
**Operations classified as `quality`:** chat, slide_generation, slide_healing, conclusion_synthesis, overview, overview_summary, overview_keypoints, research_questions, lit_review_table, methodology_extractor, gap_analysis.

Each slot can point to any provider (OpenRouter or a local endpoint). A local Ollama model can serve as the fast model, quality model, or embedding model.

### #144: Artificial Analytics Integration

Integrate Artificial Analytics benchmarking data to help users pick models and to power smart defaults for the 3 slots.

**Data sourcing:** Bundled JSON snapshot shipped with the app, with a "Refresh" button (same pattern as existing model metadata refresh). No API key required. Works offline with bundled data.

**AA data fields per model:** Quality score (ELO/index), speed (tokens/sec), price ($/M tokens), context length, provider.

**Where it surfaces:**
1. **Model picker** — AA quality/speed/price scores shown alongside each model in the selectize dropdowns. Sortable by score.
2. **Smart defaults** — When a slot has no model selected, recommend one based on AA data (cheapest fast model for fast slot, highest quality within budget for quality slot).
3. **Info panel** — Existing model info panel enriched with AA benchmark data.

### #8: Local Model Support

Users can configure custom OpenAI-compatible endpoints as providers. Any provider's models can be assigned to any of the 3 slots.

**Setup flow:**
1. Settings → new "Providers" section
2. "Add Provider" → name, base URL, optional API key
3. Provider auto-discovers available models via `/v1/models` endpoint
4. Models from all providers appear in the model pickers for all 3 slots

**Built-in provider:** OpenRouter (always present, uses existing API key config).

**Local-first considerations:**
- Local models have zero cost → `estimate_cost()` returns $0 when pricing is unavailable
- Local models may not return usage tokens → handle gracefully
- Latency tracking is especially valuable for local models (helps users tune hardware/model choices)
- Embedding models may differ in dimension → store dimension in settings, validate at index time

### Latency Tracking

Capture `duration_ms` for every LLM call inside the provider layer.

**Storage:** Add `duration_ms INTEGER` column to existing `cost_log` table (migration 012).

**Display:** New "Latency" section in Cost Tracker showing:
- Average latency per model (last 7 days)
- Average latency per operation type
- Latency trend (are calls getting slower?)

Informational only — no auto-routing based on latency in this set.

## Why This Approach

- **Provider abstraction first** because it's the foundation everything else needs. Split models need to route to different providers. Local models ARE a different provider. Latency tracking is best captured at the provider level. Building it first avoids rework.
- **3 slots (not per-operation)** because 16 individual model dropdowns would overwhelm the Settings page. Fast/quality/embedding is the right granularity — it maps to how users think about cost vs quality tradeoffs.
- **AA bundled snapshot** follows the existing pattern for model metadata refresh and keeps the app functional offline (local-first philosophy).
- **OpenAI-compatible endpoints** rather than Ollama-specific because it covers Ollama, LM Studio, vLLM, text-generation-webui, and any future local runner with zero additional code.
- **Latency log + display only** because auto-routing based on latency adds complexity without clear user value yet. Get the data flowing, build intelligence later.

## Key Decisions

- **Provider abstraction before features** — provider layer is Phase 1, everything else builds on it.
- **3 model slots: fast / quality / embedding** — operations tagged as fast or quality, not individually assignable.
- **Any OpenAI-compatible endpoint** — not Ollama-specific. User provides base URL + optional key.
- **All 3 slots support local models** — including embedding. Dimension validation at index time.
- **AA data: bundled snapshot + manual refresh** — same pattern as existing model metadata.
- **Latency: log + display only** — no auto-routing. Informational in Cost Tracker.
- **Local models: zero cost** — `estimate_cost()` returns $0 when pricing data is unavailable.

## Open Questions

- What AA API endpoint / data format should we target? Need to research the actual Artificial Analytics API.
- Should providers be stored in the DB settings table (JSON blob) or get their own table? Leaning toward settings table for simplicity.
- When a user switches embedding model (especially to a local one with different dimensions), should we auto-prompt to re-index notebooks? The stale index detection from Set A could be extended.
- Should the fast slot have a fallback to the quality model if not configured? (Probably yes — graceful degradation.)

## Next Steps

→ Run `/workflows:plan` to create the phased implementation plan
→ Research Artificial Analytics API format and available data
→ Check if OpenRouter's `/v1/models` response already includes AA-equivalent data
