library(testthat)

source_app("config.R")
source_app("api_openalex.R")
source_app("api_openrouter.R")
source_app("api_rerank.R")

# ---- Default Models ----

test_that("get_default_rerank_models returns expected structure", {
  df <- get_default_rerank_models()
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 2)
  expect_true(all(c("id", "name", "price_per_search") %in% names(df)))
  expect_true("cohere/rerank-4-pro" %in% df$id)
  expect_true("cohere/rerank-4-fast" %in% df$id)
})

test_that("get_default_rerank_models does not include v3.5", {
  df <- get_default_rerank_models()
  expect_false("cohere/rerank-v3.5" %in% df$id)
})

# ---- list_rerank_models ----

test_that("list_rerank_models falls back to defaults with invalid key", {
  df <- list_rerank_models(NULL)
  expect_s3_class(df, "data.frame")
  expect_true(nrow(df) >= 2)

  df2 <- list_rerank_models("short")
  expect_s3_class(df2, "data.frame")
  expect_true(nrow(df2) >= 2)
})

# ---- rerank ----

test_that("rerank returns empty data frame for empty documents", {
  result <- rerank("fake-key", "cohere/rerank-4-fast", "test query", character(0))
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_true(all(c("index", "relevance_score", "document") %in% names(result)))
})

test_that("rerank gracefully degrades on API failure", {
  docs <- c("First document", "Second document", "Third document")
  result <- rerank("invalid-key-for-testing", "cohere/rerank-4-fast", "test query", docs)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  expect_true(all(c("index", "relevance_score", "document") %in% names(result)))
  # All scores should be 0 (fallback)
  expect_true(all(result$relevance_score == 0))
  # Documents should be preserved
  expect_equal(sort(result$document), sort(docs))
})

test_that("rerank graceful degradation respects top_n", {
  docs <- c("First", "Second", "Third", "Fourth", "Fifth")
  result <- rerank("invalid-key-for-testing", "cohere/rerank-4-fast", "query", docs, top_n = 3)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
})

# ---- Verbose Logging ----

test_that("rerank logs rank changes when verbose_mode is on", {
  old <- options(serapeum.verbose_api = TRUE)
  on.exit(options(old))

  docs <- c("First document", "Second document", "Third document")
  msgs <- capture_messages(
    result <- rerank("invalid-key-for-testing", "cohere/rerank-4-fast", "test query", docs)
  )

  # Should contain rerank header and rank lines
  expect_true(any(grepl("\\[Rerank\\]", msgs)))
  expect_true(any(grepl("#1 <- was #", msgs)))
  expect_true(any(grepl("score=", msgs)))
})

test_that("rerank does not log when verbose_mode is off", {
  old <- options(serapeum.verbose_api = FALSE)
  on.exit(options(old))

  docs <- c("First document", "Second document")
  msgs <- capture_messages(
    result <- rerank("invalid-key-for-testing", "cohere/rerank-4-fast", "test query", docs)
  )

  # Filter out the degradation warning — only check for rerank-specific logging
  rerank_msgs <- grep("\\[Rerank\\]", msgs, value = TRUE)
  expect_length(rerank_msgs, 0)
})
