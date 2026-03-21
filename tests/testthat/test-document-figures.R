library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "config.R"))) {
  project_root <- getwd()
}
source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "pdf_images.R"))

# Helper: create a test DB with a notebook + document already inserted
# Uses direct SQL to avoid dependency on migration-added columns
setup_test_db <- function() {
  db_path <- tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  init_schema(con)

  nb_id <- uuid::UUIDgenerate()
  DBI::dbExecute(con, "
    INSERT INTO notebooks (id, name, type) VALUES (?, ?, ?)
  ", list(nb_id, "Test Notebook", "document"))

  doc_id <- uuid::UUIDgenerate()
  DBI::dbExecute(con, "
    INSERT INTO documents (id, notebook_id, filename, filepath, full_text, page_count)
    VALUES (?, ?, ?, ?, ?, ?)
  ", list(doc_id, nb_id, "paper.pdf", "/tmp/paper.pdf", "Full text here", 10L))

  list(con = con, db_path = db_path, nb_id = nb_id, doc_id = doc_id)
}

# Helper: create a second document in an existing test DB
create_test_document <- function(con, nb_id, filename) {
  doc_id <- uuid::UUIDgenerate()
  DBI::dbExecute(con, "
    INSERT INTO documents (id, notebook_id, filename, filepath, full_text, page_count)
    VALUES (?, ?, ?, ?, ?, ?)
  ", list(doc_id, nb_id, filename, paste0("/tmp/", filename), "Text", 5L))
  doc_id
}

teardown_test_db <- function(env) {
  close_db_connection(env$con)
  unlink(env$db_path)
}

# =============================================================================
# Schema tests
# =============================================================================

test_that("document_figures table is created by init_schema", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  tables <- DBI::dbGetQuery(env$con, "
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'main'
  ")$table_name

  expect_true("document_figures" %in% tables)
})

# =============================================================================
# DB helper tests
# =============================================================================

test_that("db_insert_figure inserts and returns ID", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  fig_id <- db_insert_figure(env$con, list(
    document_id = env$doc_id,
    notebook_id = env$nb_id,
    page_number = 3,
    file_path = "data/figures/nb/doc/fig_003_1.png",
    extracted_caption = "Figure 1: A chart",
    figure_label = "Figure 1",
    width = 800,
    height = 600,
    file_size = 12345,
    image_type = "chart"
  ))

  expect_type(fig_id, "character")
  expect_true(nchar(fig_id) > 0)

  # Verify it's in the DB
  row <- DBI::dbGetQuery(env$con,
    "SELECT * FROM document_figures WHERE id = ?", list(fig_id))
  expect_equal(nrow(row), 1)
  expect_equal(row$page_number, 3L)
  expect_equal(row$extracted_caption, "Figure 1: A chart")
  expect_equal(row$width, 800L)
  expect_equal(row$is_excluded, FALSE)
})

test_that("db_insert_figure handles NULL optional fields", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  fig_id <- db_insert_figure(env$con, list(
    document_id = env$doc_id,
    notebook_id = env$nb_id,
    page_number = 1,
    file_path = "data/figures/nb/doc/fig_001_1.png"
  ))

  row <- DBI::dbGetQuery(env$con,
    "SELECT * FROM document_figures WHERE id = ?", list(fig_id))
  expect_equal(nrow(row), 1)
  expect_true(is.na(row$extracted_caption))
  expect_true(is.na(row$width))
  expect_true(is.na(row$quality_score))
})

test_that("db_insert_figures_batch inserts multiple rows", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  df <- data.frame(
    document_id = rep(env$doc_id, 3),
    notebook_id = rep(env$nb_id, 3),
    page_number = c(1, 3, 5),
    file_path = paste0("data/figures/fig_", c(1, 3, 5), ".png"),
    figure_label = paste("Figure", 1:3),
    stringsAsFactors = FALSE
  )

  ids <- db_insert_figures_batch(env$con, df)
  expect_length(ids, 3)

  count <- DBI::dbGetQuery(env$con,
    "SELECT COUNT(*) as n FROM document_figures WHERE document_id = ?",
    list(env$doc_id))$n
  expect_equal(count, 3)
})

test_that("db_get_figures_for_document returns correct figures", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 2, file_path = "fig1.png", figure_label = "Figure 1"
  ))
  db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 5, file_path = "fig2.png", figure_label = "Figure 2"
  ))

  figs <- db_get_figures_for_document(env$con, env$doc_id)
  expect_equal(nrow(figs), 2)
  expect_equal(figs$page_number, c(2L, 5L))
})

test_that("db_get_figures_for_notebook joins with document filename", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 1, file_path = "fig.png"
  ))

  figs <- db_get_figures_for_notebook(env$con, env$nb_id)
  expect_equal(nrow(figs), 1)
  expect_true("document_filename" %in% names(figs))
  expect_equal(figs$document_filename, "paper.pdf")
})

test_that("db_get_slide_figures excludes excluded figures", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 1, file_path = "fig1.png", is_excluded = FALSE
  ))
  db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 2, file_path = "fig2.png", is_excluded = TRUE
  ))

  figs <- db_get_slide_figures(env$con, env$nb_id)
  expect_equal(nrow(figs), 1)
  expect_equal(figs$page_number, 1L)
})

test_that("db_get_slide_figures filters by document_ids", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  doc_id2 <- create_test_document(env$con, env$nb_id, "other.pdf")

  db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 1, file_path = "fig1.png"
  ))
  db_insert_figure(env$con, list(
    document_id = doc_id2, notebook_id = env$nb_id,
    page_number = 1, file_path = "fig2.png"
  ))

  figs <- db_get_slide_figures(env$con, env$nb_id, document_ids = env$doc_id)
  expect_equal(nrow(figs), 1)
  expect_equal(figs$document_id, env$doc_id)
})

