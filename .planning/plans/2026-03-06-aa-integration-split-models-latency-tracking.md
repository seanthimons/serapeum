# Design: AA Integration + Split Models + Latency Tracking

**Date:** 2026-03-06
**Status:** Draft — awaiting review
**Branch:** TBD (suggest `feature/model-quality-pipeline`)

---

## Problem Statement

Kimi K2.5 (`moonshotai/kimi-k2.5`) is the current default chat model for all LLM operations in Serapeum. It sits at the budget/mid-tier boundary ($0.45/M input, $2.25/M output) and is underperforming on synthesis tasks — gap analysis reports, literature review tables, overview generation, methodology extraction, conclusion synthesis, and research question generation. These are the app's highest-value LLM operations, requiring multi-document reasoning and structured output formatting.

The app currently has:
- **No quality benchmarking** of models — tier assignment is purely price-based
- **No latency/TPS tracking** — users can't see how fast models respond
- **A single model setting** for all tasks — the same model handles casual chat AND complex synthesis

This design addresses all three gaps.

---

## Solution Overview

Three interconnected features, implemented in 5 sequential phases:

1. **Database migration** — schema changes for latency columns and AA cache table
2. **Per-request latency tracking** — instrument `chat_completion()`, extend `log_cost()`, update all call sites
3. **Latency display in cost tracker** — performance value box + table columns
4. **Artificial Analysis API client** — fetch/cache model quality benchmarks from artificialanalysis.ai
5. **Split chat vs synthesis model** — two Settings dropdowns, synthesis filtered to quality-capable models

---

## Phase 1: Database Migration

### File to create: `migrations/011_add_response_time_and_aa_cache.sql`

This is a single migration file that adds all schema changes needed by phases 2-5. It will be automatically executed on next app startup by `run_pending_migrations()` in `R/db_migrations.R`, which is called from `get_db_connection()` in `R/db.R`.

The migration system tracks applied migrations in a `schema_migrations` table. The previous migration is `010_add_multi_seed_support.sql`.

#### SQL Content

```sql
-- ============================================================
-- Migration 011: Response time tracking + AA model quality cache
-- ============================================================

-- 1. Add latency tracking columns to cost_log
--    These columns are populated by the updated log_cost() function.
--    Existing rows get DEFAULT 0 values (no data loss).
ALTER TABLE cost_log ADD COLUMN response_time_ms INTEGER DEFAULT 0;
ALTER TABLE cost_log ADD COLUMN tokens_per_second DOUBLE DEFAULT 0.0;

-- 2. Artificial Analysis model quality cache
--    Stores benchmark data fetched from the AA API.
--    model_id uses OpenRouter-style IDs (e.g., "anthropic/claude-sonnet-4.5")
--    so we can join directly with OpenRouter model listings.
CREATE TABLE IF NOT EXISTS aa_model_cache (
  model_id VARCHAR PRIMARY KEY,
  model_name VARCHAR,
  intelligence_index DOUBLE,
  median_tps DOUBLE,
  median_ttft DOUBLE,
  blended_price DOUBLE,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Why no migration for settings keys?

The `settings` table is a generic key-value store. New keys like `aa_api_key` and `synthesis_model` are simply inserted via the existing `save_db_setting()` function — no schema change needed.

#### Verification

After the migration runs:
```sql
DESCRIBE cost_log;
-- Should show response_time_ms (INTEGER) and tokens_per_second (DOUBLE)

SELECT * FROM aa_model_cache;
-- Should return empty result set (0 rows)

