# Serapeum

[![GitHub](https://img.shields.io/badge/GitHub-seanthimons%2Fserapeum-181717?logo=github)](https://github.com/seanthimons/serapeum)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![R](https://img.shields.io/badge/R-%3E%3D%204.0-276DC3?logo=r)](https://www.r-project.org/)

A local-first, self-hosted research assistant inspired by NotebookLM. Built with R and Shiny.

*Named after the [Serapeum of Alexandria](https://en.wikipedia.org/wiki/Serapeum_of_Alexandria), the daughter library of the ancient Library of Alexandria.*

## Features

### Document Notebooks
Upload PDFs and chat with your documents using RAG (Retrieval-Augmented Generation).

- **Chat with citations** - Get answers with document name and page number references
- **One-click presets** - Summarize, Key Points, Study Guide, Outline, and more
- **Full-text search** - Vector embeddings for semantic search across documents
- **Slide generation** - Generate Quarto RevealJS presentations from your research

### Search Notebooks
Discover and curate academic papers via OpenAlex (240M+ scholarly works).

- **Smart search** - Query across titles, abstracts, or full text
- **Document type filters** - Filter by article, review, preprint, book, dissertation, dataset
- **Quality filters** - Exclude retracted papers, flag predatory journals/publishers
- **Citation filters** - Set minimum citation thresholds
- **Rich metadata display**:
  - Type badges (article, review, preprint, etc.)
  - Open Access status badges (gold, green, hybrid, bronze, closed)
  - Citation metrics (cited-by count, FWCI, reference count)
  - Paper keywords from OpenAlex
- **Import to documents** - Move curated papers to document notebooks for deeper analysis

### Slide Deck Generation
Generate presentation slides from notebook content using Quarto RevealJS.

- **Configurable options** - Length, audience level, theme selection
- **11 RevealJS themes** - moon, sky, beige, serif, and more
- **Speaker notes** - Optional auto-generated presenter notes
- **Multiple formats** - Preview in-app, download .qmd, export to HTML/PDF
- **Custom instructions** - Guide the AI on focus areas

### Settings & Configuration

- **API key validation** - Visual indicators show if keys are configured and working
- **Model selection** - Choose from budget, mid-tier, or premium chat models
- **Embedding models** - Select from OpenAI, Google, Mistral, and more
- **Quality data downloads** - Fetch predatory journal lists and retraction databases

### Local-First Architecture

- **All data stays local** - DuckDB for portable, single-file storage
- **No cloud dependencies** - Everything runs on your machine
- **Single-user** - No authentication needed
- **Portable** - Copy the database file to move your research

## Quick Start

### Prerequisites

- R (>= 4.0)
- [Quarto](https://quarto.org/docs/get-started/) (for slide generation)
- RStudio (optional but recommended)

### Installation

```bash
# Clone the repository
git clone https://github.com/seanthimons/serapeum.git
cd serapeum

# Install renv if not already installed
install.packages("renv")

# Restore dependencies
renv::restore()
```

### Configuration

1. Copy the example config:
   ```bash
   cp config.example.yml config.yml
   ```

2. Edit `config.yml` with your API keys:
   ```yaml
   openrouter:
     api_key: "your-openrouter-key"  # Get from openrouter.ai/keys

   openalex:
     email: "your@email.com"  # For polite pool access (faster rate limits)
   ```

   Or configure via the **Settings** page in the app (recommended).

### Run

```r
# From R console
shiny::runApp()

# Or from terminal
Rscript app.R
```

Open http://localhost:8080 in your browser.

## Usage

### Document Notebooks

1. Click **"New Document Notebook"**
2. Give it a name
3. Upload PDFs using the upload button
4. Wait for processing (text extraction)
5. Click **"Embed Documents"** to generate embeddings
6. Ask questions in the chat interface
7. Use preset buttons for common tasks (Summary, Key Points, etc.)
8. Generate slides with the **"Slides"** tab

### Search Notebooks

1. Click **"New Search Notebook"**
2. Enter a search query and configure filters:
   - Date range
   - Document types (article, review, preprint, etc.)
   - Open access only
   - Minimum citations
   - Exclude retracted papers
3. Click **"Refresh"** to search OpenAlex
4. Browse results - each paper shows:
   - Type badge (article, review, etc.)
   - OA status badge (gold, green, hybrid, etc.)
   - Citation metrics (cited-by, FWCI, references)
   - Keywords
5. Remove unwanted papers with the X button
6. Click **"Embed Papers"** to enable semantic search
7. Query the abstracts in chat
8. Import selected papers to a document notebook

### Settings

- **API Keys** - Configure OpenRouter and OpenAlex credentials
  - Visual indicators show validation status (green check = valid)
- **Models** - Select chat and embedding models
- **Quality Data** - Download predatory journal/publisher lists and retraction database

## Tech Stack

- **R + Shiny + bslib**: Web framework with Bootstrap 5 UI components
- **DuckDB**: Embedded analytical database for local storage
- **OpenRouter**: Unified API for multiple LLM providers (Claude, GPT-4, Llama, etc.)
- **OpenAlex**: Free, open academic paper search API
- **Quarto**: Scientific publishing system for slide generation
- **pdftools**: PDF text extraction

## Project Structure

```
serapeum/
├── app.R                 # Main Shiny app
├── config.yml            # Your config (gitignored)
├── config.example.yml    # Config template
├── CLAUDE.md             # AI assistant instructions
├── TODO.md               # Feature roadmap
├── R/
│   ├── config.R          # Config loading
│   ├── db.R              # Database operations
│   ├── api_openrouter.R  # OpenRouter client
│   ├── api_openalex.R    # OpenAlex client
│   ├── pdf.R             # PDF utilities
│   ├── rag.R             # RAG pipeline
│   ├── slides.R          # Slide generation
│   ├── quality_filter.R  # Predatory/retraction filtering
│   ├── mod_about.R       # About page
│   ├── mod_document_notebook.R
│   ├── mod_search_notebook.R
│   ├── mod_settings.R
│   └── mod_slides.R
├── docs/
│   └── plans/            # Feature design documents
├── data/
│   └── notebooks.duckdb  # Database file
├── storage/              # Uploaded PDFs
├── output/               # Generated slides
└── tests/
    └── testthat/         # Unit tests
```

## Development

### Run Tests

```r
testthat::test_dir("tests/testthat")
```

### Reset Database

Delete `data/notebooks.duckdb` to start fresh.

### Contributing

We welcome contributions! Please see:
- [CONTRIBUTING.md](CONTRIBUTING.md) for detailed contribution guidelines
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community standards
- [TODO.md](TODO.md) for the feature roadmap and open issues

## Disclaimer

**Important**: Serapeum is a research tool powered by AI language models.

- **Not an Oracle**: AI-generated responses may contain errors, hallucinations, or inaccuracies. Always verify important information from primary sources.
- **Not Professional Advice**: This tool is not a substitute for professional, medical, legal, financial, or other expert advice.
- **Makes Mistakes**: AI models can misinterpret documents, generate plausible-sounding but incorrect answers, and miss important context.
- **Research Tool Only**: Intended for exploratory research and learning. Critical decisions should be based on careful review of original sources.

## License

[MIT](LICENSE) - Copyright (c) 2024-2026 Sean Thimons

## Security

To report security vulnerabilities, please see [SECURITY.md](SECURITY.md).

## Acknowledgments

- Inspired by [NotebookLM](https://notebooklm.google.com/)
- Paper data from [OpenAlex](https://openalex.org/)
- LLM access via [OpenRouter](https://openrouter.ai/)
- Quality data from [Retraction Watch](https://retractionwatch.com/) and [Predatory Journals](https://predatoryjournals.org/)
