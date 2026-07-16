library(testthat)

source_app("config.R", "db_migrations.R", "db.R", "pdf.R", "import_paper.R")

test_that("import_single_paper carries OpenAlex work type metadata into documents", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con), add = TRUE)

  notebook_id <- create_notebook(con, "Document Import", "document")
  abstract_id <- create_abstract(
    con, notebook_id, "W123", "Software Paper", c("Ada Lovelace"),
    "This is the abstract text.", 2026, "Open Source Journal", NA_character_,
    work_type = "software-paper",
    work_type_crossref = "posted-content",
    doi = "10.1234/software"
  )
  abstract_row <- list_abstracts(con, notebook_id)[1, ]

  result <- import_single_paper(con, notebook_id, abstract_row, download_pdfs = FALSE)

  expect_true(result$success)
  doc <- get_document(con, result$doc_id)
  expect_equal(doc$abstract_id, abstract_id)
  expect_equal(doc$work_type, "software-paper")
  expect_equal(doc$work_type_crossref, "posted-content")
})
