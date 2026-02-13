library(testthat)

# Source the functions being tested
source("../../R/utils_citation.R")
source("../../R/utils_doi.R")

# Test escape_latex
test_that("escape_latex handles all 9 special characters", {
  # Individual characters
  expect_equal(escape_latex("\\"), "\\textbackslash{}")
  expect_equal(escape_latex("{"), "\\{")
  expect_equal(escape_latex("}"), "\\}")
  expect_equal(escape_latex("%"), "\\%")
  expect_equal(escape_latex("#"), "\\#")
  expect_equal(escape_latex("&"), "\\&")
  expect_equal(escape_latex("_"), "\\_")
  expect_equal(escape_latex("^"), "\\^{}")
  expect_equal(escape_latex("~"), "\\~{}")
  expect_equal(escape_latex("$"), "\\$")
})

test_that("escape_latex handles NA input", {
  expect_equal(escape_latex(NA), NA_character_)
  expect_equal(escape_latex(NULL), NA_character_)
})

test_that("escape_latex passes normal text unchanged", {
  expect_equal(escape_latex("Hello World"), "Hello World")
  expect_equal(escape_latex("Test 123"), "Test 123")
})

test_that("escape_latex handles mixed special characters", {
  result <- escape_latex("10% of {test} & more_$")
  expect_equal(result, "10\\% of \\{test\\} \\& more\\_\\$")
})

test_that("escape_latex doesn't double-escape", {
  # Backslash must be escaped first to avoid double-escaping
  result <- escape_latex("\\{test\\}")
  # Each backslash -> \textbackslash{}, each brace -> \{  or \}
  expect_equal(result, "\\textbackslash{}\\{test\\textbackslash{}\\}")
})

# Test extract_first_author_lastname
test_that("extract_first_author_lastname handles standard names", {
  expect_equal(extract_first_author_lastname('["John Smith"]'), "smith")
  expect_equal(extract_first_author_lastname('["Jane Doe"]'), "doe")
})

test_that("extract_first_author_lastname removes diacritics", {
  expect_equal(extract_first_author_lastname('["Hans Müller"]'), "muller")
  expect_equal(extract_first_author_lastname('["José García"]'), "garcia")
  expect_equal(extract_first_author_lastname('["François Dupont"]'), "dupont")
})

test_that("extract_first_author_lastname handles single names", {
  expect_equal(extract_first_author_lastname('["Madonna"]'), "madonna")
  expect_equal(extract_first_author_lastname('["Cher"]'), "cher")
})

test_that("extract_first_author_lastname handles NA/NULL/empty", {
  expect_equal(extract_first_author_lastname(NA), "unknown")
  expect_equal(extract_first_author_lastname(NULL), "unknown")
  expect_equal(extract_first_author_lastname(""), "unknown")
  expect_equal(extract_first_author_lastname("[]"), "unknown")
})

test_that("extract_first_author_lastname handles invalid JSON", {
  expect_equal(extract_first_author_lastname("not json"), "unknown")
  expect_equal(extract_first_author_lastname("{malformed}"), "unknown")
})

test_that("extract_first_author_lastname sanitizes special characters", {
  expect_equal(extract_first_author_lastname('["O\'Brien"]'), "obrien")
  expect_equal(extract_first_author_lastname('["Smith-Jones"]'), "smithjones")
})

# Test generate_bibtex_key
test_that("generate_bibtex_key creates basic keys", {
  expect_equal(generate_bibtex_key('["John Smith"]', 2023, character()), "smith2023")
  expect_equal(generate_bibtex_key('["Jane Doe"]', 2024, character()), "doe2024")
})

test_that("generate_bibtex_key handles collisions", {
  existing <- c("smith2023")
  expect_equal(generate_bibtex_key('["John Smith"]', 2023, existing), "smith2023a")

  existing <- c("smith2023", "smith2023a")
  expect_equal(generate_bibtex_key('["John Smith"]', 2023, existing), "smith2023b")

  existing <- c("smith2023", "smith2023a", "smith2023b")
  expect_equal(generate_bibtex_key('["John Smith"]', 2023, existing), "smith2023c")
})

test_that("generate_bibtex_key handles NA authors", {
  # Should fall back to "unknown" prefix
  expect_equal(generate_bibtex_key(NA, 2023, character()), "unknown2023")
  expect_equal(generate_bibtex_key("[]", 2023, character()), "unknown2023")
})

test_that("generate_bibtex_key is lowercase and alphanumeric", {
  key <- generate_bibtex_key('["John Smith"]', 2023, character())
  expect_true(grepl("^[a-z0-9]+$", key))

  key <- generate_bibtex_key('["O\'Brien"]', 2023, character())
  expect_true(grepl("^[a-z0-9]+$", key))
})

