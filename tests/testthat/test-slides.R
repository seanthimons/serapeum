# tests/testthat/test-slides.R
test_that("check_quarto_installed returns TRUE when quarto exists", {
  # This test will pass/fail based on local environment
  # We're testing the function exists and returns boolean
  result <- check_quarto_installed()
  expect_type(result, "logical")
})

test_that("get_quarto_version returns version string or NULL", {
  result <- get_quarto_version()
  if (!is.null(result)) {
    expect_type(result, "character")
    expect_true(grepl("^\\d+\\.\\d+", result))
  }
})

test_that("build_slides_prompt constructs valid prompt", {
  chunks <- data.frame(
    content = c("Introduction text here.", "Methods section content."),
    doc_name = c("paper.pdf", "paper.pdf"),
    page_number = c(1, 5),
    stringsAsFactors = FALSE
  )

  options <- list(
    length = "medium",
    audience = "technical",
    citation_style = "footnotes",
    include_notes = TRUE,
    custom_instructions = "Focus on methodology"
  )

  prompt <- build_slides_prompt(chunks, options)

  expect_type(prompt, "list")
  expect_true("system" %in% names(prompt))
  expect_true("user" %in% names(prompt))
  expect_true(grepl("RevealJS", prompt$system))
  expect_true(grepl("Introduction text here", prompt$user))
  expect_true(grepl("paper.pdf", prompt$user))
  expect_true(grepl("Focus on methodology", prompt$user))
})

test_that("build_slides_prompt handles different lengths", {
  chunks <- data.frame(
    content = "Test content",
    doc_name = "test.pdf",
    page_number = 1,
    stringsAsFactors = FALSE
  )

  short_prompt <- build_slides_prompt(chunks, list(length = "short"))
  medium_prompt <- build_slides_prompt(chunks, list(length = "medium"))
  long_prompt <- build_slides_prompt(chunks, list(length = "long"))

  expect_true(grepl("5-8 slides", short_prompt$user))
  expect_true(grepl("10-15 slides", medium_prompt$user))
  expect_true(grepl("20\\+? slides", long_prompt$user))
})
