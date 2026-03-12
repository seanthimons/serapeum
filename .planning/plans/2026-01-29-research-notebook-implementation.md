# Research Notebook Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a local-first NotebookLM-style research tool using R/Shiny.

**Architecture:** Shiny app with bslib UI, DuckDB for storage + vector search, OpenRouter for LLM/embeddings, OpenAlex for paper discovery. Modular structure with separate files for API clients, database operations, and Shiny modules.

**Tech Stack:** R, Shiny, bslib, DuckDB (duckdb + vss extension), httr2, pdftools, yaml

---

## Phase 1: Project Foundation

### Task 1.1: Initialize renv and Directory Structure

**Files:**
- Create: `renv.lock` (via renv::init)
- Create: `R/` directory
- Create: `data/` directory
- Create: `storage/` directory
- Create: `tests/` directory

**Step 1: Initialize renv**

Run in R console from worktree directory:
```r
setwd("C:/Users/sxthi/Documents/notebook/.worktrees/v1-build")
install.packages("renv")
renv::init()
```

**Step 2: Create directory structure**

```r
dir.create("R", showWarnings = FALSE)
dir.create("data", showWarnings = FALSE)
dir.create("storage", showWarnings = FALSE)
dir.create("tests", showWarnings = FALSE)
dir.create("tests/testthat", showWarnings = FALSE)
```

**Step 3: Install core dependencies**

```r
renv::install(c(
  "shiny",
  "bslib",
  "duckdb",
  "httr2",
  "pdftools",
  "yaml",
  "jsonlite",
  "uuid",
  "testthat"
))
renv::snapshot()
```

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: initialize project with renv and directory structure"
```

---

### Task 1.2: Create Config File Template

**Files:**
- Create: `config.example.yml`

**Step 1: Create example config**

Create `config.example.yml`:
```yaml
# API Keys
openrouter:
  api_key: "your-openrouter-api-key"

openalex:
  api_key: "your-openalex-api-key"
  email: "your-email@example.com"

# Default Models
defaults:
  chat_model: "anthropic/claude-sonnet-4"
  embedding_model: "openai/text-embedding-3-small"

# App Settings
app:
  port: 8080
  storage_path: "storage/"
  chunk_size: 500
  chunk_overlap: 50
```

**Step 2: Commit**

```bash
git add config.example.yml
git commit -m "feat: add config.example.yml template"
```

---

### Task 1.3: Create Config Loading Utility

**Files:**
- Create: `R/config.R`
- Create: `tests/testthat/test-config.R`

**Step 1: Write failing test**

Create `tests/testthat/test-config.R`:
```r
library(testthat)
source("R/config.R")

test_that("load_config reads yaml file", {
  # Create temp config
  tmp <- tempfile(fileext = ".yml")
  writeLines('openrouter:\n  api_key: "test-key"', tmp)

  config <- load_config(tmp)

  expect_equal(config$openrouter$api_key, "test-key")
  unlink(tmp)
})

test_that("load_config returns NULL for missing file", {
  config <- load_config("nonexistent.yml")
  expect_null(config)
})

test_that("get_setting returns config value", {
  # Create temp config
  tmp <- tempfile(fileext = ".yml")
  yaml::write_yaml(list(
    defaults = list(chat_model = "test-model"),
    app = list(port = 3000)
  ), tmp)

  config <- load_config(tmp)

  expect_equal(get_setting(config, "defaults", "chat_model"), "test-model")
  expect_equal(get_setting(config, "app", "port"), 3000)
  expect_null(get_setting(config, "missing", "key"))
  unlink(tmp)
})
```

**Step 2: Run test to verify it fails**

```r
testthat::test_file("tests/testthat/test-config.R")
```

Expected: FAIL (functions not defined)

**Step 3: Implement config.R**

Create `R/config.R`:
```r
#' Load configuration from YAML file
#' @param path Path to config file
#' @return List of config values or NULL if file doesn't exist
load_config <- function(path = "config.yml") {
  if (!file.exists(path)) {
    return(NULL)
  }
  yaml::read_yaml(path)
}

#' Get a nested setting from config
#' @param config Config list from load_config
#' @param ... Path to setting (e.g., "defaults", "chat_model")
#' @return Setting value or NULL if not found
get_setting <- function(config, ...) {
  keys <- list(...)
  result <- config
  for (key in keys) {
    if (is.null(result) || !key %in% names(result)) {
      return(NULL)
    }
    result <- result[[key]]
  }
  result
}
```

**Step 4: Run test to verify it passes**

```r
testthat::test_file("tests/testthat/test-config.R")
```

Expected: All tests pass

**Step 5: Commit**

```bash
git add R/config.R tests/testthat/test-config.R
git commit -m "feat: add config loading utility with tests"
```

---

## Phase 2: Database Layer

### Task 2.1: Initialize DuckDB Connection

**Files:**
- Create: `R/db.R`
- Create: `tests/testthat/test-db.R`

**Step 1: Write failing test**

Create `tests/testthat/test-db.R`:
```r
library(testthat)
source("R/db.R")

test_that("get_db_connection creates database file", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test.duckdb")

  con <- get_db_connection(db_path)

  expect_true(file.exists(db_path))
  expect_s4_class(con, "duckdb_connection")

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("init_schema creates required tables", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_schema.duckdb")

  con <- get_db_connection(db_path)
  init_schema(con)

  tables <- DBI::dbListTables(con)

  expect_true("notebooks" %in% tables)
  expect_true("documents" %in% tables)
  expect_true("abstracts" %in% tables)
  expect_true("chunks" %in% tables)
  expect_true("settings" %in% tables)

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})
```

**Step 2: Run test to verify it fails**

```r
testthat::test_file("tests/testthat/test-db.R")
```

Expected: FAIL

**Step 3: Implement db.R**

Create `R/db.R`:
```r
library(duckdb)
library(DBI)

#' Get DuckDB connection
#' @param path Path to database file
#' @return DuckDB connection object
get_db_connection <- function(path = "data/notebooks.duckdb") {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  con <- dbConnect(duckdb(), dbdir = path)
  con
}

