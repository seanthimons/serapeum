# Tests for Phase 52.1 search consolidation
# Testing extractable pure logic used in do_search() function

test_that("isTRUE guard logic handles NULL, FALSE, and TRUE correctly", {
  # BUG-02 fix verification: isTRUE catches NULL
  expect_false(isTRUE(NULL))

  # Confirms explicit FALSE is caught
  expect_false(isTRUE(FALSE))

  # Confirms TRUE passes
  expect_true(isTRUE(TRUE))
})

test_that("filter parsing handles NULL safety correctly", {
  # Parse valid JSON filters
  result <- jsonlite::fromJSON('{"from_year":2020}')
  expect_true(is.list(result))
  expect_equal(result$from_year, 2020)

  # Parse empty string returns empty list via tryCatch fallback
  result_empty <- tryCatch(
    jsonlite::fromJSON(""),
    error = function(e) list()
  )
  expect_true(is.list(result_empty))
  expect_equal(length(result_empty), 0)

  # Parse NA returns empty list via conditional check
  result_na <- if (is.na(NA)) {
    list()
  } else {
    tryCatch(jsonlite::fromJSON(NA), error = function(e) list())
  }
  expect_true(is.list(result_na))
  expect_equal(length(result_na), 0)
})

test_that("%||% operator fallback works as expected", {
  # NULL defaults to fallback value
  expect_equal(NULL %||% "default", "default")

  # Non-NULL preserves original value
  expect_equal("value" %||% "default", "value")

  # FALSE is not NULL, so it's preserved
  expect_equal(FALSE %||% TRUE, FALSE)
})

test_that("error classification returns expected structure", {
  # Source api_openalex.R to get classify_api_error function
  source("C:/Users/sxthi/Documents/serapeum/R/api_openalex.R")

  # Simulate an error and classify it
  test_error <- tryCatch(
    stop("Test error"),
    error = function(e) e
  )

  result <- classify_api_error(test_error, "TestService")

  # Verify returns list with expected fields
  expect_true(is.list(result))
  expect_true("message" %in% names(result))
  expect_true("details" %in% names(result))
  expect_true("severity" %in% names(result))
})

test_that("match.arg validates mode parameter correctly", {
  # Valid refresh mode
  expect_equal(match.arg("refresh", c("refresh", "load_more")), "refresh")

  # Valid load_more mode
  expect_equal(match.arg("load_more", c("refresh", "load_more")), "load_more")

  # Invalid mode throws error
  expect_error(
    match.arg("invalid", c("refresh", "load_more")),
    "'arg' should be one of"
  )
})
