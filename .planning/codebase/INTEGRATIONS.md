# External Integrations

**Analysis Date:** 2026-02-10

## APIs & External Services

**LLM & Chat:**
- **OpenRouter** - Unified API for multiple LLM providers (Claude, GPT-4, Llama, Gemini, DeepSeek, Kimi, etc.)
  - SDK/Client: `R/api_openrouter.R` - Custom httr2-based client
  - Auth: `openrouter.api_key` in config.yml or `OPENROUTER_API_KEY` env var
  - Base URL: `https://openrouter.ai/api/v1`
  - Endpoints: `/chat/completions`, `/embeddings`
  - Models supported: 20+ including claude-sonnet-4, gpt-4o, deepseek-chat, gemini-2.0-flash-001
  - Timeout: 120s for chat, 60s for embeddings

**Academic Search:**
- **OpenAlex** - Free academic paper search API (240M+ scholarly works)
  - SDK/Client: `R/api_openalex.R` - Custom httr2-based client
  - Auth: `openalex.email` in config.yml (optional) for polite pool; `OPENALEX_EMAIL` env var
  - Base URL: `https://api.openalex.org`
  - Polite pool: Email parameter (`mailto=`) for higher rate limits
  - Timeout: 30s
  - Features: Paper metadata, author info, citation counts, keywords

**Quality Data (External CSV Sources):**
- **Predatory Journals List** - Google Sheets CSV export
  - URL: Google Sheets export format
  - Used in: `R/quality_filter.R`
  - Purpose: Filter out predatory journals

- **Predatory Publishers List** - Google Sheets CSV export
  - URL: Google Sheets export format
  - Used in: `R/quality_filter.R`
  - Purpose: Exclude papers from predatory publishers

- **Retraction Watch Database** - GitLab CSV repository
  - URL: `https://gitlab.com/crossref/retraction-watch-data/-/raw/main/retraction_watch.csv`
  - Used in: `R/quality_filter.R`
  - Purpose: Flag retracted papers
  - Timeout: 60s

## Data Storage

**Databases:**
- **DuckDB 1.3.2** (local) — relational data
  - Connection: `data/notebooks.duckdb` file
  - Client: DBI + duckdb package
  - Schema: `R/db.R` - `init_schema()` function
  - Tables: `notebooks`, `documents`, `abstracts`, `chunks` (metadata only),
    `settings`, `quality_cache_meta`, `predatory_publishers`, `predatory_journals`,
    `retracted_papers`, `cost_log`, `import_runs`, `import_run_items`,
    `citation_audit_runs`, `citation_audit_results`, `blocked_journals`, `topics`,
    `schema_migrations`
  - No VSS extension required here — plain SQL only
  - Migrations: versioned SQL files in `migrations/` directory, tracked in `schema_migrations`

- **ragnar + DuckDB 1.3.2** (local) — vector search
  - One DuckDB file per notebook: `data/ragnar/<notebook_id>.duckdb`
  - Client: `ragnar` R package (tidyverse/ragnar)
  - Provides: VSS (vector similarity search) + BM25 hybrid retrieval
  - VSS extension is downloaded once by DuckDB's extension loader (handled transparently by ragnar; users never call INSTALL/LOAD manually)
  - Managed via: `R/_ragnar.R` - store creation, connection, retrieval helpers
  - See: `docs/plans/2026-03-04-database-stack-decision.md` for stack analysis

**File Storage:**
- Local filesystem only
  - Uploaded PDFs: `storage/` directory (configured in config.yml)
  - Generated slides: `output/` directory
  - No cloud storage (S3, GCS, etc.)

**Caching:**
- Quality data (predatory publishers, retraction lists) cached in DuckDB tables; refreshed on-demand via Settings
- Vector search index: per-notebook ragnar stores in `data/ragnar/`

## Authentication & Identity

**Auth Provider:**
- None - Single-user, local-first application
- No user authentication or sessions
- No OAuth, API key validation against external services

**API Authentication:**
- OpenRouter: Bearer token in HTTP Authorization header
- OpenAlex: Optional Bearer token for API key; email parameter for polite pool
- Quality data: Anonymous HTTPS downloads (no auth required)

## Monitoring & Observability

**Error Tracking:**
- None - Local logging only via R `message()` and `stop()` functions

**Logs:**
- Console output captured by Shiny runtime
- Error messages displayed in UI notifications via `showNotification()`
- Stack traces visible in R console/RStudio

## CI/CD & Deployment

**Hosting:**
- Local development: `shiny::runApp()` or `Rscript app.R`
- Cloud deployment options:
  - Posit Connect (with environment variable config)
  - shinyapps.io (with environment variable config)
  - Docker (user-implemented)

**CI Pipeline:**
- GitHub Actions workflow: `.github/workflows/gitleaks.yml` - Detects leaked secrets
- No automated tests in CI pipeline (tests run locally via `testthat::test_dir("tests/testthat")`)

## Environment Configuration

**Required env vars (cloud deployment):**
- `OPENROUTER_API_KEY` - OpenRouter API key (fallback when config.yml not available)
- `OPENALEX_EMAIL` - OpenAlex email (fallback)

**Optional env vars:**
- None additional

**Secrets location:**
- `config.yml` file (gitignored) - Contains API keys locally
- Environment variables (cloud) - For Posit Connect Cloud or shinyapps.io
- `.gitignore` excludes: `config.yml`, `*.env`, `secrets/`

## Webhooks & Callbacks

**Incoming:**
- None - No webhook support

**Outgoing:**
- None - Serapeum is read-only for external APIs (GET requests only)
- Quality data downloads are periodic/manual triggered by user in Settings
- No automatic polling or background jobs to external services

## API Usage Patterns

**OpenRouter (Chat):**
```r
# From R/api_openrouter.R
chat_completion(
  api_key = api_key,
  model = "anthropic/claude-sonnet-4",
  messages = list(
    list(role = "system", content = system_prompt),
    list(role = "user", content = user_message)
  )
)
```

**OpenRouter (Embeddings):**
```r
# From R/api_openrouter.R
get_embeddings(
  api_key = api_key,
  model = "openai/text-embedding-3-small",
  text = c("chunk1", "chunk2", "chunk3")
)
```

**OpenAlex (Paper Search):**
```r
# From R/api_openalex.R
# Endpoint: https://api.openalex.org/works
# Query params: title-and-abstract.search, type, publication_year, etc.
# Polite pool: mailto=user@email.com
```

## Connectivity Requirements

**On Application Startup:**
- No required API calls; app launches offline
- Config validation (API key check) deferred until Settings accessed

**During Use:**
- OpenRouter: Called when user sends chat message or clicks "Embed Documents"
- OpenAlex: Called when user clicks "Refresh" on search notebooks
- Quality data: Downloaded on-demand when user clicks "Download Quality Data" in Settings

**Error Handling:**
- Missing OpenRouter key: Chat disabled, clear error message in UI
- Missing OpenAlex email: Search works but with standard rate limits
- API timeouts: User-facing error notifications with retry option
- Network offline: Graceful fallback; local data remains accessible

---

*Integration audit: 2026-03-04*