#' Initialize database schema
#' @param con DuckDB connection
init_schema <- function(con) {
  # Notebooks table

dbExecute(con, "
    CREATE TABLE IF NOT EXISTS notebooks (
      id VARCHAR PRIMARY KEY,
      name VARCHAR NOT NULL,
      type VARCHAR NOT NULL,
      search_query VARCHAR,
      search_filters JSON,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")

  # Documents table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS documents (
      id VARCHAR PRIMARY KEY,
      notebook_id VARCHAR NOT NULL,
      filename VARCHAR NOT NULL,
      filepath VARCHAR NOT NULL,
      full_text VARCHAR,
      page_count INTEGER,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (notebook_id) REFERENCES notebooks(id)
    )
  ")

  # Abstracts table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS abstracts (
      id VARCHAR PRIMARY KEY,
      notebook_id VARCHAR NOT NULL,
      paper_id VARCHAR NOT NULL,
      title VARCHAR NOT NULL,
      authors JSON,
      abstract VARCHAR,
      year INTEGER,
      venue VARCHAR,
      pdf_url VARCHAR,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (notebook_id) REFERENCES notebooks(id)
    )
  ")

  # Chunks table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS chunks (
      id VARCHAR PRIMARY KEY,
      source_id VARCHAR NOT NULL,
      source_type VARCHAR NOT NULL,
      chunk_index INTEGER NOT NULL,
      content VARCHAR NOT NULL,
      embedding FLOAT[],
      page_number INTEGER
    )
  ")

  # Settings table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS settings (
      key VARCHAR PRIMARY KEY,
      value JSON
    )
  ")
}
```

**Step 4: Run test to verify it passes**

```r
testthat::test_file("tests/testthat/test-db.R")
```

Expected: All tests pass

**Step 5: Commit**

```bash
git add R/db.R tests/testthat/test-db.R
git commit -m "feat: add DuckDB connection and schema initialization"
```

---

### Task 2.2: Notebook CRUD Operations

**Files:**
- Modify: `R/db.R`
- Modify: `tests/testthat/test-db.R`

**Step 1: Add failing tests**

Append to `tests/testthat/test-db.R`:
```r
test_that("create_notebook inserts a notebook", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_crud.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  id <- create_notebook(con, "My Research", "document")

  result <- DBI::dbGetQuery(con, "SELECT * FROM notebooks WHERE id = ?", list(id))
  expect_equal(nrow(result), 1)
  expect_equal(result$name, "My Research")
  expect_equal(result$type, "document")

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("list_notebooks returns all notebooks", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_list.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  create_notebook(con, "Notebook 1", "document")
  create_notebook(con, "Notebook 2", "search", search_query = "machine learning")

  notebooks <- list_notebooks(con)

  expect_equal(nrow(notebooks), 2)

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("delete_notebook removes notebook", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_delete.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  id <- create_notebook(con, "To Delete", "document")
  delete_notebook(con, id)

  result <- DBI::dbGetQuery(con, "SELECT * FROM notebooks WHERE id = ?", list(id))
  expect_equal(nrow(result), 0)

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})
```

**Step 2: Run tests to verify they fail**

```r
testthat::test_file("tests/testthat/test-db.R")
```

Expected: New tests FAIL

**Step 3: Implement CRUD functions**

Append to `R/db.R`:
```r
#' Create a new notebook
#' @param con DuckDB connection
#' @param name Notebook name
#' @param type "document" or "search"
#' @param search_query Query string (for search notebooks)
#' @param search_filters Filter list (for search notebooks)
#' @return Notebook ID
create_notebook <- function(con, name, type, search_query = NULL, search_filters = NULL) {
  id <- uuid::UUIDgenerate()
  filters_json <- if (!is.null(search_filters)) jsonlite::toJSON(search_filters, auto_unbox = TRUE) else NA

  dbExecute(con, "
    INSERT INTO notebooks (id, name, type, search_query, search_filters)
    VALUES (?, ?, ?, ?, ?)
  ", list(id, name, type, search_query, filters_json))

  id
}

#' List all notebooks
#' @param con DuckDB connection
#' @return Data frame of notebooks
list_notebooks <- function(con) {
  dbGetQuery(con, "SELECT * FROM notebooks ORDER BY created_at DESC")
}

#' Get a single notebook by ID
#' @param con DuckDB connection
#' @param id Notebook ID
#' @return Single row data frame or NULL
get_notebook <- function(con, id) {
  result <- dbGetQuery(con, "SELECT * FROM notebooks WHERE id = ?", list(id))
  if (nrow(result) == 0) return(NULL)
  result
}

#' Delete a notebook and its contents
#' @param con DuckDB connection
#' @param id Notebook ID
delete_notebook <- function(con, id) {
  # Delete chunks for documents in this notebook
  dbExecute(con, "
    DELETE FROM chunks WHERE source_id IN (
      SELECT id FROM documents WHERE notebook_id = ?
    )
  ", list(id))

  # Delete chunks for abstracts in this notebook
  dbExecute(con, "
    DELETE FROM chunks WHERE source_id IN (
      SELECT id FROM abstracts WHERE notebook_id = ?
    )
  ", list(id))

  # Delete documents
  dbExecute(con, "DELETE FROM documents WHERE notebook_id = ?", list(id))

  # Delete abstracts
  dbExecute(con, "DELETE FROM abstracts WHERE notebook_id = ?", list(id))

  # Delete notebook
  dbExecute(con, "DELETE FROM notebooks WHERE id = ?", list(id))
}
```

**Step 4: Run tests to verify they pass**

```r
testthat::test_file("tests/testthat/test-db.R")
```

Expected: All tests pass

**Step 5: Commit**

```bash
git add R/db.R tests/testthat/test-db.R
git commit -m "feat: add notebook CRUD operations"
```

---

### Task 2.3: Document and Chunk Operations

**Files:**
- Modify: `R/db.R`
- Modify: `tests/testthat/test-db.R`

**Step 1: Add failing tests**

Append to `tests/testthat/test-db.R`:
```r
test_that("create_document inserts a document", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_doc.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "document")
  doc_id <- create_document(con, nb_id, "paper.pdf", "storage/paper.pdf", "Full text here", 5)

  result <- DBI::dbGetQuery(con, "SELECT * FROM documents WHERE id = ?", list(doc_id))
  expect_equal(nrow(result), 1)
  expect_equal(result$filename, "paper.pdf")
  expect_equal(result$page_count, 5)

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("list_documents returns documents for notebook", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_list_doc.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "document")
  create_document(con, nb_id, "doc1.pdf", "path1", "text1", 1)
  create_document(con, nb_id, "doc2.pdf", "path2", "text2", 2)

  docs <- list_documents(con, nb_id)

  expect_equal(nrow(docs), 2)

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})

test_that("create_chunk and list_chunks work", {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, "test_chunks.duckdb")
  con <- get_db_connection(db_path)
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "document")
  doc_id <- create_document(con, nb_id, "doc.pdf", "path", "text", 1)

  create_chunk(con, doc_id, "document", 0, "First chunk content", page_number = 1)
  create_chunk(con, doc_id, "document", 1, "Second chunk content", page_number = 1)

  chunks <- list_chunks(con, doc_id)

  expect_equal(nrow(chunks), 2)
  expect_equal(chunks$content[1], "First chunk content")

  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(db_path)
})
```

**Step 2: Run tests to verify they fail**

```r
testthat::test_file("tests/testthat/test-db.R")
```

**Step 3: Implement document and chunk functions**

Append to `R/db.R`:
```r
#' Create a document record
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @param filename Original filename
#' @param filepath Storage path
#' @param full_text Extracted text
#' @param page_count Number of pages
#' @return Document ID
create_document <- function(con, notebook_id, filename, filepath, full_text, page_count) {
  id <- uuid::UUIDgenerate()

  dbExecute(con, "
    INSERT INTO documents (id, notebook_id, filename, filepath, full_text, page_count)
    VALUES (?, ?, ?, ?, ?, ?)
  ", list(id, notebook_id, filename, filepath, full_text, page_count))

  id
}

#' List documents in a notebook
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @return Data frame of documents
list_documents <- function(con, notebook_id) {
  dbGetQuery(con, "
    SELECT * FROM documents WHERE notebook_id = ? ORDER BY created_at DESC
  ", list(notebook_id))
}

#' Create a chunk record
#' @param con DuckDB connection
#' @param source_id Document or abstract ID
#' @param source_type "document" or "abstract"
#' @param chunk_index Chunk position
#' @param content Chunk text
#' @param embedding Vector embedding (optional)
#' @param page_number Page number (optional)
#' @return Chunk ID
create_chunk <- function(con, source_id, source_type, chunk_index, content,
                         embedding = NULL, page_number = NULL) {
  id <- uuid::UUIDgenerate()

  # For now, store embedding as NULL - will update after embedding
  dbExecute(con, "
    INSERT INTO chunks (id, source_id, source_type, chunk_index, content, page_number)
    VALUES (?, ?, ?, ?, ?, ?)
  ", list(id, source_id, source_type, chunk_index, content, page_number))

  id
}

#' List chunks for a source
#' @param con DuckDB connection
#' @param source_id Document or abstract ID
#' @return Data frame of chunks
list_chunks <- function(con, source_id) {
  dbGetQuery(con, "
    SELECT * FROM chunks WHERE source_id = ? ORDER BY chunk_index
  ", list(source_id))
}

#' Update chunk embedding
#' @param con DuckDB connection
#' @param chunk_id Chunk ID
#' @param embedding Numeric vector
update_chunk_embedding <- function(con, chunk_id, embedding) {
  # Convert to array literal for DuckDB
  embedding_str <- paste0("[", paste(embedding, collapse = ","), "]")
  dbExecute(con, sprintf("
    UPDATE chunks SET embedding = %s WHERE id = ?
  ", embedding_str), list(chunk_id))
}
```

**Step 4: Run tests to verify they pass**

```r
testthat::test_file("tests/testthat/test-db.R")
```

**Step 5: Commit**

```bash
git add R/db.R tests/testthat/test-db.R
git commit -m "feat: add document and chunk database operations"
```

---

## Phase 3: API Integrations

### Task 3.1: OpenRouter API Client

**Files:**
- Create: `R/api_openrouter.R`
- Create: `tests/testthat/test-api-openrouter.R`

**Step 1: Write failing test**

Create `tests/testthat/test-api-openrouter.R`:
```r
library(testthat)
source("R/api_openrouter.R")

test_that("build_openrouter_request creates valid request", {
  req <- build_openrouter_request("test-key", "chat/completions")

  expect_s3_class(req, "httr2_request")
  expect_true(grepl("openrouter.ai", req$url))
})

test_that("format_chat_messages creates proper structure", {
  messages <- format_chat_messages("You are helpful", "Hello")

  expect_equal(length(messages), 2)
  expect_equal(messages[[1]]$role, "system")
  expect_equal(messages[[2]]$role, "user")
})
```

**Step 2: Run test to verify it fails**

```r
testthat::test_file("tests/testthat/test-api-openrouter.R")
```

**Step 3: Implement OpenRouter client**

Create `R/api_openrouter.R`:
```r
library(httr2)
library(jsonlite)

OPENROUTER_BASE_URL <- "https://openrouter.ai/api/v1"

#' Build OpenRouter API request
#' @param api_key API key
#' @param endpoint API endpoint
#' @return httr2 request object
build_openrouter_request <- function(api_key, endpoint) {
  request(paste0(OPENROUTER_BASE_URL, "/", endpoint)) |>
    req_headers(
      "Authorization" = paste("Bearer", api_key),
      "Content-Type" = "application/json"
    )
}

#' Format messages for chat API
#' @param system_prompt System message
#' @param user_message User message
#' @param history Previous messages (optional)
#' @return List of message objects
format_chat_messages <- function(system_prompt, user_message, history = list()) {
  messages <- list(
    list(role = "system", content = system_prompt)
  )
  messages <- c(messages, history)
  messages <- c(messages, list(list(role = "user", content = user_message)))
  messages
}

#' Send chat completion request
#' @param api_key API key
#' @param model Model ID
#' @param messages Message list
#' @return Response content
chat_completion <- function(api_key, model, messages) {
  req <- build_openrouter_request(api_key, "chat/completions") |>
    req_body_json(list(
      model = model,
      messages = messages
    ))

  resp <- req_perform(req)
  body <- resp_body_json(resp)

  body$choices[[1]]$message$content
}

#' Get embeddings for text
#' @param api_key API key
#' @param model Embedding model ID
#' @param text Text to embed (character vector)
#' @return List of embedding vectors
get_embeddings <- function(api_key, model, text) {
  req <- build_openrouter_request(api_key, "embeddings") |>
    req_body_json(list(
      model = model,
      input = text
    ))

  resp <- req_perform(req)
  body <- resp_body_json(resp)

  lapply(body$data, function(x) x$embedding)
}
```

**Step 4: Run tests to verify they pass**

```r
testthat::test_file("tests/testthat/test-api-openrouter.R")
```

**Step 5: Commit**

```bash
git add R/api_openrouter.R tests/testthat/test-api-openrouter.R
git commit -m "feat: add OpenRouter API client for chat and embeddings"
```

---

### Task 3.2: OpenAlex API Client

**Files:**
- Create: `R/api_openalex.R`
- Create: `tests/testthat/test-api-openalex.R`

**Step 1: Write failing test**

Create `tests/testthat/test-api-openalex.R`:
```r
library(testthat)
source("R/api_openalex.R")

test_that("build_openalex_request creates valid request", {
  req <- build_openalex_request("works", email = "test@example.com")

  expect_s3_class(req, "httr2_request")
  expect_true(grepl("openalex.org", req$url))
})

test_that("parse_openalex_work extracts required fields", {
  mock_work <- list(
    id = "https://openalex.org/W123",
    title = "Test Paper",
    authorships = list(
      list(author = list(display_name = "Author One")),
      list(author = list(display_name = "Author Two"))
    ),
    abstract_inverted_index = list("This" = list(0), "test" = list(2), "is" = list(1)),
    publication_year = 2024,
    primary_location = list(source = list(display_name = "Nature")),
    open_access = list(oa_url = "https://example.com/paper.pdf")
  )

  parsed <- parse_openalex_work(mock_work)

  expect_equal(parsed$paper_id, "W123")
  expect_equal(parsed$title, "Test Paper")
  expect_equal(parsed$year, 2024)
  expect_equal(length(parsed$authors), 2)
})
```

**Step 2: Run test to verify it fails**

```r
testthat::test_file("tests/testthat/test-api-openalex.R")
```

**Step 3: Implement OpenAlex client**

Create `R/api_openalex.R`:
```r
library(httr2)
library(jsonlite)

OPENALEX_BASE_URL <- "https://api.openalex.org"

#' Build OpenAlex API request
#' @param endpoint API endpoint
#' @param email User email for polite pool
#' @param api_key Optional API key
#' @return httr2 request object
build_openalex_request <- function(endpoint, email = NULL, api_key = NULL) {
  req <- request(paste0(OPENALEX_BASE_URL, "/", endpoint))

  if (!is.null(email)) {
    req <- req |> req_url_query(mailto = email)
  }

  if (!is.null(api_key)) {
    req <- req |> req_headers("Authorization" = paste("Bearer", api_key))
  }

  req
}

#' Reconstruct abstract from inverted index
#' @param inverted_index OpenAlex inverted index format
#' @return Plain text abstract
reconstruct_abstract <- function(inverted_index) {
  if (is.null(inverted_index)) return(NA_character_)

  # Build position -> word mapping
  words <- character()
  for (word in names(inverted_index)) {
    positions <- inverted_index[[word]]
    for (pos in positions) {
      words[pos + 1] <- word  # +1 for R's 1-indexing
    }
  }

  paste(words, collapse = " ")
}

#' Parse OpenAlex work object
#' @param work Raw work object from API
#' @return Cleaned list with relevant fields
parse_openalex_work <- function(work) {
  # Extract paper ID from URL
  paper_id <- gsub("https://openalex.org/", "", work$id)

  # Extract author names
  authors <- sapply(work$authorships, function(a) {
    a$author$display_name
  })

  # Get venue
  venue <- NA_character_
  if (!is.null(work$primary_location$source$display_name)) {
    venue <- work$primary_location$source$display_name
  }

  # Get PDF URL
  pdf_url <- NA_character_
  if (!is.null(work$open_access$oa_url)) {
    pdf_url <- work$open_access$oa_url
  }

  list(
    paper_id = paper_id,
    title = work$title,
    authors = as.list(authors),
    abstract = reconstruct_abstract(work$abstract_inverted_index),
    year = work$publication_year,
    venue = venue,
    pdf_url = pdf_url
  )
}

#' Search for papers
#' @param query Search query
#' @param email User email
#' @param api_key Optional API key
#' @param from_year Filter by start year
#' @param to_year Filter by end year
#' @param per_page Results per page (max 200)
#' @return List of parsed works
search_papers <- function(query, email, api_key = NULL,
                          from_year = NULL, to_year = NULL, per_page = 25) {
  req <- build_openalex_request("works", email, api_key)

  # Build filter string
  filters <- c("has_abstract:true")
  if (!is.null(from_year)) filters <- c(filters, paste0("from_publication_date:", from_year, "-01-01"))
  if (!is.null(to_year)) filters <- c(filters, paste0("to_publication_date:", to_year, "-12-31"))
  filter_str <- paste(filters, collapse = ",")

  req <- req |>
    req_url_query(
      search = query,
      filter = filter_str,
      per_page = per_page
    )

  resp <- req_perform(req)
  body <- resp_body_json(resp)

  lapply(body$results, parse_openalex_work)
}
```

**Step 4: Run tests to verify they pass**

```r
testthat::test_file("tests/testthat/test-api-openalex.R")
```

**Step 5: Commit**

```bash
git add R/api_openalex.R tests/testthat/test-api-openalex.R
git commit -m "feat: add OpenAlex API client for paper search"
```

---

### Task 3.3: PDF Text Extraction

**Files:**
- Create: `R/pdf.R`
- Create: `tests/testthat/test-pdf.R`

**Step 1: Write failing test**

Create `tests/testthat/test-pdf.R`:
```r
library(testthat)
source("R/pdf.R")

test_that("chunk_text splits text into overlapping chunks", {
  text <- paste(rep("word", 100), collapse = " ")

  chunks <- chunk_text(text, chunk_size = 20, overlap = 5)

  expect_true(length(chunks) > 1)
  expect_true(all(sapply(chunks, nchar) <= 150))  # rough char limit
})

test_that("chunk_text handles short text", {
  text <- "Short text"

  chunks <- chunk_text(text, chunk_size = 100, overlap = 10)

  expect_equal(length(chunks), 1)
  expect_equal(chunks[[1]], "Short text")
})
```

**Step 2: Run test to verify it fails**

```r
testthat::test_file("tests/testthat/test-pdf.R")
```

**Step 3: Implement PDF utilities**

Create `R/pdf.R`:
```r
library(pdftools)

#' Extract text from PDF file
#' @param path Path to PDF file
#' @return List with text (character vector per page) and page_count
extract_pdf_text <- function(path) {
  if (!file.exists(path)) {
    stop("PDF file not found: ", path)
  }

  text <- pdf_text(path)

  list(
    text = text,
    page_count = length(text)
  )
}

#' Split text into chunks with overlap
#' @param text Text to chunk
#' @param chunk_size Approximate words per chunk
#' @param overlap Words of overlap between chunks
#' @return Character vector of chunks
chunk_text <- function(text, chunk_size = 500, overlap = 50) {
  # Split into words
  words <- unlist(strsplit(text, "\\s+"))
  words <- words[words != ""]

  if (length(words) <= chunk_size) {
    return(list(paste(words, collapse = " ")))
  }

  chunks <- list()
  start <- 1

  while (start <= length(words)) {
    end <- min(start + chunk_size - 1, length(words))
    chunk_words <- words[start:end]
    chunks <- c(chunks, list(paste(chunk_words, collapse = " ")))

    if (end >= length(words)) break

    start <- end - overlap + 1
  }

  chunks
}

#' Process PDF into chunks with page numbers
#' @param path Path to PDF
#' @param chunk_size Words per chunk
#' @param overlap Words of overlap
#' @return Data frame with chunk content and page numbers
process_pdf <- function(path, chunk_size = 500, overlap = 50) {
  extracted <- extract_pdf_text(path)

  all_chunks <- data.frame(
    content = character(),
    page_number = integer(),
    chunk_index = integer(),
    stringsAsFactors = FALSE
  )

  global_index <- 0

  for (page_num in seq_along(extracted$text)) {
    page_text <- extracted$text[page_num]

    # Skip empty pages
    if (nchar(trimws(page_text)) == 0) next

    page_chunks <- chunk_text(page_text, chunk_size, overlap)

    for (chunk in page_chunks) {
      all_chunks <- rbind(all_chunks, data.frame(
        content = chunk,
        page_number = page_num,
        chunk_index = global_index,
        stringsAsFactors = FALSE
      ))
      global_index <- global_index + 1
    }
  }

  list(
    chunks = all_chunks,
    full_text = paste(extracted$text, collapse = "\n\n"),
    page_count = extracted$page_count
  )
}
```

**Step 4: Run tests to verify they pass**

```r
testthat::test_file("tests/testthat/test-pdf.R")
```

**Step 5: Commit**

```bash
git add R/pdf.R tests/testthat/test-pdf.R
git commit -m "feat: add PDF text extraction and chunking utilities"
```

---

## Phase 4: Basic Shiny App Shell

### Task 4.1: Create Main App Entry Point

**Files:**
- Create: `app.R`

**Step 1: Create app.R**

Create `app.R`:
```r
library(shiny)
library(bslib)

# Source all R files
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Load config
config <- load_config()

# Initialize database
db_path <- get_setting(config, "app", "db_path") %||% "data/notebooks.duckdb"
con <- get_db_connection(db_path)
init_schema(con)

# Clean up on exit
onStop(function() {
  DBI::dbDisconnect(con, shutdown = TRUE)
})

# UI
ui <- page_sidebar(
  title = "Notebook",
  theme = bs_theme(
    preset = "shiny",
    primary = "#6366f1"  # Indigo accent
  ),
  sidebar = sidebar(
    title = "Notebooks",
    width = 280,
    actionButton("new_notebook", "New Notebook",
                 class = "btn-primary w-100 mb-3"),
    hr(),
    uiOutput("notebook_list"),
    hr(),
    actionLink("settings_link", "Settings", icon = icon("gear"))
  ),
  # Main content
  uiOutput("main_content")
)

# Server
server <- function(input, output, session) {
  # Reactive: current selected notebook
  current_notebook <- reactiveVal(NULL)

  # Reactive: trigger notebook list refresh
  notebook_refresh <- reactiveVal(0)

  # Render notebook list
  output$notebook_list <- renderUI({
    notebook_refresh()  # Dependency for refresh
    notebooks <- list_notebooks(con)

    if (nrow(notebooks) == 0) {
      return(p("No notebooks yet", class = "text-muted"))
    }

    lapply(seq_len(nrow(notebooks)), function(i) {
      nb <- notebooks[i, ]
      icon_name <- if (nb$type == "search") "magnifying-glass" else "book"

      actionLink(
        inputId = paste0("select_nb_", nb$id),
        label = tagList(icon(icon_name), nb$name),
        class = "d-block py-2"
      )
    })
  })

  # Observe notebook selection clicks
  observe({
    notebooks <- list_notebooks(con)
    lapply(notebooks$id, function(nb_id) {
      observeEvent(input[[paste0("select_nb_", nb_id)]], {
        current_notebook(nb_id)
      }, ignoreInit = TRUE)
    })
  })

  # Main content switching
  output$main_content <- renderUI({
    nb_id <- current_notebook()

    if (is.null(nb_id)) {
      # Welcome screen
      card(
        card_header("Welcome to Notebook"),
        card_body(
          p("Select a notebook from the sidebar or create a new one to get started."),
          p("Notebook lets you:"),
          tags$ul(
            tags$li("Upload and chat with PDF documents"),
            tags$li("Search academic papers via OpenAlex"),
            tags$li("Generate summaries and study guides")
          )
        )
      )
    } else {
      # Notebook view (placeholder for now)
      nb <- get_notebook(con, nb_id)
      card(
        card_header(nb$name),
        card_body(
          p(paste("Type:", nb$type)),
          p("Notebook content coming soon...")
        )
      )
    }
  })

  # New notebook modal
  observeEvent(input$new_notebook, {
    showModal(modalDialog(
      title = "Create New Notebook",
      textInput("new_nb_name", "Name"),
      radioButtons("new_nb_type", "Type",
                   choices = c("Document" = "document", "Search" = "search")),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("create_nb", "Create", class = "btn-primary")
      )
    ))
  })

  # Create notebook
  observeEvent(input$create_nb, {
    req(input$new_nb_name)

    id <- create_notebook(con, input$new_nb_name, input$new_nb_type)
    removeModal()
    notebook_refresh(notebook_refresh() + 1)
    current_notebook(id)
  })

  # Settings link
  observeEvent(input$settings_link, {
    current_notebook("__settings__")
  })
}

# Run app
shinyApp(ui, server)
```

**Step 2: Test app launches**

```r
shiny::runApp(".", port = 8080)
```

Verify: App opens at http://localhost:8080, shows welcome screen, can create notebooks.

**Step 3: Commit**

```bash
git add app.R
git commit -m "feat: add basic Shiny app shell with notebook list and creation"
```

---

## Phase 5: Document Notebook Features

### Task 5.1: Document Upload Module

**Files:**
- Create: `R/mod_document_notebook.R`

**Step 1: Create document notebook module**

Create `R/mod_document_notebook.R`:
```r
#' Document Notebook Module UI
#' @param id Module ID
mod_document_notebook_ui <- function(id) {
  ns <- NS(id)

  layout_columns(
    col_widths = c(4, 8),
    # Left: Document list
    card(
      card_header("Documents"),
      card_body(
        fileInput(ns("upload_pdf"), "Upload PDF", accept = ".pdf"),
        hr(),
        uiOutput(ns("document_list"))
      )
    ),
    # Right: Chat
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center",
        "Chat",
        div(
          actionButton(ns("btn_summarize"), "Summarize", class = "btn-sm btn-outline-primary"),
          actionButton(ns("btn_keypoints"), "Key Points", class = "btn-sm btn-outline-primary"),
          actionButton(ns("btn_studyguide"), "Study Guide", class = "btn-sm btn-outline-primary"),
          actionButton(ns("btn_outline"), "Outline", class = "btn-sm btn-outline-primary")
        )
      ),
      card_body(
        class = "d-flex flex-column",
        style = "height: 500px;",
        div(
          id = ns("chat_messages"),
          class = "flex-grow-1 overflow-auto mb-3",
          uiOutput(ns("messages"))
        ),
        div(
          class = "d-flex gap-2",
          textInput(ns("user_input"), NULL, placeholder = "Ask a question...", width = "100%"),
          actionButton(ns("send"), "Send", class = "btn-primary")
        )
      )
    )
  )
}

#' Document Notebook Module Server
#' @param id Module ID
#' @param con Database connection
#' @param notebook_id Reactive notebook ID
#' @param config App config
mod_document_notebook_server <- function(id, con, notebook_id, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive: messages
    messages <- reactiveVal(list())

    # Reactive: refresh trigger
    doc_refresh <- reactiveVal(0)

    # Document list
    output$document_list <- renderUI({
      doc_refresh()
      nb_id <- notebook_id()
      req(nb_id)

      docs <- list_documents(con, nb_id)

      if (nrow(docs) == 0) {
        return(p("No documents yet", class = "text-muted"))
      }

      lapply(seq_len(nrow(docs)), function(i) {
        doc <- docs[i, ]
        div(
          class = "d-flex justify-content-between align-items-center py-2 border-bottom",
          span(doc$filename),
          span(paste(doc$page_count, "pages"), class = "text-muted small")
        )
      })
    })

    # Handle PDF upload
    observeEvent(input$upload_pdf, {
      req(input$upload_pdf)
      nb_id <- notebook_id()
      req(nb_id)

      file <- input$upload_pdf

      # Create storage directory
      storage_dir <- file.path("storage", nb_id)
      dir.create(storage_dir, showWarnings = FALSE, recursive = TRUE)

      # Copy file to storage
      dest_path <- file.path(storage_dir, file$name)
      file.copy(file$datapath, dest_path)

      # Process PDF
      withProgress(message = "Processing PDF...", {
        incProgress(0.2, detail = "Extracting text")
        result <- process_pdf(dest_path)

        incProgress(0.4, detail = "Saving to database")
        doc_id <- create_document(
          con, nb_id, file$name, dest_path,
          result$full_text, result$page_count
        )

        incProgress(0.6, detail = "Creating chunks")
        for (i in seq_len(nrow(result$chunks))) {
          chunk <- result$chunks[i, ]
          create_chunk(con, doc_id, "document",
                       chunk$chunk_index, chunk$content,
                       page_number = chunk$page_number)
        }

        # TODO: Generate embeddings
        incProgress(1, detail = "Done!")
      })

      doc_refresh(doc_refresh() + 1)
      showNotification("PDF uploaded successfully!", type = "message")
    })

    # Render messages
    output$messages <- renderUI({
      msgs <- messages()

      if (length(msgs) == 0) {
        return(p("Ask a question about your documents...", class = "text-muted"))
      }

      lapply(msgs, function(msg) {
        class <- if (msg$role == "user") {
          "bg-primary text-white p-2 rounded mb-2 ms-auto"
        } else {
          "bg-light p-2 rounded mb-2"
        }
        div(
          class = class,
          style = if (msg$role == "user") "max-width: 80%;" else "max-width: 90%;",
          HTML(msg$content)
        )
      })
    })

    # Send message
    observeEvent(input$send, {
      req(input$user_input)

      user_msg <- input$user_input
      updateTextInput(session, "user_input", value = "")

      # Add user message
      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = user_msg)))
      messages(msgs)

      # TODO: Implement RAG query
      # For now, placeholder response
      msgs <- c(msgs, list(list(
        role = "assistant",
        content = "RAG query not yet implemented. This will search your documents and generate a response."
      )))
      messages(msgs)
    })

    # Preset buttons
    observeEvent(input$btn_summarize, {
      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = "Summarize the documents in this notebook.")))
      msgs <- c(msgs, list(list(role = "assistant", content = "Summary generation not yet implemented.")))
      messages(msgs)
    })
  })
}
```

**Step 2: Update app.R to use module**

Modify `app.R` main content section to use the module for document notebooks.

**Step 3: Test upload works**

Run app and verify PDF upload saves file and creates database records.

**Step 4: Commit**

```bash
git add R/mod_document_notebook.R
git commit -m "feat: add document notebook module with PDF upload"
```

---

## Phase 6: RAG Pipeline

### Task 6.1: Implement Vector Search

**Files:**
- Modify: `R/db.R`

**Step 1: Add vector search function**

Append to `R/db.R`:
```r
#' Search chunks by embedding similarity
#' @param con DuckDB connection
#' @param query_embedding Query vector
#' @param notebook_id Limit to specific notebook
#' @param limit Number of results
#' @return Data frame of matching chunks with similarity scores
search_chunks <- function(con, query_embedding, notebook_id = NULL, limit = 5) {
  embedding_str <- paste0("[", paste(query_embedding, collapse = ","), "]")

  # Join to get notebook context
  query <- sprintf("
    SELECT
      c.*,
      d.filename as doc_name,
      d.notebook_id
    FROM chunks c
    LEFT JOIN documents d ON c.source_id = d.id AND c.source_type = 'document'
    LEFT JOIN abstracts a ON c.source_id = a.id AND c.source_type = 'abstract'
    WHERE c.embedding IS NOT NULL
    %s
    ORDER BY array_cosine_similarity(c.embedding, %s::FLOAT[]) DESC
    LIMIT %d
  ",
  if (!is.null(notebook_id)) sprintf("AND (d.notebook_id = '%s' OR a.notebook_id = '%s')", notebook_id, notebook_id) else "",
  embedding_str,
  limit)

  dbGetQuery(con, query)
}
```

**Step 2: Commit**

```bash
git add R/db.R
git commit -m "feat: add vector similarity search for chunks"
```

---

### Task 6.2: Implement RAG Query Function

**Files:**
- Create: `R/rag.R`

**Step 1: Create RAG pipeline**

Create `R/rag.R`:
```r
#' Build RAG context from retrieved chunks
#' @param chunks Data frame of chunks
#' @return Formatted context string
build_context <- function(chunks) {
  if (nrow(chunks) == 0) return("")

  contexts <- sapply(seq_len(nrow(chunks)), function(i) {
    chunk <- chunks[i, ]
    source <- if (!is.na(chunk$doc_name)) {
      sprintf("[%s, p.%d]", chunk$doc_name, chunk$page_number)
    } else {
      "[Abstract]"
    }
    sprintf("Source %s:\n%s", source, chunk$content)
  })

  paste(contexts, collapse = "\n\n---\n\n")
}

