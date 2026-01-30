library(testthat)

source(file.path(getwd(), "R", "pdf.R"))

test_that("chunk_text splits text into overlapping chunks", {
  text <- paste(rep("word", 100), collapse = " ")

  chunks <- chunk_text(text, chunk_size = 20, overlap = 5)

  expect_true(length(chunks) > 1)
})

test_that("chunk_text handles short text", {
  text <- "Short text here"

  chunks <- chunk_text(text, chunk_size = 100, overlap = 10)

  expect_equal(length(chunks), 1)
  expect_equal(chunks[[1]], "Short text here")
})

test_that("chunk_text handles empty text", {
  chunks <- chunk_text("", chunk_size = 100, overlap = 10)
  expect_equal(length(chunks), 0)
})

test_that("chunk_text handles whitespace-only text", {
  chunks <- chunk_text("   \n\t  ", chunk_size = 100, overlap = 10)
  expect_equal(length(chunks), 0)
})
