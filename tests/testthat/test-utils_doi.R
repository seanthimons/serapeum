# Tests for parse_doi_list() and helpers in R/utils_doi.R

source_app("utils_doi.R")

# --- 1. Single bare DOI ---
test_that("parse_doi_list handles single bare DOI", {
  result <- parse_doi_list("10.1234/abc")
  expect_equal(result$valid, "10.1234/abc")
  expect_equal(nrow(result$invalid), 0)
  expect_equal(nrow(result$duplicates), 0)
})

# --- 2. DOI URLs ---
test_that("parse_doi_list handles DOI URLs", {
  # https://doi.org
  result <- parse_doi_list("https://doi.org/10.1234/ABC")
  expect_equal(result$valid, "10.1234/abc")

  # http://doi.org
  result <- parse_doi_list("http://doi.org/10.1234/ABC")
  expect_equal(result$valid, "10.1234/abc")

  # https://dx.doi.org
  result <- parse_doi_list("https://dx.doi.org/10.1234/ABC")
  expect_equal(result$valid, "10.1234/abc")

  # http://dx.doi.org
  result <- parse_doi_list("http://dx.doi.org/10.1234/ABC")
  expect_equal(result$valid, "10.1234/abc")
})

# --- 3. Splitting on newlines and commas ---
test_that("parse_doi_list splits on newlines and commas", {
  # Newline-separated
  result <- parse_doi_list("10.1234/abc\n10.5678/xyz")
  expect_equal(sort(result$valid), c("10.1234/abc", "10.5678/xyz"))

  # Comma-separated
  result <- parse_doi_list("10.1234/abc, 10.5678/xyz")
  expect_equal(sort(result$valid), c("10.1234/abc", "10.5678/xyz"))

  # Mixed
  result <- parse_doi_list("10.1234/abc\n10.5678/xyz, 10.9012/def")
  expect_length(result$valid, 3)
})

# --- 4. doi: prefix ---
test_that("parse_doi_list handles doi: prefix with optional space", {
  result <- parse_doi_list("doi:10.1234/abc")
  expect_equal(result$valid, "10.1234/abc")

  result <- parse_doi_list("doi: 10.1234/abc")
  expect_equal(result$valid, "10.1234/abc")

  result <- parse_doi_list("DOI: 10.1234/abc")
  expect_equal(result$valid, "10.1234/abc")
})

# --- 5. Invalid DOI categorization ---
test_that("parse_doi_list categorizes invalid DOIs", {
  # missing_prefix: no "10." prefix
  result <- parse_doi_list("invalid-string")
  expect_equal(nrow(result$invalid), 1)
  expect_equal(result$invalid$original, "invalid-string")
  expect_equal(result$invalid$reason, "missing_prefix")

  # invalid_registrant: starts with 10. but bad registrant
  result <- parse_doi_list("10.12/abc")
  expect_equal(nrow(result$invalid), 1)
  expect_equal(result$invalid$reason, "invalid_registrant")

  # empty_suffix: registrant present but no suffix after /
  result <- parse_doi_list("10.1234/")
  expect_equal(nrow(result$invalid), 1)
  expect_equal(result$invalid$reason, "empty_suffix")
})

# --- 6. Duplicate detection ---
test_that("parse_doi_list detects duplicates", {
  result <- parse_doi_list("10.1234/abc\n10.1234/abc")
  expect_equal(result$valid, "10.1234/abc")
  expect_equal(nrow(result$duplicates), 1)
  expect_equal(result$duplicates$doi, "10.1234/abc")
  expect_equal(result$duplicates$count, 2L)
})

test_that("parse_doi_list detects case-insensitive duplicates", {
  result <- parse_doi_list("10.1234/ABC\n10.1234/abc")
  expect_equal(result$valid, "10.1234/abc")
  expect_equal(nrow(result$duplicates), 1)
  expect_equal(result$duplicates$count, 2L)
})

