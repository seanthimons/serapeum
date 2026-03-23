library(testthat)


source_app("config.R")
source_app("api_openalex.R")
source_app("api_openrouter.R")
source_app("api_provider.R")
source_app("cost_tracking.R")

# ---- Provider Config Creation ----

test_that("create_provider_config creates valid config with defaults", {
  cfg <- create_provider_config(
    name = "Test Provider",
    base_url = "http://localhost:11434/v1"
  )

  expect_true(is_provider_config(cfg))
  expect_equal(cfg$name, "Test Provider")
  expect_equal(cfg$base_url, "http://localhost:11434/v1")
  expect_null(cfg$api_key)
  expect_equal(cfg$provider_type, "openai-compatible")
  expect_equal(cfg$timeout_chat, 120)
  expect_equal(cfg$timeout_embed, 60)
})

test_that("create_provider_config strips trailing slashes from base_url", {
  cfg <- create_provider_config(
    name = "Test",
    base_url = "http://localhost:11434/v1///"
  )
  expect_equal(cfg$base_url, "http://localhost:11434/v1")
})

test_that("create_provider_config preserves custom timeouts", {
  cfg <- create_provider_config(
    name = "Local",
    base_url = "http://localhost:11434/v1",
    timeout_chat = 300,
    timeout_embed = 600
  )
  expect_equal(cfg$timeout_chat, 300)
  expect_equal(cfg$timeout_embed, 600)
})

test_that("openrouter_provider creates correct config", {
  cfg <- openrouter_provider("sk-or-test-key")

  expect_true(is_provider_config(cfg))
  expect_equal(cfg$name, "OpenRouter")
  expect_equal(cfg$base_url, "https://openrouter.ai/api/v1")
  expect_equal(cfg$api_key, "sk-or-test-key")
  expect_equal(cfg$provider_type, "openrouter")
})

test_that("is_provider_config returns FALSE for non-configs", {
  expect_false(is_provider_config(list(name = "fake")))
  expect_false(is_provider_config(NULL))
  expect_false(is_provider_config("string"))
})

# ---- Usage Normalization ----

test_that("normalize_usage handles complete usage object", {
  usage <- list(prompt_tokens = 100, completion_tokens = 50, total_tokens = 150)
  result <- normalize_usage(usage)

  expect_equal(result$prompt_tokens, 100L)
  expect_equal(result$completion_tokens, 50L)
  expect_equal(result$total_tokens, 150L)
})

test_that("normalize_usage handles NULL usage (local models)", {
  result <- normalize_usage(NULL)

  expect_equal(result$prompt_tokens, 0L)
  expect_equal(result$completion_tokens, 0L)
  expect_equal(result$total_tokens, 0L)
})

test_that("normalize_usage handles partial usage (missing fields)", {
  usage <- list(prompt_tokens = 100)
  result <- normalize_usage(usage)

  expect_equal(result$prompt_tokens, 100L)
  expect_equal(result$completion_tokens, 0L)
  expect_equal(result$total_tokens, 100L)  # calculated from prompt + completion
})

# ---- Config Bridge ----

test_that("provider_from_config creates OpenRouter provider from effective_config", {
  config <- list(
    openrouter = list(api_key = "sk-or-test-key"),
    defaults = list(chat_model = "test/model")
  )

  provider <- provider_from_config(config)

  expect_true(is_provider_config(provider))
  expect_equal(provider$api_key, "sk-or-test-key")
  expect_equal(provider$provider_type, "openrouter")
})

test_that("provider_from_config handles missing API key", {
  config <- list(
    openrouter = list(api_key = NULL),
    defaults = list(chat_model = "test/model")
  )

  provider <- provider_from_config(config)

  expect_true(is_provider_config(provider))
  expect_null(provider$api_key)
})

# ---- Health Check (offline-safe) ----

