# Tests for ragnar helper functions
# These are pure functions for path construction and metadata encoding

library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "_ragnar.R"))) {
  # Fallback: we may already be in project root
  project_root <- getwd()
}
source(file.path(project_root, "R", "_ragnar.R"))

test_that("get_notebook_ragnar_path constructs deterministic paths", {
  # Valid UUIDs produce expected paths
  expect_equal(
    get_notebook_ragnar_path("48fb8820-fbc0-4e75-bf46-92c6dae1db0b"),
    file.path("data", "ragnar", "48fb8820-fbc0-4e75-bf46-92c6dae1db0b.duckdb")
  )

  # Simple IDs work too
  expect_equal(
    get_notebook_ragnar_path("simple-id"),
    file.path("data", "ragnar", "simple-id.duckdb")
  )

  # NULL should error
  expect_error(
    get_notebook_ragnar_path(NULL),
    "notebook_id"
  )

  # Empty string should error
  expect_error(
    get_notebook_ragnar_path(""),
    "notebook_id"
  )
})

test_that("encode_origin_metadata creates pipe-delimited format", {
  # Full metadata encoding
  encoded <- encode_origin_metadata(
    "paper.pdf#page=5",
    section_hint = "conclusion",
    doi = "10.1234/abc",
    source_type = "pdf"
  )

  expect_type(encoded, "character")
  expect_match(encoded, "^paper\\.pdf#page=5\\|")
  expect_match(encoded, "section=conclusion")
  expect_match(encoded, "doi=10\\.1234/abc")
  expect_match(encoded, "type=pdf")

  # Default parameters
  encoded_default <- encode_origin_metadata("paper.pdf#page=1")
  expect_match(encoded_default, "^paper\\.pdf#page=1\\|")
  expect_match(encoded_default, "section=general")
  expect_match(encoded_default, "type=pdf")
  # DOI should be omitted when NULL
  expect_false(grepl("doi=NA", encoded_default))
  expect_false(grepl("doi=$", encoded_default))
})

test_that("decode_origin_metadata parses encoded format", {
  # Round-trip with full metadata
  encoded <- encode_origin_metadata(
    "paper.pdf#page=5",
    section_hint = "conclusion",
    doi = "10.1234/abc",
    source_type = "pdf"
  )

  decoded <- decode_origin_metadata(encoded)

  expect_type(decoded, "list")
  expect_equal(decoded$base_origin, "paper.pdf#page=5")
  expect_equal(decoded$section_hint, "conclusion")
  expect_equal(decoded$doi, "10.1234/abc")
  expect_equal(decoded$source_type, "pdf")
})

test_that("decode_origin_metadata handles missing DOI", {
  # Encode without DOI
  encoded <- encode_origin_metadata(
    "paper.pdf#page=1",
    section_hint = "methods",
    doi = NULL,
    source_type = "pdf"
  )

  decoded <- decode_origin_metadata(encoded)

  expect_equal(decoded$section_hint, "methods")
  expect_true(is.na(decoded$doi))
  expect_equal(decoded$source_type, "pdf")
})

test_that("decode_origin_metadata gracefully handles malformed input", {
  # Plain string without metadata
  decoded <- decode_origin_metadata("just-a-plain-string")

  expect_equal(decoded$section_hint, "general")
  expect_equal(decoded$base_origin, "just-a-plain-string")

  # Empty string
  decoded_empty <- decode_origin_metadata("")
  expect_equal(decoded_empty$section_hint, "general")
})

test_that("encode/decode round-trip preserves all metadata", {
  # Test round-trip with all fields
  original_base <- "document.pdf#page=10"
  original_section <- "introduction"
  original_doi <- "10.5555/example.doi"
  original_type <- "academic"

  encoded <- encode_origin_metadata(
    original_base,
    section_hint = original_section,
    doi = original_doi,
    source_type = original_type
  )

  decoded <- decode_origin_metadata(encoded)

  expect_equal(decoded$base_origin, original_base)
  expect_equal(decoded$section_hint, original_section)
  expect_equal(decoded$doi, original_doi)
  expect_equal(decoded$source_type, original_type)
})

test_that("decode_origin_metadata handles DOIs with special characters", {
  # DOIs can contain slashes and dots but not pipes
  doi_with_slash <- "10.1234/test.2024.v1"

  encoded <- encode_origin_metadata(
    "paper.pdf#page=1",
    doi = doi_with_slash
  )

  decoded <- decode_origin_metadata(encoded)

  expect_equal(decoded$doi, doi_with_slash)
})
