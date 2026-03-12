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

test_that("get_ragnar_store creates a fresh store without invoking a placeholder embed", {
  skip_if_not(tryCatch({ library(ragnar); TRUE }, error = function(e) FALSE), "ragnar not loadable")

  called_with <- list()
  mock_embeddings <- function(api_key, model, texts) {
    called_with <<- append(called_with, list(list(
      api_key = api_key,
      model = model,
      texts = texts
    )))

    embeddings <- lapply(texts, function(text) rep(as.numeric(nchar(text)), 4))
    list(embeddings = embeddings)
  }

  original <- get_embeddings
  assign("get_embeddings", mock_embeddings, envir = environment(make_embed_function))
  on.exit(assign("get_embeddings", original, envir = environment(make_embed_function)), add = TRUE)

  tmp_store <- tempfile(fileext = ".ragnar.duckdb")
  store <- get_ragnar_store(tmp_store, openrouter_api_key = "test-key", embed_model = "test-model")
  on.exit({
    tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL)
    unlink(c(tmp_store, paste0(tmp_store, ".wal"), paste0(tmp_store, ".tmp")), force = TRUE)
  }, add = TRUE)

  expect_true(file.exists(tmp_store))
  expect_true(length(called_with) >= 1)
  expect_equal(called_with[[1]]$texts, "foo")

  runtime_result <- store@embed(c("alpha", "beta"))
  expect_true(is.matrix(runtime_result))
  expect_equal(dim(runtime_result), c(2, 4))
})

test_that("invoke_reindex_progress_callback supports legacy and extended callbacks", {
  legacy_calls <- list()
  legacy_callback <- function(count, total) {
    legacy_calls <<- append(legacy_calls, list(list(count = count, total = total)))
  }

  extended_calls <- list()
  extended_callback <- function(count, total, item_name) {
    extended_calls <<- append(extended_calls, list(list(
      count = count,
      total = total,
      item_name = item_name
    )))
  }

  expect_no_error(invoke_reindex_progress_callback(legacy_callback, 2, 5, "paper-a"))
  expect_equal(legacy_calls[[1]]$count, 2)
  expect_equal(legacy_calls[[1]]$total, 5)

  expect_no_error(invoke_reindex_progress_callback(extended_callback, 3, 7, "paper-b"))
  expect_equal(extended_calls[[1]]$count, 3)
  expect_equal(extended_calls[[1]]$total, 7)
  expect_equal(extended_calls[[1]]$item_name, "paper-b")
})

test_that("check_store_integrity flags stores with chunks but no BM25 index", {
  skip_if_not(tryCatch({ library(ragnar); TRUE }, error = function(e) FALSE), "ragnar not loadable")

  tmp_store <- tempfile(fileext = ".ragnar.duckdb")
  mock_embed <- function(texts) matrix(0, nrow = length(texts), ncol = 4)
  store <- ragnar::ragnar_store_create(tmp_store, embed = mock_embed, embedding_size = 4L, version = 1)
  on.exit({
    if (!is.null(store)) {
      tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL)
    }
    unlink(c(tmp_store, paste0(tmp_store, ".wal"), paste0(tmp_store, ".tmp")), force = TRUE)
  }, add = TRUE)

  dummy_chunk <- data.frame(
    origin = "abstract:test",
    hash = rlang::hash("test chunk"),
    text = "test chunk",
    stringsAsFactors = FALSE
  )
  ragnar::ragnar_store_insert(store, dummy_chunk)
  DBI::dbDisconnect(store@con, shutdown = TRUE)
  store <- NULL

  result <- check_store_integrity(tmp_store)
  expect_false(result$ok)
  expect_false(is.null(result$error))
})

test_that("sync_document_ragnar_statuses marks documents present in the notebook store", {
  skip_if_not(tryCatch({ library(ragnar); TRUE }, error = function(e) FALSE), "ragnar not loadable")

  tmp_db <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(tmp_db)
  on.exit({
    close_db_connection(con)
    unlink(tmp_db)
  }, add = TRUE)

  init_schema(con)
  nb_id <- create_notebook(con, "Sync Test", "document")
  doc_id <- uuid::UUIDgenerate()
  dbExecute(con, "
    INSERT INTO documents (id, notebook_id, filename, filepath, full_text, page_count)
    VALUES (?, ?, ?, ?, ?, ?)
  ", list(doc_id, nb_id, "paper.txt", "", "Abstract body", 1L))
  chunk_id <- uuid::UUIDgenerate()
  dbExecute(con, "
    INSERT INTO chunks (id, source_id, source_type, chunk_index, content, page_number)
    VALUES (?, ?, ?, ?, ?, ?)
  ", list(chunk_id, doc_id, "document", 0L, "Abstract body", 1L))

  tmp_dir <- withr::local_tempdir()
  store_path <- file.path(tmp_dir, paste0(nb_id, ".duckdb"))
  mock_embed <- function(texts) matrix(0, nrow = length(texts), ncol = 4)
  store <- ragnar::ragnar_store_create(store_path, embed = mock_embed, embedding_size = 4L, version = 1)
  on.exit({
    tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL)
  }, add = TRUE)

  ragnar::ragnar_store_insert(store, data.frame(
    origin = "paper.txt#page=1|section=general|type=pdf",
    hash = rlang::hash("paper"),
    text = "Abstract body",
    stringsAsFactors = FALSE
  ))
  DBI::dbDisconnect(store@con, shutdown = TRUE)
  store <- NULL

  original_path_fun <- get_notebook_ragnar_path
  assign("get_notebook_ragnar_path", function(notebook_id) {
    file.path(tmp_dir, paste0(notebook_id, ".duckdb"))
  }, envir = .GlobalEnv)
  on.exit(assign("get_notebook_ragnar_path", original_path_fun, envir = .GlobalEnv), add = TRUE)

  result <- sync_document_ragnar_statuses(con, nb_id)
  expect_true(result$store_exists)
  expect_equal(result$marked, 1L)

  chunk_state <- dbGetQuery(con, "SELECT embedding FROM chunks WHERE source_id = ?", list(doc_id))
  expect_equal(chunk_state$embedding[[1]], "ragnar_indexed")
})
