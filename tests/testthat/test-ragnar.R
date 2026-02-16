# Tests for ragnar integration
# These tests verify the ragnar integration works correctly

library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "_ragnar.R"))) {
  # Fallback: we may already be in project root
  project_root <- getwd()
}
source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "api_openrouter.R"))
source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "_ragnar.R"))

test_that("ragnar_available returns boolean", {
  result <- ragnar_available()
  expect_type(result, "logical")
  expect_length(result, 1)
})

test_that("chunk_with_ragnar returns expected structure when ragnar available", {
  skip_if_not(ragnar_available(), "ragnar not installed")

  # Simple test with mock pages
  pages <- c(
    "This is page one with some content about testing.",
    "This is page two with different content about validation."
  )

  result <- chunk_with_ragnar(pages, origin = "test.pdf")

  expect_s3_class(result, "data.frame")
  expect_true("content" %in% names(result))
  expect_true("page_number" %in% names(result))
  expect_true("chunk_index" %in% names(result))
  expect_true("origin" %in% names(result))
})

test_that("process_pdf falls back to word-based chunking without ragnar", {
  skip_if_not(file.exists("../../testdata/sample.pdf"), "No test PDF available")

  # Force fallback by setting use_ragnar = FALSE
  result <- process_pdf("../../testdata/sample.pdf", use_ragnar = FALSE)

  expect_type(result, "list")
  expect_true("chunks" %in% names(result))
  expect_true("full_text" %in% names(result))
  expect_true("page_count" %in% names(result))
  expect_equal(result$chunking_method, "word_based")
})

test_that("process_pdf uses ragnar when available", {
  skip_if_not(ragnar_available(), "ragnar not installed")
  skip_if_not(file.exists("../../testdata/sample.pdf"), "No test PDF available")

  result <- process_pdf("../../testdata/sample.pdf", use_ragnar = TRUE)

  expect_type(result, "list")
  expect_true("chunks" %in% names(result))
  expect_true("chunking_method" %in% names(result))
  # Should use ragnar if available
  expect_equal(result$chunking_method, "ragnar")
})

test_that("search_chunks_hybrid returns expected structure", {
  skip_if_not(ragnar_available(), "ragnar not installed")

  # Create temporary database
  tmp_db <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(tmp_db)
  on.exit({
    close_db_connection(con)
    unlink(tmp_db)
  })

  init_schema(con)

  # Search with no data should return empty frame
  result <- search_chunks_hybrid(con, "test query", limit = 5)

  expect_s3_class(result, "data.frame")
  expect_true("content" %in% names(result) || nrow(result) == 0)
})

test_that("get_ragnar_store requires API key for new stores", {
  skip_if_not(ragnar_available(), "ragnar not installed")

  tmp_store <- tempfile(fileext = ".ragnar.duckdb")
  on.exit(unlink(tmp_store))

  # Creating a new store without API key should error
 expect_error(
    get_ragnar_store(tmp_store),
    "OpenRouter API key required"
  )
})

test_that("connect_ragnar_store returns NULL for non-existent store", {
  skip_if_not(ragnar_available(), "ragnar not installed")

  tmp_store <- tempfile(fileext = ".ragnar.duckdb")

  # Connecting to non-existent store should return NULL
  result <- connect_ragnar_store(tmp_store)
  expect_null(result)
})
