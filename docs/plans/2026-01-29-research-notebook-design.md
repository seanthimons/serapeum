# Research Notebook Tool - Design Document

> A local-first, self-hosted research tool inspired by NotebookLM

## Overview

A Shiny-based web application for managing research documents and querying them with AI. Users can upload PDFs into organized notebooks, ask questions with cited answers, and generate summaries and study materials. A separate "search notebook" feature enables discovery of papers via OpenAlex, with the ability to promote interesting finds into full document notebooks.

**Key differentiators:**
- Local-first: all data stored on your machine (DuckDB + filesystem)
- Self-hosted: clone, configure API keys, run
- Configurable models: choose your LLM and embedding providers via OpenRouter
- No user management: single-user per instance

## Tech Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Framework | R + Shiny + bslib | Leverage existing R skills, modern UI components |
| Database | DuckDB + vss extension | Embedded, portable, native vector search |
| LLM Access | OpenRouter | Single API for multiple model providers |
| Paper Search | OpenAlex API | Open, no approval process, semantic search built-in |
| PDF Extraction | pdftools | Reliable R package for PDF text extraction |

## Architecture

### Directory Structure

```
notebook/
├── app.R                 # Main Shiny app entry point
├── config.yml            # API keys, model defaults
├── R/
│   ├── mod_*.R          # Shiny modules (notebooks, chat, settings)
│   ├── api_openrouter.R # OpenRouter API functions
│   ├── api_openalex.R   # OpenAlex API functions
│   ├── db.R             # DuckDB operations
│   └── pdf.R            # PDF extraction utilities
├── data/
│   └── notebooks.duckdb # Single database file (portable)
└── storage/
    └── {notebook_id}/   # PDF files stored per notebook
```

### Data Model

```sql
-- Notebooks (both types)
notebooks (
  id            VARCHAR PRIMARY KEY,
  name          VARCHAR,
  type          VARCHAR,  -- 'document' or 'search'
  search_query  VARCHAR,  -- NULL for document notebooks
  search_filters JSON,    -- date range, etc. for search notebooks
  created_at    TIMESTAMP,
  updated_at    TIMESTAMP
)

-- Documents (PDFs in document notebooks)
documents (
  id           VARCHAR PRIMARY KEY,
  notebook_id  VARCHAR REFERENCES notebooks,
  filename     VARCHAR,
  filepath     VARCHAR,  -- path in storage/
  full_text    VARCHAR,
  page_count   INTEGER,
  created_at   TIMESTAMP
)

-- Abstracts (papers in search notebooks)
abstracts (
  id            VARCHAR PRIMARY KEY,
  notebook_id   VARCHAR REFERENCES notebooks,
  paper_id      VARCHAR,  -- OpenAlex ID
  title         VARCHAR,
  authors       JSON,
  abstract      VARCHAR,
  year          INTEGER,
  venue         VARCHAR,
  pdf_url       VARCHAR,  -- for later import
  created_at    TIMESTAMP
)

-- Chunks (text segments for RAG)
chunks (
  id           VARCHAR PRIMARY KEY,
  source_id    VARCHAR,  -- document or abstract ID
  source_type  VARCHAR,  -- 'document' or 'abstract'
  chunk_index  INTEGER,
  content      VARCHAR,
  embedding    FLOAT[],  -- vector via vss extension
  page_number  INTEGER   -- NULL for abstracts
)

-- Settings (runtime config)
settings (
  key   VARCHAR PRIMARY KEY,
  value JSON
)
```

## User Interface

### Layout

```
┌─────────────────────────────────────────────────────────┐
│  Notebook                                    Settings   │
├──────────────┬──────────────────────────────────────────┤
│              │                                          │
│  NOTEBOOKS   │   MAIN CONTENT AREA                      │
│              │                                          │
│  + New       │   (changes based on selection)           │
│              │                                          │
│  ─────────── │   - Notebook view: docs + chat           │
│  My Research │   - Settings: model config               │
│  ML Papers   │   - Search: OpenAlex query               │
│  [search]    │                                          │
│  Cancer Lit  │                                          │
│              │                                          │
└──────────────┴──────────────────────────────────────────┘
```

### Notebook Views

**Document Notebook:**
- Left panel: List of documents, upload button
- Right panel: Chat interface with preset buttons
- Presets: [Summarize] [Key Points] [Study Guide] [Outline]
- Citations displayed as [Document name, p.12]