#' Generate RAG response
#' @param con Database connection
#' @param config App config
#' @param question User question
#' @param notebook_id Notebook to query
#' @return Generated response with citations
rag_query <- function(con, config, question, notebook_id) {
  api_key <- get_setting(config, "openrouter", "api_key")
  chat_model <- get_setting(config, "defaults", "chat_model")
  embed_model <- get_setting(config, "defaults", "embedding_model")

  # Embed the question
  question_embedding <- get_embeddings(api_key, embed_model, question)[[1]]

  # Search for relevant chunks
  chunks <- search_chunks(con, question_embedding, notebook_id, limit = 5)

  if (nrow(chunks) == 0) {
    return("I couldn't find any relevant information in your documents to answer this question.")
  }

  # Build context
  context <- build_context(chunks)

  # Build prompt
  system_prompt <- "You are a helpful research assistant. Answer questions based ONLY on the provided sources. Always cite your sources using the format [Document Name, p.X]. If the sources don't contain enough information to answer, say so."

  user_prompt <- sprintf("Sources:\n%s\n\nQuestion: %s", context, question)

  messages <- format_chat_messages(system_prompt, user_prompt)

  # Generate response
  response <- chat_completion(api_key, chat_model, messages)

  response
}

#' Generate preset content (summary, key points, etc.)
#' @param con Database connection
#' @param config App config
#' @param notebook_id Notebook ID
#' @param preset_type Type of preset
#' @return Generated content
generate_preset <- function(con, config, notebook_id, preset_type) {
  presets <- list(
    summarize = "Provide a comprehensive summary of all the documents. Highlight the main themes, key findings, and important conclusions.",
    keypoints = "Extract the key points from these documents as a bulleted list. Focus on the most important facts, findings, and arguments.",
    studyguide = "Create a study guide based on these documents. Include key concepts, definitions, and potential exam questions with answers.",
    outline = "Create a structured outline of the main topics covered in these documents. Use hierarchical headings to organize the content."
  )

  prompt <- presets[[preset_type]]
  if (is.null(prompt)) stop("Unknown preset type: ", preset_type)

  # Get all chunks for the notebook (sample if too many)
  chunks <- dbGetQuery(con, "
    SELECT c.*, d.filename as doc_name
    FROM chunks c
    JOIN documents d ON c.source_id = d.id
    WHERE d.notebook_id = ?
    ORDER BY d.created_at, c.chunk_index
    LIMIT 50
  ", list(notebook_id))

  if (nrow(chunks) == 0) {
    return("No documents found in this notebook.")
  }

  context <- build_context(chunks)

  api_key <- get_setting(config, "openrouter", "api_key")
  chat_model <- get_setting(config, "defaults", "chat_model")

  system_prompt <- "You are a helpful research assistant. Generate content based on the provided sources."
  user_prompt <- sprintf("Sources:\n%s\n\nTask: %s", context, prompt)

  messages <- format_chat_messages(system_prompt, user_prompt)
  chat_completion(api_key, chat_model, messages)
}
```

**Step 2: Commit**

```bash
git add R/rag.R
git commit -m "feat: add RAG query and preset generation functions"
```

---

### Task 6.3: Add Embedding Generation on Upload

**Files:**
- Modify: `R/mod_document_notebook.R`

Update the PDF upload handler to generate embeddings after creating chunks.

**Step 1: Update upload handler**

In `mod_document_notebook.R`, replace the TODO comment with:
```r
incProgress(0.8, detail = "Generating embeddings")
api_key <- get_setting(config, "openrouter", "api_key")
embed_model <- get_setting(config, "defaults", "embedding_model")

# Get all chunks for this document
chunks <- list_chunks(con, doc_id)

# Batch embed (in groups of 10)
batch_size <- 10
for (i in seq(1, nrow(chunks), by = batch_size)) {
  batch_end <- min(i + batch_size - 1, nrow(chunks))
  batch <- chunks[i:batch_end, ]

  embeddings <- get_embeddings(api_key, embed_model, batch$content)

  for (j in seq_along(embeddings)) {
    update_chunk_embedding(con, batch$id[j], embeddings[[j]])
  }
}
```

**Step 2: Commit**

```bash
git add R/mod_document_notebook.R
git commit -m "feat: generate embeddings on PDF upload"
```

---

## Phase 7: Search Notebooks (OpenAlex Integration)

### Task 7.1: Create Search Notebook Module

**Files:**
- Create: `R/mod_search_notebook.R`

**Step 1: Create module**

Create `R/mod_search_notebook.R`:
```r
#' Search Notebook Module UI
mod_search_notebook_ui <- function(id) {
  ns <- NS(id)

  layout_columns(
    col_widths = c(4, 8),
    # Left: Paper list
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center",
        "Papers",
        actionButton(ns("refresh_search"), "Refresh", class = "btn-sm btn-outline-secondary")
      ),
      card_body(
        uiOutput(ns("paper_list")),
        hr(),
        actionButton(ns("import_selected"), "Import Selected", class = "btn-primary w-100")
      )
    ),
    # Right: Chat
    card(
      card_header("Chat with Abstracts"),
      card_body(
        class = "d-flex flex-column",
        style = "height: 500px;",
        div(
          id = ns("chat_messages"),
          class = "flex-grow-1 overflow-auto mb-3",
          uiOutput(ns("messages"))
        ),
        div(
          class = "d-flex gap-2",
          textInput(ns("user_input"), NULL, placeholder = "Ask about these papers...", width = "100%"),
          actionButton(ns("send"), "Send", class = "btn-primary")
        )
      )
    )
  )
}

