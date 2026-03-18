library(testthat)

project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "config.R"))) {
  project_root <- getwd()
}

source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "api_openalex.R"))
source(file.path(project_root, "R", "api_openrouter.R"))
source(file.path(project_root, "R", "api_provider.R"))
source(file.path(project_root, "R", "cost_tracking.R"))

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
  source(file.path(project_root, "R", "db_migrations.R"))
  source(file.path(project_root, "R", "db.R"))

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
