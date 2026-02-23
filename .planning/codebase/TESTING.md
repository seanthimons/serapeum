# Testing Patterns

**Analysis Date:** 2026-02-10

## Test Framework

**Runner:**
- testthat (R testing framework)
- Config: `tests/testthat/`
- No explicit config file detected (uses testthat defaults)

**Assertion Library:**
- testthat built-in expectations: `expect_equal()`, `expect_true()`, `expect_null()`, `expect_error()`, etc.

**Run Commands:**
```bash
# Run all tests from project root
testthat::test_dir("tests/testthat")

# Or via R console
test_file("tests/testthat/test-db.R")

# Note: No watch mode or coverage commands configured
```

## Test File Organization

**Location:**
- Co-located in `tests/testthat/` directory (separate from source)
- No co-location with source files

**Naming:**
- Pattern: `test-<feature>.R`
- Examples: `test-db.R`, `test-config.R`, `test-api-openalex.R`, `test-pdf.R`, `test-ragnar.R`, `test-slides.R`

**Structure:**
```
tests/
└── testthat/
    ├── test-config.R
    ├── test-db.R
    ├── test-api-openalex.R
    ├── test-pdf.R
    ├── test-ragnar.R
    └── test-slides.R
```

## Test Structure

**Suite Organization:**
```r
library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "config.R"))) {
  project_root <- getwd()
}
source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "db.R"))

test_that("descriptive test name", {
  # Arrange
  # Act
  # Assert
})
```

**Patterns:**
- **Setup:** Create temporary resources (databases, files) at test start
- **Teardown:** Cleanup via `unlink()`, `on.exit()`, or direct disconnect
- **Assertion:** One logical assertion per test; use `expect_true(condition)` for complex assertions

## Common Test Patterns

### Database Tests
```r
test_that("notebook CRUD operations work", {
  # Setup: Create temporary database
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_crud.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  # Test: Create
  id <- create_notebook(con, "My Research", "document")
  expect_true(nchar(id) > 0)

  # Test: Read
  notebooks <- list_notebooks(con)
  expect_equal(nrow(notebooks), 1)

  # Cleanup
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

# Alternate with on.exit() cleanup
test_that("get_chunks_for_documents returns chunks with source info", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  # ... test code
})
```

### API Response Tests
```r
test_that("parse_openalex_work extracts keywords", {
  # Mock object (no actual API call)
  mock_work <- list(
    id = "https://openalex.org/W12345",
    title = "Test Paper",
    keywords = list(
      list(display_name = "machine learning", score = 0.9)
    )
  )

  result <- parse_openalex_work(mock_work)

  expect_true("keywords" %in% names(result))
  expect_equal(length(result$keywords), 1)
})
```

### Conditional Tests
```r
test_that("process_pdf uses ragnar when available", {
  # Skip if dependency not available
  skip_if_not(ragnar_available(), "ragnar not installed")
  skip_if_not(file.exists("../../testdata/sample.pdf"), "No test PDF available")

  result <- process_pdf("../../testdata/sample.pdf", use_ragnar = TRUE)
  expect_equal(result$chunking_method, "ragnar")
})

test_that("integration test requiring API", {
  skip("Integration test - requires API key")

  # This test documents expected interface but doesn't run
})
```

## Mocking

**Framework:** Manual mocking with R lists/data frames (no dedicated mock library)

**Patterns:**
```r
# Mock API responses
mock_work <- list(
  id = "https://openalex.org/W12345",
  title = "Test Paper",
  authorships = list(
    list(author = list(display_name = "Jane Doe"))
  ),
  keywords = list(
    list(display_name = "machine learning", score = 0.9)
  )
)

result <- parse_openalex_work(mock_work)
expect_true("keywords" %in% names(result))
```

**What to Mock:**
- External API responses: Create list structures matching actual API response format
- File system operations: Use `tempfile()`, `tempdir()` for isolated test data
- Database: Use `:memory:` DuckDB for isolated test DB or `tempfile()` for persistent tests

**What NOT to Mock:**
- Core business logic functions: Call them directly with test data
- Database operations: Use real DuckDB (in-memory) to verify SQL correctness
- Error handling: Test actual `tryCatch()` behavior with real error conditions

Example - testing error handling without mocking:
```r
test_that("get_ragnar_store requires API key for new stores", {
  skip_if_not(ragnar_available(), "ragnar not installed")

  tmp_store <- tempfile(fileext = ".ragnar.duckdb")
  on.exit(unlink(tmp_store))

  # Test actual error, don't mock it
  expect_error(
    get_ragnar_store(tmp_store),
    "OpenRouter API key required"
  )
})
```

## Fixtures and Factories

