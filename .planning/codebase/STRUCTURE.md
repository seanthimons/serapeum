# Codebase Structure

**Analysis Date:** 2026-02-10

## Directory Layout

```
serapeum/
├── app.R                    # Main Shiny app entry point
├── R/                       # R source modules
├── tests/testthat/          # Unit tests
├── data/                    # Local DuckDB database
├── docs/plans/              # Design documents for features
├── .github/workflows/       # GitHub Actions CI/CD
├── .planning/codebase/      # Codebase analysis documents (this location)
├── config.yml              # Configuration file (API keys, model selection)
├── config.example.yml      # Example configuration template
├── CLAUDE.md               # Claude Code project instructions
├── README.md               # Project documentation
└── manifest.json           # Metadata manifest
```

## Directory Purposes

**R/ - Source Code:**
- Purpose: All R modules organized by feature/responsibility
- Contains: Shiny modules, API clients, database operations, business logic
- Key files:
  - `_ragnar.R` - Ragnar store integration (alphabetically first, sourced first)
  - `api_*.R` - External API clients (OpenRouter, OpenAlex)
  - `config.R` - Configuration loading and management
  - `db.R` - Database operations layer
  - `mod_*.R` - Shiny module UI/server pairs
  - `pdf.R` - PDF text extraction and chunking
  - `rag.R` - RAG query building and context formatting
  - `quality_filter.R` - Academic quality filtering (retractions, predatory publishers)
  - `slides.R`, `mod_slides.R` - Presentation generation (Quarto/RevealJS)

**tests/testthat/ - Test Suite:**
- Purpose: Unit tests for core functionality
- Contains: Test files matching `test-*.R` pattern
- Key tests:
  - `test-db.R` - Database CRUD and schema tests
  - `test-api-openalex.R` - OpenAlex API integration tests
  - `test-config.R` - Configuration loading tests
  - `test-pdf.R` - PDF text extraction tests
  - `test-ragnar.R` - Ragnar store integration tests
  - `test-slides.R` - Presentation generation tests

**data/ - Local Storage:**
- Purpose: Local DuckDB database file
- Contains: `notebooks.duckdb` - Single file database
- Format: DuckDB (embedded SQL database, single file, no server needed)
- Auto-created: Yes, in `get_db_connection()` if missing

**docs/plans/ - Design Documents:**
- Purpose: Feature specifications written before implementation
- Contains: Markdown files with design discussions and implementation notes
- Naming: YYYY-MM-DD prefix with feature name
- Examples:
  - `2026-01-29-research-notebook-design.md`
  - `2026-02-05-abstract-filter-and-keywords.md`
  - `2026-02-06-api-key-status-design.md`

**.planning/codebase/ - Analysis Documents:**
- Purpose: Auto-generated codebase reference documents for GSD orchestration
- Contains: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md, STACK.md, INTEGRATIONS.md
- Consumed by: GSD phase planning and execution commands

**.github/workflows/ - CI/CD:**
- Purpose: Automated testing and checks
- Contains: GitHub Actions workflow definitions
- Runs: Tests on push/PR, quality checks

## Key File Locations

**Entry Points:**
- `app.R`: Main Shiny application (18KB, 556 lines)
  - Lines 1-14: Library imports and global setup
  - Lines 16-97: UI definition
  - Lines 100-551: Server logic
  - Lines 553-555: shinyApp() call with config

**Configuration:**
- `config.yml`: User configuration (API keys, model selection)
- `config.example.yml`: Template showing required structure
- `R/config.R`: Configuration loading functions

**Core Logic:**
- `R/db.R`: Database operations (1,030 lines)
  - Connection management (lines 1-31)
  - Schema initialization with migrations (lines 33-220)
  - CRUD operations for notebooks/documents/abstracts/chunks (lines 222-591)
  - Quality cache operations (lines 810-1,030)
  - Chunk retrieval and embedding functions (lines 656-804)

- `R/rag.R`: Retrieval-augmented generation (100+ lines)
  - `build_context()`: Format retrieved chunks as context
  - `rag_query()`: Main RAG pipeline with hybrid search

- `R/pdf.R`: PDF processing (50+ lines)
  - `extract_pdf_text()`: pdftools-based text extraction
  - `chunk_text()`: Simple word-count chunking

- `R/_ragnar.R`: Semantic chunking and vector search (269 lines)
  - `ragnar_available()`: Feature detection
  - `get_ragnar_store()`: Store creation/connection
  - `chunk_with_ragnar()`: Semantic chunking via ragnar
  - `retrieve_with_ragnar()`: Hybrid VSS+BM25 retrieval

**API Clients:**
- `R/api_openrouter.R`: LLM and embedding API (206 lines)
  - `chat_completion()`: Chat API calls
  - `get_embeddings()`: Embedding generation
  - `list_models()`, `list_embedding_models()`: Model discovery
  - `validate_openrouter_key()`: API key validation