#' Search Notebook Module Server
mod_search_notebook_server <- function(id, con, notebook_id, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    messages <- reactiveVal(list())
    selected_papers <- reactiveVal(character())

    # Load papers for this notebook
    output$paper_list <- renderUI({
      nb_id <- notebook_id()
      req(nb_id)

      papers <- dbGetQuery(con, "
        SELECT * FROM abstracts WHERE notebook_id = ? ORDER BY year DESC
      ", list(nb_id))

      if (nrow(papers) == 0) {
        return(p("No papers loaded yet", class = "text-muted"))
      }

      lapply(seq_len(nrow(papers)), function(i) {
        paper <- papers[i, ]
        authors <- jsonlite::fromJSON(paper$authors)
        author_str <- if (length(authors) > 2) {
          paste0(authors[1], " et al.")
        } else {
          paste(authors, collapse = ", ")
        }

        div(
          class = "border-bottom py-2",
          checkboxInput(
            ns(paste0("select_", paper$id)),
            label = NULL,
            width = "20px"
          ),
          strong(paper$title),
          br(),
          span(class = "text-muted small",
               paste(author_str, "-", paper$year, "-", paper$venue))
        )
      })
    })

    # Refresh search
    observeEvent(input$refresh_search, {
      nb_id <- notebook_id()
      req(nb_id)

      nb <- get_notebook(con, nb_id)
      req(nb$type == "search")

      withProgress(message = "Searching OpenAlex...", {
        email <- get_setting(config, "openalex", "email")
        api_key <- get_setting(config, "openalex", "api_key")

        filters <- if (!is.null(nb$search_filters)) {
          jsonlite::fromJSON(nb$search_filters)
        } else {
          list()
        }

        papers <- search_papers(
          nb$search_query,
          email,
          api_key,
          from_year = filters$from_year,
          to_year = filters$to_year
        )

        incProgress(0.5, detail = "Saving papers...")

        for (paper in papers) {
          # Insert abstract
          abstract_id <- uuid::UUIDgenerate()
          dbExecute(con, "
            INSERT INTO abstracts (id, notebook_id, paper_id, title, authors, abstract, year, venue, pdf_url)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ", list(
            abstract_id, nb_id, paper$paper_id, paper$title,
            jsonlite::toJSON(paper$authors), paper$abstract,
            paper$year, paper$venue, paper$pdf_url
          ))

          # Create chunk for abstract
          if (!is.na(paper$abstract) && nchar(paper$abstract) > 0) {
            create_chunk(con, abstract_id, "abstract", 0, paper$abstract)
          }
        }

        # TODO: Embed abstracts
      })

      showNotification(paste("Found", length(papers), "papers"), type = "message")
    })

    # Message rendering and sending similar to document notebook...
    output$messages <- renderUI({
      msgs <- messages()
      if (length(msgs) == 0) {
        return(p("Ask questions about these papers...", class = "text-muted"))
      }
      lapply(msgs, function(msg) {
        class <- if (msg$role == "user") "bg-primary text-white p-2 rounded mb-2 ms-auto" else "bg-light p-2 rounded mb-2"
        div(class = class, HTML(msg$content))
      })
    })

    observeEvent(input$send, {
      req(input$user_input)
      user_msg <- input$user_input
      updateTextInput(session, "user_input", value = "")

      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = user_msg)))
      messages(msgs)

      # TODO: Implement RAG for abstracts
      msgs <- c(msgs, list(list(role = "assistant", content = "Abstract RAG not yet implemented.")))
      messages(msgs)
    })
  })
}
```

**Step 2: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat: add search notebook module with OpenAlex integration"
```

