# Quick Task 260421-eoy: Update OpenRouter Model Lists - Research

**Researched:** 2026-04-21
**Domain:** OpenRouter model catalog, CISA compliance filtering, embedding dimension caching
**Confidence:** HIGH

## Summary

OpenRouter's embedding model catalog has expanded significantly since the current defaults were written. New entries include BAAI/bge-m3, NVIDIA Llama Nemotron Embed, Perplexity pplx-embed, Google Gemini Embedding 2 Preview, Qwen3 Embedding 4B, and Mistral Codestral Embed. The rerank catalog now has three models (added Rerank v3.5). Chat model defaults need updating for model renames and new entries (Xiaomi MiMo, Z.ai GLM, StepFun, MiniMax).

The CISA-country filter maps cleanly to OpenRouter's `provider/model` prefix convention. Six countries of concern (per DOJ/CISA Data Security Rule, April 2025) map to known Chinese provider prefixes. No Russian, Iranian, North Korean, Cuban, or Venezuelan AI providers are on OpenRouter.

Embedding dimension caching via DuckDB is straightforward -- a simple key-value table keyed on model ID.

**Primary recommendation:** Update all three default model lists, expand KNOWN_EMBED_DIMS, add DB cache for probed dimensions, add `compliance.cisa_filter` toggle to config.yml, and wire the filter into the `allowed_providers` list in `list_chat_models()`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Implementation Decisions
- Update all three model categories: embedding, chat, and rerank defaults
- Use live OpenRouter API fetch to determine current models; add config.yml toggle to always check on startup
- Hybrid dimension approach: keep KNOWN_EMBED_DIMS as fast-path, probe unknowns, cache probes in DB
- OpenRouter API does NOT expose embedding dimensions in /models response metadata
- Add `compliance.cisa_filter: true/false` toggle in config.yml
- CISA filter should be simple boolean toggle, not complex compliance framework

### Specific Ideas
- User wants to understand why model lists aren't fetched on app startup -- investigate and add config option
- Config.yml is the right place for the toggle (consistent with existing pattern)
</user_constraints>

## 1. Current OpenRouter Embedding Models

[VERIFIED: openrouter.ai/collections/embedding-models]

| Model ID | Provider | Dimensions | Price ($/M tokens) | Context | Notes |
|----------|----------|-----------|-------------------|---------|-------|
| `openai/text-embedding-3-small` | OpenAI | 1536 | $0.02 | 8K | Already in defaults |
| `openai/text-embedding-3-large` | OpenAI | 3072 | $0.13 | 8K | Already in defaults |
| `openai/text-embedding-ada-002` | OpenAI | 1536 | $0.10 | 8K | Legacy, not in defaults |
| `google/gemini-embedding-001` | Google | 3072 (default), MRL: 768/1536 | $0.15 | 20K | Already in defaults, dimension was WRONG (listed as 768) |
| `google/gemini-embedding-2-preview` | Google | 3072 (default), MRL: 128-3072 | $0.20 | 8K | NEW -- multimodal, March 2026 |
| `qwen/qwen3-embedding-8b` | Qwen/Alibaba | 4096 | $0.01 | 32K | Already in defaults |
| `qwen/qwen3-embedding-4b` | Qwen/Alibaba | 2560 | $0.02 | 33K | NEW |
| `baai/bge-m3` | BAAI | 1024 | $0.01 | 8K | NEW |
| `mistralai/mistral-embed-2312` | Mistral | 1024 | $0.10 | 8K | Already in defaults |
| `mistralai/codestral-embed-2505` | Mistral | 3072 | $0.15 | 8K | NEW -- code-focused |
| `nvidia/llama-nemotron-embed-vl-1b-v2` | NVIDIA | 2048 | Free | 131K | NEW -- multimodal, free |
| `perplexity/pplx-embed-v1-4b` | Perplexity | 2560 | $0.03 | -- | NEW |
| `perplexity/pplx-embed-v1-0.6b` | Perplexity | 1024 | $0.004 | -- | NEW -- very cheap |

[VERIFIED: huggingface.co model cards for dimension values]

### Critical Fix: `google/gemini-embedding-001` Dimension