# Test format_bibtex_entry
test_that("format_bibtex_entry creates valid @article entries", {
  paper <- data.frame(
    title = "Test Paper",
    authors = '["John Smith"]',
    year = 2023,
    venue = "Journal of Testing",
    doi = "10.1234/test",
    abstract = "An abstract.",
    pdf_url = NA,
    work_type = "article",
    stringsAsFactors = FALSE
  )

  entry <- format_bibtex_entry(paper, "smith2023")

  expect_true(grepl("^@article\\{smith2023,", entry))
  expect_true(grepl("author = \\{John Smith\\}", entry))
  expect_true(grepl("title = \\{\\{Test Paper\\}\\}", entry))  # Double braces
  expect_true(grepl("journal = \\{Journal of Testing\\}", entry))
  expect_true(grepl("year = \\{2023\\}", entry))
  expect_true(grepl("doi = \\{10.1234/test\\}", entry))
  expect_true(grepl("abstract = \\{An abstract.\\}", entry))
  expect_true(grepl("\\}\\s*$", entry))  # Closing brace (with optional trailing whitespace)
})

test_that("format_bibtex_entry escapes special characters in fields", {
  paper <- data.frame(
    title = "Test & Validation: {50%} Success",
    authors = '["John Smith"]',
    year = 2023,
    venue = "J Test",
    doi = "10.1234/test",
    abstract = "Testing $5 & 10% results.",
    pdf_url = NA,
    work_type = "article",
    stringsAsFactors = FALSE
  )

  entry <- format_bibtex_entry(paper, "smith2023")

  # Check that special characters are escaped (use fixed=TRUE to avoid regex issues)
  expect_true(grepl("\\&", entry, fixed = TRUE))  # & escaped
  expect_true(grepl("\\%", entry, fixed = TRUE))  # % escaped
  expect_true(grepl("\\{", entry, fixed = TRUE))  # { escaped
  expect_true(grepl("\\}", entry, fixed = TRUE))  # } escaped
  expect_true(grepl("\\$", entry, fixed = TRUE))  # $ escaped
})

test_that("format_bibtex_entry includes DOI when present", {
  paper <- data.frame(
    title = "Test Paper",
    authors = '["John Smith"]',
    year = 2023,
    venue = "J Test",
    doi = "10.1234/test",
    abstract = "An abstract.",
    pdf_url = "http://example.com/paper.pdf",
    work_type = "article",
    stringsAsFactors = FALSE
  )

  entry <- format_bibtex_entry(paper, "smith2023")

  expect_true(grepl("doi = \\{10.1234/test\\}", entry))
  expect_false(grepl("url = ", entry))  # URL should NOT be included when DOI is present
})

test_that("format_bibtex_entry includes URL when DOI is absent", {
  paper <- data.frame(
    title = "Test Paper",
    authors = '["John Smith"]',
    year = 2023,
    venue = "J Test",
    doi = NA,
    abstract = "An abstract.",
    pdf_url = "http://example.com/paper.pdf",
    work_type = "article",
    stringsAsFactors = FALSE
  )

  entry <- format_bibtex_entry(paper, "smith2023")

  expect_false(grepl("doi = ", entry))  # DOI should NOT be included
  expect_true(grepl("url = \\{http://example.com/paper.pdf\\}", entry))  # URL should be included
})

test_that("format_bibtex_entry omits URL when both DOI and pdf_url are absent", {
  paper <- data.frame(
    title = "Test Paper",
    authors = '["John Smith"]',
    year = 2023,
    venue = "J Test",
    doi = NA,
    abstract = "An abstract.",
    pdf_url = NA,
    work_type = "article",
    stringsAsFactors = FALSE
  )

  entry <- format_bibtex_entry(paper, "smith2023")

  expect_false(grepl("doi = ", entry))
  expect_false(grepl("url = ", entry))
})

# Test generate_bibtex_batch
test_that("generate_bibtex_batch creates unique keys", {
  papers <- data.frame(
    title = c("Paper 1", "Paper 2"),
    authors = c('["John Smith"]', '["John Smith"]'),  # Same author
    year = c(2023, 2023),  # Same year
    venue = c("J Test", "J Test"),
    doi = c("10.1234/test1", "10.1234/test2"),
    abstract = c("Abstract 1", "Abstract 2"),
    pdf_url = c(NA, NA),
    work_type = c("article", "article"),
    stringsAsFactors = FALSE
  )

  batch <- generate_bibtex_batch(papers)

  # Should have two entries with different keys
  expect_true(grepl("@article\\{smith2023,", batch))
  expect_true(grepl("@article\\{smith2023a,", batch))
})