test_that("provider_check_health returns alive=FALSE for unreachable endpoint", {
  cfg <- create_provider_config(
    name = "Offline",
    base_url = "http://localhost:99999/v1"
  )

  result <- provider_check_health(cfg, timeout = 1)

  expect_false(result$alive)
  expect_equal(result$model_count, 0L)
  expect_equal(result$server_type, "unknown")
})

# ---- Cost Estimation ----

test_that("estimate_cost returns $0 for local models", {
  cost <- estimate_cost("local/llama3", 1000, 500, is_local = TRUE)
  expect_equal(cost, 0.0)
})

test_that("estimate_cost uses DEFAULT_PRICING for unknown cloud models", {
  cost <- estimate_cost("unknown/model", 1000000, 0, is_local = FALSE)
  expect_equal(cost, DEFAULT_PRICING$prompt)  # 1M tokens * $1.00/M
})

test_that("estimate_cost uses known pricing when available", {
  cost <- estimate_cost("openai/text-embedding-3-small", 1000000, 0)
  expect_equal(cost, 0.02)  # 1M tokens * $0.02/M
})

# ---- log_cost with duration_ms ----

test_that("log_cost works with and without duration_ms", {
  source_app("db_migrations.R")
  source_app("db.R")

  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  # Without duration_ms (backward compatible)
  id1 <- log_cost(con, "chat", "test/model", 100, 50,
                   estimated_cost = 0.001, session_id = "s1")
  expect_true(nchar(id1) > 0)

  # With duration_ms (when column doesn't exist yet — no migration 012)
  id2 <- log_cost(con, "chat", "test/model", 100, 50,
                   estimated_cost = 0.001, session_id = "s1",
                   duration_ms = 1500)
  expect_true(nchar(id2) > 0)

  # Verify records exist
  rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM cost_log")
  expect_equal(rows$n, 2)
})

# ---- Model Slot Resolution ----

test_that("resolve_model_for_operation routes quality operations correctly", {
  config <- list(defaults = list(
    fast_model = "google/gemini-3.1-flash-lite-preview",
    quality_model = "anthropic/claude-sonnet-4",
    embedding_model = "openai/text-embedding-3-small"
  ))

  expect_equal(resolve_model_for_operation(config, "chat"), "anthropic/claude-sonnet-4")
  expect_equal(resolve_model_for_operation(config, "overview"), "anthropic/claude-sonnet-4")
  expect_equal(resolve_model_for_operation(config, "slide_generation"), "anthropic/claude-sonnet-4")
  expect_equal(resolve_model_for_operation(config, "conclusion_synthesis"), "anthropic/claude-sonnet-4")
  expect_equal(resolve_model_for_operation(config, "research_questions"), "anthropic/claude-sonnet-4")
  expect_equal(resolve_model_for_operation(config, "lit_review_table"), "anthropic/claude-sonnet-4")
  expect_equal(resolve_model_for_operation(config, "methodology_extractor"), "anthropic/claude-sonnet-4")
  expect_equal(resolve_model_for_operation(config, "gap_analysis"), "anthropic/claude-sonnet-4")
})

test_that("resolve_model_for_operation routes fast operations correctly", {
  config <- list(defaults = list(
    fast_model = "google/gemini-3.1-flash-lite-preview",
    quality_model = "anthropic/claude-sonnet-4",
    embedding_model = "openai/text-embedding-3-small"
  ))

  expect_equal(resolve_model_for_operation(config, "query_build"), "google/gemini-3.1-flash-lite-preview")
  expect_equal(resolve_model_for_operation(config, "query_reformulation"), "google/gemini-3.1-flash-lite-preview")
  expect_equal(resolve_model_for_operation(config, "openalex_topics"), "google/gemini-3.1-flash-lite-preview")
})

test_that("resolve_model_for_operation routes embedding operations correctly", {
  config <- list(defaults = list(
    fast_model = "google/gemini-3.1-flash-lite-preview",
    quality_model = "anthropic/claude-sonnet-4",
    embedding_model = "openai/text-embedding-3-small"
  ))

  expect_equal(resolve_model_for_operation(config, "embedding"), "openai/text-embedding-3-small")
})