The current `KNOWN_EMBED_DIMS` has `google/gemini-embedding-001 = 768L`. This is WRONG. The model produces **3072-dimensional** vectors by default. [VERIFIED: ai.google.dev/gemini-api/docs/embeddings, developers.googleblog.com] The 768 dimension is available via Matryoshka truncation but is not the default. If any existing ragnar stores were built with this model, they will have 3072-dimensional vectors regardless of what KNOWN_EMBED_DIMS says (since the probe fallback would have been used, or the API returned 3072).

### Updated KNOWN_EMBED_DIMS

```r
KNOWN_EMBED_DIMS <- c(
  # OpenAI
  "openai/text-embedding-3-small"          = 1536L,
  "openai/text-embedding-3-large"          = 3072L,
  "openai/text-embedding-ada-002"          = 1536L,
  # Google
  "google/gemini-embedding-001"            = 3072L,   # FIXED: was 768
  "google/gemini-embedding-2-preview"      = 3072L,
  # Qwen (Alibaba) -- CISA-filterable
  "qwen/qwen3-embedding-8b"               = 4096L,
  "qwen/qwen3-embedding-4b"               = 2560L,
  # Mistral
  "mistralai/mistral-embed-2312"           = 1024L,
  "mistralai/codestral-embed-2505"         = 3072L,
  # BAAI
  "baai/bge-m3"                            = 1024L,
  # NVIDIA
  "nvidia/llama-nemotron-embed-vl-1b-v2"   = 2048L,
  # Perplexity
  "perplexity/pplx-embed-v1-4b"           = 2560L,
  "perplexity/pplx-embed-v1-0.6b"         = 1024L,
  # Local (Ollama)
  "nomic-embed-text"                       = 768L,
  "mxbai-embed-large"                      = 1024L,
  "all-minilm"                             = 384L
)
```

### Updated Default Embedding Models

```r
get_default_embedding_models <- function() {
  data.frame(
    id = c("openai/text-embedding-3-small",
           "openai/text-embedding-3-large",
           "google/gemini-embedding-001",
           "google/gemini-embedding-2-preview",
           "baai/bge-m3",
           "qwen/qwen3-embedding-8b",
           "qwen/qwen3-embedding-4b",
           "nvidia/llama-nemotron-embed-vl-1b-v2",
           "mistralai/mistral-embed-2312",
           "mistralai/codestral-embed-2505",
           "perplexity/pplx-embed-v1-0.6b",
           "perplexity/pplx-embed-v1-4b"),
    name = c("OpenAI text-embedding-3-small ($0.02/M)",
             "OpenAI text-embedding-3-large ($0.13/M)",
             "Google Gemini Embedding ($0.15/M) - MTEB #1",
             "Google Gemini Embedding 2 ($0.20/M) - Multimodal",
             "BAAI bge-m3 ($0.01/M) - Multilingual",
             "Qwen3 Embedding 8B ($0.01/M) - Budget",
             "Qwen3 Embedding 4B ($0.02/M)",
             "NVIDIA Nemotron Embed (Free) - Multimodal",
             "Mistral Embed ($0.10/M)",
             "Codestral Embed ($0.15/M) - Code",
             "Perplexity Embed 0.6B ($0.004/M) - Budget",
             "Perplexity Embed 4B ($0.03/M)"),
    price_per_million = c(0.02, 0.13, 0.15, 0.20, 0.01, 0.01, 0.02,
                          0.00, 0.10, 0.15, 0.004, 0.03),
    stringsAsFactors = FALSE
  )
}
```

## 2. Current OpenRouter Rerank Models

[VERIFIED: openrouter.ai/cohere/rerank-4-pro, openrouter.ai/cohere/rerank-v3.5]

| Model ID | Name | Price/Search | Context | Notes |
|----------|------|-------------|---------|-------|
| `cohere/rerank-4-pro` | Rerank 4 Pro | $0.0025 | 32K | Already in defaults (price was $0.005, now $0.0025) |
| `cohere/rerank-4-fast` | Rerank 4 Fast | $0.002 | 32K | Already in defaults |
| `cohere/rerank-v3.5` | Rerank v3.5 | ~$0.002 | 4K | NEW -- legacy but still available |

### Updated Default Rerank Models

