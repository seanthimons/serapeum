# Coding Conventions

**Analysis Date:** 2026-02-10

## Naming Patterns

**Files:**
- Modules: `mod_<feature>.R` (e.g., `mod_settings.R`, `mod_document_notebook.R`)
- API clients: `api_<service>.R` (e.g., `api_openrouter.R`, `api_openalex.R`)
- Utilities: `<function>.R` (e.g., `config.R`, `db.R`, `pdf.R`)
- Underscore-prefixed for internal/special: `_ragnar.R`

**Functions:**
- snake_case for all function names (e.g., `create_notebook()`, `get_db_connection()`, `format_chat_messages()`)
- Module functions use naming convention: `mod_<name>_ui()` and `mod_<name>_server()`
- Helper functions group by category with clear prefixes (e.g., `parse_openalex_work()`, `list_models()`, `validate_openrouter_key()`)

**Variables:**
- snake_case for all variables (e.g., `api_key`, `document_id`, `notebook_refresh`)
- Reactive variables in Shiny: clear names ending in descriptors (e.g., `con_r`, `config_file_r`, `is_processing`, `has_api_key`)
- Constants: UPPER_SNAKE_CASE (e.g., `OPENROUTER_BASE_URL`, `OPENALEX_BASE_URL`)

**Types:**
- S4 classes are checked with `inherits()` (e.g., `expect_s4_class(con, "duckdb_connection")`)
- Custom types documented via roxygen2 comments (e.g., `#' @return duckdb_connection`)

## Code Style

**Formatting:**
- Spaces around operators: `a <- b`, `x == y`
- No trailing semicolons
- 2-space indentation (observed in all files)
- Line continuations use pipes (`|>`) and function chaining
- Strings use double quotes throughout

**Linting:**
- No formal .eslintrc or .lintr configuration detected
- Implicit style follows R conventions: spaces before `{`, consistent indentation
- Roxygen2 documentation enforced via comments

## Import Organization

**Order:**
1. Library declarations at top of file (e.g., `library(httr2)`, `library(DBI)`)
2. No relative imports; files sourced in app.R via `source()` loop
3. All dependencies declared at function level with roxygen2 `@param` tags

**Path Aliases:**
- No path aliases used
- Modules accessed via session namespace: `ns()` in Shiny modules
- File sourcing in `app.R`: `for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) { source(f) }`

## Error Handling

**Patterns:**
- `tryCatch()` with explicit error function is standard: `tryCatch({ ... }, error = function(e) { ... })`
- Errors converted to messages when recovering: `message("Note: ", e$message)`
- `stop()` with descriptive context for fatal errors: `stop("OpenRouter API error: ", e$message)`
- Validation errors use inline if statements: `if (is.null(x)) return(NULL)` or `if (!is.valid(x)) return(FALSE)`
- Silent fallbacks with message logging for optional features: `tryCatch({ result <- feature() }, error = function(e) { message("Skipped: ", e$message); NULL })`

Examples from codebase:
```r
# From api_openrouter.R - clear error context
resp <- tryCatch({
  req_perform(req)
}, error = function(e) {
  stop("OpenRouter API error: ", e$message)
})

# From db.R - graceful failure with logging
tryCatch({
  dbExecute(con, "ALTER TABLE abstracts ADD COLUMN keywords VARCHAR")
}, error = function(e) {
  # Column already exists, ignore
})

# From mod_document_notebook.R - feature check with fallback
if (!is.null(store)) {
  results <- tryCatch({
    retrieve_with_ragnar(store, query, top_k = limit * 2)
  }, error = function(e) NULL)
}
```

## Logging

**Framework:** Base R `message()` function with prefix convention

**Patterns:**
- Prefixes for context: `[db_migration]`, `[quality_cache]`
- Info logging: `message("[quality_cache] Caching ", nrow(publishers), " publishers...")`
- Error context: Include what operation failed
- Progress tracking in long operations: `message("Bulk insert completed: ", inserted, " records")`

