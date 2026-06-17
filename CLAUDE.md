# Behavioral Rules

## Think Before Coding

- State non-obvious assumptions explicitly when they affect implementation.
- If multiple interpretations are plausible, surface them instead of silently choosing one.
- If ambiguity materially affects correctness, UX, or architecture, ask before proceeding.
- Push back on approaches that are clearly more complex than necessary.

## Simplicity First

- Write the minimum code that solves the actual request.
- Do not add speculative flexibility, configurability, or abstractions that were not requested.
- Prefer direct, readable code over cleverness.
- If a simpler approach would satisfy the requirement, use it.

## Surgical Changes

- Touch only the code necessary to complete the task.
- Match the existing style and patterns unless the task explicitly requires a change.
- Do not refactor or clean up unrelated code while implementing the request.
- Remove only the unused code or imports made obsolete by your own changes.

## Goal-Driven Verification

- Translate requests into verifiable outcomes before implementing.
- For bugs, reproduce first when practical, then fix, then verify.
- For refactors, verify behavior is preserved.
- For multi-step work, keep a brief plan and pair each step with a concrete check.

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