test_that("fast slot falls back to quality model when fast_model is NULL", {
  config <- list(defaults = list(
    fast_model = NULL,
    quality_model = "anthropic/claude-sonnet-4",
    embedding_model = "openai/text-embedding-3-small"
  ))

  expect_equal(resolve_model_for_operation(config, "query_build"), "anthropic/claude-sonnet-4")
  expect_equal(resolve_model_for_operation(config, "query_reformulation"), "anthropic/claude-sonnet-4")
})

test_that("resolve_model_for_operation errors on NA-slot operations", {
  config <- list(defaults = list(quality_model = "test"))

  expect_error(resolve_model_for_operation(config, "openalex_search"), "not an LLM operation")
  expect_error(resolve_model_for_operation(config, "openalex_fetch"), "not an LLM operation")
})

test_that("resolve_model_for_operation errors on unknown operation", {
  config <- list(defaults = list(quality_model = "test"))

  expect_error(resolve_model_for_operation(config, "totally_fake_op"), "Unknown operation")
})

test_that("resolve_model_for_operation errors when no model configured", {
  config <- list(defaults = list(
    fast_model = NULL,
    quality_model = NULL,
    embedding_model = NULL
  ))

  expect_error(resolve_model_for_operation(config, "chat"), "No model configured")
  expect_error(resolve_model_for_operation(config, "embedding"), "No model configured")
})

test_that("COST_OPERATION_META has slot field on every entry", {
  for (op_name in names(COST_OPERATION_META)) {
    meta <- COST_OPERATION_META[[op_name]]
    expect_true("slot" %in% names(meta),
                info = paste("Missing slot on operation:", op_name))
    # Slot must be a valid value or NA
    if (!is.na(meta$slot)) {
      expect_true(meta$slot %in% c("fast", "quality", "embedding"),
                  info = paste("Invalid slot on operation:", op_name, "got:", meta$slot))
    }
  }
})

# ---- Provider CRUD ----

source_app("db_migrations.R")
source_app("db.R")

