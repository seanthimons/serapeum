# Tests for ragnar helper functions
# These are pure functions for path construction and metadata encoding

library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "_ragnar.R"))) {
  # Fallback: we may already be in project root
  project_root <- getwd()
}
source(file.path(project_root, "R", "_ragnar.R"))

test_that("get_notebook_ragnar_path constructs deterministic paths", {
  # Valid UUIDs produce expected paths
  expect_equal(
    get_notebook_ragnar_path("48fb8820-fbc0-4e75-bf46-92c6dae1db0b"),
    file.path("data", "ragnar", "48fb8820-fbc0-4e75-bf46-92c6dae1db0b.duckdb")
  )

  # Simple IDs work too
  expect_equal(
    get_notebook_ragnar_path("simple-id"),
    file.path("data", "ragnar", "simple-id.duckdb")
  )

  # NULL should error
  expect_error(
    get_notebook_ragnar_path(NULL),
    "notebook_id"
  )

  # Empty string should error
  expect_error(
    get_notebook_ragnar_path(""),
    "notebook_id"
  )
})

test_that("encode_origin_metadata creates pipe-delimited format", {
  # Full metadata encoding
  encoded <- encode_origin_metadata(
    "paper.pdf#page=5",
    section_hint = "conclusion",
    doi = "10.1234/abc",
    source_type = "pdf"
  )

  expect_type(encoded, "character")
  expect_match(encoded, "^paper\\.pdf#page=5\\|")
  expect_match(encoded, "section=conclusion")
  expect_match(encoded, "doi=10\\.1234/abc")
  expect_match(encoded, "type=pdf")

  # Default parameters
  encoded_default <- encode_origin_metadata("paper.pdf#page=1")
  expect_match(encoded_default, "^paper\\.pdf#page=1\\|")
  expect_match(encoded_default, "section=general")
  expect_match(encoded_default, "type=pdf")
  # DOI should be omitted when NULL
  expect_false(grepl("doi=NA", encoded_default))
  expect_false(grepl("doi=$", encoded_default))
})

test_that("decode_origin_metadata parses encoded format", {
  # Round-trip with full metadata
  encoded <- encode_origin_metadata(
    "paper.pdf#page=5",
    section_hint = "conclusion",
    doi = "10.1234/abc",
    source_type = "pdf"
  )

  decoded <- decode_origin_metadata(encoded)

  expect_type(decoded, "list")
  expect_equal(decoded$base_origin, "paper.pdf#page=5")
  expect_equal(decoded$section_hint, "conclusion")
  expect_equal(decoded$doi, "10.1234/abc")
  expect_equal(decoded$source_type, "pdf")
})

test_that("decode_origin_metadata handles missing DOI", {
  # Encode without DOI
  encoded <- encode_origin_metadata(
    "paper.pdf#page=1",
    section_hint = "methods",
    doi = NULL,
    source_type = "pdf"
  )

  decoded <- decode_origin_metadata(encoded)

  expect_equal(decoded$section_hint, "methods")
  expect_true(is.na(decoded$doi))
  expect_equal(decoded$source_type, "pdf")
})

test_that("decode_origin_metadata gracefully handles malformed input", {
  # Plain string without metadata
  decoded <- decode_origin_metadata("just-a-plain-string")

  expect_equal(decoded$section_hint, "general")
  expect_equal(decoded$base_origin, "just-a-plain-string")

  # Empty string
  decoded_empty <- decode_origin_metadata("")
  expect_equal(decoded_empty$section_hint, "general")
})

test_that("encode/decode round-trip preserves all metadata", {
  # Test round-trip with all fields
  original_base <- "document.pdf#page=10"
  original_section <- "introduction"
  original_doi <- "10.5555/example.doi"
  original_type <- "academic"

  encoded <- encode_origin_metadata(
    original_base,
    section_hint = original_section,
    doi = original_doi,
    source_type = original_type
  )

  decoded <- decode_origin_metadata(encoded)

  expect_equal(decoded$base_origin, original_base)
  expect_equal(decoded$section_hint, original_section)
  expect_equal(decoded$doi, original_doi)
  expect_equal(decoded$source_type, original_type)
})

test_that("decode_origin_metadata handles DOIs with special characters", {
  # DOIs can contain slashes and dots but not pipes
  doi_with_slash <- "10.1234/test.2024.v1"

  encoded <- encode_origin_metadata(
    "paper.pdf#page=1",
    doi = doi_with_slash
  )

  decoded <- decode_origin_metadata(encoded)

  expect_equal(decoded$doi, doi_with_slash)
})

# ============================================================================
# Store Lifecycle Tests
# ============================================================================

