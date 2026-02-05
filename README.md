# Serapeum

[![GitHub](https://img.shields.io/badge/GitHub-seanthimons%2Fserapeum-181717?logo=github)](https://github.com/seanthimons/serapeum)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![R](https://img.shields.io/badge/R-%3E%3D%204.0-276DC3?logo=r)](https://www.r-project.org/)

A local-first, self-hosted research assistant inspired by NotebookLM. Built with R and Shiny.

*Named after the [Serapeum of Alexandria](https://en.wikipedia.org/wiki/Serapeum_of_Alexandria), the daughter library of the ancient Library of Alexandria.*

## Features

- **Document Notebooks**: Upload PDFs and chat with your documents
  - Get answers with citations (document name and page number)
  - One-click presets: Summarize, Key Points, Study Guide, Outline
  - Full-text search via vector embeddings

- **Search Notebooks**: Discover academic papers via OpenAlex
  - Search 240M+ scholarly works
  - Query across abstracts
  - Import papers to document notebooks

- **Configurable Models**: Choose your preferred AI providers via OpenRouter
  - Claude, GPT-4, Llama, and more
  - Configurable embedding models
  - API keys stored locally

- **Local-First**: All data stays on your machine
  - DuckDB for portable storage
  - No cloud dependencies
  - Single-user, no auth needed

## Quick Start

### Prerequisites

- R (>= 4.0)
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
     email: "your@email.com"  # For polite pool access
   ```

   Or configure via the Settings page in the app.

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

1. Click "New Document Notebook"
2. Give it a name
3. Upload PDFs using the upload button
4. Wait for processing (text extraction + embedding)
5. Ask questions in the chat interface
6. Use preset buttons for common tasks

### Search Notebooks

1. Click "New Search Notebook"
2. Enter a search query and date range
3. Click "Refresh" to search OpenAlex
4. Browse results and select interesting papers
5. Query the abstracts in chat
6. Import selected papers to a document notebook

## Tech Stack

- **R + Shiny + bslib**: Web framework with modern UI components
- **DuckDB**: Embedded database with vector search (vss extension)
- **OpenRouter**: Unified API for multiple LLM providers
- **OpenAlex**: Free academic paper search API
- **pdftools**: PDF text extraction

## Project Structure

```
serapeum/
├── app.R                 # Main Shiny app
├── config.yml            # Your config (gitignored)
├── config.example.yml    # Config template
├── R/
│   ├── config.R          # Config loading
│   ├── db.R              # Database operations
│   ├── api_openrouter.R  # OpenRouter client
│   ├── api_openalex.R    # OpenAlex client
│   ├── pdf.R             # PDF utilities
│   ├── rag.R             # RAG pipeline
│   ├── mod_about.R       # About page
│   ├── mod_document_notebook.R
│   ├── mod_search_notebook.R
│   └── mod_settings.R
├── data/
│   └── notebooks.duckdb  # Database file
├── storage/              # Uploaded PDFs
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

## Disclaimer

**Important**: Serapeum is a research tool powered by AI language models.

- **Not an Oracle**: AI-generated responses may contain errors, hallucinations, or inaccuracies. Always verify important information from primary sources.
- **Not Professional Advice**: This tool is not a substitute for professional, medical, legal, financial, or other expert advice.
- **Makes Mistakes**: AI models can misinterpret documents, generate plausible-sounding but incorrect answers, and miss important context.
- **Not a Flotation Device**: Use at your own risk. The authors and contributors assume no liability for decisions made based on AI-generated content.
- **Research Tool Only**: Intended for exploratory research and learning. Critical decisions should be based on careful review of original sources.

## License

MIT

## Acknowledgments

- Inspired by [NotebookLM](https://notebooklm.google.com/)
- Paper data from [OpenAlex](https://openalex.org/)
- LLM access via [OpenRouter](https://openrouter.ai/)