- `R/api_openalex.R`: Academic paper search (150+ lines)
  - `build_openalex_request()`: Request builder
  - `parse_openalex_work()`: Work object parsing
  - `search_papers()`: Search API calls
  - `reconstruct_abstract()`: Inverted index reconstruction

**Modules:**
- `R/mod_document_notebook.R`: PDF document chat interface
  - Upload, chunk, and chat with PDF documents
  - Integration with RAG for context-aware responses

- `R/mod_search_notebook.R`: Academic paper search and import
  - OpenAlex search, quality filtering, keyword extraction
  - Paper selection and import to notebook

- `R/mod_settings.R`: Configuration UI
  - API key input and validation
  - Model selection dropdowns

- `R/mod_about.R`: About page
- `R/mod_slides.R`: Presentation generation from chat history

**Testing:**
- `tests/testthat/test-db.R`: 13 test cases covering CRUD, schema, chunks, settings
- `tests/testthat/test-api-openalex.R`: API integration tests
- `tests/testthat/test-config.R`: Configuration loading tests
- `tests/testthat/test-pdf.R`: PDF text extraction tests
- `tests/testthat/test-ragnar.R`: Vector store tests
- `tests/testthat/test-slides.R`: Presentation generation tests

## Naming Conventions

**Files:**
- `app.R` - Main application entry point
- `R/<type>_<name>.R` - Modules and utilities:
  - `mod_<feature>.R` - Shiny module (UI + server in one file)
  - `api_<service>.R` - API client for external service
  - `<domain>.R` - Business logic (pdf, rag, quality_filter, config)
- `test-<domain>.R` - Test file for domain
- `config.yml` - Configuration file
- `2026-MM-DD-<feature>.md` - Design document with date prefix

**Directories:**
- `R/` - Source code (no subdirectories)
- `tests/testthat/` - Test files
- `data/` - Local database and cache files
- `docs/plans/` - Design/planning documents
- `output/` - Generated reports and presentations
- `.temp/` - Temporary files (PDFs, caches)
- `.planning/codebase/` - Codebase analysis documents

**Functions:**
- snake_case: `get_db_connection()`, `create_notebook()`, `chunk_text()`
- Exported functions: No underscore prefix
- Internal functions: No special prefix (use documentation to indicate scope)
- Module functions: `mod_<name>_ui()`, `mod_<name>_server()`

**Variables:**
- snake_case: `notebook_id`, `api_key`, `chat_model`
- Reactives: `-` suffix when needed for clarity, suffix `_r` for reactive wrapped values (e.g., `con_r`, `config_file_r`)
- Column names: snake_case in database and data frames

**Constants:**
- UPPER_SNAKE_CASE: `OPENROUTER_BASE_URL`, `OPENALEX_BASE_URL`

## Where to Add New Code

**New Feature:**
- Primary code: `R/<domain>.R` for business logic, `R/mod_<feature>.R` for UI/interaction
- Tests: `tests/testthat/test-<domain>.R`
- Design doc: `docs/plans/YYYY-MM-DD-<feature>.md` (before implementation)

**New Module (UI/Server):**
- Implementation: Create `R/mod_<feature>.R` with both `mod_<feature>_ui()` and `mod_<feature>_server()` functions
- Register in app: Import module in `app.R` via `source()` (automatic via loop at line 11-13), call UI/server in main server

**New API Client:**
- Implementation: Create `R/api_<service>.R` with request builder and specific operation functions
- Pattern: Use `httr2` library, follow `build_<service>_request()` pattern for headers and auth

**Utilities:**
- Shared helpers: `R/<domain>.R` (e.g., `R/rag.R`, `R/pdf.R`)
- Database ops: Always add to `R/db.R`, not scattered across modules

**Database Schema Changes:**
- Add migration: `init_schema()` in `R/db.R` with try-catch for existing columns (see lines 102-155)
- Backward compatible: Use `CREATE TABLE IF NOT EXISTS` and `ALTER TABLE... ADD COLUMN` with error suppression

## Special Directories

**data/:**
- Purpose: Local database and data files
- Generated: Yes, created automatically on first run
- Committed: No (in .gitignore)
- Contents: `notebooks.duckdb` (DuckDB database)

**.temp/:**
- Purpose: Temporary file storage (uploaded PDFs, caches)
- Generated: Yes, created on PDF upload
- Committed: No (in .gitignore)
- Structure: `.temp/pdfs/<notebook_id>/` for uploaded PDFs

**output/:**
- Purpose: Generated reports and presentations (Quarto HTML/RevealJS)
- Generated: Yes, by slides generation module
- Committed: No (in .gitignore)

**.github/workflows/:**
- Purpose: CI/CD automation
- Generated: No, manually maintained
- Files: GitHub Actions workflow YAML files

---

*Structure analysis: 2026-02-10*
