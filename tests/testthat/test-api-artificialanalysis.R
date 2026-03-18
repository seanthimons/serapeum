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
source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "api_artificialanalysis.R"))

# ---- Bundled Data Loading ----

test_that("load_bundled_aa_data loads the snapshot", {
  data <- load_bundled_aa_data(project_root)
  expect_true(nrow(data) > 0)
  expect_true(all(c("aa_model_id", "aa_model_name", "intelligence_index",
                     "tokens_per_second", "price_blended_1m") %in% names(data)))
})

test_that("load_bundled_aa_data has expected models", {
  data <- load_bundled_aa_data(project_root)
  expect_true("claude-sonnet-4" %in% data$aa_model_id)
  expect_true("gpt-4o" %in% data$aa_model_id)
  expect_true("gemini-2-5-flash" %in% data$aa_model_id)
})

test_that("empty_aa_frame has correct column types", {
  df <- empty_aa_frame()
  expect_equal(nrow(df), 0)
  expect_true("intelligence_index" %in% names(df))
  expect_true(is.numeric(df$intelligence_index))
})

# ---- Model Matching ----

test_that("normalize_model_id strips provider prefix and normalizes", {
  expect_equal(normalize_model_id("openai/gpt-4o"), "gpt-4o")
  expect_equal(normalize_model_id("anthropic/claude-sonnet-4"), "claude-sonnet-4")
  expect_equal(normalize_model_id("google/gemini-2.5-flash-preview-05-20"), "gemini-2-5-flash")
  expect_equal(normalize_model_id("google/gemini-2.0-flash-001"), "gemini-2-0-flash")
  expect_equal(normalize_model_id("vendor/model-latest"), "model")
})

test_that("match_aa_model finds models via manual mapping", {
  data <- load_bundled_aa_data(project_root)
  mapping <- load_aa_model_mapping(project_root)

  row <- match_aa_model("anthropic/claude-sonnet-4", data, mapping)
  expect_false(is.null(row))
  expect_equal(row$aa_model_name, "Claude Sonnet 4")

  row <- match_aa_model("google/gemini-3.1-flash-lite-preview", data, mapping)
  expect_false(is.null(row))
  expect_equal(row$creator_name, "Google")
})

test_that("match_aa_model returns NULL for unknown models", {
  data <- load_bundled_aa_data(project_root)
  row <- match_aa_model("totally/unknown-model", data)
  expect_null(row)
})

test_that("match_aa_model works via fuzzy match", {
  data <- load_bundled_aa_data(project_root)

  # This should match via normalization even without manual mapping
  row <- match_aa_model("openai/gpt-4o", data, character())
  expect_false(is.null(row))
  expect_equal(row$aa_model_id, "gpt-4o")
})

# ---- Model Enrichment ----

test_that("enrich_models_with_aa adds AA columns", {
  models <- get_default_chat_models()
  aa <- load_bundled_aa_data(project_root)

  enriched <- enrich_models_with_aa(models, aa)
  expect_true("intelligence_index" %in% names(enriched))
  expect_true("tokens_per_second" %in% names(enriched))
  expect_true("price_blended_1m" %in% names(enriched))
  expect_equal(nrow(enriched), nrow(models))
})

test_that("enrich_models_with_aa handles empty AA data", {
  models <- get_default_chat_models()
  enriched <- enrich_models_with_aa(models, empty_aa_frame())
  expect_true(all(is.na(enriched$intelligence_index)))
})

test_that("enrich_models_with_aa matches known models", {
  models <- get_default_chat_models()
  aa <- load_bundled_aa_data(project_root)
  enriched <- enrich_models_with_aa(models, aa)

  # Gemini 3.1 Flash Lite should match
  flash_lite <- enriched[enriched$id == "google/gemini-3.1-flash-lite-preview", ]
  if (nrow(flash_lite) > 0) {
    expect_false(is.na(flash_lite$intelligence_index))
  }
})

# ---- Smart Defaults ----

test_that("suggest_model_for_slot returns cheapest competent model for fast", {
  models <- data.frame(
    id = c("cheap-fast", "expensive-smart", "dumb-free"),
    name = c("Cheap Fast", "Expensive Smart", "Dumb Free"),
    intelligence_index = c(60, 90, 30),
    tokens_per_second = c(200, 50, 300),
    price_blended_1m = c(0.20, 5.00, 0.00),
    stringsAsFactors = FALSE
  )

  # dumb-free has intelligence 30 < 50 threshold, so excluded
  # cheap-fast (60 >= 50, price 0.20) is cheapest qualified
  result <- suggest_model_for_slot(models, "fast")
  expect_equal(result, "cheap-fast")
})

test_that("suggest_model_for_slot returns smartest affordable model for quality", {
  models <- data.frame(
    id = c("cheap", "mid", "expensive"),
    name = c("Cheap", "Mid", "Expensive"),
    intelligence_index = c(60, 85, 95),
    tokens_per_second = c(200, 80, 40),
    price_blended_1m = c(0.20, 3.00, 15.00),
    stringsAsFactors = FALSE
  )

  result <- suggest_model_for_slot(models, "quality")
  expect_equal(result, "mid")  # 85 is highest with price <= $10
})

test_that("suggest_model_for_slot returns NULL for embedding", {
  models <- data.frame(id = "test", name = "Test", intelligence_index = 80,
                       tokens_per_second = 100, price_blended_1m = 1.0,
                       stringsAsFactors = FALSE)
  expect_null(suggest_model_for_slot(models, "embedding"))
})

# ---- DB Caching ----

test_that("get_aa_models returns cached data from DB", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))

  # Seed cache
  original <- load_bundled_aa_data(project_root)
  save_aa_cache(con, original)

  data <- get_aa_models(con)
  expect_true(nrow(data) > 0)
  expect_equal(nrow(data), nrow(original))
})

test_that("save_aa_cache and get_aa_models round-trip", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))

  original <- load_bundled_aa_data(project_root)
  save_aa_cache(con, original)

  retrieved <- get_aa_models(con)
  expect_equal(nrow(retrieved), nrow(original))
  expect_equal(retrieved$aa_model_id, original$aa_model_id)
})

# ---- Format Enriched Choices ----

test_that("format_chat_model_choices uses AA data when available", {
  models <- data.frame(
    id = "test/model",
    name = "Test Model",
    context_length = 100000,
    prompt_price = 1.00,
    completion_price = 3.00,
    tier = "mid",
    intelligence_index = 85,
    tokens_per_second = 120,
    price_blended_1m = 2.50,
    stringsAsFactors = FALSE
  )

  choices <- format_chat_model_choices(models)
  label <- names(choices)[1]

  expect_match(label, "Q:85")
  expect_match(label, "120 tok/s")
  expect_match(label, "\\$2\\.50/M")
})

test_that("format_chat_model_choices falls back without AA data", {
  models <- get_default_chat_models()
  choices <- format_chat_model_choices(models)

  # Should use tier-based format since no AA columns
  label <- names(choices)[1]
  expect_match(label, "\\[\\$")  # tier icon
})
