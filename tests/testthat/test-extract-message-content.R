library(testthat)

source_app("api_openrouter.R")

test_that("extract_message_content returns normal string content", {
  msg <- list(content = "Hello, world!")
  expect_equal(extract_message_content(msg), "Hello, world!")
})

test_that("extract_message_content returns reasoning when content is NULL", {
  msg <- list(content = NULL, reasoning = "I reasoned this.")
  expect_equal(extract_message_content(msg), "I reasoned this.")
})

test_that("extract_message_content returns NULL when content and reasoning are NULL", {
  msg <- list(content = NULL, reasoning = NULL)
  expect_null(extract_message_content(msg))
})

test_that("extract_message_content falls through empty string to reasoning", {
  msg <- list(content = "", reasoning = "fallback reasoning")
  expect_equal(extract_message_content(msg), "fallback reasoning")
})

test_that("extract_message_content returns empty string when no reasoning fallback", {
  msg <- list(content = "")
  # Content is empty, no reasoning → falls through and returns content as-is
  expect_equal(extract_message_content(msg), "")
})

test_that("extract_message_content handles multi-element character vector", {
  # This was the bug — nchar() on a vector yields a vector, if() errors
  msg <- list(content = c("Hello", "World"))
  expect_equal(extract_message_content(msg), c("Hello", "World"))
})

test_that("extract_message_content concatenates list-of-parts content", {
  msg <- list(content = list(
    list(text = "Part one"),
    list(text = "Part two")
  ))
  expect_equal(extract_message_content(msg), "Part one\nPart two")
})

test_that("extract_message_content handles mixed list parts", {
  msg <- list(content = list(
    list(text = "Structured"),
    "plain string"
  ))
  expect_equal(extract_message_content(msg), "Structured\nplain string")
})
