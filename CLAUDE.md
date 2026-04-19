# Git Workflow

**IMPORTANT: Always create a feature branch or worktree (depending on impact) before making code changes.**

Before implementing any feature or fix:
1. Create the branch, name should be descriptive
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

## Shiny Reactive Safety

**`observe()` + read/write same reactiveVal = infinite loop.** Any `observe()` block that reads a `reactiveVal` AND writes to it (e.g., `counter(counter() + 1)`) will self-trigger infinitely. The read creates a dependency, the write invalidates it, the observer re-fires.

**Fix:** Wrap everything except the primary trigger in `isolate({...})`:
```r
observe({
  result <- task$result()  # only reactive trigger
  isolate({
    # All other reactive reads/writes here
    refresh(refresh() + 1)
    showNotification(...)
  })
})
```

This applies to ExtendedTask result handlers, pollers, and any `observe()` that mutates reactive state. `observeEvent()` is scoped to one trigger and doesn't have this problem.

## Testing

Run tests with:
```r
testthat::test_dir("tests/testthat")
```

## Design Documents

New features should have a design document in `docs/plans/` before implementation.

## Task Tracking

GitHub Issues + beans (`beans`) is the issue tracker. Use `beans list --ready` to find unblocked work. Issues live as markdown files in `.beans/`. Do not maintain a separate TODO.md.

## Evergreen Tasks

**After completing a feature or at the end of a session, check:**

- [ ] **README.md** - Does it reflect current features and setup instructions?

Prompt the user: "Should I update the README to document the new features?"