**Test Data:**
```r
# Inline data creation pattern (no separate fixtures)
test_that("chunk_text handles different scenarios", {
  # Short chunks created inline
  text <- paste(rep("word", 100), collapse = " ")
  chunks <- chunk_text(text, chunk_size = 20, overlap = 5)
  expect_true(length(chunks) > 1)

  # Edge case: empty text
  empty_chunks <- chunk_text("", chunk_size = 100, overlap = 10)
  expect_equal(length(empty_chunks), 0)
})

# Data frame factory for slides testing
chunks <- data.frame(
  content = c("Introduction text here.", "Methods section content."),
  doc_name = c("paper.pdf", "paper.pdf"),
  page_number = c(1, 5),
  stringsAsFactors = FALSE
)
```

**Location:**
- No separate fixtures directory
- Test data created inline in test functions
- YAML templates for config testing: `writeLines('openrouter:\n  api_key: "test-key"', tmp)`

## Coverage

**Requirements:**
- No coverage targets enforced
- No .codecov.yml or similar configuration

**View Coverage:**
```bash
# No built-in command; would require covr package installation
# Installation: install.packages("covr")
# Usage: covr::file_coverage("R/db.R", "tests/testthat/test-db.R")
```

## Test Types

**Unit Tests:**
- Scope: Individual functions (database CRUD, API parsing, config loading)
- Approach: Fast, isolated tests with temporary resources
- Examples: `test-config.R` (4 tests), `test-pdf.R` (4 tests)
- Run time: <1 second per test

**Integration Tests:**
```r
test_that("render_qmd_to_html returns path or error", {
  skip_if_not(check_quarto_installed(), "Quarto not installed")

  # Creates actual file and calls Quarto renderer
  qmd_content <- "---\ntitle: Test\nformat: revealjs\n---\n\n## Slide 1\n\nHello"
  qmd_path <- tempfile(fileext = ".qmd")
  writeLines(qmd_content, qmd_path)

  result <- render_qmd_to_html(qmd_path)

  expect_true(file.exists(result$path))
  expect_true(grepl("\\.html$", result$path))

  unlink(qmd_path)
  unlink(result$path)
})
```
- Scope: Multiple components working together (database + API, file I/O + rendering)
- Approach: Skip-able with `skip_if_not()` for optional dependencies
- Examples: `test-ragnar.R` (6 tests mixing unit + integration), `test-slides.R` (8 tests)

**E2E Tests:**
- Framework: Not used
- Reason: Shiny app doesn't have automated E2E tests; manual testing expected

## Common Patterns

### Async Testing
Not used in this codebase. All functions are synchronous R/database calls.

### Error Testing
```r
# Pattern 1: Expect specific error message
expect_error(
  get_ragnar_store(tmp_store),
  "OpenRouter API key required"
)

# Pattern 2: Expect silent failure with NULL return
result <- validate_openrouter_key("invalid-key")
expect_equal(result$valid, FALSE)

# Pattern 3: Graceful degradation
test_that("function falls back when dependency missing", {
  skip_if_not(file.exists("dependency.txt"), "Dependency missing")
  # Test with dependency
})
```

### State Testing
```r
# Database state changes
test_that("notebook update modifies search_query", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "search")

  # State before
  nb_before <- get_notebook(con, nb_id)
  expect_true(is.na(nb_before$search_query))

  # Update
  update_notebook(con, nb_id, search_query = "new query")

  # State after
  nb_after <- get_notebook(con, nb_id)
  expect_equal(nb_after$search_query, "new query")
})
```

### JSON/List Testing
```r
# Store and retrieve JSON data
test_that("create_abstract stores keywords", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "search")
  keywords <- c("machine learning", "neural networks")

  create_abstract(con, nb_id, "W123", "Title", list("Author"),
                  "Abstract.", 2024, "Nature", NULL,
                  keywords = keywords)

  abstracts <- list_abstracts(con, nb_id)
  stored_keywords <- jsonlite::fromJSON(abstracts$keywords[1])
  expect_equal(stored_keywords, keywords)
})
```

## Test File Summary

| File | Tests | Focus |
|------|-------|-------|
| `test-config.R` | 4 | Config loading, YAML parsing, nested settings |
| `test-db.R` | 16 | CRUD operations, schema creation, migrations, chunk storage |
| `test-api-openalex.R` | 3 | API response parsing, keyword extraction, edge cases |
| `test-pdf.R` | 4 | Text chunking with various inputs (short, empty, whitespace) |
| `test-ragnar.R` | 6 | Semantic chunking, store connection, fallback behavior |
| `test-slides.R` | 8 | Prompt building, theme injection, rendering, quarto integration |

## Best Practices Observed

1. **Isolation:** Each test creates fresh database or temp files
2. **Cleanup:** Always use `unlink()` or `on.exit()` to prevent test pollution
3. **Descriptive names:** Test names clearly describe what is being tested
4. **One logical assertion per test:** Complex scenarios split into multiple tests
5. **Readable arrange-act-assert:** Clear separation of setup, execution, and verification
6. **Graceful skipping:** Tests skip when optional dependencies unavailable
7. **No external dependencies in unit tests:** Mocked or in-memory data only
8. **Documentation via skip messages:** `skip("Integration test - requires API key")` explains why test is skipped

---

*Testing analysis: 2026-02-10*
