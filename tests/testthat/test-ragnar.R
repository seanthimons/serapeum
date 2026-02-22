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

test_that("chunk_with_ragnar returns expected structure when ragnar available", {
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

test_that("process_pdf uses ragnar chunking", {
  skip_if_not(file.exists("../../testdata/sample.pdf"), "No test PDF available")

  result <- process_pdf("../../testdata/sample.pdf")

  expect_type(result, "list")
  expect_true("chunks" %in% names(result))
  expect_true("chunking_method" %in% names(result))
  expect_equal(result$chunking_method, "ragnar")
})

test_that("search_chunks_hybrid returns expected structure", {
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
  tmp_store <- tempfile(fileext = ".ragnar.duckdb")
  on.exit(unlink(tmp_store))

  # Creating a new store without API key should error
 expect_error(
    get_ragnar_store(tmp_store),
    "OpenRouter API key required"
  )
})

test_that("connect_ragnar_store returns NULL for non-existent store", {
  tmp_store <- tempfile(fileext = ".ragnar.duckdb")

  # Connecting to non-existent store should return NULL
  result <- connect_ragnar_store(tmp_store)
  expect_null(result)
})

test_that("make_embed_function returns a function that calls get_embeddings", {
  # Mock get_embeddings to verify it's called with correct args
  called_with <- NULL
  mock_embeddings <- function(api_key, model, texts) {
    called_with <<- list(api_key = api_key, model = model, texts = texts)
    list(embeddings = list(c(0.1, 0.2, 0.3), c(0.4, 0.5, 0.6)))
  }

  # Temporarily replace get_embeddings
  original <- get_embeddings
  assign("get_embeddings", mock_embeddings, envir = environment(make_embed_function))
  on.exit(assign("get_embeddings", original, envir = environment(make_embed_function)))

  embed_fn <- make_embed_function("test-key", "test-model")

  # Verify it returns a function

  expect_type(embed_fn, "closure")

  # Call it and verify correct args passed through
  result <- embed_fn(c("hello", "world"))

  expect_equal(called_with$api_key, "test-key")
  expect_equal(called_with$model, "test-model")
  expect_equal(called_with$texts, c("hello", "world"))

  # Verify matrix output
  expect_true(is.matrix(result))
  expect_equal(nrow(result), 2)
  expect_equal(ncol(result), 3)
})
