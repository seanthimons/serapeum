# Integration tests for local provider (LM Studio) end-to-end path
#
# Tests the full flow: providers DB → provider_from_config → LLM calls → cost estimation
# Requires LM Studio running on localhost:1234 with a chat + embedding model loaded.

project_root <- normalizePath(file.path(dirname(getwd()), ".."), winslash = "/")
if (basename(getwd()) == "testthat") {
  project_root <- normalizePath(file.path(getwd(), "..", ".."), winslash = "/")
}

source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "api_openalex.R"))
source(file.path(project_root, "R", "api_provider.R"))
source(file.path(project_root, "R", "cost_tracking.R"))

LM_STUDIO_URL <- "http://localhost:1234/v1"
CHAT_MODEL <- "gemma-3-270m-it"
EMBED_MODEL <- "text-embedding-nomic-embed-text-v1.5"

# Helper: check if LM Studio is reachable
lm_studio_available <- function() {
  tryCatch({
    cfg <- create_provider_config("LM Studio", LM_STUDIO_URL)
    health <- provider_check_health(cfg, timeout = 2)
    isTRUE(health$alive)
  }, error = function(e) FALSE)
}

# Helper: set up DB with LM Studio as default provider
setup_local_provider_db <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  init_schema(con)
  run_pending_migrations(con)

  # Create providers table if migrations didn't
  has_table <- tryCatch(DBI::dbExistsTable(con, "providers"), error = function(e) FALSE)
  if (!has_table) {
    DBI::dbExecute(con, "
      CREATE TABLE providers (
        id VARCHAR PRIMARY KEY, name VARCHAR NOT NULL, base_url VARCHAR NOT NULL,
        api_key VARCHAR, provider_type VARCHAR NOT NULL DEFAULT 'openai-compatible',
        timeout_chat INTEGER DEFAULT 300, timeout_embed INTEGER DEFAULT 600,
        is_default BOOLEAN DEFAULT FALSE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ")
  }

  # Insert LM Studio as default provider (no API key!)
  save_provider(con, "lmstudio-local", "LM Studio",
                LM_STUDIO_URL,
                provider_type = "openai-compatible")
  # Mark as default (save_provider doesn't expose is_default)
  DBI::dbExecute(con, "UPDATE providers SET is_default = TRUE WHERE id = 'lmstudio-local'")

  con
}

# ---- Test: provider_from_config resolves local default from DB ----

test_that("provider_from_config resolves DB-backed local default provider", {
  con <- setup_local_provider_db()
  on.exit(close_db_connection(con))

  config <- list(
    openrouter = list(api_key = "sk-or-should-not-use-this"),
    defaults = list(quality_model = CHAT_MODEL, embedding_model = EMBED_MODEL)
  )

  provider <- provider_from_config(config, con)

  expect_true(is_provider_config(provider))
  expect_equal(provider$name, "LM Studio")
  expect_equal(provider$base_url, LM_STUDIO_URL)
  expect_true(is.na(provider$api_key) || is.null(provider$api_key))
  expect_equal(provider$provider_type, "openai-compatible")
  expect_true(is_local_provider(provider))
})

test_that("provider_from_config falls back to OpenRouter when no DB", {
  config <- list(
    openrouter = list(api_key = "sk-or-fallback"),
    defaults = list(quality_model = "openai/gpt-4o-mini")
  )

  provider <- provider_from_config(config)

  expect_equal(provider$provider_type, "openrouter")
  expect_equal(provider$api_key, "sk-or-fallback")
})

# ---- Test: local provider passes through api_key guards ----

test_that("get_ragnar_store allows local provider with NULL api_key", {
  skip("Requires ragnar package - testing guard logic only")
})

test_that("is_local_provider correctly identifies LM Studio config", {
  cfg <- create_provider_config("LM Studio", LM_STUDIO_URL, api_key = NULL)
  expect_true(is_local_provider(cfg))
})

test_that("estimate_cost returns $0 for local models", {
  cost <- estimate_cost("gemma-3-270m-it", 100, 50, is_local = TRUE)
  expect_equal(cost, 0.0)
})

test_that("estimate_cost falls back to DEFAULT_PRICING for cloud models without is_local", {
  cost <- estimate_cost("unknown-cloud-model", 1000000, 0, is_local = FALSE)
  expect_gt(cost, 0)
})

# ---- Test: live LM Studio chat completion ----

test_that("provider_chat_completion works with local LM Studio", {
  skip_if_not(lm_studio_available(), "LM Studio not running on localhost:1234")

  provider <- create_provider_config("LM Studio", LM_STUDIO_URL, api_key = NULL)

  result <- provider_chat_completion(provider, CHAT_MODEL, list(
    list(role = "user", content = "Reply with exactly: OK")
  ))

  expect_true(!is.null(result$content))
  expect_true(nchar(result$content) > 0)
  expect_true(result$duration_ms > 0)
  expect_true(!is.null(result$usage))
  expect_true(result$usage$prompt_tokens > 0)
})

# ---- Test: live LM Studio embeddings ----

test_that("provider_get_embeddings works with local LM Studio", {
  skip_if_not(lm_studio_available(), "LM Studio not running on localhost:1234")

  provider <- create_provider_config("LM Studio", LM_STUDIO_URL, api_key = NULL)

  result <- provider_get_embeddings(provider, EMBED_MODEL, "test embedding")

  expect_true(length(result$embeddings) == 1)
  expect_true(length(result$embeddings[[1]]) == 768)
  expect_true(result$duration_ms > 0)
})

# ---- Test: full flow with cost logging ----

test_that("local provider chat completion logs $0 cost", {
  skip_if_not(lm_studio_available(), "LM Studio not running on localhost:1234")

  con <- setup_local_provider_db()
  on.exit(close_db_connection(con))

  config <- list(
    openrouter = list(api_key = "sk-or-unused"),
    defaults = list(quality_model = CHAT_MODEL, embedding_model = EMBED_MODEL)
  )

  provider <- provider_from_config(config, con)

  # Make a real chat call
  result <- provider_chat_completion(provider, CHAT_MODEL, list(
    list(role = "user", content = "Say hello")
  ))

  # Estimate cost — should be $0 for local
  cost <- estimate_cost(CHAT_MODEL,
                        result$usage$prompt_tokens,
                        result$usage$completion_tokens,
                        is_local = is_local_provider(provider))

  expect_equal(cost, 0.0)

  # Log it
  log_cost(con, "chat", CHAT_MODEL,
           result$usage$prompt_tokens,
           result$usage$completion_tokens,
           estimated_cost = cost,
           session_id = "test-session",
           duration_ms = result$duration_ms)

  # Verify logged record
  costs <- get_session_costs(con, "test-session")
  expect_equal(nrow(costs), 1)
  expect_equal(costs$estimated_cost[1], 0.0)
  expect_equal(costs$model[1], CHAT_MODEL)
})
