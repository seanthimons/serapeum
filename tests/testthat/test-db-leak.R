# Connection Leak Detection Tests
# Tests verify DEBT-01 (connection cleanup in search_chunks_hybrid) and
# DEBT-02 (dead code removal for with_ragnar_store and register_ragnar_cleanup)

library(testthat)

source_app("config.R", "db_migrations.R", "db.R", "_ragnar.R")

# Ragnar availability check using safe pattern
ragnar_loadable <- tryCatch({ library(ragnar); TRUE }, error = function(e) FALSE)

# Mock embed function for offline testing
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
# Test 1: search_chunks_hybrid closes self-opened stores (DEBT-01)
# ============================================================================

test_that("search_chunks_hybrid closes self-opened stores", {
  skip_if_not(ragnar_loadable, "ragnar not loadable")

  # Setup: temp notebook DB
  tmp_db <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(tmp_db)
  on.exit({
    close_db_connection(con)
    unlink(tmp_db)
  }, add = TRUE)

  init_schema(con)
  nb_id <- create_notebook(con, "Leak Test", "document")

  # Setup: create a temp ragnar store file
  tmp_dir <- withr::local_tempdir()
  store_path <- file.path(tmp_dir, paste0(nb_id, ".duckdb"))

  # Create minimal ragnar store with mock embed
  store <- ragnar::ragnar_store_create(store_path, embed = mock_embed, embedding_size = 16L, version = 1)

  # Insert one dummy chunk so search doesn't fail
  dummy_chunk <- data.frame(
    origin = "test.pdf#page=1",
    hash = rlang::hash("test content|1"),
    text = "test content",
    stringsAsFactors = FALSE
  )
  ragnar::ragnar_store_insert(store, dummy_chunk)
  build_ragnar_index(store)

  # Close the store (we want search_chunks_hybrid to open its own connection)
  DBI::dbDisconnect(store@con, shutdown = TRUE)

  # Call search_chunks_hybrid with ragnar_store_path (not ragnar_store)
  # This should internally open AND close the store
  # Using api_key = "test" to attach embed function
  result <- search_chunks_hybrid(
    con,
    "test query",
    notebook_id = nb_id,
    ragnar_store_path = store_path,
    api_key = "test",
    embed_model = "mock"
  )

  # After the call returns, verify the store connection was closed by attempting
  # to connect to the same file again. If the previous connection was properly
  # closed with shutdown = TRUE, this should succeed. If leaked, DuckDB will
  # error with "database is locked" or similar.
  expect_no_error({
    store_reconnect <- ragnar::ragnar_store_connect(store_path)
    DBI::dbDisconnect(store_reconnect@con, shutdown = TRUE)
  }, message = "search_chunks_hybrid should close self-opened ragnar stores")
})

# ============================================================================
# Test 2: search_chunks_hybrid does NOT close caller-provided stores (DEBT-01 ownership)
# ============================================================================

test_that("search_chunks_hybrid does NOT close caller-provided stores", {
  skip_if_not(ragnar_loadable, "ragnar not loadable")

  # Setup: temp notebook DB
  tmp_db <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(tmp_db)
  on.exit({
    close_db_connection(con)
    unlink(tmp_db)
  }, add = TRUE)

  init_schema(con)
  nb_id <- create_notebook(con, "Ownership Test", "document")

  # Setup: create a ragnar store explicitly
  tmp_dir <- withr::local_tempdir()
  store_path <- file.path(tmp_dir, paste0(nb_id, ".duckdb"))
  store <- ragnar::ragnar_store_create(store_path, embed = mock_embed, embedding_size = 16L, version = 1)

  # Ensure cleanup happens at the end
  on.exit({
    tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL)
  }, add = TRUE)

  # Insert one dummy chunk
  dummy_chunk <- data.frame(
    origin = "test.pdf#page=1",
    hash = rlang::hash("test content|1"),
    text = "test content",
    stringsAsFactors = FALSE
  )
  ragnar::ragnar_store_insert(store, dummy_chunk)
  build_ragnar_index(store)

  # Attach embed function for search
  store@embed <- mock_embed

  # Call search_chunks_hybrid with the store object (caller owns it)
  result <- search_chunks_hybrid(
    con,
    "test query",
    notebook_id = nb_id,
    ragnar_store = store,
    api_key = "test",
    embed_model = "mock"
  )

  # After the call returns, verify the store connection is STILL open
  # (caller retains ownership)
  expect_no_error({
    # Try a simple query on the store connection
    # If the connection was closed, this would error
    chunk_count <- DBI::dbGetQuery(store@con, "SELECT COUNT(*) as n FROM chunks")$n[1]
    expect_equal(chunk_count, 1L)
  }, message = "search_chunks_hybrid should NOT close caller-provided stores")

  # The caller then closes it explicitly in on.exit
})

# ============================================================================
# Test 3: Dead code is absent from codebase (DEBT-02)
# ============================================================================

test_that("dead code (with_ragnar_store, register_ragnar_cleanup) is absent from codebase", {
  # Get all R source files in R/ directory
  r_dir <- file.path(app_root(), "R")
  r_files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)

  # Search for dead function names in all R files
  with_ragnar_store_matches <- character(0)
  register_ragnar_cleanup_matches <- character(0)

  for (file_path in r_files) {
    lines <- readLines(file_path, warn = FALSE)

    # Check for with_ragnar_store
    with_matches <- grep("with_ragnar_store", lines, value = TRUE)
    if (length(with_matches) > 0) {
      with_ragnar_store_matches <- c(
        with_ragnar_store_matches,
        paste0(basename(file_path), ": ", with_matches)
      )
    }

    # Check for register_ragnar_cleanup
    register_matches <- grep("register_ragnar_cleanup", lines, value = TRUE)
    if (length(register_matches) > 0) {
      register_ragnar_cleanup_matches <- c(
        register_ragnar_cleanup_matches,
        paste0(basename(file_path), ": ", register_matches)
      )
    }
  }

  # Expect zero matches for dead code
  expect_equal(
    length(with_ragnar_store_matches),
    0,
    label = "with_ragnar_store should not exist in R/ directory",
    info = paste("Found matches:", paste(with_ragnar_store_matches, collapse = "\n"))
  )

  expect_equal(
    length(register_ragnar_cleanup_matches),
    0,
    label = "register_ragnar_cleanup should not exist in R/ directory",
    info = paste("Found matches:", paste(register_ragnar_cleanup_matches, collapse = "\n"))
  )
})
