---
phase: quick-260421-eoy
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - R/api_openrouter.R
  - R/api_provider.R
  - R/api_rerank.R
  - R/db.R
  - config.yml
  - migrations/022_create_embedding_dim_cache.sql
  - tests/testthat/test-api-provider.R
autonomous: true
requirements: [MODEL-UPDATE]

must_haves:
  truths:
    - "KNOWN_EMBED_DIMS contains all 15 models with correct dimensions (gemini-embedding-001 fixed to 3072)"
    - "get_default_embedding_models() returns 12 embedding models (was 5)"
    - "get_default_rerank_models() returns 3 rerank models with corrected pricing"
    - "get_default_chat_models() includes current chat model set"
    - "list_chat_models() allowed_providers includes nvidia, minimax, z-ai, stepfun, xiaomi, perplexity"
    - "list_chat_models() and list_embedding_models() accept cisa_filter parameter and exclude CISA blocked providers when TRUE"
    - "CISA_BLOCKED_PROVIDERS constant contains 9 Chinese provider prefixes"
    - "config.yml has compliance.cisa_filter toggle defaulting to false"
    - "detect_embedding_dimension() checks DB cache before probing and caches probe results"
    - "Migration 022 creates embedding_dim_cache table"
  artifacts:
    - path: "R/api_openrouter.R"
      provides: "Updated embedding/chat/rerank defaults, CISA filter in list functions"
    - path: "R/api_provider.R"
      provides: "Updated KNOWN_EMBED_DIMS, DB-cached detect_embedding_dimension, CISA_BLOCKED_PROVIDERS constant"
    - path: "R/api_rerank.R"
      provides: "Updated rerank defaults with v3.5 and corrected pricing"
    - path: "config.yml"
      provides: "compliance.cisa_filter toggle"
    - path: "migrations/022_create_embedding_dim_cache.sql"
      provides: "DB schema for embedding dimension cache"
  key_links:
    - from: "R/api_provider.R"
      to: "R/api_openrouter.R"
      via: "CISA_BLOCKED_PROVIDERS constant used in list_*_models()"
      pattern: "CISA_BLOCKED_PROVIDERS"
    - from: "R/api_provider.R"
      to: "R/db.R"
      via: "detect_embedding_dimension reads/writes embedding_dim_cache table"
      pattern: "embedding_dim_cache"
---

<objective>
Update all three OpenRouter model category defaults (embedding, chat, rerank), fix the gemini-embedding-001 dimension bug (768 -> 3072), expand KNOWN_EMBED_DIMS to 15 models, add DB-cached embedding dimension probing, add CISA country-of-concern provider filtering toggle, and expand allowed_providers for chat model listing.

Purpose: Stale model defaults mean users see outdated/incomplete model options. The gemini dimension bug could cause silent RAG failures. CISA filter enables compliance-conscious users to exclude adversary-nation providers.

Output: Updated api_openrouter.R, api_provider.R, api_rerank.R, config.yml, new migration 022, updated tests.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/quick/260421-eoy-update-openrouter-model-lists-to-include/260421-eoy-RESEARCH.md
@.planning/quick/260421-eoy-update-openrouter-model-lists-to-include/260421-eoy-CONTEXT.md

<interfaces>
<!-- Key types and contracts the executor needs. Extracted from codebase. -->

From R/api_provider.R (current):
```r
KNOWN_EMBED_DIMS <- c(
  "openai/text-embedding-3-small" = 1536L,
  "openai/text-embedding-3-large" = 3072L,
  "openai/text-embedding-ada-002" = 1536L,
  "google/gemini-embedding-001" = 768L,    # BUG: should be 3072L
  "qwen/qwen3-embedding-8b" = 4096L,
  "mistralai/mistral-embed-2312" = 1024L,
  "nomic-embed-text" = 768L,
  "mxbai-embed-large" = 1024L,
  "all-minilm" = 384L
)

detect_embedding_dimension <- function(model, provider = NULL)
# Returns integer dimension or NULL. Currently: hardcoded lookup -> probe.
# Needs: hardcoded lookup -> DB cache -> probe (with cache-write-back).
```

From R/api_openrouter.R (current signatures):
```r
get_default_embedding_models <- function()   # returns df: id, name, price_per_million
list_embedding_models <- function(api_key)   # returns df: id, name, price_per_million
get_default_chat_models <- function()        # returns df: id, name, context_length, prompt_price, completion_price, tier
list_chat_models <- function(api_key)        # returns df (same cols). Has allowed_providers filter.
```

From R/api_rerank.R (current):
```r
get_default_rerank_models <- function()      # returns df: id, name, price_per_search
list_rerank_models <- function(api_key)      # returns df: id, name, price_per_search
```

From R/db.R (upsert pattern used in this project):
```r
# DuckDB uses INSERT INTO ... ON CONFLICT ... DO UPDATE SET (NOT INSERT OR REPLACE)
dbExecute(con, "INSERT INTO settings (key, value) VALUES (?, ?)
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value", ...)
```

