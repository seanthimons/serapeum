# Tests for RAG citation label formatting (#159)

library(testthat)

source_app("rag.R")

# --- format_citation_label() tests ---

test_that("format_citation_label handles full metadata with plain string authors", {
  result <- format_citation_label('["Jane Smith", "Bob Jones"]', 2023)
  expect_equal(result, "Smith & Jones (2023)")
})

test_that("format_citation_label handles three+ authors with et al.", {
  result <- format_citation_label('["Alice Brown", "Bob Jones", "Carol White"]', 2021)
  expect_equal(result, "Brown et al. (2021)")
})

test_that("format_citation_label handles single author", {
  result <- format_citation_label('["Jane Smith"]', 2020)
  expect_equal(result, "Smith (2020)")
})

test_that("format_citation_label handles structured OpenAlex author objects", {
  authors_json <- '[{"display_name": "Jane Smith"}, {"display_name": "Bob Jones"}, {"display_name": "Carol White"}]'
  result <- format_citation_label(authors_json, 2024)
  expect_equal(result, "Smith et al. (2024)")
})

test_that("format_citation_label handles two structured authors", {
  authors_json <- '[{"display_name": "Jane Smith"}, {"display_name": "Bob Jones"}]'
  result <- format_citation_label(authors_json, 2022)
  expect_equal(result, "Smith & Jones (2022)")
})

test_that("format_citation_label falls back to Unknown when authors NULL", {
  result <- format_citation_label(NULL, 2023)
  expect_equal(result, "Unknown (2023)")
})

test_that("format_citation_label falls back to Unknown when authors NA", {
  result <- format_citation_label(NA_character_, 2023)
  expect_equal(result, "Unknown (2023)")
})

test_that("format_citation_label falls back to Unknown when authors empty string", {
  result <- format_citation_label("", 2023)
  expect_equal(result, "Unknown (2023)")
})

test_that("format_citation_label falls back to n.d. when year NA", {
  result <- format_citation_label('["Jane Smith"]', NA_integer_)
  expect_equal(result, "Smith (n.d.)")
})

test_that("format_citation_label falls back to n.d. when year NULL", {
  result <- format_citation_label('["Jane Smith"]', NULL)
  expect_equal(result, "Smith (n.d.)")
})

test_that("format_citation_label uses fallback_label when both missing", {
  result <- format_citation_label(NULL, NA, fallback_label = "Some Paper Title")
  expect_equal(result, "Some Paper Title")
})

test_that("format_citation_label handles empty JSON array", {
  result <- format_citation_label("[]", 2023)
  expect_equal(result, "Unknown (2023)")
})

test_that("format_citation_label handles malformed JSON gracefully", {
  result <- format_citation_label("{not valid json", 2023, fallback_label = "Fallback")
  # Should fall through to Unknown (year available) or fallback

  expect_true(result %in% c("Unknown (2023)", "Fallback"))
})

test_that("format_citation_label handles double-encoded JSON (#177)", {
  # Double-encoded: a JSON string containing a JSON array
  double_encoded <- '"[\\"Jane Smith\\", \\"Bob Jones\\"]"'
  result <- format_citation_label(double_encoded, 2023)
  expect_equal(result, "Smith & Jones (2023)")
})

# --- build_context() label construction tests ---

test_that("build_context uses author/year for abstract chunks", {
  chunks <- data.frame(
    content = "Some abstract content about BPA.",
    doc_name = NA_character_,
    abstract_title = "Degradation of BPA by ferrate",
    abstract_authors = '["Jane Smith", "Bob Jones"]',
    abstract_year = 2023L,
    doc_authors = NA_character_,
    doc_year = NA_integer_,
    page_number = NA_integer_,
    stringsAsFactors = FALSE
  )

  result <- build_context(chunks)
  expect_match(result, "\\[Smith & Jones \\(2023\\)\\]")
  expect_match(result, "Some abstract content")
})

test_that("build_context uses author/year for document chunks with page", {
  chunks <- data.frame(
    content = "Document content here.",
    doc_name = "report.pdf",
    abstract_title = NA_character_,
    abstract_authors = NA_character_,
    abstract_year = NA_integer_,
    doc_authors = '["Alice Brown"]',
    doc_year = 2021L,
    page_number = 5L,
    stringsAsFactors = FALSE
  )

  result <- build_context(chunks)
  expect_match(result, "\\[Brown \\(2021\\), p\\.5\\]")
})

test_that("build_context falls back to filename when no document metadata", {
  chunks <- data.frame(
    content = "Document content.",
    doc_name = "my_report.pdf",
    abstract_title = NA_character_,
    abstract_authors = NA_character_,
    abstract_year = NA_integer_,
    doc_authors = NA_character_,
    doc_year = NA_integer_,
    page_number = 3L,
    stringsAsFactors = FALSE
  )

  result <- build_context(chunks)
  expect_match(result, "\\[my_report\\.pdf, p\\.3\\]")
})

test_that("build_context falls back to abstract title when no author/year", {
  chunks <- data.frame(
    content = "Abstract content.",
    doc_name = NA_character_,
    abstract_title = "Some Paper About Things",
    abstract_authors = NA_character_,
    abstract_year = NA_integer_,
    doc_authors = NA_character_,
    doc_year = NA_integer_,
    page_number = NA_integer_,
    stringsAsFactors = FALSE
  )

  result <- build_context(chunks)
  expect_match(result, "\\[Some Paper About Things\\]")
})

test_that("build_context handles chunks without metadata columns gracefully", {
  # Minimal chunks data frame (e.g., from legacy code paths)
  chunks <- data.frame(
    content = "Some content.",
    stringsAsFactors = FALSE
  )

  result <- build_context(chunks)
  expect_match(result, "\\[Source\\]")
  expect_match(result, "Some content")
})

test_that("build_context handles multiple chunks with separator", {
  chunks <- data.frame(
    content = c("First chunk.", "Second chunk."),
    doc_name = NA_character_,
    abstract_title = c("Paper A", "Paper B"),
    abstract_authors = c('["Smith"]', '["Jones"]'),
    abstract_year = c(2020L, 2022L),
    doc_authors = NA_character_,
    doc_year = NA_integer_,
    page_number = NA_integer_,
    stringsAsFactors = FALSE
  )

  result <- build_context(chunks)
  expect_match(result, "Smith \\(2020\\)")
  expect_match(result, "Jones \\(2022\\)")
  expect_match(result, "---")  # separator between chunks
})
