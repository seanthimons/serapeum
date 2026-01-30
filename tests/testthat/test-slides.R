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
