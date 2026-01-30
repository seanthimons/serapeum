library(testthat)

# Source required files
source(file.path(getwd(), "R", "config.R"))
source(file.path(getwd(), "R", "db.R"))

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
