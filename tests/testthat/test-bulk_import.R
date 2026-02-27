library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "bulk_import.R"))) {
  project_root <- getwd()
}
source(file.path(project_root, "R", "bulk_import.R"))

# --- extract_dois_from_bib tests ---

test_that("extract_dois_from_bib extracts DOIs from standard .bib content", {
  bib_lines <- c(
    "@article{smith2020,",
    "  title = {A Great Paper},",
    "  author = {Smith, John},",
    "  doi = {10.1038/nature12373},",
    "  year = {2020}",
    "}",
    "",
    "@inproceedings{jones2021,",
    "  title = {Another Paper},",
    "  doi = {10.1126/science.1242592}",
    "}"
  )
  result <- extract_dois_from_bib(bib_lines)
  expect_equal(length(result$dois), 2)
  expect_true("10.1038/nature12373" %in% result$dois)
  expect_true("10.1126/science.1242592" %in% result$dois)
  expect_equal(result$entries_without_doi, 0L)
})

test_that("extract_dois_from_bib reports entries without DOI", {
  bib_lines <- c(
    "@article{smith2020,",
    "  title = {Paper With DOI},",
    "  doi = {10.1234/abc}",
    "}",
    "@book{jones2019,",
    "  title = {Book Without DOI},",
    "  author = {Jones}",
    "}",
    "@article{brown2021,",
    "  title = {Another Without DOI}",
    "}"
  )
  result <- extract_dois_from_bib(bib_lines)
  expect_equal(length(result$dois), 1)
  expect_equal(result$entries_without_doi, 2L)
})

test_that("extract_dois_from_bib handles double-quoted DOI values", {
  bib_lines <- c(
    '@article{test,',
    '  doi = "10.9999/quoted"',
    '}'
  )
  result <- extract_dois_from_bib(bib_lines)
  expect_equal(result$dois, "10.9999/quoted")
})

test_that("extract_dois_from_bib handles case-insensitive DOI field", {
  bib_lines <- c(
    "@article{test,",
    "  DOI = {10.1111/uppercase}",
    "}"
  )
  result <- extract_dois_from_bib(bib_lines)
  expect_equal(result$dois, "10.1111/uppercase")
})

test_that("extract_dois_from_bib returns empty for no input", {
  result <- extract_dois_from_bib(character(0))
  expect_equal(result$dois, character(0))
  expect_equal(result$entries_without_doi, 0L)

  result2 <- extract_dois_from_bib(NULL)
  expect_equal(result2$dois, character(0))
})

test_that("extract_dois_from_bib handles .bib with no entries", {
  bib_lines <- c("% Just a comment", "")
  result <- extract_dois_from_bib(bib_lines)
  expect_equal(length(result$dois), 0)
})

# --- estimate_import_time tests ---

test_that("estimate_import_time returns seconds for small counts", {
  result <- estimate_import_time(10)
  expect_true(grepl("seconds", result))
})

test_that("estimate_import_time returns minutes for large counts", {
  # 2000 DOIs = 40 batches * 1.6s = 64s > 60 = minutes
  result <- estimate_import_time(2000)
  expect_true(grepl("minutes", result))
})

test_that("estimate_import_time handles zero", {
  result <- estimate_import_time(0)
  expect_equal(result, "~0 seconds")
})

test_that("estimate_import_time scales with batch size", {
  small <- estimate_import_time(100, batch_size = 50)
  large <- estimate_import_time(100, batch_size = 10)
  # More batches = longer time
  expect_true(grepl("seconds|minutes", small))
  expect_true(grepl("seconds|minutes", large))
})

# --- read/write_import_progress tests ---

test_that("write and read import progress round-trips correctly", {
  pf <- tempfile(fileext = ".progress")
  on.exit(unlink(pf))

  write_import_progress(pf, 3, 10, 45, 5, "Batch 3/10: 45 found, 5 not found")
  result <- read_import_progress(pf)

  expect_equal(result$batch, 3)
  expect_equal(result$total_batches, 10)
  expect_equal(result$found, 45)
  expect_equal(result$failed, 5)
  expect_equal(result$message, "Batch 3/10: 45 found, 5 not found")
  expect_equal(result$pct, 30)  # 3/10 * 100
})

test_that("read_import_progress returns defaults for missing file", {
  result <- read_import_progress("/nonexistent/path.progress")
  expect_equal(result$batch, 0)
  expect_equal(result$pct, 0)
  expect_equal(result$message, "Waiting...")
})

test_that("read_import_progress returns defaults for NULL", {
  result <- read_import_progress(NULL)
  expect_equal(result$batch, 0)
  expect_equal(result$pct, 0)
})

# --- get_notebook_dois tests (requires DB) ---

test_that("get_notebook_dois returns existing DOIs from notebook", {
  source(file.path(project_root, "R", "db_migrations.R"))
  source(file.path(project_root, "R", "db.R"))
  source(file.path(project_root, "R", "utils_doi.R"))

  # Save and restore working directory (migrations need project root)
  old_wd <- getwd()
  setwd(project_root)
  on.exit(setwd(old_wd), add = TRUE)

  db_path <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(path = db_path)
  on.exit({
    close_db_connection(con)
    unlink(db_path)
  }, add = TRUE)

  # Create test notebook
  nb_id <- create_notebook(con, "Test NB", "search")

  # Add abstracts with DOIs
  create_abstract(con, nb_id, "W123", "Paper 1", list("Author"),
                  "Abstract text", 2020, "Journal", NA, doi = "10.1234/abc")
  create_abstract(con, nb_id, "W456", "Paper 2", list("Author"),
                  "Abstract text", 2021, "Journal", NA, doi = "10.5678/xyz")
  # One without DOI
  create_abstract(con, nb_id, "W789", "Paper 3", list("Author"),
                  "Abstract text", 2022, "Journal", NA)

  dois <- get_notebook_dois(con, nb_id)
  expect_equal(length(dois), 2)
  expect_true("10.1234/abc" %in% dois)
  expect_true("10.5678/xyz" %in% dois)
})

