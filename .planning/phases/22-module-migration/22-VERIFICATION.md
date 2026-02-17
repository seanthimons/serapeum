---
phase: 22-module-migration
verified: 2026-02-17T21:00:00Z
status: human_needed
score: 4/4 must-haves verified
re_verification: false
human_verification:
  - test: "Upload a PDF to notebook A, send a chat message, inspect retrieved chunks"
    expected: "All retrieved chunks belong to notebook A's store (data/ragnar/{notebookA_id}.duckdb). No chunks from other notebooks appear."
    why_human: "Cannot verify actual vector retrieval results programmatically without running the app and embeddings API."
  - test: "Switch from notebook A to notebook B with embedded content; trigger a chat or synthesis"
    expected: "Retrieval automatically uses data/ragnar/{notebookB_id}.duckdb without any manual path selection."
    why_human: "Cannot verify reactive notebook_id() switch drives correct store path at runtime without running the app."
  - test: "Open a search notebook that has abstracts but no per-notebook store file"
    expected: "Migration modal appears immediately on notebook open; synthesis/send buttons are greyed out until re-index completes."
    why_human: "Cannot verify modal appearance, button visual state, or modal easyClose=FALSE behavior without a browser session."
  - test: "Click Re-index Now in migration modal, let it run, then click Stop mid-way"
    expected: "Progress bar animates with per-paper detail (e.g. 'Embedding 3 of 12: Smith et al. 2023'). On cancel, modal closes, buttons remain greyed out, partial store is deleted."
    why_human: "Cannot verify async ExtendedTask + mirai coordination, progress file polling, or interrupt signal propagation without running the app."
  - test: "Embed abstracts in a search notebook and then remove one paper"
    expected: "The removed paper's chunks are deleted from the per-notebook ragnar store (data/ragnar/{id}.duckdb chunks table has no rows for that abstract)."
    why_human: "Cannot verify delete_abstract_chunks_from_ragnar actually removes rows from the live store without running the app and inspecting DuckDB contents."
  - test: "After embedding, query synthesis with a section-targeted filter (e.g. conclusions)"
    expected: "Retrieved chunks have section_hint='general' (set via encode_origin_metadata) and section_filter logic in search_chunks_hybrid correctly filters or falls back gracefully."
    why_human: "Cannot verify end-to-end section_hint encoding → retrieval → filter path without a live API call and DuckDB inspection."
---

# Phase 22: Module Migration Verification Report

**Phase Goal:** Document and search notebook modules use per-notebook ragnar stores for all RAG operations, eliminating cross-notebook pollution
**Verified:** 2026-02-17T21:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User uploads PDF to notebook A and chats with it, sees only chunks from notebook A in retrieval results | VERIFIED | `search_chunks_hybrid()` derives path via `get_notebook_ragnar_path(notebook_id)` when `ragnar_store_path=NULL`; upload handler calls `ensure_ragnar_store(nb_id, ...)` not shared store; `rag.R` callers pass `notebook_id` — all confirmed in source |
| 2 | User switches to notebook B and retrieval automatically uses notebook B's store without filtering | VERIFIED | `notebook_id()` reactive drives migration check observeEvent and path derivation in `search_chunks_hybrid`; no shared state between notebook instances |
| 3 | User embeds abstracts in search notebook and section-targeted synthesis retrieves correct chunks using encoded section_hint | VERIFIED | `encode_origin_metadata(paste0("abstract:", abs_row$id), section_hint = "general", ...)` called in embed handler; `section_filter` logic in `search_chunks_hybrid` lines 886-931 is substantive (joins chunks table for section_hint, filters, graceful degradation) |
| 4 | User can work with multiple notebooks simultaneously without cross-contamination of retrieval results | VERIFIED | Per-notebook store paths (`data/ragnar/{notebook_id}.duckdb`) are derived from `notebook_id` at call time; no shared mutable state; legacy `data/serapeum.ragnar.duckdb` deleted on app startup |

