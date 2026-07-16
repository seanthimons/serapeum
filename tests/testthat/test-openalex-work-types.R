library(testthat)

source_app("config.R", "api_openalex.R", "mod_search_notebook.R")

openalex_types_body <- function(slugs) {
  list(
    meta = list(count = length(slugs)),
    results = lapply(slugs, function(slug) {
      list(
        id = paste0("https://openalex.org/types/", slug),
        display_name = slug,
        description = paste("Description for", slug),
        works_count = 1L
      )
    })
  )
}

CURRENT_OPENALEX_TYPE_SLUGS <- c(
  "article", "book", "book-chapter", "book-review", "conference-abstract",
  "conference-paper", "data-paper", "dataset", "dissertation", "editorial",
  "erratum", "letter", "libguides", "other", "paratext", "peer-review",
  "preprint", "reference-entry", "report", "retraction", "review", "software",
  "software-paper", "standard", "supplementary-materials"
)

test_that("OpenAlex work type catalog is generated from /types response", {
  records <- parse_openalex_types_response(openalex_types_body(CURRENT_OPENALEX_TYPE_SLUGS))
  catalog <- build_work_type_catalog(records)
  slugs <- get_work_type_slugs(catalog)

  expect_equal(length(slugs), 25)
  expect_true(all(CURRENT_OPENALEX_TYPE_SLUGS %in% slugs))
  expect_true(all(c("software", "software-paper", "conference-paper") %in% slugs))
  expect_false("grant" %in% slugs)
})

test_that("work type catalog preserves observed future or retired types", {
  records <- parse_openalex_types_response(openalex_types_body(c("article", "review")))
  catalog <- build_work_type_catalog(
    records,
    observed_types = c("software", "report-component", "book-section", NA, "")
  )
  slugs <- get_work_type_slugs(catalog)

  expect_true(all(c("article", "review", "software", "report-component", "book-section") %in% slugs))
  expect_equal(get_type_badge("report-component", catalog)$label, "Report Component")
  expect_equal(get_type_badge("software-paper", catalog)$label, "Software Paper")
})

test_that("type filter treats all selected or none selected as no API filter", {
  expect_null(selected_work_types_or_null(c("article", "review"), c("article", "review")))
  expect_null(selected_work_types_or_null(c("article", "review"), character()))
  expect_equal(selected_work_types_or_null(c("article", "review"), "article"), "article")
})
