# Integration tests for per-notebook ragnar workflow
# Tests the full pipeline: chunk -> insert -> build_index -> retrieve
# Uses mock embeddings so no API key is required

library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "_ragnar.R"))) {
  # Fallback: we may already be in project root
  project_root <- getwd()
}
source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "_ragnar.R"))
source(file.path(project_root, "R", "config.R"))

# Ragnar availability check using safe pattern
# requireNamespace() is unreliable on this machine due to broken renv DESCRIPTION files
ragnar_loadable <- tryCatch({ library(ragnar); TRUE }, error = function(e) FALSE)

# Mock embed function for offline testing
# Returns deterministic small-dimensional embeddings using nchar-based seed
# Note: must use stats::runif (not runif) to avoid namespace issues inside ragnar's call scope
mock_embed <- function(texts) {
  n <- length(texts)
  m <- matrix(0.0, nrow = n, ncol = 16L)
  for (i in seq_len(n)) {
    set.seed(nchar(texts[[i]]))
    m[i, ] <- stats::runif(16L)
  }
  m
}

# ============================================================================
# Test 1: Full ragnar workflow (chunk -> insert -> build_index -> retrieve)
# ============================================================================

test_that("ragnar workflow: chunk -> insert -> build_index -> retrieve works end-to-end", {
  skip_if_not(ragnar_loadable, "ragnar not loadable")

  # Setup: temp notebook DB
  tmp_db <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(tmp_db)
  on.exit({
    DBI::dbDisconnect(con, shutdown = TRUE)
    unlink(tmp_db)
  }, add = TRUE)

  init_schema(con)
  nb_id <- create_notebook(con, "Integration Test", "document")

  # Setup: temp ragnar store with mock embed (version 1 to match insert_chunks_to_ragnar format)
  tmp_dir <- withr::local_tempdir()
  store_path <- file.path(tmp_dir, paste0(nb_id, ".duckdb"))
  store <- ragnar::ragnar_store_create(store_path, embed = mock_embed, embedding_size = 16L, version = 1)
  on.exit(
    tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL),
    add = TRUE
  )

  # Create synthetic pages about neural networks
  pages <- c(
    "Introduction: This paper studies neural network architectures and deep learning methods.",
    "Methods: We applied gradient descent optimization to train weights across multiple layers.",
    "Results and Benchmarks: The approach achieved 95% accuracy on standard benchmark datasets."
  )

  # Chunk the pages
  chunks <- chunk_with_ragnar(pages, origin = "test_paper.pdf")
  expect_true(nrow(chunks) > 0)
  expect_true("content" %in% names(chunks))
  expect_true("origin" %in% names(chunks))

  # Insert chunks into ragnar store
  insert_chunks_to_ragnar(store, chunks, source_id = "doc-001", source_type = "document")

  # Build the index (required before retrieval)
  build_ragnar_index(store)

  # Retrieve matching chunks
  results <- retrieve_with_ragnar(store, "neural network", top_k = 3)

  # Assertions
  expect_s3_class(results, "data.frame")
  expect_true(nrow(results) > 0)
  expect_true("text" %in% names(results))
})

# ============================================================================
# Test 2: section_hint encoding survives round-trip through ragnar store
# ============================================================================

test_that("section_hint encoding survives round-trip through ragnar store", {
  skip_if_not(ragnar_loadable, "ragnar not loadable")

  # Setup: temp ragnar store with mock embed
  tmp_dir <- withr::local_tempdir()
  store_path <- file.path(tmp_dir, "section-hint-test.duckdb")
  store <- ragnar::ragnar_store_create(store_path, embed = mock_embed, embedding_size = 16L, version = 1)
  on.exit(
    tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL),
    add = TRUE
  )

  # Encode origin with section_hint
  encoded_origin <- encode_origin_metadata(
    "paper.pdf#page=5",
    section_hint = "conclusion",
    doi = "10.1234/test",
    source_type = "pdf"
  )

  # Create a single-row chunks data frame with encoded origin
  chunks <- data.frame(
    content = "The main conclusions are significant and demonstrate the effectiveness of the approach.",
    page_number = 5L,
    chunk_index = 0L,
    context = "",
    origin = encoded_origin,
    stringsAsFactors = FALSE
  )

  # Insert into store and build index
  insert_chunks_to_ragnar(store, chunks, source_id = "doc-002", source_type = "document")
  build_ragnar_index(store)

  # Retrieve
  results <- retrieve_with_ragnar(store, "conclusions", top_k = 1)
  expect_true(nrow(results) > 0)

  # Decode origin and verify section_hint survived the round-trip
  decoded <- decode_origin_metadata(results$origin[1])
  expect_equal(decoded$section_hint, "conclusion")
})

# ============================================================================
# Test 3: Legacy shared store deletion removes all companion files
# ============================================================================

test_that("legacy shared store deletion removes main DB and companion files", {
  # No ragnar skip needed — this tests file operations only
  tmp_dir <- withr::local_tempdir()

  # Create fake legacy files
  legacy_store <- file.path(tmp_dir, "serapeum.ragnar.duckdb")
  legacy_wal <- paste0(legacy_store, ".wal")
  legacy_tmp <- paste0(legacy_store, ".tmp")

  file.create(legacy_store)
  file.create(legacy_wal)
  file.create(legacy_tmp)

  expect_true(file.exists(legacy_store))
  expect_true(file.exists(legacy_wal))
  expect_true(file.exists(legacy_tmp))

  # Run the same deletion logic as in app.R global scope
  if (file.exists(legacy_store)) {
    file.remove(legacy_store)
    for (ext in c(".wal", ".tmp")) {
      f <- paste0(legacy_store, ext)
      if (file.exists(f)) file.remove(f)
    }
  }

  # All three files should be gone
  expect_false(file.exists(legacy_store))
  expect_false(file.exists(legacy_wal))
  expect_false(file.exists(legacy_tmp))
})