test_that("get_notebook_dois returns empty for notebook with no DOIs", {
  source(file.path(project_root, "R", "db_migrations.R"))
  source(file.path(project_root, "R", "db.R"))
  source(file.path(project_root, "R", "utils_doi.R"))

  old_wd <- getwd()
  setwd(project_root)
  on.exit(setwd(old_wd), add = TRUE)

  db_path <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(path = db_path)
  on.exit({
    close_db_connection(con)
    unlink(db_path)
  }, add = TRUE)

  nb_id <- create_notebook(con, "Empty NB", "search")
  dois <- get_notebook_dois(con, nb_id)
  expect_equal(length(dois), 0)
})

# --- parse_bibtex_metadata tests (Phase 36) ---

test_that("parse_bibtex_metadata returns tibble with expected columns", {
  fixture_path <- file.path(project_root, "tests", "testthat", "fixtures", "test.bib")
  result <- parse_bibtex_metadata(fixture_path)
  expect_true(is.data.frame(result$data))
  expect_true("DOI" %in% names(result$data))
  expect_true("TITLE" %in% names(result$data))
  expect_true("ABSTRACT" %in% names(result$data))
  expect_true("YEAR" %in% names(result$data))
})

test_that("parse_bibtex_metadata extracts correct DOI count", {
  fixture_path <- file.path(project_root, "tests", "testthat", "fixtures", "test.bib")
  result <- parse_bibtex_metadata(fixture_path)
  expect_equal(result$diagnostics$entries_with_doi, 4L)
})

test_that("parse_bibtex_metadata reports entries without DOIs", {
  fixture_path <- file.path(project_root, "tests", "testthat", "fixtures", "test.bib")
  result <- parse_bibtex_metadata(fixture_path)
  expect_true(result$diagnostics$entries_without_doi >= 1L)
})

test_that("parse_bibtex_metadata reports total entry count", {
  fixture_path <- file.path(project_root, "tests", "testthat", "fixtures", "test.bib")
  result <- parse_bibtex_metadata(fixture_path)
  expect_equal(result$diagnostics$total_entries, 5L)
})

test_that("parse_bibtex_metadata handles nonexistent file gracefully", {
  result <- parse_bibtex_metadata("/nonexistent/path/fake.bib")
  expect_true(is.data.frame(result$data))
  expect_equal(nrow(result$data), 0)
  expect_equal(result$diagnostics$total_entries, 0L)
})

test_that("parse_bibtex_metadata filters to entries with DOI only when requested", {
  fixture_path <- file.path(project_root, "tests", "testthat", "fixtures", "test.bib")
  result <- parse_bibtex_metadata(fixture_path)
  # Filter to DOI-only entries
  doi_rows <- result$data[!is.na(result$data$DOI), ]
  expect_equal(nrow(doi_rows), 4)
  expect_true(all(!is.na(doi_rows$DOI)))
})

# --- merge_bibtex_openalex tests (Phase 36) ---

test_that("merge_bibtex_openalex fills abstract from BibTeX when OpenAlex lacks it", {
  openalex_paper <- list(abstract = NA_character_, title = "Some Paper")
  bibtex_row <- data.frame(ABSTRACT = "BibTeX abstract text", DOI = "10.1234/test", stringsAsFactors = FALSE)
  result <- merge_bibtex_openalex(openalex_paper, bibtex_row)
  expect_equal(result$abstract, "BibTeX abstract text")
})

test_that("merge_bibtex_openalex preserves OpenAlex abstract when both exist", {
  openalex_paper <- list(abstract = "OpenAlex abstract", title = "Some Paper")
  bibtex_row <- data.frame(ABSTRACT = "BibTeX abstract", DOI = "10.1234/test", stringsAsFactors = FALSE)
  result <- merge_bibtex_openalex(openalex_paper, bibtex_row)
  expect_equal(result$abstract, "OpenAlex abstract")
})

test_that("merge_bibtex_openalex returns unchanged paper when BibTeX has no abstract", {
  openalex_paper <- list(abstract = NA_character_, title = "Some Paper")
  bibtex_row <- data.frame(ABSTRACT = NA_character_, DOI = "10.1234/test", stringsAsFactors = FALSE)
  result <- merge_bibtex_openalex(openalex_paper, bibtex_row)
  expect_true(is.na(result$abstract))
})

test_that("merge_bibtex_openalex handles NULL abstract fields", {
  openalex_paper <- list(abstract = NULL, title = "Some Paper")
  bibtex_row <- data.frame(ABSTRACT = "BibTeX abstract", DOI = "10.1234/test", stringsAsFactors = FALSE)
  result <- merge_bibtex_openalex(openalex_paper, bibtex_row)
  expect_equal(result$abstract, "BibTeX abstract")
})
