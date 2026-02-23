# Architecture

**Analysis Date:** 2026-02-10

## Pattern Overview

**Overall:** Modular Shiny MVC with reactive data flow

**Key Characteristics:**
- Server-driven architecture with reactive state management
- Layered separation: UI modules → Server modules → Business logic → Data persistence
- Notebook-centric data model (documents or search notebooks)
- Dual retrieval paths: RAG-based (ragnar hybrid VSS+BM25) with fallback to cosine similarity
- External integrations abstracted into dedicated API clients

## Layers

**Presentation Layer (UI Modules):**
- Purpose: Define Shiny reactive user interfaces with input/output binding
- Location: `R/mod_*.R` (5 modules)
- Contains: Shiny module functions (ns(), renderUI(), reactive inputs)
- Depends on: Server modules, config reactives
- Used by: `app.R` main server function

**Module Server Layer:**
- Purpose: Handle module-level business logic, state management, and event handling
- Location: Embedded in `R/mod_*.R` via moduleServer()
- Contains: observeEvent handlers, reactive values, event triggers
- Depends on: Database connection, config, API clients
- Used by: Main app server and nested module chains

**Application Server (Orchestration):**
- Purpose: Route between modules, manage notebook switching, handle navigation
- Location: `app.R` (server function, lines 100-551)
- Contains: Notebook lifecycle (create, select, delete), main content routing, config initialization
- Depends on: All modules, database, config
- Used by: Shiny framework

**Business Logic Layer:**
- Purpose: Text processing, RAG context building, API request formatting, data transformation
- Location: `R/pdf.R`, `R/rag.R`, `R/quality_filter.R`, `R/api_*.R`
- Contains: Pure functions for chunking, embedding, parsing, API building
- Depends on: Database layer for retrieval
- Used by: Module servers

**Data Access Layer:**
- Purpose: All database operations via DBI/DuckDB
- Location: `R/db.R` (1,030 lines)
- Contains: CRUD operations for notebooks, documents, abstracts, chunks, settings, quality cache
- Depends on: DuckDB and DBI packages
- Used by: Business logic and module servers

**Data Storage:**
- Purpose: Persistent local storage
- Location: `data/notebooks.duckdb` (DuckDB database file)
- Contains: 9 tables (notebooks, documents, abstracts, chunks, settings, quality filter caches)
- Depends on: Schema initialization in `db.R`

**Configuration Layer:**
- Purpose: Load and manage app settings from config file or environment
- Location: `R/config.R`
- Contains: Config file parsing, nested setting retrieval, null-coalescing operator
- Depends on: YAML library, environment variables
- Used by: All modules for API keys and model selection

## Data Flow

**Document Notebook Flow:**

1. User uploads PDF → `R/pdf.R` extracts text and chunks
2. Chunks stored in `chunks` table with source_id (document ID)
3. Chunks indexed in ragnar store if available
4. User asks question → `R/rag.R` retrieves chunks via ragnar or cosine similarity
5. Retrieved chunks formatted as context → OpenRouter API with OpenAlex chat model
6. Response streamed to UI and stored in message history

**Search Notebook Flow:**

1. User creates search → `app.R` calls OpenAlex API via `R/api_openalex.R`
2. Results stored in `abstracts` table with full metadata
3. User filters by keywords → keyword extraction and filtering in module
4. Quality filters applied: retraction check, predatory publisher/journal check
5. User imports selected papers → abstracts and chunks stored like documents

**State Management:**

- **Notebook refresh trigger** (`notebook_refresh` reactive in app.R): Incremented on notebook create/delete to re-render list
- **Current notebook** (`current_notebook` reactiveVal): Holds selected notebook ID, passed to modules
- **Current view** (`current_view` reactiveVal): Routes between "welcome", "notebook", "settings", "about"
- **Module messages** (local reactiveVal per module): Accumulates chat messages within session
- **Config file** (`config_file_r` reactive): Loaded once at startup, shared with all modules

## Key Abstractions

**Notebook:**
- Purpose: Container for documents (PDFs) or search results (abstracts)
- Schema: `notebooks` table with id, name, type, search_query, search_filters, excluded_paper_ids
- Pattern: Reference via UUID generated in `create_notebook()`

**Chunk:**
- Purpose: Segment of text with optional embedding for retrieval
- Schema: `chunks` table with source_id (document or abstract), source_type, content, embedding, page_number
- Pattern: Created by `chunk_text()` (simple) or `chunk_with_ragnar()` (semantic) then stored via `create_chunk()`

**RagnarStore:**
- Purpose: Hybrid VSS+BM25 vector store for semantic search
- Files: `data/serapeum.ragnar.duckdb`
- Pattern: Created via `get_ragnar_store()`, checked with `ragnar_available()`

**Quality Filter Cache:**
- Purpose: In-memory lookup tables for retracted papers, predatory journals/publishers
- Schema: 3 cache tables + 1 metadata table in database
- Pattern: Populated by `refresh_quality_cache()`, checked before displaying search results

## Entry Points

**Application Entry:**
- Location: `app.R` (lines 1-14, 553-555)
- Triggers: Running `shiny::runApp()` or sourcing app.R
- Responsibilities: Load config, initialize database, define UI, launch server

**Notebook Selection:**
- Location: `app.R` (lines 203-214)
- Triggers: User clicks notebook in sidebar
- Responsibilities: Set `current_notebook` and `current_view` to switch to notebook module

**PDF Upload:**
- Location: `R/mod_document_notebook.R` (lines 14-17)
- Triggers: File input in document notebook module
- Responsibilities: Validate file, extract text, chunk, embed, store

**Search Creation:**
- Location: `app.R` (lines 254-313)
- Triggers: User clicks "New Search Notebook" button
- Responsibilities: Build OpenAlex query, validate filters, create notebook record

## Error Handling

**Strategy:** Try-catch blocks with user-facing notifications

**Patterns:**
- API errors: `tryCatch({ req_perform(req) }, error = function(e) { stop() })` in `api_*.R`
- Database errors: Silent error handling in schema migrations (`init_schema()` lines 104-155)
- Config errors: Graceful fallback to defaults in module servers (e.g., `get_setting()` returns NULL)
- PDF parsing: Error notification in module with message to user

## Cross-Cutting Concerns

**Logging:** No formal logging framework; messages via `message()` and `showNotification()`

**Validation:**
- Config: `validate_openrouter_key()` in `R/api_openrouter.R`
- URLs: `is_safe_url()` in `R/mod_search_notebook.R`
- Settings: Implicit via model selection dropdowns in settings module

**Authentication:**
- OpenRouter: API key passed in `Authorization: Bearer` header
- OpenAlex: Email passed as `mailto` query parameter for polite pool access
- Config file: YAML file or environment variables loaded at startup

---

*Architecture analysis: 2026-02-10*
