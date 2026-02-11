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

test_that("search_chunks finds abstract chunks by notebook", {
  db_path <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  on.exit({
    close_db_connection(con)
    unlink(db_path)
  })

  # Create test notebook
  notebook_id <- create_notebook(con, "Test Notebook", "search")

  # Create abstract with text
  abstract_id <- create_abstract(
    con,
    notebook_id,
    "test-paper-1",
    "Machine Learning in Healthcare",
    c("Jane Doe"),
    "Machine learning is transforming healthcare with predictive models.",
    2023,
    "AI Journal",
    "https://example.com/ml.pdf"
  )

  # Create chunk
  chunk_id <- create_chunk(con, abstract_id, "abstract", 0, "Machine learning is transforming healthcare with predictive models.")

  # Create a fake embedding (256-dimensional vector)
  fake_embedding <- rep(0.1, 256)
  fake_embedding[1] <- 1.0  # Make first dimension distinct
  embedding_str <- paste(fake_embedding, collapse = ",")

  # Update chunk with embedding
  DBI::dbExecute(con, "UPDATE chunks SET embedding = ? WHERE id = ?", list(embedding_str, chunk_id))

  # Create a similar query embedding (should match based on cosine similarity)
  query_embedding <- rep(0.1, 256)
  query_embedding[1] <- 0.9  # Similar to our chunk

  # Search for chunks
  results <- search_chunks(con, query_embedding, notebook_id)

  # Verify results
  expect_true(nrow(results) > 0)
  expect_true("abstract_title" %in% names(results))
  expect_equal(results$source_type[1], "abstract")
  expect_equal(results$abstract_title[1], "Machine Learning in Healthcare")
  expect_false(is.na(results$abstract_title[1]))
})

test_that("search_chunks filters abstracts by notebook", {
  db_path <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  on.exit({
    close_db_connection(con)
    unlink(db_path)
  })

  # Create two notebooks
  notebook1_id <- create_notebook(con, "Notebook 1", "search")
  notebook2_id <- create_notebook(con, "Notebook 2", "search")

  # Create abstract in notebook 1
  abstract1_id <- create_abstract(
    con, notebook1_id, "paper-1", "Paper in Notebook 1",
    c("Author A"), "Content for notebook 1", 2023, "Journal A", "http://ex.com/1"
  )
  chunk1_id <- create_chunk(con, abstract1_id, "abstract", 0, "Content for notebook 1")

  # Create abstract in notebook 2
  abstract2_id <- create_abstract(
    con, notebook2_id, "paper-2", "Paper in Notebook 2",
    c("Author B"), "Content for notebook 2", 2023, "Journal B", "http://ex.com/2"
  )
  chunk2_id <- create_chunk(con, abstract2_id, "abstract", 0, "Content for notebook 2")

  # Add embeddings to both
  fake_emb <- paste(rep(0.5, 256), collapse = ",")
  DBI::dbExecute(con, "UPDATE chunks SET embedding = ? WHERE id = ?", list(fake_emb, chunk1_id))
  DBI::dbExecute(con, "UPDATE chunks SET embedding = ? WHERE id = ?", list(fake_emb, chunk2_id))

  # Search in notebook 1
  query_emb <- rep(0.5, 256)
  results1 <- search_chunks(con, query_emb, notebook1_id, limit = 10)

  # Should only find notebook 1's abstract
  expect_equal(nrow(results1), 1)
  expect_equal(results1$abstract_title[1], "Paper in Notebook 1")

  # Search in notebook 2
  results2 <- search_chunks(con, query_emb, notebook2_id, limit = 10)

  # Should only find notebook 2's abstract
  expect_equal(nrow(results2), 1)
  expect_equal(results2$abstract_title[1], "Paper in Notebook 2")
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