---

## Phase 8: Settings Page

### Task 8.1: Create Settings Module

**Files:**
- Create: `R/mod_settings.R`

**Step 1: Create settings module**

Create `R/mod_settings.R`:
```r
#' Settings Module UI
mod_settings_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header("Settings"),
    card_body(
      h5("API Keys"),
      textInput(ns("openrouter_key"), "OpenRouter API Key", placeholder = "sk-or-..."),
      textInput(ns("openalex_email"), "OpenAlex Email"),

      hr(),
      h5("Models"),
      selectInput(ns("chat_model"), "Chat Model",
                  choices = c(
                    "anthropic/claude-sonnet-4" = "anthropic/claude-sonnet-4",
                    "anthropic/claude-haiku" = "anthropic/claude-3-5-haiku",
                    "openai/gpt-4o" = "openai/gpt-4o",
                    "openai/gpt-4o-mini" = "openai/gpt-4o-mini"
                  )),
      selectInput(ns("embed_model"), "Embedding Model",
                  choices = c(
                    "openai/text-embedding-3-small" = "openai/text-embedding-3-small",
                    "openai/text-embedding-3-large" = "openai/text-embedding-3-large"
                  )),

      hr(),
      h5("Advanced"),
      numericInput(ns("chunk_size"), "Chunk Size (words)", value = 500, min = 100, max = 2000),
      numericInput(ns("chunk_overlap"), "Chunk Overlap (words)", value = 50, min = 0, max = 200),

      hr(),
      actionButton(ns("save"), "Save Settings", class = "btn-primary")
    )
  )
}

#' Settings Module Server
mod_settings_server <- function(id, con, config) {
  moduleServer(id, function(input, output, session) {

    # Load current settings on init
    observe({
      # Try database first, fall back to config
      settings <- tryCatch({
        dbGetQuery(con, "SELECT * FROM settings")
      }, error = function(e) data.frame())

      # API Keys
      or_key <- get_setting(config, "openrouter", "api_key") %||% ""
      updateTextInput(session, "openrouter_key", value = or_key)

      oa_email <- get_setting(config, "openalex", "email") %||% ""
      updateTextInput(session, "openalex_email", value = oa_email)

      # Models
      chat_model <- get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"
      updateSelectInput(session, "chat_model", selected = chat_model)

      embed_model <- get_setting(config, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"
      updateSelectInput(session, "embed_model", selected = embed_model)
    })

    # Save settings
    observeEvent(input$save, {
      # Save to database
      save_setting <- function(key, value) {
        dbExecute(con, "
          INSERT INTO settings (key, value) VALUES (?, ?)
          ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value
        ", list(key, jsonlite::toJSON(value, auto_unbox = TRUE)))
      }

      save_setting("openrouter_api_key", input$openrouter_key)
      save_setting("openalex_email", input$openalex_email)
      save_setting("chat_model", input$chat_model)
      save_setting("embedding_model", input$embed_model)
      save_setting("chunk_size", input$chunk_size)
      save_setting("chunk_overlap", input$chunk_overlap)

      showNotification("Settings saved!", type = "message")
    })
  })
}
```

