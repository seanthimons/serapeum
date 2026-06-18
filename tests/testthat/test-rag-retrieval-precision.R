library(testthat)

source_app("config.R", "db_migrations.R", "db.R")

with_mocked_rerank <- function(mock, code) {
  had_original <- exists("rerank", envir = globalenv(), inherits = FALSE)
  original <- if (had_original) get("rerank", envir = globalenv()) else NULL
  assign("rerank", mock, envir = globalenv())
  on.exit({
    if (had_original) {
      assign("rerank", original, envir = globalenv())
    } else {
      rm("rerank", envir = globalenv())
    }
  }, add = TRUE)
  force(code)
}

test_that("rerank_retrieval_candidates orders final chunks by rerank score", {
  candidates <- data.frame(
    content = c("alpha", "beta", "gamma"),
    source_type = "document",
    source_id = c("doc-1", "doc-2", "doc-3"),
    page_range = c("1", "2", "3-4"),
    section_hint = c("general", "methods", "results"),
    rrf_score = c(0.3, 0.2, 0.1),
    stringsAsFactors = FALSE
  )

  provider <- list(api_key = "test-key")
  config <- list(defaults = list(rerank_model = "test-rerank"), app = list(rerank = TRUE))

  with_mocked_rerank(function(api_key, model, query, documents, top_n = NULL) {
    expect_equal(api_key, "test-key")
    expect_equal(model, "test-rerank")
    expect_equal(query, "target question")
    expect_equal(top_n, 2L)
    expect_match(documents[3], "doc-3")

    out <- data.frame(
      index = c(3L, 1L),
      relevance_score = c(0.91, 0.72),
      document = documents[c(3L, 1L)],
      stringsAsFactors = FALSE
    )
    attr(out, "rerank_fallback") <- FALSE
    out
  }, {
    result <- rerank_retrieval_candidates(
      candidates,
      query = "target question",
      limit = 2L,
      provider = provider,
      config = config,
      rerank_context = "chat"
    )
  })

  expect_equal(result$content, c("gamma", "alpha"))
  expect_equal(result$rerank_score, c(0.91, 0.72))
  expect_false(isTRUE(attr(result, "rerank_fallback")))
})

test_that("rerank_retrieval_candidates preserves RRF order on rerank fallback", {
  candidates <- data.frame(
    content = c("alpha", "beta", "gamma"),
    source_type = "document",
    source_id = c("doc-1", "doc-2", "doc-3"),
    page_range = c("1", "2", "3"),
    section_hint = "general",
    rrf_score = c(0.3, 0.2, 0.1),
    stringsAsFactors = FALSE
  )

  provider <- list(api_key = "test-key")
  config <- list(defaults = list(rerank_model = "test-rerank"), app = list(rerank = TRUE))

  with_mocked_rerank(function(api_key, model, query, documents, top_n = NULL) {
    out <- data.frame(
      index = seq_len(top_n),
      relevance_score = rep(0, top_n),
      document = documents[seq_len(top_n)],
      stringsAsFactors = FALSE
    )
    attr(out, "rerank_fallback") <- TRUE
    attr(out, "rerank_error") <- "network down"
    out
  }, {
    result <- rerank_retrieval_candidates(
      candidates,
      query = "target question",
      limit = 2L,
      provider = provider,
      config = config,
      rerank_context = "chat"
    )
  })

  expect_equal(result$content, c("alpha", "beta"))
  expect_true(isTRUE(attr(result, "rerank_fallback")))
  expect_equal(attr(result, "rerank_error"), "network down")
})
