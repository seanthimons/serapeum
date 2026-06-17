library(testthat)
library(DBI)
library(duckdb)


source_app("config.R")
source_app("utils_doi.R")
source_app("db.R")
source_app("api_openalex.R")
source_app("interrupt.R")
source_app("citation_audit.R")

# ============================================================================
# Progress I/O tests
# ============================================================================

test_that("write_audit_progress / read_audit_progress round-trip works", {
  pf <- tempfile(fileext = ".progress")
  on.exit(unlink(pf), add = TRUE)

  write_audit_progress(pf, 2, 3, "Fetching forward citations...")
  result <- read_audit_progress(pf)

  expect_equal(result$step, 2L)
  expect_equal(result$total_steps, 3L)
  expect_equal(result$message, "Fetching forward citations...")
})

test_that("read_audit_progress returns defaults for missing file", {
  result <- read_audit_progress("/nonexistent/path.progress")
  expect_equal(result$step, 0L)
  expect_equal(result$total_steps, 3L)
  expect_equal(result$message, "Waiting...")
})

test_that("write_audit_progress handles NULL progress_file gracefully", {
  expect_silent(write_audit_progress(NULL, 1, 3, "test"))
})

# ============================================================================
# rank_missing_papers tests
# ============================================================================

test_that("rank_missing_papers merges backward and forward counts", {
  backward <- c(W1 = 3L, W2 = 2L, W3 = 1L)
  forward <- c(W2 = 2L, W3 = 1L, W4 = 3L)

  result <- rank_missing_papers(backward, forward, threshold = 2)

  expect_true(is.data.frame(result))
  expect_true("work_id" %in% names(result))
  expect_true("backward_count" %in% names(result))
  expect_true("forward_count" %in% names(result))
  expect_true("collection_frequency" %in% names(result))

  # W2 should have backward=2, forward=2, total=4
  w2 <- result[result$work_id == "W2", ]
  expect_equal(w2$backward_count, 2L)
  expect_equal(w2$forward_count, 2L)
  expect_equal(w2$collection_frequency, 4L)

  # Results should be sorted descending by collection_frequency
  expect_true(all(diff(result$collection_frequency) <= 0))

  # W3 should be filtered out (frequency = 1+1=2, threshold=2 → included)
  expect_true("W3" %in% result$work_id)
})

test_that("rank_missing_papers filters by threshold", {
  backward <- c(W1 = 3L, W2 = 1L)
  forward <- c(W1 = 1L)

  result <- rank_missing_papers(backward, forward, threshold = 3)

  # Only W1 should pass (3+1=4 >= 3)
  expect_equal(nrow(result), 1)
  expect_equal(result$work_id[1], "W1")
})

test_that("rank_missing_papers handles empty inputs", {
  result <- rank_missing_papers(integer(0), integer(0), threshold = 2)
  expect_equal(nrow(result), 0)
  expect_true(is.data.frame(result))
  expect_true("work_id" %in% names(result))
})

test_that("rank_missing_papers handles backward-only results", {
  backward <- c(W1 = 3L, W2 = 2L)
  result <- rank_missing_papers(backward, integer(0), threshold = 2)

  expect_equal(nrow(result), 2)
  expect_equal(result$forward_count[1], 0L)
  expect_equal(result$forward_count[2], 0L)
})

test_that("rank_missing_papers handles forward-only results", {
  forward <- c(W1 = 3L, W2 = 2L)
  result <- rank_missing_papers(integer(0), forward, threshold = 2)

  expect_equal(nrow(result), 2)
  expect_equal(result$backward_count[1], 0L)
  expect_equal(result$backward_count[2], 0L)
})

# ============================================================================
# enrich_ranked_with_metadata tests
# ============================================================================

test_that("enrich_ranked_with_metadata adds metadata columns", {
  ranked <- data.frame(
    work_id = c("W1", "W2"),
    backward_count = c(3L, 2L),
    forward_count = c(1L, 2L),
    collection_frequency = c(4L, 4L),
    stringsAsFactors = FALSE
  )

  metadata <- list(
    list(
      paper_id = "W1",
      title = "Paper One",
      authors = list("Alice", "Bob"),
      year = 2020L,
      doi = "10.1000/a",
      cited_by_count = 100L
    ),
    list(
      paper_id = "W2",
      title = "Paper Two",
      authors = list("Charlie"),
      year = 2021L,
      doi = "10.1000/b",
      cited_by_count = 50L
    )
  )

  result <- enrich_ranked_with_metadata(ranked, metadata)

  expect_equal(result$title[1], "Paper One")
  expect_equal(result$title[2], "Paper Two")
  expect_equal(result$year[1], 2020L)
  expect_equal(result$cited_by_count[1], 100L)
  expect_true(grepl("Alice", result$authors[1]))
})

test_that("enrich_ranked_with_metadata handles empty metadata", {
  ranked <- data.frame(
    work_id = "W1",
    backward_count = 3L,
    forward_count = 1L,
    collection_frequency = 4L,
    stringsAsFactors = FALSE
  )

  result <- enrich_ranked_with_metadata(ranked, list())
  expect_true("title" %in% names(result))
  expect_true(is.na(result$title[1]))
})

# ============================================================================
# DB CRUD tests (in-memory DuckDB)
# ============================================================================