From R/config.R:
```r
get_setting <- function(config, ...)  # Nested key access: get_setting(config, "compliance", "cisa_filter")
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update model defaults, KNOWN_EMBED_DIMS, and add CISA filter infrastructure</name>
  <files>R/api_openrouter.R, R/api_provider.R, R/api_rerank.R, config.yml</files>
  <action>
**R/api_provider.R changes:**

1. Replace `KNOWN_EMBED_DIMS` with the expanded 15-model table from RESEARCH.md Section 1. Critical fix: `google/gemini-embedding-001` changes from `768L` to `3072L`. Add all new models: `google/gemini-embedding-2-preview` = 3072L, `qwen/qwen3-embedding-4b` = 2560L, `baai/bge-m3` = 1024L, `mistralai/codestral-embed-2505` = 3072L, `nvidia/llama-nemotron-embed-vl-1b-v2` = 2048L, `perplexity/pplx-embed-v1-4b` = 2560L, `perplexity/pplx-embed-v1-0.6b` = 1024L. Keep all 3 existing Ollama entries.

2. Add `CISA_BLOCKED_PROVIDERS` constant (character vector) immediately after `KNOWN_EMBED_DIMS`:
```r
CISA_BLOCKED_PROVIDERS <- c(
  "deepseek", "qwen", "moonshotai", "minimax",
  "z-ai", "stepfun", "xiaomi", "baichuan", "01-ai"
)
```
Add a comment: `# Provider prefixes for CISA countries of concern (DOJ Data Security Rule, April 2025)`.

3. Add helper function `filter_cisa_providers()` near the CISA constant:
```r
filter_cisa_providers <- function(provider_ids, cisa_filter = FALSE) {
  if (!isTRUE(cisa_filter)) return(provider_ids)
  prefixes <- paste0("^", CISA_BLOCKED_PROVIDERS, "/")
  blocked <- Reduce(`|`, lapply(prefixes, function(p) grepl(p, provider_ids)))
  provider_ids[!blocked]
}
```
This works on model IDs (e.g., "deepseek/deepseek-v3.2") by checking provider prefix, and also works on bare provider names when used with `setdiff()` on allowed_providers lists.

**R/api_openrouter.R changes:**

4. Replace `get_default_embedding_models()` body with the 12-model table from RESEARCH.md Section 1 (the `get_default_embedding_models` function).

5. Replace `get_default_rerank_models()` -- move this to api_rerank.R changes below.

6. Replace `get_default_chat_models()` body -- keep the existing model IDs and structure but no additions needed per RESEARCH.md (current set is reasonable). Do NOT change this function.

7. In `list_chat_models()`, expand `allowed_providers` vector to add: `"nvidia"`, `"minimax"`, `"z-ai"`, `"stepfun"`, `"xiaomi"`, `"perplexity"`.

8. Add `cisa_filter = FALSE` parameter to `list_chat_models()` signature. After the `allowed_providers` definition, add:
```r
if (isTRUE(cisa_filter)) {
  allowed_providers <- setdiff(allowed_providers, CISA_BLOCKED_PROVIDERS)
}
```

9. Add `cisa_filter = FALSE` parameter to `list_embedding_models()` signature. Before the return at the end (after building `df`), add CISA filtering on the df:
```r
if (isTRUE(cisa_filter) && nrow(df) > 0) {
  df <- df[!sapply(df$id, function(id) {
    provider <- strsplit(id, "/")[[1]][1]
    provider %in% CISA_BLOCKED_PROVIDERS
  }), ]
}
```

**R/api_rerank.R changes:**

10. Update `get_default_rerank_models()` to include 3 models per RESEARCH.md Section 2: add `cohere/rerank-v3.5` with price $0.002. Fix `cohere/rerank-4-pro` price from $0.005 to $0.0025. Update display names to match RESEARCH.md format.

**config.yml changes:**

11. Add a `compliance:` section after the existing `app:` section:
```yaml
# Compliance
compliance:
  # Filter out models from CISA countries of concern (China, Russia, Iran, DPRK, Cuba, Venezuela)
  cisa_filter: false
```
  </action>
  <verify>
    <automated>
Write and run a temp R script that sources api_provider.R and api_openrouter.R and api_rerank.R, then:
- Checks length(KNOWN_EMBED_DIMS) == 15
- Checks KNOWN_EMBED_DIMS["google/gemini-embedding-001"] == 3072L
- Checks nrow(get_default_embedding_models()) == 12
- Checks nrow(get_default_rerank_models()) == 3
- Checks length(CISA_BLOCKED_PROVIDERS) == 9
- Checks "nvidia" %in% the allowed_providers (grep the source)
- Verifies config.yml can be read and compliance.cisa_filter exists
    </automated>
  </verify>
  <done>
