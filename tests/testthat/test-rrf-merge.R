library(testthat)

project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "rag.R"))) {
  project_root <- getwd()
}

source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "rag.R"))

# --- Phase 3: RRF Merge Algorithm ---

test_that("rrf_merge produces correct scores for two ranked lists", {
  list_a <- data.frame(
    text = c("chunk1", "chunk2", "chunk3"),
    origin = c("a.pdf#page=1", "a.pdf#page=2", "a.pdf#page=3"),
    hash = c("h1", "h2", "h3"),
    stringsAsFactors = FALSE
  )
  list_b <- data.frame(
    text = c("chunk2", "chunk3", "chunk1"),
    origin = c("a.pdf#page=2", "a.pdf#page=3", "a.pdf#page=1"),
    hash = c("h2", "h3", "h1"),
    stringsAsFactors = FALSE
  )

  result <- rrf_merge(list(list_a, list_b), k = 60)

  expect_equal(nrow(result), 3)

  # h2 should be ranked first: rank 2 in A (1/62) + rank 1 in B (1/61) = highest
  expect_equal(result$hash[1], "h2")

  # Verify exact scores
  h1_score <- 1/61 + 1/63  # rank 1 in A, rank 3 in B
  h2_score <- 1/62 + 1/61  # rank 2 in A, rank 1 in B
  h3_score <- 1/63 + 1/62  # rank 3 in A, rank 2 in B

  expect_equal(result$rrf_score[result$hash == "h1"], h1_score, tolerance = 1e-10)
  expect_equal(result$rrf_score[result$hash == "h2"], h2_score, tolerance = 1e-10)
  expect_equal(result$rrf_score[result$hash == "h3"], h3_score, tolerance = 1e-10)
})

test_that("rrf_merge handles chunks appearing in only one list", {
  list_a <- data.frame(
    text = c("c1", "c2"), origin = c("a", "b"), hash = c("h1", "h2"),
    stringsAsFactors = FALSE
  )
  list_b <- data.frame(
    text = c("c3", "c4"), origin = c("c", "d"), hash = c("h3", "h4"),
    stringsAsFactors = FALSE
  )

  result <- rrf_merge(list(list_a, list_b), k = 60)

  expect_equal(nrow(result), 4)
  # Single-list chunks should have score = 1/(k+rank)
  expect_equal(result$rrf_score[result$hash == "h1"], 1/61, tolerance = 1e-10)
  expect_equal(result$rrf_score[result$hash == "h3"], 1/61, tolerance = 1e-10)
})

test_that("rrf_merge deduplicates by chunk hash", {
  list_a <- data.frame(
    text = c("chunk1", "chunk2"), origin = c("a", "b"), hash = c("same_hash", "h2"),
    stringsAsFactors = FALSE
  )
  list_b <- data.frame(
    text = c("chunk1_copy", "chunk3"), origin = c("a", "c"), hash = c("same_hash", "h3"),
    stringsAsFactors = FALSE
  )

  result <- rrf_merge(list(list_a, list_b), k = 60)

  # same_hash should appear only once
  expect_equal(sum(result$hash == "same_hash"), 1)
  # Its score should be accumulated
  expect_equal(result$rrf_score[result$hash == "same_hash"], 1/61 + 1/61, tolerance = 1e-10)
})

test_that("rrf_merge returns results sorted by score descending", {
  list_a <- data.frame(
    text = c("top", "mid", "low"), origin = c("a", "b", "c"),
    hash = c("h1", "h2", "h3"), stringsAsFactors = FALSE
  )

  result <- rrf_merge(list(list_a), k = 60)

  scores <- result$rrf_score
  expect_true(all(diff(scores) <= 0), info = "Scores should be non-increasing")
})

test_that("rrf_merge handles empty lists gracefully", {
  empty <- data.frame(text = character(), origin = character(), hash = character(),
                      stringsAsFactors = FALSE)
  populated <- data.frame(
    text = c("chunk1"), origin = c("a"), hash = c("h1"),
    stringsAsFactors = FALSE
  )

  # One empty + one populated
  result <- rrf_merge(list(empty, populated), k = 60)
  expect_equal(nrow(result), 1)

  # All empty
  result2 <- rrf_merge(list(empty, empty), k = 60)
  expect_equal(nrow(result2), 0)
  expect_true("hash" %in% names(result2))
})

test_that("rrf_merge with many lists accumulates scores correctly", {
  # 5 lists, chunk h1 appears in all of them at rank 1
  lists <- lapply(1:5, function(i) {
    data.frame(text = "chunk1", origin = "a", hash = "h1", stringsAsFactors = FALSE)
  })

  result <- rrf_merge(lists, k = 60)

  # Score should be 5 * 1/(60+1) = 5/61
  expect_equal(result$rrf_score[1], 5/61, tolerance = 1e-10)
})