test_that("db_update_figure updates specified fields", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  fig_id <- db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 1, file_path = "fig.png"
  ))

  db_update_figure(env$con, fig_id,
    extracted_caption = "Updated caption",
    quality_score = 0.85,
    is_excluded = TRUE
  )

  row <- DBI::dbGetQuery(env$con,
    "SELECT * FROM document_figures WHERE id = ?", list(fig_id))
  expect_equal(row$extracted_caption, "Updated caption")
  expect_equal(row$quality_score, 0.85, tolerance = 0.001)
  expect_equal(row$is_excluded, TRUE)
})

test_that("db_update_figure ignores disallowed fields", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  fig_id <- db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 1, file_path = "fig.png"
  ))

  # Attempt to update id and document_id (not allowed)
  db_update_figure(env$con, fig_id, id = "hacked", document_id = "other")

  row <- DBI::dbGetQuery(env$con,
    "SELECT * FROM document_figures WHERE id = ?", list(fig_id))
  expect_equal(row$id, fig_id)
  expect_equal(row$document_id, env$doc_id)
})

test_that("db_delete_figures_for_document removes rows", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 1, file_path = "fig1.png"
  ))
  db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 2, file_path = "fig2.png"
  ))

  db_delete_figures_for_document(env$con, env$doc_id)

  count <- DBI::dbGetQuery(env$con,
    "SELECT COUNT(*) as n FROM document_figures WHERE document_id = ?",
    list(env$doc_id))$n
  expect_equal(count, 0)
})

test_that("delete_document cascades to figures", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 1, file_path = "fig.png"
  ))

  delete_document(env$con, env$doc_id)

  count <- DBI::dbGetQuery(env$con,
    "SELECT COUNT(*) as n FROM document_figures WHERE document_id = ?",
    list(env$doc_id))$n
  expect_equal(count, 0)
})

# Stub for delete_notebook_store (lives in _ragnar.R, not needed for DB tests)
if (!exists("delete_notebook_store", envir = globalenv())) {
  assign("delete_notebook_store", function(notebook_id) invisible(TRUE), envir = globalenv())
}

test_that("delete_notebook cascades to figures", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))

  db_insert_figure(env$con, list(
    document_id = env$doc_id, notebook_id = env$nb_id,
    page_number = 1, file_path = "fig.png"
  ))

  delete_notebook(env$con, env$nb_id)

  count <- DBI::dbGetQuery(env$con,
    "SELECT COUNT(*) as n FROM document_figures")$n
  expect_equal(count, 0)
})

# =============================================================================
# File utility tests
# =============================================================================

test_that("create_figure_dir creates nested directory", {
  # Use temp dir to avoid polluting project
  old_dir <- getwd()
  tmp <- tempdir()
  setwd(tmp)
  on.exit({
    setwd(old_dir)
    unlink(file.path(tmp, "data"), recursive = TRUE)
  })

  path <- create_figure_dir("nb123", "doc456")
  expect_true(dir.exists(path))
  expect_true(grepl("nb123", path))
  expect_true(grepl("doc456", path))
})

test_that("save_figure writes from raw bytes", {
  old_dir <- getwd()
  tmp <- tempdir()
  setwd(tmp)
  on.exit({
    setwd(old_dir)
    unlink(file.path(tmp, "data"), recursive = TRUE)
  })

  # Minimal valid PNG (1x1 pixel)
  png_bytes <- as.raw(c(
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41,
    0x54, 0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0x00,
    0x00, 0x00, 0x02, 0x00, 0x01, 0xe2, 0x21, 0xbc,
    0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
    0x44, 0xae, 0x42, 0x60, 0x82
  ))

  path <- save_figure(png_bytes, "nb1", "doc1", page = 3, index = 1)
  expect_true(file.exists(path))
  expect_true(grepl("fig_003_1\\.png$", path))
  expect_equal(file.size(path), length(png_bytes))
})

test_that("save_figure copies from existing file", {
  old_dir <- getwd()
  tmp <- tempdir()
  setwd(tmp)
  on.exit({
    setwd(old_dir)
    unlink(file.path(tmp, "data"), recursive = TRUE)
  })

  # Create a source file
  src <- tempfile(fileext = ".png")
  writeBin(charToRaw("fake png"), src)

  path <- save_figure(src, "nb2", "doc2", page = 7, index = 2)
  expect_true(file.exists(path))
  expect_true(grepl("fig_007_2\\.png$", path))
})

test_that("cleanup_figure_files removes document directory", {
  old_dir <- getwd()
  tmp <- tempdir()
  setwd(tmp)
  on.exit({
    setwd(old_dir)
    unlink(file.path(tmp, "data"), recursive = TRUE)
  })

  create_figure_dir("nb3", "doc3")
  writeBin(charToRaw("data"), file.path("data/figures/nb3/doc3/fig.png"))

  expect_true(dir.exists("data/figures/nb3/doc3"))
  cleanup_figure_files("nb3", "doc3")
  expect_false(dir.exists("data/figures/nb3/doc3"))
  # Notebook dir should still exist
  expect_true(dir.exists("data/figures/nb3"))
})

test_that("cleanup_figure_files removes notebook directory", {
  old_dir <- getwd()
  tmp <- tempdir()
  setwd(tmp)
  on.exit({
    setwd(old_dir)
    unlink(file.path(tmp, "data"), recursive = TRUE)
  })

  create_figure_dir("nb4", "doc4")
  cleanup_figure_files("nb4")
  expect_false(dir.exists("data/figures/nb4"))
})

test_that("cleanup_figure_files is safe on nonexistent paths", {
  expect_silent(cleanup_figure_files("nonexistent_nb", "nonexistent_doc"))
})
