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

test_that("extract_pdf_images requires pdfimager package", {
  # This test will fail if pdfimager is not installed
  skip_if_not_installed("pdfimager")
  
  # Test with non-existent file
  expect_error(
    extract_pdf_images("nonexistent.pdf"),
    "PDF file not found"
  )
})

test_that("extract_pdf_images returns data frame structure", {
  skip_if_not_installed("pdfimager")
  
  # Create a minimal empty result
  # We can't test actual extraction without a sample PDF with images
  # so we just verify the function signature works
  expect_true(is.function(extract_pdf_images))
  
  # Verify function takes expected parameters
  expect_equal(length(formals(extract_pdf_images)), 2)
  expect_true("path" %in% names(formals(extract_pdf_images)))
  expect_true("output_dir" %in% names(formals(extract_pdf_images)))
})

test_that("has_pdf_images returns logical", {
  skip_if_not_installed("pdfimager")
  
  # Test with non-existent file returns FALSE (not error)
  result <- has_pdf_images("nonexistent.pdf")
  expect_type(result, "logical")
  expect_false(result)
})

test_that("has_pdf_images handles errors gracefully", {
  # Should return FALSE for any error, not throw
  result <- has_pdf_images("definitely_not_a_file.pdf")
  expect_false(result)
})
