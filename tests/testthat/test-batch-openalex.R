library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "api_openalex.R"))) {
  project_root <- getwd()
}
source(file.path(project_root, "R", "api_openalex.R"))

# --- chunk_dois tests ---

test_that("chunk_dois splits 5 DOIs into 3 chunks of size 2", {
  dois <- c("10.1000/a", "10.1000/b", "10.1000/c", "10.1000/d", "10.1000/e")
  chunks <- chunk_dois(dois, batch_size = 2)
  expect_equal(length(chunks), 3)
  expect_equal(length(chunks[[1]]), 2)
  expect_equal(length(chunks[[2]]), 2)
  expect_equal(length(chunks[[3]]), 1)
})

test_that("chunk_dois puts 3 DOIs into 1 chunk with batch_size=50", {
  dois <- c("10.1000/a", "10.1000/b", "10.1000/c")
  chunks <- chunk_dois(dois, batch_size = 50)
  expect_equal(length(chunks), 1)
  expect_equal(length(chunks[[1]]), 3)
})

test_that("chunk_dois returns empty list for empty input", {
  chunks <- chunk_dois(character(0), batch_size = 50)
  expect_equal(length(chunks), 0)
})

test_that("chunk_dois handles single DOI", {
  chunks <- chunk_dois("10.1000/a", batch_size = 50)
  expect_equal(length(chunks), 1)
  expect_equal(length(chunks[[1]]), 1)
})

# --- build_batch_filter tests ---

test_that("build_batch_filter creates pipe-separated filter for 3 DOIs", {
  dois <- c("10.1000/a", "10.1000/b", "10.1000/c")
  filter <- build_batch_filter(dois)
  expect_equal(filter, "doi:10.1000/a|10.1000/b|10.1000/c")
})

test_that("build_batch_filter handles single DOI", {
  filter <- build_batch_filter("10.1000/a")
  expect_equal(filter, "doi:10.1000/a")
})

# --- match_results_to_dois tests ---

test_that("match_results_to_dois identifies found and not_found DOIs", {
  # Simulate parsed works with doi field (OpenAlex returns full URL)
  works <- list(
    list(paper_id = "W1", doi = "https://doi.org/10.1000/a", title = "Paper A"),
    list(paper_id = "W2", doi = "https://doi.org/10.1000/b", title = "Paper B")
  )
  input_dois <- c("10.1000/a", "10.1000/b", "10.1000/c")

  result <- match_results_to_dois(works, input_dois)

  expect_equal(length(result$found), 2)
  expect_equal(length(result$not_found), 1)
  expect_equal(result$not_found[[1]]$doi, "10.1000/c")
  expect_equal(result$not_found[[1]]$reason, "not_found")
})

test_that("match_results_to_dois handles case differences", {
  works <- list(
    list(paper_id = "W1", doi = "https://doi.org/10.1000/ABC", title = "Paper A")
  )
  input_dois <- c("10.1000/abc")

  result <- match_results_to_dois(works, input_dois)

  expect_equal(length(result$found), 1)
  expect_equal(length(result$not_found), 0)
})

test_that("match_results_to_dois handles all DOIs found", {
  works <- list(
    list(paper_id = "W1", doi = "https://doi.org/10.1000/a", title = "Paper A")
  )
  input_dois <- c("10.1000/a")

  result <- match_results_to_dois(works, input_dois)

  expect_equal(length(result$found), 1)
  expect_equal(length(result$not_found), 0)
})

test_that("match_results_to_dois handles no DOIs found", {
  works <- list()
  input_dois <- c("10.1000/a", "10.1000/b")

  result <- match_results_to_dois(works, input_dois)

  expect_equal(length(result$found), 0)
  expect_equal(length(result$not_found), 2)
})

# --- batch_fetch_papers integration tests (mocked HTTP) ---

test_that("batch_fetch_papers validates inputs", {
  # Non-character input
  expect_error(batch_fetch_papers(123, "test@test.com"))

  # Empty vector
  expect_error(batch_fetch_papers(character(0), "test@test.com"))

  # batch_size out of range
  expect_error(batch_fetch_papers("10.1000/a", "test@test.com", batch_size = 0))
  expect_error(batch_fetch_papers("10.1000/a", "test@test.com", batch_size = 51))
})

test_that("batch_fetch_papers calls progress_callback with correct values", {
  # Mock fetch_single_batch to avoid real HTTP calls
  mock_fetch <- function(dois, email, api_key = NULL, parse = TRUE) {
    works <- lapply(seq_along(dois), function(i) {
      list(paper_id = paste0("W", i), doi = paste0("https://doi.org/", dois[i]),
           title = paste("Paper", i))
    })
    list(found = works, not_found = list())
  }

  # Temporarily replace fetch_single_batch
  original_fn <- NULL
  if (exists("fetch_single_batch", mode = "function")) {
    original_fn <- fetch_single_batch
  }
  assignInNamespace_safe <- function(name, value) {
    assign(name, value, envir = globalenv())
  }
  assign("fetch_single_batch", mock_fetch, envir = globalenv())

  progress_calls <- list()
  callback <- function(batch_current, batch_total, found_so_far, not_found_so_far) {
    progress_calls[[length(progress_calls) + 1]] <<- list(
      batch_current = batch_current,
      batch_total = batch_total,
      found_so_far = found_so_far,
      not_found_so_far = not_found_so_far
    )
  }

  dois <- c("10.1000/a", "10.1000/b", "10.1000/c")
  result <- batch_fetch_papers(dois, "test@test.com", batch_size = 2, delay = 0,
                                progress_callback = callback)

  # Should have 2 progress callbacks (2 batches: [a,b] and [c])
  expect_equal(length(progress_calls), 2)
  expect_equal(progress_calls[[1]]$batch_current, 1)
  expect_equal(progress_calls[[1]]$batch_total, 2)
  expect_equal(progress_calls[[2]]$batch_current, 2)
  expect_equal(progress_calls[[2]]$batch_total, 2)

  # Restore
  if (!is.null(original_fn)) {
    assign("fetch_single_batch", original_fn, envir = globalenv())
  } else {
    rm("fetch_single_batch", envir = globalenv())
  }
})

