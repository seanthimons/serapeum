---
phase: 23-legacy-code-removal
plan: 01
subsystem: rag
tags: [cleanup, legacy-removal, ragnar, rlang]
dependency_graph:
  requires: [22-01, 22-02, 22-03]
  provides: [unconditional-ragnar-paths, clean-rag-codebase]
  affects: [R/_ragnar.R, R/db.R, R/rag.R, R/pdf.R, R/mod_document_notebook.R, R/mod_search_notebook.R]
tech_stack:
  added: [rlang::hash]
  patterns: [unconditional-ragnar, single-code-path]
key_files:
  modified:
    - R/_ragnar.R
    - R/db.R
    - R/rag.R
    - R/pdf.R
    - R/mod_document_notebook.R
    - R/mod_search_notebook.R
    - tests/testthat/test-ragnar.R
    - tests/testthat/test-embedding.R
    - tests/testthat/test-pdf.R
    - .planning/ROADMAP.md
decisions:
  - "rlang::hash replaces digest::digest for chunk hashing — same semantics, no separate digest dependency required"
  - "NULL guard added to file.exists(ragnar_store_path) in search_chunks_hybrid to handle calls without notebook_id"
  - "test-pdf.R cleared entirely — chunk_text() deleted, all tests were dead code"
metrics:
  duration: 7 minutes
  tasks_completed: 2
  files_modified: 10
  completed_date: 2026-02-17
---

# Phase 23 Plan 01: Legacy Code Removal Summary

**One-liner:** Single-sweep removal of all dual-codepath RAG code — ragnar_available() guards, cosine similarity, chunk_text() fallback, digest::digest(), and legacy embedding loops — leaving ragnar as the sole unconditional RAG backend.

## What Was Done

Eliminated 554 lines of legacy code across 6 production files and 3 test files. All conditional branches that checked for ragnar availability are gone; all RAG operations now go through ragnar unconditionally.

## Tasks

### Task 1: Remove all legacy code from production files and replace digest with rlang::hash

**Files:** R/_ragnar.R, R/db.R, R/rag.R, R/pdf.R, R/mod_document_notebook.R, R/mod_search_notebook.R

**Changes:**

- **R/_ragnar.R**: Deleted `ragnar_available()` function, deleted `check_ragnar_version()` (~70 lines), removed `ragnar_available()` guards from `get_ragnar_store`, `connect_ragnar_store`, `chunk_with_ragnar`, `insert_chunks_to_ragnar`, `retrieve_with_ragnar`, `build_ragnar_index`. Replaced `digest::digest()` with `rlang::hash()` in `insert_chunks_to_ragnar`.
- **R/db.R**: Deleted `update_chunk_embedding()`, `cosine_similarity()`, `parse_embedding()`, `search_chunks()` (legacy cosine-similarity search). Removed `ragnar_available()` guard from `search_chunks_hybrid()`, deleted legacy fallback block, updated docstring. Added NULL guard to `file.exists(ragnar_store_path)`.
- **R/rag.R**: Removed line 1 comment, removed `use_ragnar` parameter from `rag_query()`, deleted legacy `get_embeddings()` + `search_chunks()` fallback block, updated docstring.
- **R/pdf.R**: Removed line 1 comment, deleted `chunk_text()` function, simplified `process_pdf()` to ragnar-only with updated signature.
- **R/mod_document_notebook.R**: Removed line 1 comment, removed `ragnar_available()` guard from upload handler, deleted `ragnar_indexed` tracking variable and legacy embedding loop, removed `use_ragnar = TRUE` from `rag_query()` call.
- **R/mod_search_notebook.R**: Removed line 1 comment, removed `ragnar_available()` guard and `ragnar_indexed` tracking from embed handler, deleted legacy `get_embeddings()` loop fallback, removed `use_ragnar = TRUE` from `rag_query()` call.

**Commit:** 9d55f05

### Task 2: Clean up test files and amend ROADMAP success criteria

**Files:** tests/testthat/test-ragnar.R, tests/testthat/test-embedding.R, tests/testthat/test-pdf.R, .planning/ROADMAP.md

**Changes:**

- **test-ragnar.R**: Deleted `ragnar_available returns boolean` test, deleted `process_pdf falls back to word-based` test, removed `skip_if_not(ragnar_available(), ...)` guards from all remaining tests, removed `use_ragnar = TRUE` from process_pdf test call.
- **test-embedding.R**: Deleted `search_chunks finds abstract chunks by notebook` and `search_chunks filters abstracts by notebook` tests (both exercise deleted `search_chunks()` function).
- **test-pdf.R**: Cleared all tests — the entire file exercised only `chunk_text()` which is now deleted.
- **ROADMAP.md**: Updated Phase 23 description and success criteria to reflect digest-to-rlang::hash replacement and corrected grep targets.

**Commit:** dda453a

## Verification Results

All zero-result checks pass in R/ and tests/:
- `ragnar_available`: 0 results
- `cosine_similarity`: 0 results
- `use_ragnar`: 0 results
- `check_ragnar_version`: 0 results
- `update_chunk_embedding`: 0 results
- `parse_embedding`: 0 results
- `digest::digest`: 0 results

Exact-count checks:
- `get_embeddings` in R/: 3 lines (1 definition in api_openrouter.R + 1 comment + 1 call in _ragnar.R embed closure)
- `rlang::hash` in R/: exactly 1 result
- `search_chunks` (without `_hybrid`) in R/: 0 results

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] NULL guard missing in search_chunks_hybrid after removing ragnar_available() guard**
- **Found during:** Task 2 verification (test run)
- **Issue:** `file.exists(ragnar_store_path)` would throw "invalid 'file' argument" when both `ragnar_store_path` and `notebook_id` are NULL. Previously protected by `ragnar_available() && file.exists(...)` — removing the `ragnar_available()` guard exposed the NULL case.
- **Fix:** Changed `if (file.exists(ragnar_store_path))` to `if (!is.null(ragnar_store_path) && file.exists(ragnar_store_path))`
- **Files modified:** R/db.R
- **Commit:** dda453a (included with Task 2)

**2. [Rule 1 - Bug] test-pdf.R had 4 tests for deleted chunk_text() function**
- **Found during:** Task 2 verification (grep check on tests/)
- **Issue:** The `chunk_text` grep flagged test-pdf.R which still had 4 tests calling the now-deleted `chunk_text()` function.
- **Fix:** Cleared test-pdf.R content, left explanatory comment pointing to test-ragnar.R for process_pdf integration tests.
- **Files modified:** tests/testthat/test-pdf.R
- **Commit:** dda453a (included with Task 2)

## Self-Check: PASSED

All key files exist. Both task commits (9d55f05, dda453a) confirmed in git log.
