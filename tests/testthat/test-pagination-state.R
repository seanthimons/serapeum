# Test format_result_count helper (Phase 51)

# Source the module to access the helper function
# testthat runs from package root, so path is relative to project root
source("../../R/mod_search_notebook.R", local = TRUE)

test_that("format_result_count returns empty string when no results", {
  expect_equal(format_result_count(0, 0), "")
  expect_equal(format_result_count(0, NULL), "")
})

test_that("format_result_count shows X of Y when more results available", {
  expect_equal(format_result_count(25, 100), "25 of 100 results")
  expect_equal(format_result_count(1, 500), "1 of 500 results")
})

test_that("format_result_count shows total when all fetched", {
  expect_equal(format_result_count(100, 100), "100 results")
  expect_equal(format_result_count(150, 100), "100 results")
})