SELECT * FROM schema_migrations WHERE name = '011_add_response_time_and_aa_cache';
-- Should return 1 row showing the migration was applied
```

---

## Phase 2: Per-Request Latency Backend

This phase has zero UI dependencies and touches only backend code. It's independently testable.

### Step 2a: Instrument `chat_completion()` in `R/api_openrouter.R`

**Current code (lines 37-63):**
```r
chat_completion <- function(api_key, model, messages) {
  req <- build_openrouter_request(api_key, "chat/completions") |>
    req_body_json(list(
      model = model,
      messages = messages
    )) |>
    req_timeout(120)

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop_api_error(e, "OpenRouter")
  })

  body <- resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("OpenRouter error: ", body$error$message)
  }

  list(
    content = body$choices[[1]]$message$content,
    usage = body$usage,
    model = model,
    id = body$id
  )
}
```

**Modified code:**
```r
chat_completion <- function(api_key, model, messages) {
  req <- build_openrouter_request(api_key, "chat/completions") |>
    req_body_json(list(
      model = model,
      messages = messages
    )) |>
    req_timeout(120)

  start_time <- Sys.time()

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop_api_error(e, "OpenRouter")
  })

  elapsed_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000

  body <- resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("OpenRouter error: ", body$error$message)
  }

  list(
    content = body$choices[[1]]$message$content,
    usage = body$usage,
    model = model,
    id = body$id,
    response_time_ms = round(elapsed_ms)
  )
}
```

**Changes:**
- Added `start_time <- Sys.time()` before the `req_perform()` call
- Added `elapsed_ms` calculation after the response
- Added `response_time_ms = round(elapsed_ms)` to the returned list

**Same pattern for `get_embeddings()` (lines 70-95):**
```r
get_embeddings <- function(api_key, model, text) {
  req <- build_openrouter_request(api_key, "embeddings") |>
    req_body_json(list(
      model = model,
      input = as.list(text)
    )) |>
    req_timeout(60)

  start_time <- Sys.time()

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop_api_error(e, "OpenRouter")
  })

  elapsed_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000

  body <- resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("OpenRouter error: ", body$error$message)
  }

  list(
    embeddings = lapply(body$data, function(x) unlist(x$embedding)),
    usage = body$usage,
    model = model,
    response_time_ms = round(elapsed_ms)
  )
}
```

### Step 2b: Extend `log_cost()` in `R/cost_tracking.R`

**Current code (lines 73-97):**
```r
log_cost <- function(con, operation, model, prompt_tokens, completion_tokens = 0,
                     total_tokens = NULL, estimated_cost, session_id) {
  id <- UUIDgenerate()

  if (is.null(total_tokens)) {
    total_tokens <- prompt_tokens + completion_tokens
  }

  dbExecute(con, "
    INSERT INTO cost_log (id, session_id, operation, model, prompt_tokens, completion_tokens, total_tokens, estimated_cost)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  ", list(
    id, session_id, operation, model,
    as.integer(prompt_tokens), as.integer(completion_tokens),
    as.integer(total_tokens), as.numeric(estimated_cost)
  ))

  id
}
```

**Modified code:**
```r
log_cost <- function(con, operation, model, prompt_tokens, completion_tokens = 0,
                     total_tokens = NULL, estimated_cost, session_id,
                     response_time_ms = 0) {
  id <- UUIDgenerate()

  if (is.null(total_tokens)) {
    total_tokens <- prompt_tokens + completion_tokens
  }

  # Calculate tokens per second (output tokens only, since that's what TPS measures)
  tokens_per_second <- if (response_time_ms > 0 && completion_tokens > 0) {
    completion_tokens / (response_time_ms / 1000)
  } else {
    0.0
  }

  dbExecute(con, "
    INSERT INTO cost_log (id, session_id, operation, model, prompt_tokens,
                          completion_tokens, total_tokens, estimated_cost,
                          response_time_ms, tokens_per_second)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ", list(
    id, session_id, operation, model,
    as.integer(prompt_tokens), as.integer(completion_tokens),
    as.integer(total_tokens), as.numeric(estimated_cost),
    as.integer(response_time_ms), as.numeric(tokens_per_second)
  ))

  id
}
```

**Key decisions:**
- `response_time_ms = 0` default makes this backward-compatible — any call site that doesn't pass it still works
- TPS is calculated from `completion_tokens` (not `total_tokens`) because TPS conventionally measures output generation speed
- Division-by-zero is guarded with the conditional

### Step 2c: Update `get_session_costs()` in `R/cost_tracking.R`

**Current SELECT (line 106):**
```sql
SELECT operation, model, prompt_tokens, completion_tokens, total_tokens, estimated_cost, created_at
FROM cost_log WHERE session_id = ? ORDER BY created_at DESC
```

**Updated SELECT:**
```sql
SELECT operation, model, prompt_tokens, completion_tokens, total_tokens,
       estimated_cost, response_time_ms, tokens_per_second, created_at
