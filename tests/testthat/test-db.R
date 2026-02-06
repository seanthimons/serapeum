library(testthat)

# Source required files from project root
# Navigate up from tests/testthat to project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "config.R"))) {
  # Fallback: we may already be in project root (e.g., when run via Rscript from project root)
  project_root <- getwd()
}
source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "db.R"))

test_that("get_db_connection creates database file", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test.duckdb")

  con <- get_db_connection(db_path)

  expect_true(file.exists(db_path))
  expect_s4_class(con, "duckdb_connection")

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("init_schema creates required tables", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_schema.duckdb")

  con <- get_db_connection(db_path)
  init_schema(con)

  tables <- DBI::dbListTables(con)

  expect_true("notebooks" %in% tables)
  expect_true("documents" %in% tables)
  expect_true("abstracts" %in% tables)
  expect_true("chunks" %in% tables)
  expect_true("settings" %in% tables)

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("notebook CRUD operations work", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_crud.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  # Create
  id <- create_notebook(con, "My Research", "document")
  expect_true(nchar(id) > 0)

  # Read
  notebooks <- list_notebooks(con)
  expect_equal(nrow(notebooks), 1)
  expect_equal(notebooks$name[1], "My Research")

  # Get single
  nb <- get_notebook(con, id)
  expect_equal(nb$type, "document")

  # Delete
  delete_notebook(con, id)
  notebooks <- list_notebooks(con)
  expect_equal(nrow(notebooks), 0)

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("document operations work", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_docs.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "document")
  doc_id <- create_document(con, nb_id, "paper.pdf", "storage/paper.pdf", "Full text", 5)

  docs <- list_documents(con, nb_id)
  expect_equal(nrow(docs), 1)
  expect_equal(docs$filename[1], "paper.pdf")

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("chunk operations work", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_chunks.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "document")
  doc_id <- create_document(con, nb_id, "doc.pdf", "path", "text", 1)

  create_chunk(con, doc_id, "document", 0, "First chunk", page_number = 1)
  create_chunk(con, doc_id, "document", 1, "Second chunk", page_number = 1)

  chunks <- list_chunks(con, doc_id)
  expect_equal(nrow(chunks), 2)

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("settings operations work", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_settings.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  save_db_setting(con, "test_key", "test_value")
  result <- get_db_setting(con, "test_key")
  expect_equal(result, "test_value")

  # Update
  save_db_setting(con, "test_key", "new_value")
  result <- get_db_setting(con, "test_key")
  expect_equal(result, "new_value")

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("get_chunks_for_documents returns chunks with source info", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  # Create notebook and document
  nb_id <- create_notebook(con, "Test", "document")
  doc_id <- create_document(con, nb_id, "test.pdf", "/path/test.pdf", "Full text", 5)

  # Create chunks
  create_chunk(con, doc_id, "document", 1, "Chunk one content", page_number = 1)
  create_chunk(con, doc_id, "document", 2, "Chunk two content", page_number = 2)

  # Fetch chunks
  chunks <- get_chunks_for_documents(con, doc_id)

  expect_equal(nrow(chunks), 2)
  expect_true("doc_name" %in% names(chunks))
  expect_true("page_number" %in% names(chunks))
  expect_equal(chunks$doc_name[1], "test.pdf")
})

test_that("get_chunks_for_documents handles multiple document IDs", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "document")
  doc1_id <- create_document(con, nb_id, "doc1.pdf", "/path/doc1.pdf", "Text 1", 3)
  doc2_id <- create_document(con, nb_id, "doc2.pdf", "/path/doc2.pdf", "Text 2", 2)

  create_chunk(con, doc1_id, "document", 1, "Doc1 chunk", page_number = 1)
  create_chunk(con, doc2_id, "document", 1, "Doc2 chunk", page_number = 1)

  chunks <- get_chunks_for_documents(con, c(doc1_id, doc2_id))

  expect_equal(nrow(chunks), 2)
  expect_true("doc1.pdf" %in% chunks$doc_name)
  expect_true("doc2.pdf" %in% chunks$doc_name)
})

test_that("create_abstract stores keywords", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  # Create a notebook first
  nb_id <- create_notebook(con, "Test", "search")

  # Create abstract with keywords
  keywords <- c("machine learning", "neural networks", "deep learning")
  create_abstract(
    con, nb_id, "paper123", "Test Paper", list("Author One"),
    "This is an abstract.", 2024, "Nature", "https://example.com/pdf",
    keywords = keywords
  )

  # Retrieve and verify
  abstracts <- list_abstracts(con, nb_id)
  expect_equal(nrow(abstracts), 1)
  expect_true("keywords" %in% names(abstracts))

  stored_keywords <- jsonlite::fromJSON(abstracts$keywords[1])
  expect_equal(stored_keywords, keywords)
})

test_that("create_abstract works without keywords (backward compatible)", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "search")

  # Create abstract without keywords parameter
  create_abstract(
    con, nb_id, "paper456", "Test Paper 2", list("Author Two"),
    "Another abstract.", 2023, "Science", NULL
  )

  abstracts <- list_abstracts(con, nb_id)
  expect_equal(nrow(abstracts), 1)
  # Keywords should be empty JSON array or NULL
  expect_true(is.na(abstracts$keywords[1]) || abstracts$keywords[1] == "[]")
})

test_that("notebook stores excluded_paper_ids", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "search")

  # Update with excluded papers
  excluded <- c("W12345", "W67890")
  update_notebook(con, nb_id, excluded_paper_ids = excluded)

  # Retrieve and verify
  nb <- get_notebook(con, nb_id)
  stored_excluded <- jsonlite::fromJSON(nb$excluded_paper_ids)
  expect_equal(stored_excluded, excluded)
})

test_that("notebook excluded_paper_ids defaults to empty array", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "search")

  nb <- get_notebook(con, nb_id)
  # Should be NULL, NA, or empty JSON array
  expect_true(is.na(nb$excluded_paper_ids) || nb$excluded_paper_ids == "[]" || is.null(nb$excluded_paper_ids))
})
