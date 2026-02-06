library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "api_openalex.R"))) {
  # Fallback: we may already be in project root (e.g., when run via Rscript from project root)
  project_root <- getwd()
}
source(file.path(project_root, "R", "api_openalex.R"))

test_that("parse_openalex_work extracts keywords", {
  # Mock OpenAlex work object with keywords
  mock_work <- list(
    id = "https://openalex.org/W12345",
    title = "Test Paper",
    authorships = list(
      list(author = list(display_name = "Jane Doe"))
    ),
    abstract_inverted_index = list(
      "This" = list(0),
      "is" = list(1),
      "abstract" = list(2)
    ),
    publication_year = 2024,
    primary_location = list(
      source = list(display_name = "Nature")
    ),
    open_access = list(oa_url = "https://example.com/paper.pdf"),
    keywords = list(
      list(display_name = "machine learning", id = "kw1", score = 0.9),
      list(display_name = "artificial intelligence", id = "kw2", score = 0.8),
      list(display_name = "deep learning", id = "kw3", score = 0.7)
    )
  )

  result <- parse_openalex_work(mock_work)

  expect_true("keywords" %in% names(result))
  expect_equal(length(result$keywords), 3)
  expect_true("machine learning" %in% result$keywords)
  expect_true("artificial intelligence" %in% result$keywords)
})

test_that("parse_openalex_work handles missing keywords", {
  mock_work <- list(
    id = "https://openalex.org/W67890",
    title = "Test Paper No Keywords",
    authorships = list(),
    abstract_inverted_index = NULL,
    publication_year = 2023,
    primary_location = NULL,
    open_access = NULL,
    keywords = NULL
  )

  result <- parse_openalex_work(mock_work)

  expect_true("keywords" %in% names(result))
  expect_equal(length(result$keywords), 0)
})

test_that("parse_openalex_work handles empty keywords array", {
  mock_work <- list(
    id = "https://openalex.org/W11111",
    title = "Test Paper Empty Keywords",
    authorships = list(),
    abstract_inverted_index = NULL,
    publication_year = 2022,
    primary_location = NULL,
    open_access = NULL,
    keywords = list()
  )

  result <- parse_openalex_work(mock_work)

  expect_true("keywords" %in% names(result))
  expect_equal(length(result$keywords), 0)
})
