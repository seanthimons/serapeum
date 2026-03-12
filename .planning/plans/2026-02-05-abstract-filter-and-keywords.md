# Abstract Filter & Keywords Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add ability to filter out papers without abstracts (#5) and fetch/display paper keywords from OpenAlex (#13).

**Architecture:** Both features extend the existing search notebook pipeline. Keywords are extracted from OpenAlex API, stored as JSON in a new column, and displayed as badges. The abstract filter adds a client-side toggle to hide papers with empty abstracts from the list view.

**Tech Stack:** R/Shiny, DuckDB, OpenAlex API, jsonlite

---

## Task 1: Add Keywords Column to Database Schema

**Files:**
- Modify: `R/db.R:65-78`
- Test: `tests/testthat/test-db.R`

**Step 1: Write the failing test**

Add to `tests/testthat/test-db.R`:

```r
test_that("create_abstract stores keywords", {
  con <- init_db(":memory:")
  on.exit(DBI::dbDisconnect(con))

  # Create a notebook first
  create_notebook(con, "test-nb", "Test", "search")

  # Create abstract with keywords
  keywords <- c("machine learning", "neural networks", "deep learning")
  create_abstract(
    con, "test-nb", "paper123", "Test Paper", list("Author One"),
    "This is an abstract.", 2024, "Nature", "https://example.com/pdf",
    keywords = keywords
  )

  # Retrieve and verify
  abstracts <- list_abstracts(con, "test-nb")
  expect_equal(nrow(abstracts), 1)
  expect_true("keywords" %in% names(abstracts))

  stored_keywords <- jsonlite::fromJSON(abstracts$keywords[1])
  expect_equal(stored_keywords, keywords)
})

test_that("create_abstract works without keywords (backward compatible)", {
  con <- init_db(":memory:")
  on.exit(DBI::dbDisconnect(con))

  create_notebook(con, "test-nb", "Test", "search")

  # Create abstract without keywords parameter
  create_abstract(
    con, "test-nb", "paper456", "Test Paper 2", list("Author Two"),
    "Another abstract.", 2023, "Science", NULL
  )

  abstracts <- list_abstracts(con, "test-nb")
  expect_equal(nrow(abstracts), 1)
  # Keywords should be empty JSON array or NULL
  expect_true(is.na(abstracts$keywords[1]) || abstracts$keywords[1] == "[]")
})
```

**Step 2: Run test to verify it fails**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-db.R')"`
Expected: FAIL with "unused argument (keywords = keywords)"

**Step 3: Update database schema**

In `R/db.R`, modify the abstracts table creation (around line 65):

```r
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS abstracts (
      id VARCHAR PRIMARY KEY,
      notebook_id VARCHAR NOT NULL,
      paper_id VARCHAR NOT NULL,
      title VARCHAR NOT NULL,
      authors VARCHAR,
      abstract VARCHAR,
      keywords VARCHAR,
      year INTEGER,
      venue VARCHAR,
      pdf_url VARCHAR,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (notebook_id) REFERENCES notebooks(id)
    )
  ")
```

**Step 4: Update create_abstract function**

In `R/db.R`, modify `create_abstract()` (around line 412):

```r
create_abstract <- function(con, notebook_id, paper_id, title, authors,
                            abstract, year, venue, pdf_url, keywords = NULL) {
  id <- uuid::UUIDgenerate()
  authors_json <- jsonlite::toJSON(authors, auto_unbox = TRUE)

  # Convert keywords to JSON, default to empty array
  keywords_json <- if (is.null(keywords) || length(keywords) == 0) {
    "[]"
  } else {
    jsonlite::toJSON(keywords, auto_unbox = TRUE)
  }

  dbExecute(con, "
    INSERT INTO abstracts (id, notebook_id, paper_id, title, authors, abstract, keywords, year, venue, pdf_url)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ", list(id, notebook_id, paper_id, title, authors_json, abstract, keywords_json, year, venue, pdf_url))

  id
}
```

**Step 5: Run test to verify it passes**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-db.R')"`
Expected: PASS

**Step 6: Commit**

```bash
git add R/db.R tests/testthat/test-db.R
git commit -m "feat(db): add keywords column to abstracts table (#13)"
```

---

## Task 2: Extract Keywords from OpenAlex API

**Files:**
- Modify: `R/api_openalex.R:59-95`
- Test: `tests/testthat/test-api-openalex.R` (create if needed)

**Step 1: Write the failing test**

Create `tests/testthat/test-api-openalex.R`:

```r
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
      list(keyword = "machine learning"),
      list(keyword = "artificial intelligence"),
      list(keyword = "deep learning")
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
```

**Step 2: Run test to verify it fails**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"`
Expected: FAIL with "keywords" not found in result

**Step 3: Implement keyword extraction**

In `R/api_openalex.R`, modify `parse_openalex_work()` (around line 59-95). Add keyword extraction before the return statement:

```r
parse_openalex_work <- function(work) {
  # ... existing code for paper_id, authors, abstract, venue, pdf_url ...

  # Extract keywords
  keywords <- character()
  if (!is.null(work$keywords) && length(work$keywords) > 0) {
    keywords <- sapply(work$keywords, function(k) {
      if (!is.null(k$keyword)) k$keyword else ""
    })
    keywords <- keywords[keywords != ""]
  }

  list(
    paper_id = paper_id,
    title = work$title,
    authors = as.list(authors),
    abstract = reconstruct_abstract(work$abstract_inverted_index),
    keywords = as.list(keywords),
    year = work$publication_year,
    venue = venue,
    pdf_url = pdf_url
  )
}
```

**Step 4: Run test to verify it passes**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"`
Expected: PASS

**Step 5: Commit**

