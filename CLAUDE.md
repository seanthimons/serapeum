# Claude Code Instructions for Serapeum

## Git Workflow

**IMPORTANT: Always create a feature branch before making code changes.**

Before implementing any feature or fix:
1. Create a new branch: `git checkout -b feature/<feature-name>` or `git checkout -b fix/<issue-name>`
2. Make changes on the feature branch
3. Create a PR to merge back to main

Never commit directly to main.

## Project Overview

Serapeum is a local-first research assistant built with R/Shiny. It uses:
- **R + Shiny + bslib** for the web interface
- **DuckDB** for local database storage
- **OpenRouter** for LLM access (chat and embeddings)
- **OpenAlex** for academic paper search

## Key Files

- `app.R` - Main Shiny app entry point
- `R/mod_*.R` - Shiny modules (settings, document notebook, search notebook, etc.)
- `R/api_*.R` - API clients (OpenRouter, OpenAlex)
- `R/db.R` - Database operations
- `tests/testthat/` - Unit tests

## Testing

Run tests with:
```r
testthat::test_dir("tests/testthat")
```

## Design Documents

New features should have a design document in `docs/plans/` before implementation.

## Evergreen Tasks

**After completing a feature or at the end of a session, check:**

- [ ] **README.md** - Does it reflect current features and setup instructions?
- [ ] **TODO.md** - Is completed work marked done? Are new issues added?

Prompt the user: "Should I update the README to document the new features?"