test_that("generate_bibtex_batch handles papers without DOI", {
  papers <- data.frame(
    title = c("Deep Learning for NLP", "Machine Learning Basics"),
    authors = c('["John Smith"]', '["Jane Doe"]'),
    year = c(2023, 2024),
    venue = c("J Test", "J Test"),
    doi = c(NA, NA),  # No DOIs
    abstract = c("Abstract 1", "Abstract 2"),
    pdf_url = c("http://example.com/1.pdf", "http://example.com/2.pdf"),
    work_type = c("article", "article"),
    stringsAsFactors = FALSE
  )

  batch <- generate_bibtex_batch(papers)

  # Should use title-based keys (from utils_doi.R generate_citation_key)
  # generate_citation_key takes first 3 non-article words: "deep", "learning", "for" (not "nlp")
  expect_true(grepl("@article\\{deep_learning_for_2023,", batch))
  expect_true(grepl("@article\\{machine_learning_basics_2024,", batch))
})

test_that("generate_bibtex_batch returns empty string for empty input", {
  papers <- data.frame(
    title = character(),
    authors = character(),
    year = integer(),
    venue = character(),
    doi = character(),
    abstract = character(),
    pdf_url = character(),
    work_type = character(),
    stringsAsFactors = FALSE
  )

  expect_equal(generate_bibtex_batch(papers), "")
})

# Test format_csv_export
test_that("format_csv_export returns expected columns", {
  papers <- data.frame(
    title = "Test Paper",
    authors = '["John Smith"]',
    year = 2023,
    venue = "J Test",
    doi = "10.1234/test",
    abstract = "An abstract.",
    work_type = "article",
    oa_status = "gold",
    cited_by_count = 5,
    fwci = 1.2,
    referenced_works_count = 10,
    pdf_url = "http://example.com/paper.pdf",
    stringsAsFactors = FALSE
  )

  export <- format_csv_export(papers)

  expected_cols <- c("citation_key", "title", "authors", "year", "venue", "doi",
                     "abstract", "work_type", "oa_status", "cited_by_count",
                     "fwci", "referenced_works_count", "pdf_url")

  expect_equal(colnames(export), expected_cols)
  expect_equal(nrow(export), 1)
})

test_that("format_csv_export parses authors JSON to semicolon-separated string", {
  papers <- data.frame(
    title = "Test Paper",
    authors = '["John Smith", "Jane Doe", "Bob Johnson"]',
    year = 2023,
    venue = "J Test",
    doi = "10.1234/test",
    abstract = "An abstract.",
    work_type = "article",
    oa_status = "gold",
    cited_by_count = 5,
    fwci = 1.2,
    referenced_works_count = 10,
    pdf_url = "http://example.com/paper.pdf",
    stringsAsFactors = FALSE
  )

  export <- format_csv_export(papers)

  expect_equal(export$authors[1], "John Smith; Jane Doe; Bob Johnson")
})

test_that("format_csv_export includes citation_key", {
  papers <- data.frame(
    title = "Test Paper",
    authors = '["John Smith"]',
    year = 2023,
    venue = "J Test",
    doi = "10.1234/test",
    abstract = "An abstract.",
    work_type = "article",
    oa_status = "gold",
    cited_by_count = 5,
    fwci = 1.2,
    referenced_works_count = 10,
    pdf_url = "http://example.com/paper.pdf",
    stringsAsFactors = FALSE
  )

  export <- format_csv_export(papers)

  expect_equal(export$citation_key[1], "smith2023")
})

test_that("format_csv_export handles NA values gracefully", {
  papers <- data.frame(
    title = "Test Paper",
    authors = '["John Smith"]',
    year = 2023,
    venue = NA,
    doi = NA,
    abstract = NA,
    work_type = NA,
    oa_status = NA,
    cited_by_count = NA,
    fwci = NA,
    referenced_works_count = NA,
    pdf_url = NA,
    stringsAsFactors = FALSE
  )

  export <- format_csv_export(papers)

  expect_equal(export$venue[1], "")
  expect_equal(export$doi[1], "")
  expect_equal(export$abstract[1], "")
  expect_equal(export$work_type[1], "")
  expect_equal(export$oa_status[1], "")
  expect_equal(export$cited_by_count[1], 0)
  expect_true(is.na(export$fwci[1]))
  expect_equal(export$referenced_works_count[1], 0)
  expect_equal(export$pdf_url[1], "")
})

test_that("format_csv_export returns empty data frame for empty input", {
  papers <- data.frame(
    title = character(),
    authors = character(),
    year = integer(),
    venue = character(),
    doi = character(),
    abstract = character(),
    work_type = character(),
    oa_status = character(),
    cited_by_count = integer(),
    fwci = numeric(),
    referenced_works_count = integer(),
    pdf_url = character(),
    stringsAsFactors = FALSE
  )

  export <- format_csv_export(papers)

  expect_equal(nrow(export), 0)
  expect_equal(ncol(export), 13)
})
