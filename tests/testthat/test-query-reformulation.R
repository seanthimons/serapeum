library(testthat)

project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "rag.R"))) {
  project_root <- getwd()
}

source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "rag.R"))

# --- Phase 4: Query Variant Parsing ---

test_that("parse_query_variants extracts one query per line", {
  result <- parse_query_variants("variant 1\nvariant 2\nvariant 3")
  expect_equal(result, c("variant 1", "variant 2", "variant 3"))
})

test_that("parse_query_variants handles numbered list format", {
  result <- parse_query_variants("1. first query\n2. second query\n3. third query")
  expect_equal(result, c("first query", "second query", "third query"))
})

test_that("parse_query_variants handles numbered with closing paren", {
  result <- parse_query_variants("1) first\n2) second")
  expect_equal(result, c("first", "second"))
})

test_that("parse_query_variants handles dash-prefixed lists", {
  result <- parse_query_variants("- variant A\n- variant B")
  expect_equal(result, c("variant A", "variant B"))
})

test_that("parse_query_variants strips empty lines and whitespace", {
  result <- parse_query_variants("  query one  \n\n  query two  \n\n")
  expect_equal(result, c("query one", "query two"))
})

test_that("parse_query_variants handles single line", {
  result <- parse_query_variants("single query")
  expect_equal(result, "single query")
})

test_that("parse_query_variants handles empty input", {
  result <- parse_query_variants("")
  expect_equal(length(result), 0)
})