- KNOWN_EMBED_DIMS has 15 entries with gemini-embedding-001 at 3072L
- get_default_embedding_models() returns 12 rows
- get_default_rerank_models() returns 3 rows with corrected pricing
- CISA_BLOCKED_PROVIDERS has 9 provider prefixes
- list_chat_models() and list_embedding_models() accept cisa_filter parameter
- list_chat_models() allowed_providers includes 6 new providers
- config.yml has compliance.cisa_filter: false
  </done>
</task>

<task type="auto">
  <name>Task 2: Add DB-cached embedding dimension detection and migration 022</name>
  <files>migrations/022_create_embedding_dim_cache.sql, R/api_provider.R, R/db.R, tests/testthat/test-api-provider.R</files>
  <action>
**Migration file:**

1. Create `migrations/022_create_embedding_dim_cache.sql`:
```sql
CREATE TABLE IF NOT EXISTS embedding_dim_cache (
  model_id VARCHAR PRIMARY KEY,
  dimensions INTEGER NOT NULL,
  probed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**R/api_provider.R changes:**

2. Update `detect_embedding_dimension()` to accept optional `con` parameter (DuckDB connection) as the second param, shifting `provider` to third. New signature: `detect_embedding_dimension(model, con = NULL, provider = NULL)`.

The three-tier lookup:
  a. Check KNOWN_EMBED_DIMS (instant, existing behavior).
  b. If `con` is not NULL, query `embedding_dim_cache` table: `SELECT dimensions FROM embedding_dim_cache WHERE model_id = ?`. If found, return as integer.
  c. If `provider` is not NULL, probe via `provider_get_embeddings(provider, model, "test")` and get `length(resp$embeddings[[1]])`. If successful AND `con` is not NULL, cache the result: `INSERT INTO embedding_dim_cache (model_id, dimensions) VALUES (?, ?) ON CONFLICT (model_id) DO UPDATE SET dimensions = EXCLUDED.dimensions, probed_at = CURRENT_TIMESTAMP`. Return the probed dimension.
  d. Return NULL if all fail.

Wrap DB operations in tryCatch to gracefully handle missing table (pre-migration DBs).

IMPORTANT: Check all call sites of `detect_embedding_dimension()` in the codebase. The signature change (adding `con` before `provider`) must not break existing callers. Since both new params are named with defaults, existing calls using `detect_embedding_dimension(model, provider = p)` will work unchanged. Search for any calls using positional args.

**Tests:**

3. Add tests to `tests/testthat/test-api-provider.R`:
  - Test that `detect_embedding_dimension("openai/text-embedding-3-small")` returns 1536L (hardcoded path).
  - Test that `detect_embedding_dimension("google/gemini-embedding-001")` returns 3072L (the fix).
  - Test that `detect_embedding_dimension("unknown/model")` returns NULL (no provider, no con).
  - Test that `KNOWN_EMBED_DIMS` has 15 entries.
  - Test that `CISA_BLOCKED_PROVIDERS` has 9 entries.
  - Test `filter_cisa_providers()`: given a vector of model IDs, verify it removes deepseek/ and qwen/ prefixed models when cisa_filter=TRUE, and passes all through when FALSE.
  </action>
  <verify>
    <automated>"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-api-provider.R')"</automated>
  </verify>
  <done>
- Migration 022 SQL file exists and creates embedding_dim_cache table
- detect_embedding_dimension() has 3-tier lookup: hardcoded -> DB cache -> probe with write-back
- All existing callers of detect_embedding_dimension() still work (named args)
- Tests pass: hardcoded lookup returns correct values, CISA filter works, unknown model returns NULL
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| config.yml -> filter functions | User-controlled config value drives provider filtering |
| OpenRouter API -> model lists | Untrusted external response populates UI dropdowns |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-quick-01 | Tampering | CISA_BLOCKED_PROVIDERS | accept | Hardcoded constant, not user-modifiable; only affects UI filtering, not API calls |
| T-quick-02 | Information Disclosure | embedding_dim_cache | accept | Stores only model_id + dimension integer, no sensitive data |
| T-quick-03 | Spoofing | OpenRouter /models response | accept | Existing behavior unchanged; fallback defaults protect against empty/malicious responses |
</threat_model>

<verification>
1. Run full test suite: `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"`
2. Verify KNOWN_EMBED_DIMS["google/gemini-embedding-001"] == 3072L (the critical fix)
3. Verify config.yml parses cleanly: `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "yaml::read_yaml('config.yml')"`
4. Verify migration 022 file exists and has valid SQL
5. Shiny smoke test: start app, verify it loads without errors
</verification>

<success_criteria>
- All 15 KNOWN_EMBED_DIMS entries present with correct values
- gemini-embedding-001 dimension fixed from 768 to 3072
- 12 default embedding models, 3 default rerank models
- CISA filter toggle in config.yml, wired into list_chat_models() and list_embedding_models()
- DB-cached dimension probing via migration 022 table
- Existing tests pass, new tests for dimension lookup and CISA filter pass
- App starts without errors (Shiny smoke test)
</success_criteria>

<output>
After completion, create `.planning/quick/260421-eoy-update-openrouter-model-lists-to-include/260421-eoy-SUMMARY.md`
</output>
