# Technology Stack

**Analysis Date:** 2026-02-10

## Languages

**Primary:**
- R (>= 4.0) - Main application language for web framework and backend logic

**Secondary:**
- HTML/CSS - Bootstrap 5 UI components via bslib, minimal direct HTML/CSS writing
- JavaScript - Dark mode toggle and client-side interactions in `app.R`
- YAML - Configuration files (`config.yml`, `config.example.yml`)
- Quarto/Markdown - Slide generation output

## Runtime

**Environment:**
- R 4.5.1 (as per project setup instructions)

**Package Manager:**
- renv - Lockfile-based dependency management
- Manifest: `manifest.json` tracks all installed packages with versions
- No `renv.lock` committed to repo; dependencies managed through manifest.json

## Frameworks

**Core:**
- **Shiny** - Web framework for interactive R applications
- **bslib** - Bootstrap 5 styling and theming (used in `app.R`)
- **yaml** - YAML configuration parsing (`R/config.R`)

**Database:**
- **DuckDB** - Embedded analytical database for local data storage
- **DBI** - R database interface for DuckDB connections
- **connections** - RStudio connection pane integration (optional enhancement)

**HTTP & APIs:**
- **httr2** - Modern HTTP client for REST API calls (OpenRouter, OpenAlex, quality data sources)
- **jsonlite** - JSON serialization/deserialization for API responses

**PDF Processing:**
- **pdftools** - PDF text extraction and page processing

**Utilities:**
- **processx** - External process execution (for Quarto CLI)
- **ragnar** - Optional vector store for semantic chunking and hybrid search (VSS + BM25)
- **digest** - Required by ragnar for hashing

**Testing:**
- **testthat** - Unit testing framework
- Tests located in `tests/testthat/`

## Key Dependencies

**Critical:**
- DuckDB - Local data persistence; all notebooks and metadata stored here
- OpenRouter (via API, not package) - LLM access for chat and embeddings
- OpenAlex (via API, not package) - Academic paper search and metadata

**Infrastructure:**
- bslib - Theme system; primary UI styling with Bootstrap 5
- Shiny modules - Modular architecture using `mod_*.R` files in `R/`
- pdftools - PDF text extraction required for document processing
- httr2 - API communication; all external integrations use this

**Optional but Important:**
- Quarto CLI (external binary) - Required for slide generation; checked via `check_quarto_installed()` in `R/slides.R`
- ragnar (R package) - Optional for improved semantic chunking and hybrid search; gracefully falls back to word-based chunking

## Configuration

**Environment:**
- Primary: `config.yml` (gitignored, created by user from `config.example.yml`)
- Fallback: Environment variables for cloud deployment (Posit Connect Cloud, shinyapps.io)
  - `OPENROUTER_API_KEY` - OpenRouter API key
  - `OPENALEX_EMAIL` - OpenAlex polite pool email
- Loaded via `load_config()` in `R/config.R`

**Application Settings** (config.yml):
- `openrouter.api_key` - API key for LLM access
- `openalex.api_key` - Optional; email field used for polite pool
- `openalex.email` - User email for OpenAlex polite pool (improves rate limits)
- `defaults.chat_model` - Default LLM model (e.g., "anthropic/claude-sonnet-4")
- `defaults.embedding_model` - Default embedding model (e.g., "openai/text-embedding-3-small")
- `app.port` - Server port (default: 8080)
- `app.storage_path` - Directory for uploaded PDFs (default: "storage/")
- `app.chunk_size` - Words per text chunk for RAG (default: 500)
- `app.chunk_overlap` - Words overlap between chunks (default: 50)
- `app.db_path` - DuckDB file location (default: "data/notebooks.duckdb")

## Platform Requirements

**Development:**
- R >= 4.0
- Quarto (optional, for slide generation; auto-detected via `check_quarto_installed()`)
- RStudio recommended but not required
- Windows/macOS/Linux compatible

**Production:**
- Single-machine deployment only (local-first architecture)
- DuckDB file stored locally in `data/notebooks.duckdb`
- No server infrastructure required
- Can be deployed to Posit Connect Cloud or shinyapps.io (uses environment variables for config)

**External Dependencies:**
- Internet connection for OpenRouter and OpenAlex API calls
- OpenRouter API key required for LLM access
- OpenAlex is free but email recommended for polite pool access

---

*Stack analysis: 2026-02-10*