# --- 7. Empty lines ---
test_that("parse_doi_list ignores empty lines silently", {
  result <- parse_doi_list("10.1234/abc\n\n\n10.5678/xyz")
  expect_equal(sort(result$valid), c("10.1234/abc", "10.5678/xyz"))
  expect_equal(nrow(result$invalid), 0)

  # Whitespace-only lines
  result <- parse_doi_list("10.1234/abc\n   \n10.5678/xyz")
  expect_equal(sort(result$valid), c("10.1234/abc", "10.5678/xyz"))
  expect_equal(nrow(result$invalid), 0)
})

# --- 8. Trailing punctuation ---
test_that("parse_doi_list strips trailing punctuation", {
  result <- parse_doi_list("10.1234/abc.")
  expect_equal(result$valid, "10.1234/abc")

  result <- parse_doi_list("10.1234/abc,")
  expect_equal(result$valid, "10.1234/abc")

  result <- parse_doi_list("10.1234/abc;")
  expect_equal(result$valid, "10.1234/abc")
})

# --- 9. URL-encoded DOIs ---
test_that("parse_doi_list handles URL-encoded DOIs", {
  result <- parse_doi_list("https://doi.org/10.1234%2Fabc")
  expect_equal(result$valid, "10.1234/abc")
})

# --- 10. Query parameters ---
test_that("parse_doi_list strips query parameters", {
  result <- parse_doi_list("https://doi.org/10.1234/abc?ref=pdf")
  expect_equal(result$valid, "10.1234/abc")

  result <- parse_doi_list("https://doi.org/10.1234/abc?locatt=label:secondary")
  expect_equal(result$valid, "10.1234/abc")
})

# --- 11. Character vector input ---
test_that("parse_doi_list accepts character vector input", {
  result <- parse_doi_list(c("10.1234/abc", "10.5678/xyz"))
  expect_equal(sort(result$valid), c("10.1234/abc", "10.5678/xyz"))
  expect_equal(nrow(result$invalid), 0)
})

# --- 12. Return structure ---
test_that("parse_doi_list returns correct structure", {
  result <- parse_doi_list("10.1234/abc")

  expect_type(result, "list")
  expect_named(result, c("valid", "invalid", "duplicates"))

  # $valid is character vector
  expect_type(result$valid, "character")

  # $invalid is data.frame with correct columns
  expect_s3_class(result$invalid, "data.frame")
  expect_named(result$invalid, c("original", "reason"))

  # $duplicates is data.frame with correct columns
  expect_s3_class(result$duplicates, "data.frame")
  expect_named(result$duplicates, c("doi", "count"))
})

test_that("parse_doi_list returns empty structure for empty input", {
  result <- parse_doi_list("")

  expect_length(result$valid, 0)
  expect_equal(nrow(result$invalid), 0)
  expect_equal(nrow(result$duplicates), 0)
})

# --- 13. Mixed valid and invalid ---
test_that("parse_doi_list handles mixed valid and invalid", {
  result <- parse_doi_list("10.1234/abc\ninvalid-string\n10.5678/xyz")
  expect_equal(sort(result$valid), c("10.1234/abc", "10.5678/xyz"))
  expect_equal(nrow(result$invalid), 1)
  expect_equal(result$invalid$original, "invalid-string")
  expect_equal(result$invalid$reason, "missing_prefix")
})

# --- Helper function tests ---
test_that("split_doi_input splits on newlines and commas", {
  expect_equal(split_doi_input("a\nb"), c("a", "b"))
  expect_equal(split_doi_input("a, b"), c("a", "b"))
  expect_equal(split_doi_input("a\nb, c"), c("a", "b", "c"))
})

test_that("categorize_doi_error returns correct reasons", {
  expect_equal(categorize_doi_error("not-a-doi"), "missing_prefix")
  expect_equal(categorize_doi_error("10.12/abc"), "invalid_registrant")
  expect_equal(categorize_doi_error("10.1234/"), "empty_suffix")
})