# Helper: create in-memory DB with providers table
setup_db_with_providers <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  init_schema(con)
  # Apply migration 013 directly since test cwd may not have migrations/
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS providers (
      id VARCHAR PRIMARY KEY, name VARCHAR NOT NULL, base_url VARCHAR NOT NULL,
      api_key VARCHAR, provider_type VARCHAR NOT NULL DEFAULT 'openai-compatible',
      timeout_chat INTEGER DEFAULT 300, timeout_embed INTEGER DEFAULT 600,
      is_default BOOLEAN DEFAULT FALSE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")
  DBI::dbExecute(con, "
    INSERT INTO providers (id, name, base_url, provider_type, is_default, timeout_chat, timeout_embed)
    VALUES ('openrouter', 'OpenRouter', 'https://openrouter.ai/api/v1', 'openrouter', TRUE, 120, 60)
    ON CONFLICT DO NOTHING
  ")
  con
}

test_that("save_provider and get_provider round-trip correctly", {
  con <- setup_db_with_providers()
  on.exit(close_db_connection(con))

  save_provider(con, "ollama-local", "My Ollama",
                "http://localhost:11434/v1",
                provider_type = "openai-compatible")

  p <- get_provider(con, "ollama-local")
  expect_equal(p$name, "My Ollama")
  expect_equal(p$base_url, "http://localhost:11434/v1")
  expect_equal(p$provider_type, "openai-compatible")
  expect_true(is.na(p$api_key))
  expect_equal(p$timeout_chat, 300L)
})

test_that("get_providers returns all providers including seeded OpenRouter", {
  con <- setup_db_with_providers()
  on.exit(close_db_connection(con))

  providers <- get_providers(con)
  expect_true(nrow(providers) >= 1)
  expect_true("openrouter" %in% providers$id)
})

test_that("save_provider upserts on conflict", {
  con <- setup_db_with_providers()
  on.exit(close_db_connection(con))

  save_provider(con, "test-p", "V1", "http://old/v1")
  save_provider(con, "test-p", "V2", "http://new/v1")

  p <- get_provider(con, "test-p")
  expect_equal(p$name, "V2")
  expect_equal(p$base_url, "http://new/v1")
})

test_that("delete_provider removes non-default provider", {
  con <- setup_db_with_providers()
  on.exit(close_db_connection(con))

  save_provider(con, "temp", "Temp", "http://temp/v1")
  expect_true(delete_provider(con, "temp"))
  expect_null(get_provider(con, "temp"))
})

test_that("delete_provider refuses to delete default provider", {
  con <- setup_db_with_providers()
  on.exit(close_db_connection(con))

  expect_error(delete_provider(con, "openrouter"), "Cannot delete")
})

test_that("provider_row_to_config creates valid provider_config", {
  row <- list(
    name = "Ollama", base_url = "http://localhost:11434/v1",
    api_key = NULL, provider_type = "openai-compatible",
    timeout_chat = 300L, timeout_embed = 600L
  )
  cfg <- provider_row_to_config(row)
  expect_true(is_provider_config(cfg))
  expect_equal(cfg$name, "Ollama")
  expect_null(cfg$api_key)
})

test_that("provider_row_to_config respects api_key_override", {
  row <- list(
    name = "OR", base_url = "https://openrouter.ai/api/v1",
    api_key = NULL, provider_type = "openrouter",
    timeout_chat = 120L, timeout_embed = 60L
  )
  cfg <- provider_row_to_config(row, api_key_override = "sk-test")
  expect_equal(cfg$api_key, "sk-test")
})

# ---- Local Provider Detection ----

test_that("is_local_provider identifies OpenRouter as non-local", {
  cfg <- openrouter_provider("sk-test")
  expect_false(is_local_provider(cfg))
})

test_that("is_local_provider identifies non-openrouter as local", {
  cfg <- create_provider_config("Ollama", "http://localhost:11434/v1")
  expect_true(is_local_provider(cfg))
})

# ---- Embedding Dimension Detection ----

test_that("detect_embedding_dimension returns known dimensions", {
  expect_equal(detect_embedding_dimension("openai/text-embedding-3-small"), 1536L)
  expect_equal(detect_embedding_dimension("openai/text-embedding-3-large"), 3072L)
  expect_equal(detect_embedding_dimension("nomic-embed-text"), 768L)
})

test_that("detect_embedding_dimension returns NULL for unknown model without provider", {
  expect_null(detect_embedding_dimension("unknown/model"))
})

# ---- Model Aggregation ----

test_that("get_all_available_models returns empty frame for empty input", {
  result <- get_all_available_models(list())
  expect_equal(nrow(result), 0)
  expect_true(all(c("model_id", "display_name", "provider_id", "provider_name") %in% names(result)))
})

# ---- Stale Index Detection ----

test_that("is_ragnar_store_stale detects embedding model mismatch", {
  source_app("_ragnar.R")

  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  nb_id <- "test-nb"
  mark_ragnar_store_current(con, nb_id, embed_model = "openai/text-embedding-3-small")

  # Same model — not stale
  expect_false(is_ragnar_store_stale(con, nb_id, current_embed_model = "openai/text-embedding-3-small"))

  # Different model — stale
  expect_true(is_ragnar_store_stale(con, nb_id, current_embed_model = "openai/text-embedding-3-large"))
})

test_that("is_ragnar_store_stale works without embed model check", {
  source_app("_ragnar.R")

  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  nb_id <- "test-nb"
  mark_ragnar_store_current(con, nb_id)

  # No embed model passed — only checks schema version
  expect_false(is_ragnar_store_stale(con, nb_id))
})
