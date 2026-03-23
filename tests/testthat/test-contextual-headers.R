library(testthat)


source_app("config.R")
source_app("db_migrations.R")
source_app("db.R")
source_app("api_openrouter.R")
source_app("_ragnar.R")

# --- Phase 5: Contextual Chunk Headers ---

test_that("prepend_contextual_header adds title to chunk content", {
  result <- prepend_contextual_header("Some chunk text", paper_title = "My Paper")
  expect_equal(result, "[My Paper]\nSome chunk text")
})

test_that("prepend_contextual_header adds title + section when available", {
  result <- prepend_contextual_header("Methods text", paper_title = "My Paper", section_hint = "Methods")
  expect_equal(result, "[My Paper | Section: Methods]\nMethods text")
})

test_that("prepend_contextual_header handles NULL/empty section", {
  # NULL section -> title only
  result <- prepend_contextual_header("text", paper_title = "Title", section_hint = NULL)
  expect_equal(result, "[Title]\ntext")

  # Empty section -> title only
  result2 <- prepend_contextual_header("text", paper_title = "Title", section_hint = "")
  expect_equal(result2, "[Title]\ntext")

  # NA section -> title only
  result3 <- prepend_contextual_header("text", paper_title = "Title", section_hint = NA)
  expect_equal(result3, "[Title]\ntext")

  # "general" section -> title only (default section_hint is "general")
  result4 <- prepend_contextual_header("text", paper_title = "Title", section_hint = "general")
  expect_equal(result4, "[Title]\ntext")
})

test_that("prepend_contextual_header returns content as-is for missing title", {
  result <- prepend_contextual_header("raw text", paper_title = NULL)
  expect_equal(result, "raw text")

  result2 <- prepend_contextual_header("raw text", paper_title = "")
  expect_equal(result2, "raw text")

  result3 <- prepend_contextual_header("raw text", paper_title = NA)
  expect_equal(result3, "raw text")
})

test_that("chunk_with_ragnar prepends contextual header when paper_title given", {
  pages <- c("This is page one with content about testing.")
  result <- chunk_with_ragnar(pages, origin = "test.pdf", paper_title = "Water Quality Study")

  expect_true(nrow(result) > 0)
  # Check that the content starts with the contextual header
  expect_true(grepl("^\\[Water Quality Study\\]\n", result$content[1]))
})

test_that("chunk_with_ragnar works without paper_title (backward compatible)", {
  pages <- c("Page content here.")
  result <- chunk_with_ragnar(pages, origin = "test.pdf")

  expect_true(nrow(result) > 0)
  # No header prepended
  expect_false(grepl("^\\[", result$content[1]))
})

# --- Stale Index Detection ---

test_that("is_ragnar_store_stale returns TRUE when no version stored", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  init_schema(con)

  expect_true(is_ragnar_store_stale(con, "test-notebook-id"))
})

test_that("is_ragnar_store_stale returns FALSE when version is current", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  init_schema(con)

  mark_ragnar_store_current(con, "test-notebook-id")
  expect_false(is_ragnar_store_stale(con, "test-notebook-id"))
})

test_that("is_ragnar_store_stale returns TRUE when version is old", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  init_schema(con)

  # Set an old version
  save_db_setting(con, "index_schema_version_test-nb", 1L)
  expect_true(is_ragnar_store_stale(con, "test-nb"))
})

test_that("mark_ragnar_store_current sets the correct version", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  init_schema(con)

  mark_ragnar_store_current(con, "nb-123")

  stored <- get_db_setting(con, "index_schema_version_nb-123")
  expect_equal(stored, RAGNAR_INDEX_SCHEMA_VERSION)
})