test_that("batch_fetch_papers handles batch failure gracefully", {
  call_count <- 0
  mock_fetch_with_failure <- function(dois, email, api_key = NULL, parse = TRUE) {
    call_count <<- call_count + 1
    if (call_count == 1) {
      stop("HTTP 500 Internal Server Error")
    }
    # Second batch succeeds
    works <- lapply(seq_along(dois), function(i) {
      list(paper_id = paste0("W", i + 10), doi = paste0("https://doi.org/", dois[i]),
           title = paste("Paper", i))
    })
    list(found = works, not_found = list())
  }

  original_fn <- if (exists("fetch_single_batch", mode = "function")) fetch_single_batch else NULL
  assign("fetch_single_batch", mock_fetch_with_failure, envir = globalenv())

  dois <- c("10.1000/a", "10.1000/b", "10.1000/c", "10.1000/d")
  result <- batch_fetch_papers(dois, "test@test.com", batch_size = 2, delay = 0)

  # First batch (a, b) failed -> api_error
  # Second batch (c, d) succeeded
  expect_true(length(result$papers) > 0)
  expect_true(length(result$errors) > 0)

  # Check error categorization
  error_reasons <- vapply(result$errors, function(e) e$reason, character(1))
  expect_true("api_error" %in% error_reasons)

  # Restore
  if (!is.null(original_fn)) {
    assign("fetch_single_batch", original_fn, envir = globalenv())
  } else {
    rm("fetch_single_batch", envir = globalenv())
  }
})

test_that("batch_fetch_papers deduplicates by paper_id", {
  mock_fetch_dupes <- function(dois, email, api_key = NULL, parse = TRUE) {
    # Return same paper_id for different DOIs
    works <- list(
      list(paper_id = "W1", doi = "https://doi.org/10.1000/a", title = "Paper A"),
      list(paper_id = "W1", doi = "https://doi.org/10.1000/b", title = "Paper A duplicate")
    )
    list(found = works, not_found = list())
  }

  original_fn <- if (exists("fetch_single_batch", mode = "function")) fetch_single_batch else NULL
  assign("fetch_single_batch", mock_fetch_dupes, envir = globalenv())

  dois <- c("10.1000/a", "10.1000/b")
  result <- batch_fetch_papers(dois, "test@test.com", batch_size = 50, delay = 0)

  # Should deduplicate to 1 paper
  expect_equal(length(result$papers), 1)
  expect_equal(result$papers[[1]]$paper_id, "W1")

  # Restore
  if (!is.null(original_fn)) {
    assign("fetch_single_batch", original_fn, envir = globalenv())
  } else {
    rm("fetch_single_batch", envir = globalenv())
  }
})

test_that("batch_fetch_papers rate_limited error on 429", {
  mock_fetch_429 <- function(dois, email, api_key = NULL, parse = TRUE) {
    stop("HTTP 429 Too Many Requests rate limit exceeded")
  }

  original_fn <- if (exists("fetch_single_batch", mode = "function")) fetch_single_batch else NULL
  assign("fetch_single_batch", mock_fetch_429, envir = globalenv())

  dois <- c("10.1000/a")
  result <- batch_fetch_papers(dois, "test@test.com", batch_size = 50, delay = 0)

  expect_equal(length(result$papers), 0)
  expect_equal(length(result$errors), 1)
  expect_equal(result$errors[[1]]$reason, "rate_limited")

  # Restore
  if (!is.null(original_fn)) {
    assign("fetch_single_batch", original_fn, envir = globalenv())
  } else {
    rm("fetch_single_batch", envir = globalenv())
  }
})

test_that("batch_fetch_papers writes to log file", {
  mock_fetch_simple <- function(dois, email, api_key = NULL, parse = TRUE) {
    list(found = list(), not_found = list())
  }

  original_fn <- if (exists("fetch_single_batch", mode = "function")) fetch_single_batch else NULL
  assign("fetch_single_batch", mock_fetch_simple, envir = globalenv())

  log_file <- tempfile(fileext = ".log")

  dois <- c("10.1000/a")
  result <- batch_fetch_papers(dois, "test@test.com", batch_size = 50, delay = 0,
                                log_file = log_file)

  # Log file should exist and have content
  expect_true(file.exists(log_file))
  log_content <- readLines(log_file)
  expect_true(length(log_content) > 0)
  expect_true(any(grepl("batch_fetch_papers started", log_content)))
  expect_true(any(grepl("batch_fetch_papers complete", log_content)))

  # Cleanup
  unlink(log_file)
  if (!is.null(original_fn)) {
    assign("fetch_single_batch", original_fn, envir = globalenv())
  } else {
    rm("fetch_single_batch", envir = globalenv())
  }
})