FROM cost_log WHERE session_id = ? ORDER BY created_at DESC
```

### Step 2d: Add `get_session_performance()` in `R/cost_tracking.R`

Add this new function after `get_session_costs()`:

```r
#' Get performance metrics for a session
#'
#' @param con DuckDB connection
#' @param session_id Shiny session ID
#' @return Data frame with avg_response_ms, avg_tps, max_tps, request_count
get_session_performance <- function(con, session_id) {
  dbGetQuery(con, "
    SELECT
      AVG(response_time_ms) as avg_response_ms,
      AVG(tokens_per_second) as avg_tps,
      MAX(tokens_per_second) as max_tps,
      COUNT(*) as request_count
    FROM cost_log
    WHERE session_id = ? AND response_time_ms > 0
  ", list(session_id))
}
```

### Step 2e: Update all 13 `log_cost()` call sites

Every call site follows the same pattern. Here's the exact change for each:

#### `R/rag.R` — 10 call sites

**Pattern (example from `rag_query()`, line 123):**

Before:
```r
log_cost(con, "chat", chat_model,
         result$usage$prompt_tokens %||% 0,
         result$usage$completion_tokens %||% 0,
         result$usage$total_tokens %||% 0,
         cost, session_id)
```

After:
```r
log_cost(con, "chat", chat_model,
         result$usage$prompt_tokens %||% 0,
         result$usage$completion_tokens %||% 0,
         result$usage$total_tokens %||% 0,
         cost, session_id,
         response_time_ms = result$response_time_ms %||% 0)
```

Apply the same `response_time_ms = result$response_time_ms %||% 0` addition to ALL of these:

| Function | Line | Operation logged |
|----------|------|------------------|
| `rag_query()` | ~123 | `"chat"` |
| `generate_preset()` | ~221 | `"chat"` |
| `generate_conclusions_preset()` | ~396 | `"conclusion_synthesis"` |
| `generate_overview_preset()` / quick | ~548 | `"overview"` |
| `generate_overview_preset()` / summary | ~577 | `"overview_summary"` |
| `generate_overview_preset()` / keypoints | ~604 | `"overview_keypoints"` |
| `generate_research_questions()` | ~817 | `"research_questions"` |
| `generate_lit_review_table()` | ~1027 | `"lit_review_table"` |
| `generate_methodology_extractor()` | ~1231 | `"methodology_extractor"` |
| `generate_gap_analysis()` | ~1461 | `"gap_analysis"` |

#### `R/mod_query_builder.R` — 1 call site (line ~100)

Before:
```r
log_cost(con(), "query_build", model,
         result$usage$prompt_tokens %||% 0,
         result$usage$completion_tokens %||% 0,
         result$usage$total_tokens %||% 0,
         cost, session$token)
```

After:
```r
log_cost(con(), "query_build", model,
         result$usage$prompt_tokens %||% 0,
         result$usage$completion_tokens %||% 0,
         result$usage$total_tokens %||% 0,
         cost, session$token,
         response_time_ms = result$response_time_ms %||% 0)
```

#### `R/slides.R` — 2 call sites (lines ~283 and ~437)

Same pattern — add `response_time_ms = result$response_time_ms %||% 0` to each `log_cost()` call.

### Phase 2 Verification

```r
# After making a chat query in the app:
con <- DBI::dbConnect(duckdb::duckdb(), "serapeum.duckdb")
DBI::dbGetQuery(con, "
  SELECT operation, model, response_time_ms, tokens_per_second
  FROM cost_log
  ORDER BY created_at DESC
  LIMIT 5
")
# Expected: response_time_ms > 0 (e.g., 3500 for 3.5 seconds)
#           tokens_per_second > 0 (e.g., 45.2 for 45 tok/s)
```

---

## Phase 3: Latency Display in Cost Tracker

### Step 3a: Add icon to `R/theme_catppuccin.R`

Add after the last icon definition (currently around line 487):

```r
icon_bolt <- function(...) shiny::icon("bolt", ...)
```

### Step 3b: Add Performance value_box to UI in `R/mod_cost_tracker.R`

**Current UI (lines 13-20):**
```r
value_box(
  title = "Session Cost",
  value = textOutput(ns("session_total"), inline = TRUE),
  showcase = icon_dollar(),
  showcase_layout = "left center",
  theme = "primary"
),
```

**Add after that value_box (before the `hr()` on line 21):**
```r
uiOutput(ns("performance_card")),
```

### Step 3c: Add performance card server logic in `R/mod_cost_tracker.R`

Add after the `session_total` reactive (around line 99):

```r
# Session performance reactive
session_performance <- reactive({
  session_timer()
  req(con_r(), session_id_r())
  get_session_performance(con_r(), session_id_r())
})

output$performance_card <- renderUI({
  perf <- session_performance()
  req(perf$request_count > 0)

  value_box(
    title = "Avg Performance",
    value = sprintf("%.0f tok/s", perf$avg_tps),
    showcase = icon_bolt(),
    showcase_layout = "left center",
    theme = "info",
    p(class = "small mb-0",
      sprintf("%.1fs avg response | %d requests",
              perf$avg_response_ms / 1000,
              perf$request_count))
  )
})
```

### Step 3d: Add columns to Recent Requests table

**Current table columns (lines 147-169):**
```r
data.frame(
  Time = ...,
  Operation = ...,
  Model = ...,
  Tokens = df$total_tokens,
  Cost = sprintf("$%.4f", df$estimated_cost),
  stringsAsFactors = FALSE
)
```

**Updated with two new columns:**
```r
data.frame(
  Time = ...,
  Operation = ...,
  Model = ...,
  Tokens = df$total_tokens,
  Cost = sprintf("$%.4f", df$estimated_cost),
  `Time (s)` = ifelse(df$response_time_ms > 0,
                      sprintf("%.1f", df$response_time_ms / 1000), "-"),
  TPS = ifelse(df$tokens_per_second > 0,
               sprintf("%.0f", df$tokens_per_second), "-"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
```

### Step 3e: Update operation label switch for new synthesis operations

The existing `switch()` in `renderTable` (line 155) and `cost_by_operation` (line 206) should be extended:

```r
switch(op,
  "chat" = "\U1F4AC Chat",
  "embedding" = "\U1F9E0 Embed",
  "query_build" = "\U2728 Query",
  "slide_generation" = "\U1F4CA Slides",
  "slide_healing" = "\U1F527 Slide Fix",
  "overview" = "\U1F4DD Overview",
  "overview_summary" = "\U1F4DD Summary",
  "overview_keypoints" = "\U1F4DD Key Points",
  "conclusion_synthesis" = "\U1F52C Conclusions",
  "research_questions" = "\U2753 Research Qs",
  "lit_review_table" = "\U1F4CA Lit Review",
  "methodology_extractor" = "\U1F52C Methods",
  "gap_analysis" = "\U1F50D Gap Analysis",
  op)
```

### Phase 3 Verification

1. Start the app
2. Make a few chat queries and/or run a preset
3. Navigate to Cost Tracker tab
4. Verify: Performance value box shows avg TPS and response time
5. Verify: Recent Requests table has "Time (s)" and "TPS" columns with non-zero values

---

## Phase 4: Artificial Analysis API Client

### File to create: `R/api_artificial_analysis.R`

This is a standalone module. It depends only on `httr2`, `jsonlite`, and `DBI` (all already loaded by the app).

```r
library(httr2)
library(jsonlite)

AA_BASE_URL <- "https://artificialanalysis.ai/api/v2"
AA_CACHE_TTL_HOURS <- 24

# ─── Hardcoded ID mapping ───────────────────────────────────────────
# Maps AA model names/slugs to OpenRouter model IDs.
# This is necessary because AA uses display names while OpenRouter uses
# provider/model-slug format. Only models from our curated provider list
# are mapped. The mapping is maintained manually — when new models are
# added to get_default_chat_models(), add them here too.

AA_TO_OPENROUTER_MAP <- list(
  # OpenAI
  "GPT-4.1 Mini"       = "openai/gpt-4.1-mini",
  "GPT-5 Mini"         = "openai/gpt-5-mini",
  "GPT-5"              = "openai/gpt-5",
  "GPT-5.2"            = "openai/gpt-5.2",
  # Anthropic
  "Claude Haiku 4.5"   = "anthropic/claude-haiku-4.5",
  "Claude Sonnet 4.5"  = "anthropic/claude-sonnet-4.5",
  # Google
  "Gemini 2.5 Flash"   = "google/gemini-2.5-flash",
  "Gemini 2.5 Pro"     = "google/gemini-2.5-pro",
  "Gemini 3 Pro"       = "google/gemini-3-pro-preview",
  # DeepSeek
  "DeepSeek V3.2"      = "deepseek/deepseek-v3.2",
  # Moonshot
  "Kimi K2.5"          = "moonshotai/kimi-k2.5"
)

#' Attempt to map an AA model name to an OpenRouter model ID
#' @param aa_name Model name from AA API response
#' @return OpenRouter-style model ID string, or NA if unmapped
map_aa_to_openrouter_id <- function(aa_name) {
  # Try exact match first
  mapped <- AA_TO_OPENROUTER_MAP[[aa_name]]
  if (!is.null(mapped)) return(mapped)

  # Try case-insensitive match
  for (key in names(AA_TO_OPENROUTER_MAP)) {
    if (tolower(key) == tolower(aa_name)) {
      return(AA_TO_OPENROUTER_MAP[[key]])
    }
  }

  NA_character_
}

#' Fetch model benchmarks from Artificial Analysis API
#'
#' @param api_key AA API key
#' @return Data frame with columns: model_id, model_name, intelligence_index,
#'   median_tps, median_ttft, blended_price. Returns NULL on error.
fetch_aa_models <- function(api_key) {
  if (is.null(api_key) || nchar(trimws(api_key)) == 0) return(NULL)

  tryCatch({
    resp <- request(paste0(AA_BASE_URL, "/data/llms/models")) |>
      req_headers("x-api-key" = api_key) |>
      req_timeout(30) |>
      req_perform()

    body <- resp_body_json(resp)

    # body should be a list of model objects
    if (!is.list(body) || length(body) == 0) return(NULL)

    # Extract and normalize each model
    rows <- lapply(body, function(m) {
      aa_name <- m$name %||% ""
      openrouter_id <- map_aa_to_openrouter_id(aa_name)

      # Skip models we can't map to OpenRouter
      if (is.na(openrouter_id)) return(NULL)

      data.frame(
        model_id = openrouter_id,
        model_name = aa_name,
        intelligence_index = as.numeric(m$intelligence_index %||% NA),
        median_tps = as.numeric(m$median_output_tokens_per_second %||% NA),
        median_ttft = as.numeric(m$median_time_to_first_token_seconds %||% NA),
        blended_price = as.numeric(m$pricing$blended %||% NA),
        stringsAsFactors = FALSE
      )
    })

    # Remove NULLs and bind
    rows <- Filter(Negate(is.null), rows)
    if (length(rows) == 0) return(NULL)

    do.call(rbind, rows)
  }, error = function(e) {
    message("[fetch_aa_models] AA API error: ", e$message)
    NULL
  })
}

#' Cache AA model data to database
#'
#' @param con DuckDB connection
#' @param models_df Data frame from fetch_aa_models()
#' @return invisible(NULL)
cache_aa_models <- function(con, models_df) {
  if (is.null(models_df) || nrow(models_df) == 0) return(invisible(NULL))

  # DuckDB lacks native UPSERT, so DELETE + INSERT
  for (i in seq_len(nrow(models_df))) {
    row <- models_df[i, ]
    dbExecute(con, "DELETE FROM aa_model_cache WHERE model_id = ?",
              list(row$model_id))
    dbExecute(con, "
      INSERT INTO aa_model_cache (model_id, model_name, intelligence_index,
                                   median_tps, median_ttft, blended_price, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ", list(
      row$model_id, row$model_name,
      as.numeric(row$intelligence_index),
      as.numeric(row$median_tps),
      as.numeric(row$median_ttft),
      as.numeric(row$blended_price)
    ))
  }

  invisible(NULL)
}

#' Get cached AA model data from database
#'
#' @param con DuckDB connection
#' @return Data frame from aa_model_cache, or empty data.frame
get_cached_aa_models <- function(con) {
  tryCatch({
    dbGetQuery(con, "SELECT * FROM aa_model_cache")
  }, error = function(e) {
    data.frame()
  })
}

#' Check if AA cache is stale (older than TTL)
#'
#' @param con DuckDB connection
#' @return TRUE if cache is empty or oldest entry is > AA_CACHE_TTL_HOURS old
is_aa_cache_stale <- function(con) {
  tryCatch({
    result <- dbGetQuery(con, "
      SELECT MIN(updated_at) as oldest
      FROM aa_model_cache
    ")
    if (nrow(result) == 0 || is.na(result$oldest[1])) return(TRUE)
    age_hours <- as.numeric(difftime(Sys.time(), result$oldest[1], units = "hours"))
    age_hours > AA_CACHE_TTL_HOURS
  }, error = function(e) {
    TRUE
  })
}

#' Refresh AA cache if stale, then return cached data
#'
#' @param con DuckDB connection
#' @param api_key AA API key (can be NULL)
#' @return Data frame of AA model data, or empty data.frame
refresh_aa_cache <- function(con, api_key = NULL) {
  if (!is.null(api_key) && nchar(trimws(api_key)) > 0) {
    if (is_aa_cache_stale(con)) {
      fresh <- fetch_aa_models(api_key)
      if (!is.null(fresh) && nrow(fresh) > 0) {
        cache_aa_models(con, fresh)
      }
    }
  }

  get_cached_aa_models(con)
}

#' Get AA enrichment data (main entry point for model listing)
#'
#' Graceful degradation chain:
#' 1. AA key + API reachable -> fresh data, cached
#' 2. No key or API error -> cached data from DB
#' 3. No cache -> empty data.frame (callers work without AA data)
#'
#' @param con DuckDB connection
#' @param api_key AA API key (optional, can be NULL)
#' @return Data frame with model_id, intelligence_index, median_tps, etc.
get_aa_enrichment <- function(con, api_key = NULL) {
  tryCatch({
    refresh_aa_cache(con, api_key)
  }, error = function(e) {
    message("[get_aa_enrichment] Error: ", e$message)
    # Final fallback: try reading cache even if refresh failed
    tryCatch(get_cached_aa_models(con), error = function(e2) data.frame())
  })
}
```

### Important notes on the AA API response

The exact field names in the AA API response need to be verified at implementation time. Based on their documentation:
- `intelligence_index` — a composite quality score (0-57 range observed in leaderboard)
- `median_output_tokens_per_second` — output TPS
- `median_time_to_first_token_seconds` — TTFT

The response structure may be `body$data` (list of models) rather than `body` directly. The `fetch_aa_models()` function should be adjusted after testing with a real API key to match the actual response shape.

### Model ID mapping maintenance

The `AA_TO_OPENROUTER_MAP` must be updated when:
- New models are added to `get_default_chat_models()` in `R/api_openrouter.R`
- AA changes model naming conventions

This is a manual maintenance burden but limited to ~15 models.

### Phase 4 Verification

```r
# Unit test with in-memory DuckDB
con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
DBI::dbExecute(con, "CREATE TABLE aa_model_cache (...)")  # from migration

# Test cache round-trip
test_df <- data.frame(
  model_id = "anthropic/claude-sonnet-4.5",
  model_name = "Claude Sonnet 4.5",
  intelligence_index = 52,
  median_tps = 120,
  median_ttft = 0.8,
  blended_price = 6.0,
  stringsAsFactors = FALSE
)
cache_aa_models(con, test_df)
cached <- get_cached_aa_models(con)
stopifnot(nrow(cached) == 1)
stopifnot(cached$intelligence_index == 52)

# Test staleness
stopifnot(!is_aa_cache_stale(con))  # just cached, should not be stale
```

---

## Phase 5: Split Chat vs Synthesis Model

### Step 5a: Add `icon_gauge` to `R/theme_catppuccin.R`

```r
icon_gauge <- function(...) shiny::icon("gauge-high", ...)
```

(Used for the synthesis model info panel. `icon_flask` already exists and will be used for the section header.)

### Step 5b: Add synthesis model filtering to `R/api_openrouter.R`

Add after `format_chat_model_choices()` (line 387):

```r
#' Filter chat models to synthesis-capable subset
#'
#' When AA enrichment data is available, filters to models with
#' intelligence_index >= threshold. Otherwise, falls back to
#' tier-based filtering (mid + premium only).
#'
#' @param chat_models_df Data frame from list_chat_models() or get_default_chat_models()
#' @param aa_data Data frame from get_aa_enrichment() (may be empty/NULL)
#' @param intelligence_threshold Minimum AA intelligence index (default 40)
#' @return Filtered data frame of synthesis-capable models
get_synthesis_models <- function(chat_models_df, aa_data = data.frame(),
                                 intelligence_threshold = 40) {
  if (!is.null(aa_data) && is.data.frame(aa_data) && nrow(aa_data) > 0) {
    # Merge AA data with chat models
    merged <- merge(chat_models_df, aa_data[, c("model_id", "intelligence_index")],
                    by.x = "id", by.y = "model_id", all.x = TRUE)
    # Filter: has intelligence_index >= threshold
    qualified <- merged[!is.na(merged$intelligence_index) &
                        merged$intelligence_index >= intelligence_threshold, ]
    if (nrow(qualified) > 0) {
      # Drop the intelligence_index column from the result (it's used for filtering only)
      # Actually keep it for display in format_synthesis_model_choices
      return(qualified)
    }
  }

  # Fallback: tier-based filtering (mid + premium only)
  chat_models_df[chat_models_df$tier %in% c("mid", "premium"), ]
}

#' Format synthesis model choices for selectizeInput
#'
#' Like format_chat_model_choices() but includes intelligence_index when available.
#'
#' @param models_df Data frame from get_synthesis_models()
#' @return Named character vector (names = display labels, values = model IDs)
format_synthesis_model_choices <- function(models_df) {
  tier_icons <- c("budget" = "$", "mid" = "$$", "premium" = "$$$")

  labels <- sapply(1:nrow(models_df), function(i) {
    row <- models_df[i, ]

    # Format context length
    ctx <- if (row$context_length >= 1000000) {
      sprintf("%.1fM", row$context_length / 1000000)
    } else {
      sprintf("%dk", round(row$context_length / 1000))
    }

    # Include intelligence index if available
    iq_str <- if ("intelligence_index" %in% names(row) && !is.na(row$intelligence_index)) {
      sprintf("IQ: %.0f, ", row$intelligence_index)
    } else {
      ""
    }

    sprintf("[%s] %s (%sctx: %s, $%.2f/M in, $%.2f/M out)",
            tier_icons[row$tier],
            row$name,
            iq_str,
            ctx,
            row$prompt_price,
            row$completion_price)
  })

  setNames(models_df$id, labels)
}
```

### Step 5c: Add AA API key field to Settings UI (`R/mod_settings.R`)

In the left column, after the OpenAlex email section (after line ~45, before the `hr()` that precedes "Advanced"):

```r
hr(),
div(
  class = "d-flex align-items-end gap-2",
  div(
    style = "flex-grow: 1;",
    textInput(ns("aa_api_key"), "Artificial Analysis API Key (Optional)",
              placeholder = "aa-...")
  ),
  uiOutput(ns("aa_status"))
),
p(class = "text-muted small",
  "Optional. Enriches model selection with quality benchmarks from ",
  tags$a(href = "https://artificialanalysis.ai",
         target = "_blank", "artificialanalysis.ai"),
  ". Data is cached locally for 24 hours."),
```

### Step 5d: Add synthesis model dropdown to Settings UI (`R/mod_settings.R`)

In the right column, after the chat model info panel and before "Quality Data" section. Insert after `uiOutput(ns("model_info"))` (around line 92):

```r
hr(),
h5(icon_flask(), " Synthesis Model"),
p(class = "text-muted small",
  "Used for quality-sensitive tasks: overviews, gap analysis, lit review tables, ",
  "methodology extraction, and research questions. Filtered to high-capability models. ",
  "If unset, falls back to the Chat Model above."),
div(
  class = "d-flex align-items-end gap-2",
  div(
    style = "flex-grow: 1;",
    selectizeInput(ns("synthesis_model"), "Synthesis Model",
                   choices = NULL)
  ),
  actionButton(ns("refresh_synthesis_models"), NULL,
               icon = icon_refresh(),
               class = "btn-outline-secondary btn-sm mb-3",
               title = "Refresh synthesis model list")
),
uiOutput(ns("synthesis_model_info")),
```

### Step 5e: Wire up settings server logic (`R/mod_settings.R`)

This is the most complex part. Here are all the server-side changes:

#### Add new reactive values (near line 150):

```r
# Store synthesis models data for info panel
synthesis_models_data <- reactiveVal(NULL)
# Store AA enrichment data
aa_enrichment_data <- reactiveVal(data.frame())
```

#### Add AA key validation helper (near the other validation helpers):

```r
validate_and_update_aa_status <- function(key) {
  if (is.null(key) || nchar(key) == 0) {
    api_status$aa <- list(status = "empty", message = "No API key (optional)")
  } else {
    api_status$aa <- list(status = "validating", message = "Checking...")

    result <- tryCatch({
      models <- fetch_aa_models(key)
      if (!is.null(models) && nrow(models) > 0) {
        list(valid = TRUE, count = nrow(models))
      } else {
        list(valid = FALSE, error = "No models returned")
      }
    }, error = function(e) {
      list(valid = FALSE, error = e$message)
    })

    api_status$aa <- if (isTRUE(result$valid)) {
      list(status = "valid", message = sprintf("Found %d models", result$count))
    } else {
      list(status = "invalid", message = result$error %||% "Validation failed")
    }
  }
}
```

#### Add `update_synthesis_model_choices()` helper:

```r
update_synthesis_model_choices <- function(chat_models, aa_data, current_selection = NULL) {
  synthesis_models <- get_synthesis_models(chat_models, aa_data)

  if (is.null(synthesis_models) || nrow(synthesis_models) == 0) {
    synthesis_models <- chat_models[chat_models$tier %in% c("mid", "premium"), ]
  }

  synthesis_models_data(synthesis_models)

  choices <- format_synthesis_model_choices(synthesis_models)

  selected <- if (!is.null(current_selection) && current_selection %in% choices) {
    current_selection
  } else if (length(choices) > 0) {
    choices[[1]]
  } else {
    NULL
  }

  updateSelectizeInput(session, "synthesis_model",
                       choices = choices,
                       selected = selected)
}
```

#### Update the init observe block (~line 286) to load AA and synthesis settings:

After the chat model init:
```r
# AA API key
aa_key <- get_db_setting(con(), "aa_api_key") %||% ""
updateTextInput(session, "aa_api_key", value = aa_key)
validate_and_update_aa_status(aa_key)

# AA enrichment data
aa_data <- get_aa_enrichment(con(), if (nchar(aa_key) > 0) aa_key else NULL)
aa_enrichment_data(aa_data)

# Synthesis model
synthesis_model <- get_db_setting(con(), "synthesis_model") %||% chat_model
# Need chat models to be loaded first
chat_models <- chat_models_data()
if (!is.null(chat_models)) {
  update_synthesis_model_choices(chat_models, aa_data, synthesis_model)
}
```

#### Add observer to refresh synthesis models when chat models or AA data change:

```r
# Re-populate synthesis models when chat models or AA data update
observe({
  chat_models <- chat_models_data()
  aa_data <- aa_enrichment_data()
  req(chat_models)
  current <- input$synthesis_model
  update_synthesis_model_choices(chat_models, aa_data, current)
})
```

#### Handle synthesis model refresh button:

```r
observeEvent(input$refresh_synthesis_models, {
  # Also refresh AA data
  aa_key <- input$aa_api_key
  if (!is.null(aa_key) && nchar(aa_key) > 0) {
    aa_data <- refresh_aa_cache(con(), aa_key)
    aa_enrichment_data(aa_data)
  }
  showNotification("Refreshing synthesis models...", type = "message", duration = 2)
})
```

#### Add AA status icon rendering:

```r
output$aa_status <- renderUI({
  status <- api_status$aa
  if (is.null(status)) {
    return(render_status_icon("empty", "No API key (optional)"))
  }
  render_status_icon(status$status, status$message)
})
```

#### Add synthesis model info panel:

```r
output$synthesis_model_info <- renderUI({
  req(input$synthesis_model)
  models <- synthesis_models_data()
  req(models)

  selected <- models[models$id == input$synthesis_model, ]
  if (nrow(selected) == 0) return(NULL)

  row <- selected[1, ]
  tier_badge <- switch(row$tier,
    "budget" = span(class = "badge bg-success", "Budget"),
    "mid" = span(class = "badge bg-primary", "Mid-tier"),
    "premium" = span(class = "badge bg-warning text-body", "Premium"),
    span(class = "badge bg-secondary", row$tier)
  )

  # AA intelligence badge
  iq_badge <- if ("intelligence_index" %in% names(row) && !is.na(row$intelligence_index)) {
    span(class = "badge bg-info ms-1",
         sprintf("IQ: %.0f", row$intelligence_index))
  } else {
    NULL
  }

  ctx_display <- if (row$context_length >= 1000000) {
    sprintf("%.1fM tokens", row$context_length / 1000000)
  } else {
    sprintf("%sk tokens", format(round(row$context_length / 1000), big.mark = ","))
  }

  div(
    class = "card card-body bg-body-secondary py-2 px-3 mt-2 small",
    div(class = "d-flex justify-content-between align-items-center mb-1",
      span(class = "fw-semibold", row$name),
      div(tier_badge, iq_badge)
    ),
    div(class = "text-muted",
      icon_window_maximize(class = "me-1"), "Context: ", ctx_display,
      span(class = "mx-2", "|"),
      icon_arrow_right_bracket(class = "me-1"),
      sprintf("$%.2f/M in", row$prompt_price),
      span(class = "mx-1", "/"),
      sprintf("$%.2f/M out", row$completion_price)
    ),
    # AA attribution
    div(class = "text-muted mt-1",
      tags$small("Quality data from ",
        tags$a(href = "https://artificialanalysis.ai",
               target = "_blank",
               class = "text-muted",
               "artificialanalysis.ai"))
    )
  )
})
```

#### Update the save handler (~line 627):

Add after existing save calls:
```r
save_db_setting(con(), "synthesis_model", input$synthesis_model)

# Save AA key (only if non-empty)
aa_key <- trimws(input$aa_api_key %||% "")
if (nchar(aa_key) > 0) {
  save_db_setting(con(), "aa_api_key", aa_key)
}
```

#### Update the return reactive (~line 661):

Add `synthesis_model` to the `defaults` list:
```r
defaults = list(
  chat_model = get_db_setting(con(), "chat_model") %||%
               get_setting(cfg, "defaults", "chat_model") %||%
               "moonshotai/kimi-k2.5",
  synthesis_model = get_db_setting(con(), "synthesis_model") %||%
                    get_db_setting(con(), "chat_model") %||%
                    get_setting(cfg, "defaults", "chat_model") %||%
                    "anthropic/claude-sonnet-4",
  embedding_model = get_db_setting(con(), "embedding_model") %||%
                    get_setting(cfg, "defaults", "embedding_model") %||%
                    "openai/text-embedding-3-small"
),
```

Note: synthesis_model falls back to chat_model, then to `"anthropic/claude-sonnet-4"` as the final default (a known strong synthesis model).

### Step 5f: Add `get_model_for_task()` helper to `R/rag.R`

Add at the top of the file, after the existing helper functions:

```r
#' Get the appropriate model for a given task type
#'
#' Returns the synthesis model for synthesis tasks, falling back to
#' the chat model if no synthesis model is configured.
#'
#' @param config App config (from mod_settings reactive)
#' @param task_type "chat" or "synthesis"
#' @return Model ID string
get_model_for_task <- function(config, task_type = "chat") {
  if (task_type == "synthesis") {
    model <- get_setting(config, "defaults", "synthesis_model")
    if (!is.null(model) && is.character(model) && nchar(model) > 0) {
      return(model)
    }
  }
  get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"
}
```

### Step 5g: Update synthesis functions in `R/rag.R`

In each of the 7 synthesis functions, replace the model retrieval line.

**Before (same in all 7 functions):**
```r
chat_model <- get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"
if (length(chat_model) > 1) chat_model <- chat_model[1]
```

**After:**
```r
chat_model <- get_model_for_task(config, "synthesis")
if (length(chat_model) > 1) chat_model <- chat_model[1]
```

The variable stays named `chat_model` to minimize diff — it's used throughout each function for cost logging, error messages, etc.

**Functions to update (7 total):**

| Function | Approx line | Where to change |
|----------|-------------|-----------------|
| `generate_preset()` | 161 | `chat_model <- get_setting(config, "defaults", "chat_model") %||% ...` |
| `generate_conclusions_preset()` | 253 | Same pattern |
| `generate_overview_preset()` | 434 | Same pattern |
| `generate_research_questions()` | 669 | Same pattern |
| `generate_lit_review_table()` | 885 | Same pattern |
| `generate_methodology_extractor()` | 1084 | Same pattern |
| `generate_gap_analysis()` | 1293 | Same pattern |

**Functions that should NOT be changed (keep using chat_model):**
- `rag_query()` (line 64) — interactive chat, latency > quality
- `R/mod_query_builder.R` — interactive query building
- `R/slides.R` — slide generation (separate concern)

### Phase 5 Verification

1. In Settings, set Chat Model = "deepseek/deepseek-v3.2" (budget) and Synthesis Model = "google/gemini-2.5-pro" (mid)
2. Save settings
3. Run an Overview preset — check `cost_log` that the model column shows `google/gemini-2.5-pro`
4. Send a chat message — check `cost_log` shows `deepseek/deepseek-v3.2`
5. Unset the synthesis model (clear the dropdown) — verify it falls back to the chat model

---

## End-to-End Verification Checklist

1. **Migration:** App starts without errors, `DESCRIBE cost_log` shows new columns, `aa_model_cache` exists
2. **Smoke test:** `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "shiny::runApp('app.R', port=3838, launch.browser=FALSE)"` shows "Listening on" without crash
3. **Latency backend:** Chat query logs `response_time_ms > 0` and `tokens_per_second > 0` in `cost_log`
4. **Latency UI:** Cost tracker shows TPS column in table and performance value box
5. **AA cache:** With AA key, `aa_model_cache` populates; without key, app works normally
6. **Synthesis dropdown:** Shows only mid+premium models (or AA-scored >= 40)
7. **Model split:** Synthesis operations use `synthesis_model`; chat uses `chat_model`
8. **Graceful degradation:** With no AA key and no cache, everything works with hardcoded defaults

## Files Changed Summary

| File | Action | Phase |
|------|--------|-------|
| `migrations/011_add_response_time_and_aa_cache.sql` | **Create** | 1 |
| `R/api_openrouter.R` | Edit (timing + synthesis filtering) | 2, 5 |
| `R/cost_tracking.R` | Edit (log_cost, get_session_costs, new get_session_performance) | 2, 3 |
| `R/rag.R` | Edit (13 call sites + get_model_for_task + 7 function model switches) | 2, 5 |
| `R/mod_query_builder.R` | Edit (1 call site) | 2 |
| `R/slides.R` | Edit (2 call sites) | 2 |
| `R/mod_cost_tracker.R` | Edit (table columns + performance card) | 3 |
| `R/api_artificial_analysis.R` | **Create** | 4 |
| `R/mod_settings.R` | Edit (AA key field + synthesis dropdown + wiring) | 5 |
| `R/theme_catppuccin.R` | Edit (add icon_bolt, icon_gauge) | 3, 5 |

## Attribution Requirement

Per Artificial Analysis free API terms, attribution to https://artificialanalysis.ai/ is required. This is handled by the attribution line in the synthesis model info panel.
