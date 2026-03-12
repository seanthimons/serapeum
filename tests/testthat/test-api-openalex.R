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

# --- Phase 34: New fields (is_retracted, cited_by_percentile, topics) ---

# Helper to create a minimal mock work object
make_mock_work <- function(overrides = list()) {
  base <- list(
    id = "https://openalex.org/W99999",
    title = "Mock Paper",
    authorships = list(),
    abstract_inverted_index = NULL,
    publication_year = 2024,
    primary_location = NULL,
    open_access = NULL,
    keywords = list()
  )
  modifyList(base, overrides)
}

# --- is_retracted tests ---

test_that("parse_openalex_work extracts is_retracted TRUE", {
  work <- make_mock_work(list(is_retracted = TRUE))
  result <- parse_openalex_work(work)
  expect_true(result$is_retracted)
})

test_that("parse_openalex_work extracts is_retracted FALSE", {
  work <- make_mock_work(list(is_retracted = FALSE))
  result <- parse_openalex_work(work)
  expect_false(result$is_retracted)
})

test_that("parse_openalex_work defaults is_retracted to FALSE when NULL", {
  work <- make_mock_work()  # no is_retracted field
  result <- parse_openalex_work(work)
  expect_false(result$is_retracted)
})

# --- cited_by_percentile tests ---

test_that("parse_openalex_work extracts cited_by_percentile from min", {
  work <- make_mock_work(list(
    cited_by_percentile_year = list(min = 85.5, max = 90.0)
  ))
  result <- parse_openalex_work(work)
  expect_equal(result$cited_by_percentile, 85.5)
})

test_that("parse_openalex_work returns NA for missing cited_by_percentile_year", {
  work <- make_mock_work()  # no cited_by_percentile_year
  result <- parse_openalex_work(work)
  expect_true(is.na(result$cited_by_percentile))
})

test_that("parse_openalex_work returns NA when cited_by_percentile_year$min is NULL", {
  work <- make_mock_work(list(
    cited_by_percentile_year = list(min = NULL, max = 90.0)
  ))
  result <- parse_openalex_work(work)
  expect_true(is.na(result$cited_by_percentile))
})

# --- topics tests ---

test_that("parse_openalex_work extracts topics with id, name, score", {
  work <- make_mock_work(list(
    topics = list(
      list(
        id = "https://openalex.org/T12345",
        display_name = "Machine Learning",
        score = 0.95
      ),
      list(
        id = "https://openalex.org/T67890",
        display_name = "Neural Networks",
        score = 0.72
      )
    )
  ))
  result <- parse_openalex_work(work)
  expect_equal(length(result$topics), 2)
  # URL prefix should be stripped
  expect_equal(result$topics[[1]]$id, "T12345")
  expect_equal(result$topics[[1]]$name, "Machine Learning")
  expect_equal(result$topics[[1]]$score, 0.95)
  expect_equal(result$topics[[2]]$id, "T67890")
  expect_equal(result$topics[[2]]$name, "Neural Networks")
})

test_that("parse_openalex_work returns empty topics when NULL", {
  work <- make_mock_work()  # no topics field
  result <- parse_openalex_work(work)
  expect_equal(length(result$topics), 0)
})

test_that("parse_openalex_work returns empty topics when empty list", {
  work <- make_mock_work(list(topics = list()))
  result <- parse_openalex_work(work)
  expect_equal(length(result$topics), 0)
})

# --- Backward compatibility ---

test_that("parse_openalex_work returns all 21 fields including new ones", {
  work <- make_mock_work(list(
    is_retracted = FALSE,
    cited_by_percentile_year = list(min = 50.0, max = 60.0),
    topics = list(list(id = "https://openalex.org/T1", display_name = "AI", score = 0.9))
  ))
  result <- parse_openalex_work(work)

  # Check all expected fields exist
  expected_fields <- c(
    "paper_id", "title", "authors", "abstract", "year", "venue",
    "publisher", "doi", "cited_by_count", "pdf_url", "keywords",
    "work_type", "work_type_crossref", "oa_status", "is_oa",
    "referenced_works_count", "referenced_works", "fwci",
    "is_retracted", "cited_by_percentile", "topics"
  )
  for (field in expected_fields) {
    expect_true(field %in% names(result), info = paste("Missing field:", field))
  }
  expect_equal(length(result), 21)
})

# --- Phase 50: Cursor pagination ---

test_that("parse_search_response returns list with papers, next_cursor, count", {
  # Mock API response body
  body <- list(
    meta = list(
      count = 42,
      next_cursor = "IlsxNjc4OTEyMDAwMDAwLCAnV2lkXzk5OTknXSI="
    ),
    results = list(
      make_mock_work(list(id = "https://openalex.org/W1", title = "Paper 1")),
      make_mock_work(list(id = "https://openalex.org/W2", title = "Paper 2"))
    )
  )

  result <- parse_search_response(body)

  expect_true("papers" %in% names(result))
  expect_true("next_cursor" %in% names(result))
  expect_true("count" %in% names(result))
  expect_equal(length(result$papers), 2)
  expect_equal(result$next_cursor, "IlsxNjc4OTEyMDAwMDAwLCAnV2lkXzk5OTknXSI=")
  expect_equal(result$count, 42)
})

test_that("parse_search_response throws on missing meta field", {
  body <- list(
    results = list(make_mock_work())
  )

  expect_error(
    parse_search_response(body),
    "Unexpected OpenAlex response format: missing 'meta' or 'results' field"
  )
})

test_that("parse_search_response throws on missing results field", {
  body <- list(
    meta = list(count = 0, next_cursor = NULL)
  )

  expect_error(
    parse_search_response(body),
    "Unexpected OpenAlex response format: missing 'meta' or 'results' field"
  )
})

test_that("parse_search_response returns empty structure when no results", {
  body <- list(
    meta = list(count = 0, next_cursor = NULL),
    results = list()
  )

  result <- parse_search_response(body)

  expect_equal(length(result$papers), 0)
  expect_null(result$next_cursor)
  expect_equal(result$count, 0)
})

test_that("parse_search_response handles NULL next_cursor", {
  body <- list(
    meta = list(count = 5, next_cursor = NULL),
    results = list(make_mock_work())
  )

  result <- parse_search_response(body)

  expect_null(result$next_cursor)
  expect_equal(result$count, 5)
})

test_that("parse_search_response defaults count to 0 when NULL", {
  body <- list(
    meta = list(next_cursor = NULL),
    results = list()
  )

  result <- parse_search_response(body)

  expect_equal(result$count, 0)
})

test_that("build_query_preview includes has_abstract filter by default", {
  preview <- build_query_preview("PFOA", from_year = 2020, to_year = 2025)

  expect_match(preview$filter, "has_abstract:true")
})

test_that("build_query_preview omits has_abstract filter when disabled", {
  preview <- build_query_preview(
    "PFOA method detection reporting limit LC/MC",
    from_year = 2020,
    to_year = 2025,
    has_abstract = FALSE,
    exclude_retracted = TRUE
  )

  expect_false(grepl("has_abstract:true", preview$filter, fixed = TRUE))
  expect_match(preview$filter, "is_retracted:false", fixed = TRUE)
  expect_match(preview$filter, "from_publication_date:2020-01-01", fixed = TRUE)
  expect_match(preview$filter, "to_publication_date:2025-12-31", fixed = TRUE)
})
