---
phase: 28-literature-review-table
plan: 01
subsystem: synthesis-preset
tags: [lit-review, rag, gfm-table, doi-injection, document-metadata, schema-migration]
dependency_graph:
  requires:
    - Phase 27 research question generator (generate_research_questions pattern)
    - Phase 21 document notebook RAG infrastructure
    - Migration 007 section_hint chunks column
  provides:
    - Literature Review Table synthesis preset
    - Document metadata schema (title, authors, year, doi, abstract_id)
    - Server-side DOI injection for imported papers
    - GFM table validation utility
  affects:
    - R/rag.R (3 new functions)
    - R/mod_document_notebook.R (button + handler + renderer)
    - R/mod_search_notebook.R (import carries metadata)
    - R/db.R (create_document extended)
    - app.R (CSS)
    - migrations/ (008)
tech_stack:
  added:
    - commonmark::markdown_html with gsub post-processing for scroll wrapper injection
    - jsonlite::fromJSON for author JSON parsing in label generation
    - tools::file_path_sans_ext for filename fallback labels
  patterns:
    - Dynamic token budget loop (lapply inside repeat, chunks_per_paper reduction)
    - Pipe-count GFM validation (validate_gfm_table)
    - Server-side DOI link injection (gsub fixed=TRUE after LLM call)
    - Section-aware SQL chunk retrieval with fallback distributed sampling
key_files:
  created:
    - migrations/008_add_document_metadata.sql
    - (functions added to existing files, no new R files)
  modified:
    - R/db.R (create_document extended with 5 optional metadata params)
    - R/rag.R (build_context_by_paper, validate_gfm_table, generate_lit_review_table added)
    - R/mod_document_notebook.R (Lit Review button, handler, disclaimer, HTML post-processing)
    - R/mod_search_notebook.R (import loop carries OpenAlex metadata)
    - app.R (lit-review-scroll CSS with frozen first column)
decisions:
  - "GFM pipe tables over DT widget (SYNTH-02): stays within existing message pipeline, export-compatible"
  - "Server-side DOI injection (not by LLM): LLM uses plain Author/Year labels; server replaces with markdown links after validation"
  - "No sticky column headers: dropped per CONTEXT.md — chat panel is scroll ancestor, only horizontal frozen first column implemented"
  - "20+ paper warning toast: user notification, not a hard block — LLM quality may degrade at scale"
  - "lapply INSIDE repeat loop: critical for re-querying chunks when chunks_per_paper is reduced"
  - "Plain text error message for malformed table: no retry button, simple user instruction to click again"
metrics:
  duration: "~3 minutes"
  completed: "2026-02-19"
  tasks_completed: 5
  files_modified: 5
  files_created: 1
  commits: 5
---

# Phase 28 Plan 01: Literature Review Table Summary

**One-liner:** Literature review synthesis preset generating GFM comparison matrix with server-side DOI injection, dynamic token budget, and frozen first column scroll UI.

## What Was Built

A "Lit Review" button in the document notebook preset panel that generates a structured per-paper comparison table (Author/Year | Methodology | Sample | Key Findings | Limitations) for all papers in the notebook.

Key design decisions implemented:
- **Document metadata infrastructure:** Migration 008 adds 5 nullable columns (title, authors, year, doi, abstract_id) to the documents table. Papers imported from search notebooks now carry OpenAlex metadata through.
- **Server-side DOI injection:** LLM receives plain "Smith et al. (2023)" labels in the prompt. After generation, the server replaces matching labels with `[Smith et al. (2023)](https://doi.org/10.xxx)` links using fixed string matching — no regex escaping needed.
- **GFM validation:** `validate_gfm_table()` checks pipe-count consistency across all table lines before accepting LLM output. Malformed output returns a plain text error message directing users to retry.
- **Dynamic token budget:** `lapply` is placed INSIDE the `repeat` loop so chunk re-querying actually occurs when `chunks_per_paper` is reduced (7 → 2 minimum).
- **CSS frozen first column:** `position: sticky; left: 0` with `border-collapse: separate` (required for sticky to work). No sticky headers — dropped because the chat panel is the scroll ancestor.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Schema migration and create_document() update | 2b62ab6 | migrations/008_add_document_metadata.sql, R/db.R |
| 2 | Update search notebook import with OpenAlex metadata | 766c946 | R/mod_search_notebook.R |
| 3 | Add rag.R synthesis functions | 4f1e605 | R/rag.R |
| 4 | Wire Lit Review button, handler, disclaimer, HTML | 59017c3 | R/mod_document_notebook.R |
| 5 | Add CSS for scrollable table with frozen first column | a03f6a5 | app.R |

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- migrations/008_add_document_metadata.sql: FOUND
- 28-01-SUMMARY.md: FOUND
- Commit 2b62ab6 (Task 1): FOUND
- Commit 766c946 (Task 2): FOUND
- Commit 4f1e605 (Task 3): FOUND
- Commit 59017c3 (Task 4): FOUND
- Commit a03f6a5 (Task 5): FOUND