describe("Store Lifecycle", {

  # ---- check_store_integrity tests ----

  test_that("check_store_integrity returns ok=FALSE with missing=TRUE for non-existent file", {
    # Use a path that definitely doesn't exist
    fake_path <- file.path(tempdir(), "nonexistent-store.duckdb")

    result <- check_store_integrity(fake_path)

    expect_false(result$ok)
    expect_true(result$missing)
    expect_match(result$error, "not found")
  })

  test_that("check_store_integrity returns ok=FALSE for corrupted file", {
    skip_if_not(requireNamespace("ragnar", quietly = TRUE))

    # Create a temp file with garbage content
    temp_dir <- withr::local_tempdir()
    corrupted_path <- file.path(temp_dir, "corrupted.duckdb")

    # Write garbage data
    writeLines("This is not a valid DuckDB file", corrupted_path)

    result <- check_store_integrity(corrupted_path)

    expect_false(result$ok)
    expect_false(result$missing)
    expect_type(result$error, "character")
  })

  # ---- delete_notebook_store tests ----

  test_that("delete_notebook_store returns TRUE for non-existent store", {
    # Use a random UUID that won't have a store
    random_uuid <- "00000000-0000-0000-0000-000000000000"

    result <- delete_notebook_store(random_uuid)

    expect_true(result)
  })

  test_that("delete_notebook_store removes existing file and returns TRUE", {
    # Create temp directory and file
    temp_dir <- withr::local_tempdir()

    # Override ragnar dir for testing
    ragnar_dir <- file.path(temp_dir, "ragnar")
    dir.create(ragnar_dir, recursive = TRUE)

    # Create a fake store file
    test_id <- "test-notebook-id"
    store_path <- file.path(ragnar_dir, paste0(test_id, ".duckdb"))
    file.create(store_path)

    expect_true(file.exists(store_path))

    # Temporarily override get_notebook_ragnar_path
    original_fun <- get_notebook_ragnar_path
    assignInNamespace("get_notebook_ragnar_path", function(notebook_id) {
      file.path(ragnar_dir, paste0(notebook_id, ".duckdb"))
    }, ns = "serapeum", envir = parent.frame())

    on.exit({
      assignInNamespace("get_notebook_ragnar_path", original_fun, ns = "serapeum")
    })

    result <- delete_notebook_store(test_id)

    expect_true(result)
    expect_false(file.exists(store_path))
  })

  test_that("delete_notebook_store cleans up WAL file alongside main store", {
    # Create temp directory
    temp_dir <- withr::local_tempdir()
    ragnar_dir <- file.path(temp_dir, "ragnar")
    dir.create(ragnar_dir, recursive = TRUE)

    # Create fake files
    test_id <- "test-wal-cleanup"
    store_path <- file.path(ragnar_dir, paste0(test_id, ".duckdb"))
    wal_path <- paste0(store_path, ".wal")

    file.create(store_path)
    file.create(wal_path)

    expect_true(file.exists(store_path))
    expect_true(file.exists(wal_path))

    # Override path function
    original_fun <- get_notebook_ragnar_path
    assignInNamespace("get_notebook_ragnar_path", function(notebook_id) {
      file.path(ragnar_dir, paste0(notebook_id, ".duckdb"))
    }, ns = "serapeum", envir = parent.frame())

    on.exit({
      assignInNamespace("get_notebook_ragnar_path", original_fun, ns = "serapeum")
    })

    result <- delete_notebook_store(test_id)

    expect_true(result)
    expect_false(file.exists(store_path))
    expect_false(file.exists(wal_path))
  })

  # ---- find_orphaned_stores tests ----

  test_that("find_orphaned_stores returns orphans correctly", {
    skip_if_not(requireNamespace("DBI", quietly = TRUE))
    skip_if_not(requireNamespace("duckdb", quietly = TRUE))

    # Create temp directory for ragnar stores
    temp_dir <- withr::local_tempdir()
    ragnar_dir <- file.path(temp_dir, "ragnar")
    dir.create(ragnar_dir, recursive = TRUE)

    # Create in-memory database with one notebook
    con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

    DBI::dbExecute(con, "CREATE TABLE notebooks (id VARCHAR PRIMARY KEY)")

    valid_id <- "valid-notebook-id"
    orphan_id <- "orphan-notebook-id"

    DBI::dbExecute(con, "INSERT INTO notebooks (id) VALUES (?)", list(valid_id))

    # Create two store files: one valid, one orphan
    valid_path <- file.path(ragnar_dir, paste0(valid_id, ".duckdb"))
    orphan_path <- file.path(ragnar_dir, paste0(orphan_id, ".duckdb"))

    file.create(valid_path)
    file.create(orphan_path)

    # Override data/ragnar path temporarily
    withr::local_dir(temp_dir)

    orphans <- find_orphaned_stores(con)

    # Should find only the orphan
    expect_length(orphans, 1)
    expect_true(grepl(orphan_id, orphans[1]))
    expect_false(any(grepl(valid_id, orphans)))
  })
})