test_that("citation audit DB CRUD works end-to-end", {
  con <- dbConnect(duckdb())
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # Initialize schema
  init_schema(con)

  # Create a test notebook
  nb_id <- uuid::UUIDgenerate()
  dbExecute(con, "INSERT INTO notebooks (id, name, type) VALUES (?, ?, ?)",
            list(nb_id, "Test Notebook", "search"))

  # Test create_audit_run
  run_id <- create_audit_run(con, nb_id)
  expect_true(nchar(run_id) > 0)

  # Test get_latest_audit_run
  latest <- get_latest_audit_run(con, nb_id)
  expect_false(is.null(latest))
  expect_equal(latest$id, run_id)
  expect_equal(latest$status, "running")

  # Test update_audit_run
  update_audit_run(con, run_id, status = "completed",
                   backward_count = 100, forward_count = 50,
                   missing_found = 25, total_papers = 10)
  updated <- get_latest_audit_run(con, nb_id)
  expect_equal(updated$status, "completed")
  expect_equal(updated$backward_count, 100L)
  expect_equal(updated$forward_count, 50L)
  expect_equal(updated$missing_found, 25L)
  expect_equal(updated$total_papers, 10L)

  # Test save_audit_results
  results_df <- data.frame(
    work_id = c("W100", "W200", "W300"),
    title = c("Paper A", "Paper B", "Paper C"),
    authors = c("Alice", "Bob", "Charlie"),
    year = c(2020L, 2021L, 2022L),
    doi = c("10.1000/a", "10.1000/b", NA),
    cited_by_count = c(100L, 50L, 25L),
    backward_count = c(5L, 3L, 2L),
    forward_count = c(2L, 2L, 1L),
    collection_frequency = c(7L, 5L, 3L),
    stringsAsFactors = FALSE
  )
  saved <- save_audit_results(con, run_id, nb_id, results_df)
  expect_equal(saved, 3L)

  # Test get_audit_results
  results <- get_audit_results(con, run_id)
  expect_equal(nrow(results), 3)
  expect_equal(results$work_id[1], "W100")  # Highest collection_frequency first
  expect_equal(results$collection_frequency[1], 7L)

  # Test mark_audit_result_imported
  first_id <- results$id[1]
  mark_audit_result_imported(con, first_id)
  results2 <- get_audit_results(con, run_id)
  expect_true(results2$imported[results2$id == first_id])

  # Test check_audit_imports - add an abstract matching W200
  dbExecute(con, "INSERT INTO abstracts (id, notebook_id, paper_id, title) VALUES (?, ?, ?, ?)",
            list(uuid::UUIDgenerate(), nb_id, "W200", "Paper B"))
  check_audit_imports(con, run_id, nb_id)
  results3 <- get_audit_results(con, run_id)
  expect_true(results3$imported[results3$work_id == "W200"])

  # Test get_latest_audit_run returns NULL for unknown notebook
  expect_null(get_latest_audit_run(con, "nonexistent"))

  # Test delete_audit_run
  delete_audit_run(con, run_id)
  results4 <- get_audit_results(con, run_id)
  expect_equal(nrow(results4), 0)
  expect_null(get_latest_audit_run(con, nb_id))
})

test_that("save_audit_results handles empty data frame", {
  con <- dbConnect(duckdb())
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
  init_schema(con)

  result <- save_audit_results(con, "fake-run", "fake-nb", data.frame())
  expect_equal(result, 0L)
})

test_that("save_audit_results handles NULL input", {
  con <- dbConnect(duckdb())
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
  init_schema(con)

  result <- save_audit_results(con, "fake-run", "fake-nb", NULL)
  expect_equal(result, 0L)
})

# ============================================================================
# import_audit_papers tests
# ============================================================================

test_that("import_audit_papers returns skipped_count for partial duplicates", {
  skip("Requires live OpenAlex API - skipped for automated testing")
  # This test would verify skipped_count with mix of new and existing papers
  # Requires actual API calls, so skipped in unit tests
})

test_that("import_audit_papers returns correct skipped_count when all are duplicates", {
  con <- dbConnect(duckdb())
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
  init_schema(con)

  nb_id <- uuid::UUIDgenerate()
  dbExecute(con, "INSERT INTO notebooks (id, name, type) VALUES (?, ?, ?)",
            list(nb_id, "Test Notebook", "search"))

  # Add both papers as existing
  dbExecute(con, "INSERT INTO abstracts (id, notebook_id, paper_id, title) VALUES (?, ?, ?, ?)",
            list(uuid::UUIDgenerate(), nb_id, "W100", "Paper A"))
  dbExecute(con, "INSERT INTO abstracts (id, notebook_id, paper_id, title) VALUES (?, ?, ?, ?)",
            list(uuid::UUIDgenerate(), nb_id, "W200", "Paper B"))

  result <- import_audit_papers(
    work_ids = c("W100", "W200"),
    notebook_id = nb_id,
    email = "test@example.com",
    api_key = NULL,
    con = con
  )

  expect_equal(result$imported_count, 0L)
  expect_equal(result$skipped_count, 2L)  # Both already exist
  expect_equal(result$failed_count, 0L)
})

test_that("import_audit_papers with empty work_ids returns all counts as 0", {
  con <- dbConnect(duckdb())
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
  init_schema(con)

  nb_id <- uuid::UUIDgenerate()
  dbExecute(con, "INSERT INTO notebooks (id, name, type) VALUES (?, ?, ?)",
            list(nb_id, "Test Notebook", "search"))

  result <- import_audit_papers(
    work_ids = character(0),
    notebook_id = nb_id,
    email = "test@example.com",
    api_key = NULL,
    con = con
  )

  expect_equal(result$imported_count, 0L)
  expect_equal(result$skipped_count, 0L)
  expect_equal(result$failed_count, 0L)
})

test_that("import_audit_papers calls progress_callback with correct parameters", {
  skip("Requires live OpenAlex API - skipped for automated testing")
  # This test would verify progress_callback is called with (current, total) parameters
  # Requires actual API calls, so skipped in unit tests
})
