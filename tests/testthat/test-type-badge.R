# Tests for get_type_badge() and runtime OpenAlex work type catalog behavior

source_app("config.R", "api_openalex.R", "mod_search_notebook.R")

test_that("get_type_badge uses current OpenAlex catalog labels", {
  catalog <- build_work_type_catalog(observed_types = c("software-paper", "conference-paper"))

  badge <- get_type_badge("software-paper", catalog)
  expect_equal(badge$label, "Software Paper")
  expect_false(grepl("-", badge$label))

  badge2 <- get_type_badge("conference-paper", catalog)
  expect_equal(badge2$label, "Conference Paper")
  expect_false(grepl("-", badge2$label))
})

test_that("get_type_badge handles NULL, NA, and empty inputs", {
  badge_null <- get_type_badge(NULL)
  expect_equal(badge_null$class, "bg-body-tertiary text-body")
  expect_equal(badge_null$label, "Unknown")

  badge_na <- get_type_badge(NA)
  expect_equal(badge_na$class, "bg-body-tertiary text-body")
  expect_equal(badge_na$label, "Unknown")

  badge_empty <- get_type_badge("")
  expect_equal(badge_empty$class, "bg-body-tertiary text-body")
  expect_equal(badge_empty$label, "Unknown")
})

test_that("get_type_badge returns gray fallback for unknown types", {
  badge <- get_type_badge("some-unknown-type", catalog = list())
  expect_equal(badge$class, "bg-body-tertiary text-body")
  expect_equal(badge$label, "some Unknown Type")  # Title-cased per tools::toTitleCase behavior
})

test_that("retired OpenAlex types do not break saved-filter badges", {
  catalog <- build_work_type_catalog(observed_types = c("book-section", "report-component"))

  expect_equal(get_type_badge("book-section", catalog)$label, "Book Section")
  expect_equal(get_type_badge("report-component", catalog)$label, "Report Component")
})