Examples:
```r
message("[db_migration] Recreating retracted_papers table with VARCHAR date column")
message("[quality_cache] Caching ", nrow(publishers), " publishers...")
message("Ragnar store updated for document: ", file$name)
```

## Comments

**When to Comment:**
- Complex logic: Loop reconstruction in `reconstruct_abstract()`
- Non-obvious decisions: `# Column already exists, ignore` after error handling
- Section headers: `# ============================================================================`
- Inline clarifications for business logic, not obvious code

**JSDoc/TSDoc:**
- Roxygen2 tags mandatory for all public functions:
  - `#' @param name Description` for each parameter
  - `#' @return Description` for return value
  - `#' Description` at top of function
- Example from `config.R`:
  ```r
  #' Get a nested setting from config
  #' @param config Config list from load_config
  #' @param ... Path to setting (e.g., "defaults", "chat_model")
  #' @return Setting value or NULL if not found
  get_setting <- function(config, ...) { ... }
  ```

## Function Design

**Size:**
- Database functions: 1-50 lines (focused on single operations)
- API functions: 20-60 lines (request building + response handling)
- Module functions: 100-300 lines (server logic with multiple reactives)
- Utility functions: 10-30 lines

**Parameters:**
- Named parameters with defaults where applicable
- Optional params use `NULL` as default, checked with `is.null(x)`
- Multiple optional params in data-heavy functions (see `create_abstract()` with 11 parameters, all with defaults)
- Reactive parameters in Shiny: pass `reactive()` objects, call them with `()` inside function

**Return Values:**
- Explicit returns with clear types: `return(NULL)`, `return(data.frame())`, `return(id)`
- List returns for multi-value results: `list(valid = TRUE, error = NULL)`
- Data frames for tabular data from database
- Numeric vectors for embeddings (stored as comma-separated strings in DB)

## Module Design

**Exports:**
- All module functions exported (no `::` private namespacing)
- Public interface: `mod_<name>_ui()` + `mod_<name>_server()`
- Server function uses `moduleServer()` with `session$ns` for ID namespacing

Example from `mod_document_notebook.R`:
```r
#' Document Notebook Module UI
#' @param id Module ID
mod_document_notebook_ui <- function(id) {
  ns <- NS(id)
  # ... return UI
}

#' Document Notebook Module Server
mod_document_notebook_server <- function(id, con, notebook_id, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    # ... reactive logic
  })
}
```

**Barrel Files:**
- No barrel files used
- All sourcing happens in `app.R` via loop that sources all `R/*.R` files in order

**Reactive Patterns:**
- `reactiveVal()` for state: `messages <- reactiveVal(list())`
- `reactive()` for derived values: `has_api_key <- reactive({ ... })`
- `observe()` for side effects: `observe({ ... })`
- Event binding: `|> bindEvent(TRUE, once = TRUE)` for one-time setup
- Invalidation: `doc_refresh <- reactiveVal(0)` + `observeEvent(input$delete, { doc_refresh(doc_refresh() + 1) })`

## Data Type Conventions

**NULL vs NA:**
- Use `NA_character_`, `NA_integer_`, `NA_real_` for proper vector typing
- `NULL` for missing optional parameters: `if (is.null(x))`
- JSON handling: `NULL` → `NA` for DBI binding: `search_query_val <- if (is.null(search_query)) NA_character_ else search_query`

**JSON Storage:**
- Lists stored as JSON strings in database using `jsonlite::toJSON()`
- Retrieval: `jsonlite::fromJSON()` to restore objects
- Example: `excluded_paper_ids` stored as `"[]"` (JSON array string)

**Embedding Vectors:**
- Stored as comma-separated strings: `paste(embedding, collapse = ",")`
- Parsed back to numeric vector: `as.numeric(strsplit(cleaned, ",")[[1]])`
- Safety checks for corrupt data: if >10% NAs, return `NULL`

---

*Convention analysis: 2026-02-10*