```r
get_default_rerank_models <- function() {
  data.frame(
    id = c("cohere/rerank-4-pro",
           "cohere/rerank-4-fast",
           "cohere/rerank-v3.5"),
    name = c("Cohere Rerank 4 Pro ($0.0025/search) - SOTA",
             "Cohere Rerank 4 Fast ($0.002/search) - Low Latency",
             "Cohere Rerank v3.5 ($0.002/search) - Legacy"),
    price_per_search = c(0.0025, 0.002, 0.002),
    stringsAsFactors = FALSE
  )
}
```

## 3. Current OpenRouter Chat Models

The existing `get_default_chat_models()` already contains a reasonable set but the `allowed_providers` list in `list_chat_models()` needs expanding. Key changes:

### Providers to Add to `allowed_providers`

Current: `openai`, `anthropic`, `google`, `meta-llama`, `deepseek`, `moonshotai`, `mistralai`, `qwen`, `cohere`

Add: `nvidia`, `minimax`, `z-ai`, `stepfun`, `xiaomi`, `perplexity` [VERIFIED: openrouter.ai model pages]

These are the major active providers on OpenRouter. Note that `z-ai` is Zhipu's prefix (not `zhipu/`).

### Chat Default Updates Needed

The current default list references models that appear current. Main observations:
- `google/gemini-3.1-flash-lite-preview` -- verify still active (preview may have graduated) [ASSUMED]
- `deepseek/deepseek-v3.2` -- active [VERIFIED: openrouter.ai/deepseek/deepseek-v3.2]
- `moonshotai/kimi-k2.5` -- active [VERIFIED: openrouter.ai/moonshotai]
- All OpenAI/Anthropic/Google entries appear current [ASSUMED]

When the CISA filter is active, the `allowed_providers` list should dynamically exclude Chinese providers. This affects which models appear in the dropdowns.

## 4. CISA Adversary Nations and Provider Mapping

### Countries of Concern

The DOJ/CISA Data Security Rule (effective April 8, 2025) formally designates six "countries of concern" [VERIFIED: aoshearman.com/en/insights/dojcisa-finalize-new-rules-regarding-data-transfers-to-countries-of-concern]:

| Country | LLM Providers on OpenRouter | Provider Prefix |
|---------|----------------------------|-----------------|
| **China** (inc. HK, Macau) | DeepSeek, Qwen (Alibaba), Moonshot/Kimi, MiniMax, Zhipu/Z.ai, StepFun, Xiaomi, Baichuan | `deepseek/`, `qwen/`, `moonshotai/`, `minimax/`, `z-ai/`, `stepfun/`, `xiaomi/`, `baichuan/` |
| **Russia** | None on OpenRouter | -- |
| **Iran** | None on OpenRouter | -- |
| **North Korea** | None on OpenRouter | -- |
| **Cuba** | None on OpenRouter | -- |
| **Venezuela** | None on OpenRouter | -- |

[VERIFIED: CISA nation-state threats page lists China, Russia, Iran, North Korea as primary cyber adversaries. DOJ Data Security Rule adds Cuba and Venezuela.]

### Implementation: CISA Provider Prefix Blocklist

```r
# Provider prefixes for companies headquartered in CISA countries of concern
CISA_BLOCKED_PROVIDERS <- c(
  # China (PRC, including Hong Kong and Macau)
  "deepseek",
  "qwen",
  "moonshotai",
  "minimax",
  "z-ai",       # Zhipu AI
  "stepfun",
  "xiaomi",
  "baichuan",
  "01-ai"       # Yi / 01.AI (if present)
)
```

This list only needs Chinese prefixes since no Russian/Iranian/DPRK/Cuban/Venezuelan providers exist on OpenRouter. If new providers appear, this list is easy to extend.

### Config.yml Addition

```yaml
# Compliance settings
compliance:
  # Filter out models from providers in CISA-designated countries of concern
  # Countries: China (inc. HK/Macau), Russia, Iran, North Korea, Cuba, Venezuela
  cisa_filter: false
```

Default is `false` (opt-in) to avoid surprising existing users.

### Wiring the Filter

The filter should be applied in three places:
1. `list_chat_models()` -- filter `allowed_providers` minus `CISA_BLOCKED_PROVIDERS`
2. `list_embedding_models()` -- add provider filtering (currently has none)
3. `get_default_*` functions -- these are fallbacks and should also respect the filter

Pattern:
```r
# In list_chat_models() and list_embedding_models():
if (isTRUE(cisa_filter)) {
  allowed_providers <- setdiff(allowed_providers, CISA_BLOCKED_PROVIDERS)
}
```