**Search Notebook:**
- Left panel: List of papers (title, year, authors)
- Right panel: Chat interface for querying abstracts
- Action: Select papers → "Import to Notebook" button

### Design Aesthetic
- Clean, minimal interface
- bslib theming with subtle accent color
- Light/dark mode toggle

## Core Workflows

### 1. Document Upload

```
User uploads PDF
  → pdftools::pdf_text() extracts text
  → Text split into ~500 token chunks (with overlap)
  → Each chunk sent to OpenRouter embedding endpoint
  → Chunks + embeddings stored in DuckDB
  → PDF file saved to storage/{notebook_id}/
```

### 2. Chat / Q&A

```
User asks question
  → Question embedded via OpenRouter
  → Vector similarity search in DuckDB (top 5-10 chunks)
  → Retrieved chunks assembled into context
  → Prompt sent to OpenRouter chat model:
      "Answer based on these sources: {chunks}
       Question: {user_question}
       Cite sources as [Document, page X]"
  → Response streamed back to UI
```

### 3. Preset Generation

```
User clicks [Summarize]
  → Retrieves all chunks for notebook (or samples if large)
  → Sends to OpenRouter with preset prompt
  → Response displayed in chat
```

### 4. OpenAlex Search

```
User creates search notebook with query + filters
  → API call to OpenAlex /works endpoint
  → Papers parsed and stored in abstracts table
  → Each abstract embedded and stored as a chunk
  → Notebook ready for querying
```

### 5. Paper Promotion

```
User selects papers in search notebook
  → Clicks "Import to Notebook"
  → Chooses target document notebook (or creates new)
  → PDFs downloaded via pdf_url (if available)
  → Full documents processed and indexed
```

## Configuration

### config.yml

```yaml
# API Keys
openrouter:
  api_key: "sk-or-..."

openalex:
  api_key: "..."
  email: "you@example.com"

# Default Models
defaults:
  chat_model: "anthropic/claude-sonnet-4"
  embedding_model: "openai/text-embedding-3-small"

# App Settings
app:
  port: 8080
  storage_path: "storage/"
```

### In-App Settings

- API Keys: Edit without touching config file
- Model Selection: Dropdowns for chat and embedding models
- Chunk Settings: Size and overlap (advanced)
- Theme: Light/dark toggle, accent color

Config file provides baseline; UI changes stored in DuckDB and override config values.

## Error Handling

### API Failures
- OpenRouter down: Show error toast, disable chat, allow document browsing
- OpenAlex down: Show error on search, existing notebooks still queryable
- Rate limits: Queue requests with exponential backoff

### Document Processing
- PDF extraction fails: Mark as "needs OCR", show warning
- Large PDFs (100+ pages): Background processing with progress bar
- Corrupt PDFs: Reject with clear error message

### Edge Cases
- Embedding fails mid-document: Mark chunks "pending", offer retry
- Model changed: Warn user, offer "re-embed notebook" option
- DuckDB locked: "Another instance running?" error
- Disk full: Check before upload, clear message

### UI Feedback
- Async operations show spinners/progress
- Errors as dismissible toasts
- Success confirmations for key actions

## Scope

### v1 (In Scope)
- Document notebooks with PDF upload
- Search notebooks via OpenAlex
- Chat/Q&A with citations
- Preset generation (summary, key points, study guide, outline)
- Promote papers from search → document notebook
- Config file + in-app settings
- OpenRouter for LLM calls
- DuckDB with vector search
- Clean bslib UI

### Out of Scope (v1)
- Audio overviews
- Other document types (Word, web pages, markdown)
- Collaboration / multi-user
- Export features
- Chat history persistence
- OCR for scanned PDFs

### Future Considerations
- Save/export chat conversations
- Multiple embedding providers
- Batch paper import from BibTeX
- Citation graph visualization
- **Moonshot: Local OpenAlex snapshot** - Download full OpenAlex database as Parquet files, ingest into DuckDB for fully offline 240M+ paper search (see: https://docs.openalex.org/download-all-data/snapshot-data-format)

## Getting Started (for users)

```bash
# Clone the repository
git clone <repo-url>
cd notebook

# Copy and edit config
cp config.example.yml config.yml
# Add your OpenRouter and OpenAlex API keys

# Install R dependencies
Rscript -e "renv::restore()"

# Run the app
Rscript app.R
# Open http://localhost:8080
```