**Score:** 4/4 truths verified (automated checks)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/db.R` | `search_chunks_hybrid` with per-notebook path derivation | VERIFIED | `ragnar_store_path = NULL` default; `get_notebook_ragnar_path(notebook_id)` called when NULL; no hardcoded shared store path; parses cleanly |
| `R/_ragnar.R` | `delete_abstract_chunks_from_ragnar`, `mark_as_ragnar_indexed`, `write_reindex_progress`, `read_reindex_progress`, enhanced `rebuild_notebook_store` | VERIFIED | All four helpers exist with full implementations; `rebuild_notebook_store` has `interrupt_flag`, `progress_file`, `db_path` params with substantive loop logic; parses cleanly |
| `app.R` | Legacy shared store deletion on startup | VERIFIED | Lines 29-39: Phase 22 block deletes `data/serapeum.ragnar.duckdb` and `.wal`/`.tmp` companions on startup |
| `R/mod_document_notebook.R` | Migration prompt, `rag_ready` state, per-notebook upload, async re-index | VERIFIED | `rag_ready` reactiveVal; `ExtendedTask` + `mirai` async re-index; `reindex_notebook` handler; `cancel_reindex` with `signal_interrupt`; `read_reindex_progress` poller; `ensure_ragnar_store` in upload; `uiOutput("send_button_ui")` with disabled state; parses cleanly |
| `R/mod_search_notebook.R` | Per-notebook embed, chunk deletion on paper remove, migration prompt, async re-index | VERIFIED | `rag_ready`/`store_healthy`/`rag_available`; `reindex_search_nb` handler; `cancel_reindex` with `signal_interrupt`; `ensure_ragnar_store` in embed; `delete_abstract_chunks_from_ragnar` in delete handler; `mark_as_ragnar_indexed` after embed; `encode_origin_metadata` in chunk data.frame; `uiOutput("send_btn_ui")` and `uiOutput("conclusions_btn_ui")`; early-return guards in both send handlers; parses cleanly |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `R/db.R` `search_chunks_hybrid` | `R/_ragnar.R` `get_notebook_ragnar_path` | Call when `ragnar_store_path=NULL` | WIRED | Lines 842-843: `ragnar_store_path <- get_notebook_ragnar_path(notebook_id)` present and substantive |
| `R/rag.R` `rag_query` | `R/db.R` `search_chunks_hybrid` | Passes `notebook_id` as positional arg | WIRED | Line 86: `search_chunks_hybrid(con, question, notebook_id, limit = 5)` |
| `R/rag.R` `generate_conclusions_preset` | `R/db.R` `search_chunks_hybrid` | Passes `notebook_id =` named arg + `section_filter` | WIRED | Lines 306-339: three calls all pass `notebook_id = notebook_id` |
| `R/mod_document_notebook.R` upload handler | `R/_ragnar.R` `ensure_ragnar_store` | Called with `nb_id` | WIRED | Line 529: `ensure_ragnar_store(nb_id, session, api_key, embed_model)` |
| `R/mod_document_notebook.R` `cancel_reindex` handler | `R/_ragnar.R`/`interrupt.R` `signal_interrupt` | Called with `current_interrupt_flag()` | WIRED | Line 348: `signal_interrupt(flag)` |
| `R/mod_document_notebook.R` `reindex_task` result handler | `R/_ragnar.R` `delete_notebook_store` | Called on cancellation | WIRED | `tryCatch(delete_notebook_store(notebook_id()), ...)` on `result$partial == TRUE` |
| `R/mod_search_notebook.R` embed handler | `R/_ragnar.R` `ensure_ragnar_store` | Called with `nb_id` | WIRED | Line 1999: `ensure_ragnar_store(nb_id, session, api_key_or, embed_model)` |
| `R/mod_search_notebook.R` delete handler | `R/_ragnar.R` `delete_abstract_chunks_from_ragnar` | Called with `notebook_id()` and `paper$id` | WIRED | Line 991: `delete_abstract_chunks_from_ragnar(notebook_id(), paper$id)` |
| `R/mod_search_notebook.R` embed handler | `R/_ragnar.R` `mark_as_ragnar_indexed` | Called after embed succeeds | WIRED | Line 2034: `mark_as_ragnar_indexed(con(), paper_ids, source_type = "abstract")` |
| `R/mod_search_notebook.R` embed handler | `R/_ragnar.R` `encode_origin_metadata` | Called for each abstract chunk | WIRED | Lines 2015-2020: `encode_origin_metadata(paste0("abstract:", abs_row$id), section_hint = "general", ...)` |
| Search/doc notebook UI `uiOutput` | Server `renderUI` checking `rag_available()` | DOM replacement of send/conclusions buttons | WIRED | `uiOutput(ns("send_button_ui"))` in doc notebook UI; `uiOutput(ns("send_btn_ui"))` and `uiOutput(ns("conclusions_btn_ui"))` in search notebook UI — all matched to `renderUI` in server |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `R/_ragnar.R` | 153 | `get_ragnar_store()` still has `"data/serapeum.ragnar.duckdb"` default | Info | Legacy function kept for Phase 23 removal; not called by any migrated code path — confirmed by grep |
| `R/_ragnar.R` | 193 | `connect_ragnar_store()` still has `"data/serapeum.ragnar.duckdb"` default | Info | Same legacy function; not called by migrated paths |

No blocking anti-patterns found. The two legacy functions are intentionally preserved for Phase 23 cleanup, as noted in Plan 01.

### Human Verification Required

#### 1. Per-notebook retrieval isolation

**Test:** Upload a PDF to notebook A, send a chat message, open browser dev tools or inspect logs to see which store file is opened
**Expected:** Logs show `data/ragnar/{notebookA_id}.duckdb` being opened; no chunks from other notebooks appear in the response context
**Why human:** Vector retrieval correctness cannot be verified by static analysis; requires a live embedding model call and store read

#### 2. Notebook switch triggers correct store

**Test:** With both notebook A (documents, indexed) and notebook B (documents, indexed) existing, switch between them and send a chat in each
**Expected:** Each chat response draws context only from the respective notebook's store; no bleed-through
**Why human:** Reactive `notebook_id()` switching behavior requires a running Shiny session

#### 3. Migration modal appearance and button disabled state

**Test:** Open a search or document notebook that has content but whose `data/ragnar/{id}.duckdb` file does not exist
**Expected:** "Search Index Setup Required" modal appears immediately; send/synthesis buttons render as greyed-out with tooltip "re-index this notebook first"
**Why human:** Visual UI state, modal rendering, and `uiOutput` disabled button rendering require a browser session

#### 4. Async re-index with Stop cancellation

**Test:** Click "Re-index Now", observe progress modal, click "Stop" mid-way through a multi-document notebook
**Expected:** Progress bar animates with per-item detail (e.g. "Embedding 3 of 12: Smith et al. 2023"); on Stop: partial store is deleted, buttons remain greyed out, "Re-indexing cancelled" notification appears
**Why human:** ExtendedTask + mirai coordination, interrupt flag propagation, and progress file polling require runtime execution

#### 5. Paper removal deletes chunks from ragnar store

**Test:** In a search notebook, embed papers, then remove one paper; inspect `data/ragnar/{id}.duckdb` chunks table
**Expected:** No rows with `origin LIKE 'abstract:{removed_paper_id}%'` remain in the store
**Why human:** DuckDB DELETE verification requires opening the store file and running a query; cannot be verified from static code alone

#### 6. Section-targeted synthesis retrieval

**Test:** Run synthesis from a search notebook using a section-targeted query; check whether section filtering falls through gracefully
**Expected:** Either filtered chunks are returned (if section_hint data exists) or a graceful fallback to unfiltered results occurs (with a log message)
**Why human:** End-to-end section_hint encoding → storage → retrieval → filter path requires a live API call and database state

## Gaps Summary

No gaps found. All automated checks passed:

- All four success criteria are supported by substantive, wired code in the actual codebase
- No hardcoded shared store paths remain in module code (only legacy functions in `_ragnar.R` awaiting Phase 23 removal)
- All five key files parse cleanly without errors
- All key links are verified present and wired (not stubs)
- Git commits (9a4b4b9, 3b4d0d7, 64770d8, 4083a6d, 895ea37) exist and match the plan descriptions

Six items require human runtime verification to confirm behavioral correctness. These are inherently untestable by static analysis (vector retrieval, async coordination, visual UI state, live database inspection).

---

_Verified: 2026-02-17T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