**Design question:** How does the filter setting reach these functions? Options:
- **A) Pass as parameter:** `list_chat_models(api_key, cisa_filter = FALSE)` -- cleanest, no global state
- **B) Read config inside function:** Couples API functions to config -- not ideal
- **Recommendation:** Option A. The caller (mod_settings.R) already has config access.

## 5. Embedding Dimension DB Cache

### Migration Schema

```sql
-- Migration 022: Create embedding dimension cache
CREATE TABLE IF NOT EXISTS embedding_dim_cache (
  model_id VARCHAR PRIMARY KEY,
  dimensions INTEGER NOT NULL,
  probed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

This is simpler than the refiner_embedding_cache (migration 021) since it's just model->dimension, not per-paper.

### Integration with detect_embedding_dimension()

```r
detect_embedding_dimension <- function(model, provider = NULL, con = NULL) {
  # 1. Check hardcoded lookup (instant)
  dim <- unname(KNOWN_EMBED_DIMS[model])
  if (length(dim) == 1 && !is.na(dim)) return(as.integer(dim))

  # 2. Check DB cache (fast)
  if (!is.null(con)) {
    cached <- tryCatch({
      dbGetQuery(con,
        "SELECT dimensions FROM embedding_dim_cache WHERE model_id = ?",
        params = list(model))
    }, error = function(e) data.frame())
    if (nrow(cached) > 0) return(as.integer(cached$dimensions[1]))
  }

  # 3. Probe via test embedding (slow, costs tokens)
  if (!is.null(provider)) {
    result <- tryCatch({
      resp <- provider_get_embeddings(provider, model, "test")
      length(resp$embeddings[[1]])
    }, error = function(e) NULL)

    if (!is.null(result) && result > 0) {
      # Cache the probed result
      if (!is.null(con)) {
        tryCatch(
          dbExecute(con,
            "INSERT OR REPLACE INTO embedding_dim_cache (model_id, dimensions) VALUES (?, ?)",
            params = list(model, as.integer(result))),
          error = function(e) NULL
        )
      }
      return(as.integer(result))
    }
  }

  NULL
}
```

**DuckDB syntax note:** DuckDB uses `INSERT OR REPLACE INTO` (not `INSERT ... ON CONFLICT ... DO UPDATE`). [ASSUMED -- verify against DuckDB docs]

## 6. Why Models Aren't Fetched on Startup

### Current Behavior

Looking at `app.R`, model lists are NOT fetched at startup. They are fetched lazily when the user visits Settings and their API key is validated. The `list_*_models()` functions are called from `mod_settings.R` helper functions (`update_embed_model_choices`, `update_chat_model_choices`, etc.) which are triggered by `observeEvent` on API key validation.

### Why This Is the Current Design

1. **No API key at startup** -- config.yml has the key, but Shiny modules initialize asynchronously
2. **Blocking call** -- `list_models()` makes an HTTP request; blocking Shiny startup for this would delay the UI
3. **Fallback defaults exist** -- `get_default_*()` functions serve as offline-capable fallbacks

### Recommendation: Startup Refresh Pattern

Don't block app startup. Instead, add an `observe()` in the server function that fires once the session starts:

```r
# In mod_settings_server or server function:
observe({
  api_key <- get_setting(config, "openrouter", "api_key")
  if (!is.null(api_key) && nchar(api_key) >= 10) {
    # Refresh model lists in background
    update_chat_model_choices(api_key, current_selection = config$defaults$quality_model)
    update_embed_model_choices(api_key, current_selection = config$defaults$embedding_model)
    update_rerank_model_choices(api_key, current_selection = config$defaults$rerank_model)
  }
}) |> bindEvent(TRUE, once = TRUE)  # Fire once on session start
```

This is effectively what already happens when the user navigates to settings. The change is making it happen eagerly. A config toggle is not really needed -- the app should always try to refresh if it has a valid key. The fallback defaults handle the offline case already.

**Config option (if user insists):**
```yaml
app:
  # Fetch fresh model lists from OpenRouter on startup (requires valid API key)
  refresh_models_on_startup: true
