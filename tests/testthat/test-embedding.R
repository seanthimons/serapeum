library(testthat)

# Source required files from project root
# Navigate up from tests/testthat to project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "config.R"))) {
  # Fallback: we may already be in project root (e.g., when run via Rscript from project root)
  project_root <- getwd()
}
source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "rag.R"))

test_that("abstract chunks are created with correct source_type", {
  db_path <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  on.exit({
    close_db_connection(con)
    unlink(db_path)
  })

  # Create a test notebook (type = "search")
  notebook_id <- create_notebook(con, "Test Search Notebook", "search")

  # Create an abstract
  abstract_id <- create_abstract(
    con,
    notebook_id,
    "test-paper-id",
    "Test Paper Title",
    c("Author One", "Author Two"),
    "This is a test abstract text for embedding.",
    2024,
    "Test Journal",
    "https://example.com/paper.pdf"
  )

  # Create a chunk with abstract source
  chunk_id <- create_chunk(con, abstract_id, "abstract", 0, "This is a test abstract text for embedding.")

  # Query chunks table to verify
  chunks <- DBI::dbGetQuery(con, "SELECT * FROM chunks WHERE id = ?", list(chunk_id))

  expect_equal(nrow(chunks), 1)
  expect_equal(chunks$source_type, "abstract")
  expect_equal(chunks$source_id, abstract_id)
  expect_equal(chunks$content, "This is a test abstract text for embedding.")
  expect_equal(chunks$chunk_index, 0)
})

test_that("build_context formats abstract citations correctly", {
  # Create a mock result data frame mimicking search results
  mock_results <- data.frame(
    content = c("Machine learning improves diagnosis.", "Deep learning is a subset of ML."),
    page_number = c(1, 2),
    doc_name = c(NA_character_, NA_character_),
    abstract_title = c("AI in Healthcare", "Deep Learning Basics"),
    stringsAsFactors = FALSE
  )

  # Build context
  context <- build_context(mock_results)

  # Verify context contains paper titles in citation format
  expect_true(grepl("\\[AI in Healthcare\\]", context))
  expect_true(grepl("\\[Deep Learning Basics\\]", context))
  expect_true(grepl("Machine learning improves diagnosis", context))
  expect_true(grepl("Deep learning is a subset of ML", context))
})

test_that("build_context handles mixed document and abstract sources", {
  # Mix of document chunks and abstract chunks
  mock_results <- data.frame(
    content = c("Document content here.", "Abstract content here."),
    page_number = c(5, 1),
    doc_name = c("research_paper.pdf", NA_character_),
    abstract_title = c(NA_character_, "Test Abstract Title"),
    stringsAsFactors = FALSE
  )

  context <- build_context(mock_results)

  # Document citation should include page number
  expect_true(grepl("\\[research_paper.pdf, p\\.5\\]", context))
  # Abstract citation should only include title
  expect_true(grepl("\\[Test Abstract Title\\]", context))
})