**Step 2: Commit**

```bash
git add R/mod_settings.R
git commit -m "feat: add settings module for API keys and model selection"
```

---

## Phase 9: Integration and Polish

### Task 9.1: Wire All Modules into app.R

Update `app.R` to properly route between modules based on notebook type and settings.

### Task 9.2: Add Error Handling

Add try-catch blocks around API calls, show user-friendly error messages.

### Task 9.3: Add Loading States

Add spinners/progress indicators for all async operations.

### Task 9.4: Theme Toggle

Add light/dark mode toggle in the header.

---

## Phase 10: Final Testing

### Task 10.1: Run All Tests

```r
testthat::test_dir("tests/testthat")
```

### Task 10.2: Manual Testing Checklist

- [ ] Create document notebook
- [ ] Upload PDF, verify text extraction
- [ ] Ask question, get cited response
- [ ] Run preset (summarize)
- [ ] Create search notebook
- [ ] Search OpenAlex, verify papers load
- [ ] Import paper to document notebook
- [ ] Change settings, verify persistence
- [ ] Test with missing API key (graceful error)

### Task 10.3: Create README

Update README with setup instructions, screenshots.

---

## Execution Notes

- **Run tests after each task** to catch regressions
- **Commit after each task** for easy rollback
- **Test API calls manually first** before integrating
- If stuck on R/Shiny specifics, check bslib docs: https://rstudio.github.io/bslib/