```bash
git add R/api_openalex.R tests/testthat/test-api-openalex.R
git commit -m "feat(api): extract keywords from OpenAlex response (#13)"
```

---

## Task 3: Wire Keywords Through Paper Import

**Files:**
- Modify: `R/mod_search_notebook.R:577-581`

**Step 1: Identify the import location**

In `R/mod_search_notebook.R`, find where `create_abstract()` is called (around line 577-581 in the paper refresh handler).

**Step 2: Update the create_abstract call**

Modify the call to pass keywords:

```r
abstract_id <- create_abstract(
  con(), nb_id, paper$paper_id, paper$title,
  paper$authors, paper$abstract,
  paper$year, paper$venue, paper$pdf_url,
  keywords = paper$keywords
)
```

**Step 3: Manual test**

1. Start the app: `Rscript -e "shiny::runApp()"`
2. Create or open a search notebook
3. Run a search and refresh results
4. Check database: `SELECT keywords FROM abstracts LIMIT 5;`
5. Verify keywords are populated as JSON arrays

**Step 4: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(search): pass keywords to create_abstract on import (#13)"
```

---

## Task 4: Display Keywords in Paper Detail View

**Files:**
- Modify: `R/mod_search_notebook.R:320` (paper detail area)

**Step 1: Find the paper detail rendering**

Locate where individual paper details are rendered (the card/panel showing title, authors, abstract).

**Step 2: Add keywords display section**

After the abstract display, add:

```r
# Keywords section
keywords_ui <- NULL
if (!is.null(paper$keywords) && !is.na(paper$keywords) && nchar(paper$keywords) > 0) {
  keywords <- tryCatch({
    jsonlite::fromJSON(paper$keywords)
  }, error = function(e) character())

  if (length(keywords) > 0) {
    keywords_ui <- div(
      class = "mt-2",
      tags$small(class = "text-muted", "Keywords: "),
      lapply(keywords, function(k) {
        span(class = "badge bg-secondary me-1", k)
      })
    )
  }
}
```

Include `keywords_ui` in the paper card output.

**Step 3: Manual test**

1. Start the app
2. Open a search notebook with papers
3. Click on a paper to view details
4. Verify keywords appear as badges below the abstract

**Step 4: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(ui): display paper keywords as badges (#13)"
```

---

## Task 5: Add "Hide Papers Without Abstracts" Filter

**Files:**
- Modify: `R/mod_search_notebook.R:151-165` (paper list reactive)
- Modify: `R/mod_search_notebook.R:443-460` (filter UI area)

**Step 1: Add filter checkbox to UI**

In the filter section of the search notebook UI (around line 443-460), add:

```r
checkboxInput(
  ns("filter_has_abstract"),
  "Show only papers with abstracts",
  value = TRUE
)
```

**Step 2: Add reactive filter logic**

Modify the `papers_data` reactive or add a filtered reactive:

```r
filtered_papers <- reactive({
  papers <- papers_data()
  req(papers)

  if (isTRUE(input$filter_has_abstract)) {
    papers <- papers[!is.na(papers$abstract) & nchar(papers$abstract) > 0, ]
  }

  papers
})
```

**Step 3: Update paper list to use filtered data**

Replace references to `papers_data()` with `filtered_papers()` in the paper list rendering.

**Step 4: Manual test**

1. Start the app
2. Open a search notebook
3. Uncheck "Show only papers with abstracts"
4. Verify papers without abstracts appear (if any exist)
5. Re-check the filter
6. Verify papers without abstracts are hidden

**Step 5: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(search): add filter to hide papers without abstracts (#5)"
```

---

## Task 6: Update Filter Persistence

**Files:**
- Modify: `R/mod_search_notebook.R:496-501` (filter storage)
- Modify: `R/mod_search_notebook.R:405-410` (filter loading)

**Step 1: Add to filter storage**

When saving filters, include the new checkbox state:

```r
filters <- list(
  # ... existing filters ...
  has_abstract = input$filter_has_abstract
)
```

**Step 2: Add to filter loading**

When loading filters, restore the checkbox:

```r
has_abstract <- if (!is.null(filters$has_abstract)) filters$has_abstract else TRUE
updateCheckboxInput(session, "filter_has_abstract", value = has_abstract)
```

**Step 3: Manual test**

1. Start the app
2. Open a search notebook
3. Uncheck "Show only papers with abstracts"
4. Close and reopen the notebook
5. Verify the filter state persisted

**Step 4: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(search): persist abstract filter state (#5)"
```

---

## Task 7: Final Integration Test

**Step 1: Full workflow test**

1. Start fresh: delete `data/notebooks.duckdb`
2. Run: `Rscript -e "shiny::runApp()"`
3. Create new search notebook
4. Search for papers (e.g., "machine learning 2024")
5. Verify:
   - Papers have keywords displayed
   - "Show only papers with abstracts" filter works
   - Filter state persists across page reloads

**Step 2: Run all tests**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: All tests PASS

**Step 3: Final commit**

```bash
git add -A
git commit -m "test: verify abstract filter and keywords integration (#5, #13)"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Database schema + keywords column | `R/db.R`, `tests/testthat/test-db.R` |
| 2 | Extract keywords from OpenAlex | `R/api_openalex.R`, `tests/testthat/test-api-openalex.R` |
| 3 | Wire keywords through import | `R/mod_search_notebook.R` |
| 4 | Display keywords in UI | `R/mod_search_notebook.R` |
| 5 | Add abstract filter checkbox | `R/mod_search_notebook.R` |
| 6 | Persist filter state | `R/mod_search_notebook.R` |
| 7 | Integration test | - |

**Estimated commits:** 7
**Key patterns:** JSON storage for arrays, reactive filtering, checkbox persistence