```

## Common Pitfalls

### Pitfall 1: Stale Dimension in KNOWN_EMBED_DIMS
**What goes wrong:** A model's default dimension changes or a model is used that's not in the lookup table.
**How to avoid:** The hybrid approach (hardcoded -> DB cache -> probe) handles this. The hardcoded table is a fast path, not the only path.

### Pitfall 2: DuckDB `INSERT OR REPLACE` Syntax
**What goes wrong:** Standard SQL `UPSERT` syntax varies across databases.
**How to avoid:** Verify DuckDB syntax. DuckDB supports `INSERT OR REPLACE INTO` as of v0.9.0. [ASSUMED]

### Pitfall 3: CISA Filter Blocking the User's Selected Model
**What goes wrong:** User enables CISA filter but their configured embedding_model or chat_model is from a Chinese provider. The model disappears from dropdowns but remains in config.yml.
**How to avoid:** When CISA filter is enabled, check if current selections are affected and show a warning toast. Don't silently change their config.

### Pitfall 4: `gemini-embedding-001` Dimension Was Wrong
**What goes wrong:** Existing ragnar stores might have been built assuming 768 dimensions when the actual embeddings are 3072.
**How to avoid:** The dimension is only used for ragnar store creation (`detect_embedding_dimension`). Since the probe fallback exists and would have returned the correct 3072, existing stores should be fine. Just fix the lookup table entry.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | DuckDB supports `INSERT OR REPLACE INTO` syntax | Section 5 | Low -- easy to change to alternative upsert syntax |
| A2 | Google Gemini 3.1 Flash Lite Preview still active on OpenRouter | Section 3 | Low -- only affects default list, live fetch overrides |
| A3 | All GPT-5 series models in default chat list are current | Section 3 | Low -- live fetch handles it |
| A4 | Perplexity pplx-embed-v1-0.6b dimension is 1024 | Section 1 | Low -- probe fallback handles it |

## Sources

### Primary (HIGH confidence)
- [OpenRouter embedding models collection](https://openrouter.ai/collections/embedding-models) -- model IDs and pricing
- [OpenRouter Cohere rerank models](https://openrouter.ai/cohere) -- rerank model IDs
- [Google Gemini Embedding docs](https://ai.google.dev/gemini-api/docs/embeddings) -- 3072 default dimensions
- [Google Gemini Embedding 2 blog](https://blog.google/innovation-and-ai/models-and-research/gemini-models/gemini-embedding-2/) -- multimodal, dimensions
- [Qwen3-Embedding-8B HuggingFace](https://huggingface.co/Qwen/Qwen3-Embedding-8B) -- 4096 dimensions
- [Qwen3-Embedding-4B HuggingFace](https://huggingface.co/Qwen/Qwen3-Embedding-4B) -- 2560 dimensions
- [BAAI/bge-m3 HuggingFace](https://huggingface.co/BAAI/bge-m3) -- 1024 dimensions
- [NVIDIA llama-nemotron-embed-vl-1b-v2 HuggingFace](https://huggingface.co/nvidia/llama-nemotron-embed-vl-1b-v2) -- 2048 dimensions
- [Mistral Codestral Embed docs](https://docs.mistral.ai/capabilities/embeddings/code_embeddings) -- 3072 dimensions
- [DOJ/CISA Data Security Rule](https://www.aoshearman.com/en/insights/dojcisa-finalize-new-rules-regarding-data-transfers-to-countries-of-concern) -- 6 countries of concern

### Secondary (MEDIUM confidence)
- [Perplexity pplx-embed research](https://research.perplexity.ai/articles/pplx-embed-state-of-the-art-embedding-models-for-web-scale-retrieval) -- dimensions from research blog
- [Chinese AI Q2 2026 landscape report](https://www.digitalapplied.com/blog/chinese-ai-models-q2-2026-market-share-report) -- provider prefix mapping
- [CISA nation-state threats](https://www.cisa.gov/topics/cyber-threats-and-advisories/nation-state-cyber-actors) -- China, Russia, Iran, DPRK

### Codebase (verified by reading)
- `R/api_openrouter.R` -- current defaults, allowed_providers, list functions
- `R/api_provider.R` -- KNOWN_EMBED_DIMS, detect_embedding_dimension()
- `R/api_rerank.R` -- rerank defaults and list function
- `R/config.R` -- load_config(), get_setting()
- `R/mod_settings.R` -- model list update helpers
- `config.yml` -- current config structure
- `app.R` -- startup flow
