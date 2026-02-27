# Phase 35: Bulk DOI Import UI - Research

**Researched:** 2026-02-26
**Domain:** R/Shiny UI module, DuckDB schema, async import with ExtendedTask
**Confidence:** HIGH

## Summary

Phase 35 adds a bulk DOI import sidebar panel to the search notebook module. Users can paste DOI lists or upload .bib files, preview the parse results (valid/invalid/duplicate counts), then trigger an async batch import via Phase 34's `batch_fetch_papers()`. The import runs in an ExtendedTask with progress modal (matching the existing citation network builder pattern), stores results in new DuckDB tables (`import_runs`, `import_run_items`), and displays categorized results with retry capability.

The codebase already has all foundational pieces: `parse_doi_list()` (Phase 33) for DOI parsing, `batch_fetch_papers()` (Phase 34) for OpenAlex batch queries, `ExtendedTask` + `mirai` for async operations, file-based interrupt/progress patterns (`R/interrupt.R`), and `create_abstract()` for persisting papers. The main work is UI construction, import orchestration logic, DB schema for import history, and .bib file parsing.

**Primary recommendation:** Add a new Shiny module `mod_bulk_import` that integrates into the search notebook as a modal-based workflow (triggered from the Papers card header). Reuse the ExtendedTask + progress modal + file-based interrupt pattern from `mod_citation_network.R` lines 360-470. Store import run history in DuckDB with two new tables. Use base R regex for .bib DOI extraction (simple pattern matching, not full BibTeX parsing).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Sidebar panel (always visible as a tab alongside other notebook panels like search)
- Supports both textarea (for pasting raw DOI lists) and .bib file upload
- .bib file upload extracts DOIs from BibTeX entries and runs them through the same batch import pipeline
- .bib entries without a DOI field are skipped and reported as "no DOI found" in results
- Preview step before import: shows categorized breakdown (N valid new, N already in notebook, N malformed with reasons, time estimate)
- Time estimate always shown in preview based on DOI count and batch size
- Warn with prominent styling at 200+ DOIs (show estimated time)
- No hard upper limit on DOIs — just warnings. User can always cancel mid-import
- No file size limit for .bib uploads, but warn at 500+ entries with time estimate
- Copy the network builder modal pattern for progress display (existing app pattern)
- Cancel button to abort mid-import — papers already fetched are kept, remaining batches skipped
- Warn before navigating away if import is running (confirmation dialog)
- Auto-refresh notebook document list when import completes — imported papers appear immediately
- Inline summary replaces the import form in the sidebar after completion
- Counts: N imported, N failed, N duplicates skipped
- Errors categorized by type: "Malformed (3)", "Not found in OpenAlex (2)", "API error (1)" — expandable to see individual DOIs per category
- "Retry failed DOIs" button re-runs only not_found and api_error DOIs
- Import history kept as collapsible log (like billing history pattern) — not reset on new import
- Each import run tagged with user-provided name + date slug (e.g., "Ozone treatment - 2026-02-26")
- Optional name field above import button; auto-generates from date if blank
- Skip duplicates silently, report count in results summary (expandable to see which DOIs)
- Duplicate detection during preview step (before API calls) — saves API calls for known duplicates
- Only check current notebook for duplicates — same paper can exist in multiple notebooks independently
- Store import runs in DuckDB: run name, date, notebook_id, total/imported/failed/skipped counts
- Also store per-DOI results: DOI string, status (success/not_found/api_error/malformed/duplicate), error reason
- Users can delete import run records (history cleanup) but imported papers stay in notebook
- Enables retry of failed DOIs from history and detailed import audit

### Claude's Discretion
- Exact sidebar layout and component sizing
- BibTeX DOI extraction implementation (regex vs parser library)
- DB schema design for import_runs and import_run_items tables
- Time estimate calculation formula (based on batch size, delay, retry assumptions)
- How the cancel button integrates with ExtendedTask + file-based interrupt flags

### Deferred Ideas (OUT OF SCOPE)
- BibTeX metadata enrichment (using .bib title/author/year when OpenAlex enrichment fails) — Phase 36
- Title-based matching for .bib entries without DOIs — Phase 36
- "Undo import" (delete run + remove imported papers) — future enhancement
- Cross-notebook duplicate awareness ("also exists in Notebook X") — future enhancement
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BULK-01 | User can paste a list of DOIs (one per line, comma-separated, or URL format) | `parse_doi_list()` from Phase 33 handles all formats; textarea UI with preview step |
| BULK-02 | User can upload a CSV/text file of DOIs | `fileInput()` reads file, `readLines()` extracts content, feeds to `parse_doi_list()` |
| BULK-04 | System batch-queries OpenAlex (50 DOIs per request) with rate limiting | `batch_fetch_papers()` from Phase 34 handles batching, retry, rate limiting |
| BULK-05 | Import runs async with progress bar showing N/total papers fetched | ExtendedTask + mirai pattern from `mod_citation_network.R`; progress file polling |
| BULK-06 | User sees import results (N imported, N failed, N duplicates skipped) | Results summary UI with expandable error categories; stored in import_run_items |
</phase_requirements>

## Standard Stack

### Core (Already in Project)
| Library | Purpose | Why Standard |
|---------|---------|--------------|
| shiny + bslib | UI framework | Project standard, all modules use this |
| DBI + duckdb | Database | Project standard for all data storage |
| httr2 | HTTP client | Used by `batch_fetch_papers()` in Phase 34 |
| mirai | Async execution | Used by ExtendedTask pattern in citation network |
| uuid | ID generation | Used by `create_abstract()` and other DB functions |
| jsonlite | JSON serialization | Used throughout for authors, keywords |

### Supporting (New for Phase 35)
| Library | Purpose | When to Use |
|---------|---------|-------------|
| base R regex | BibTeX DOI extraction | Simple `regmatches()` + `regexpr()` to find `doi = {10.xxxx/yyyy}` |

### No New Dependencies Needed
All required libraries are already in the project. BibTeX DOI extraction uses base R string functions — no external BibTeX parser needed since we only extract DOI fields, not full metadata (Phase 36 handles metadata enrichment).

## Architecture Patterns

### Recommended Module Structure
```
R/
├── mod_bulk_import.R      # New Shiny module (UI + server)
├── bulk_import.R          # Business logic (orchestration, .bib parsing)
├── db.R                   # Extended with import_runs/import_run_items schema + helpers
├── utils_doi.R            # Already exists (Phase 33) — parse_doi_list()
├── api_openalex.R         # Already exists (Phase 34) — batch_fetch_papers()
└── interrupt.R            # Already exists — reused for cancel support
```

### Pattern 1: ExtendedTask + Progress Modal (from mod_citation_network.R)
**What:** Async operation with file-based progress reporting and cancel support
**When:** Import runs that may take 10+ seconds
**Reference:** `R/mod_citation_network.R` lines 192-470

The established pattern:
1. Create interrupt flag + progress file via `create_interrupt_flag()` / `create_progress_file()`
2. Show modal with progress bar + cancel button
3. Invoke `ExtendedTask$new()` with `mirai::mirai()` inside
4. Poll progress file with `invalidateLater(1000)` observer
5. Cancel writes "interrupt" to flag file; worker checks `check_interrupt()`
6. On result: destroy poller, `removeModal()`, clean up flags

**Key adaptation for bulk import:** Progress file format needs batch_current/batch_total instead of hop/total_hops. Write a new `write_import_progress()` / `read_import_progress()` pair, or reuse with different field semantics.

### Pattern 2: Sidebar Integration
**What:** The bulk import panel lives as a tab/section within the search notebook
**Reference:** `R/mod_search_notebook.R` UI structure (lines 38-240)

The search notebook uses `layout_columns(col_widths = c(4, 8))` with the left column being the papers card. The bulk import should be accessible from the Papers card header (add an "Import DOIs" button) that opens the import workflow.

**Design choice:** Given the sidebar is already dense with sort/filter/year controls, the bulk import UI should use a **modal dialog** for the main workflow (paste/upload/preview/import) rather than trying to fit into the existing sidebar. The import history can be a collapsible section at the bottom of the Papers card. This follows the existing pattern of using modals for multi-step workflows (import to notebook, edit search).

### Pattern 3: DuckDB Migration Pattern
**What:** Adding new tables via `init_schema()` or `run_pending_migrations()`
**Reference:** `R/db.R` lines 32-140

The project uses `CREATE TABLE IF NOT EXISTS` in `init_schema()` for core tables, plus `tryCatch(ALTER TABLE ...)` blocks for column migrations. New tables should be added to `init_schema()` with `CREATE TABLE IF NOT EXISTS`.

### Anti-Patterns to Avoid
- **Don't put complex UI in the sidebar:** The sidebar is already crowded. Use a modal for the import workflow.
- **Don't hand-roll async polling:** Use the existing `interrupt.R` infrastructure.
- **Don't create a separate route/page:** Import is a feature of the search notebook, not a standalone page.
- **Don't use `shiny::Progress`:** The project uses file-based progress for cross-process compatibility with mirai.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DOI parsing | Custom parser | `parse_doi_list()` from `R/utils_doi.R` | Phase 33 handles all formats, validation, categorization |
| Batch API calls | Custom HTTP loop | `batch_fetch_papers()` from `R/api_openalex.R` | Phase 34 handles batching, retry, rate limiting, progress callbacks |
| Async execution | Custom threading | `ExtendedTask$new()` + `mirai::mirai()` | Shiny's built-in async pattern, proven in citation network |
| Progress reporting | Custom WebSocket | `write_progress()` / `read_progress()` from `R/interrupt.R` | File-based, cross-process compatible |
| Cancel support | Process killing | `signal_interrupt()` / `check_interrupt()` from `R/interrupt.R` | Graceful, partial results preserved |
| Abstract storage | Custom INSERT | `create_abstract()` from `R/db.R` | Handles all field normalization, JSON conversion |

## Common Pitfalls

### Pitfall 1: Duplicate Detection Timing
**What goes wrong:** Checking duplicates only after fetching from OpenAlex wastes API calls
**Why it happens:** Natural to validate after getting results back
**How to avoid:** Check duplicates during preview step (before import). Query `SELECT doi FROM abstracts WHERE notebook_id = ? AND doi IS NOT NULL` and compare against parsed DOIs. Remove known duplicates from the fetch list.
**Warning signs:** Import reports "50 duplicates skipped" but took full API time

### Pitfall 2: ExtendedTask DB Connection
**What goes wrong:** mirai worker can't use the main session's DuckDB connection
**Why it happens:** DuckDB connections aren't shareable across processes
**How to avoid:** The mirai worker must open its own DB connection inside the `mirai::mirai()` block, or pass results back to the main session for DB writes. The citation network pattern passes results back and handles DB writes in the main session's result observer.
**Warning signs:** "Connection is closed" errors, database lock errors

### Pitfall 3: .bib File Encoding
**What goes wrong:** Non-ASCII characters in .bib files cause encoding errors
**Why it happens:** BibTeX files from different tools use different encodings (UTF-8, Latin-1, Windows-1252)
**How to avoid:** Read with `readLines(encoding = "UTF-8")` and fall back to `readLines(encoding = "latin1")` if that fails. Since we only extract DOIs (ASCII-safe), encoding issues in other fields don't matter for Phase 35.
**Warning signs:** Garbled characters in error messages, `readLines()` warnings

### Pitfall 4: Progress File Format Mismatch
**What goes wrong:** Using the existing `write_progress()` which has BFS-specific field names (hop, total_hops, frontier_size)
**Why it happens:** Tempting to reuse directly
**How to avoid:** Write a simple import-specific progress format: `"batch_current|batch_total|found_so_far|failed_so_far|message"`. Or reuse the existing format with different semantics (hop=batch, total_hops=total_batches, paper_idx=found, frontier_size=total_dois).
**Warning signs:** Confusing progress percentages, wrong message display

### Pitfall 5: Large Import Memory
**What goes wrong:** Collecting all papers in memory before writing to DB
**Why it happens:** batch_fetch_papers() returns all results at once
**How to avoid:** Process results incrementally via the progress_callback in batch_fetch_papers(). The callback fires after each batch — use it to write papers to DB batch-by-batch rather than waiting for all batches to complete. This keeps memory flat regardless of import size.
**Warning signs:** R process memory spikes with 500+ DOI imports

### Pitfall 6: Namespace Collisions
**What goes wrong:** Module input/output IDs collide with search notebook
**Why it happens:** Bulk import module is nested inside search notebook
**How to avoid:** Use proper `ns()` namespacing. The bulk import module must use its own `NS(id)` namespace, and the parent module calls it with a unique ID like `"bulk_import"`.
**Warning signs:** Clicking import button triggers search refresh, or vice versa

## Code Examples

### BibTeX DOI Extraction (Base R)
```r
#' Extract DOIs from BibTeX file content
#' @param bib_text Character vector of lines from a .bib file
#' @return Character vector of DOI strings found
extract_dois_from_bib <- function(bib_text) {
  # Collapse to single string for multi-line doi fields
  full_text <- paste(bib_text, collapse = "\n")

  # Match doi = {value} or doi = "value" or doi = value patterns
  # BibTeX field format: doi = {10.1234/abc} or doi = "10.1234/abc"
  pattern <- "doi\\s*=\\s*[{\"]?\\s*(10\\.[^},\"\\s]+)"
  matches <- gregexpr(pattern, full_text, ignore.case = TRUE, perl = TRUE)
  raw_matches <- regmatches(full_text, matches)[[1]]

  if (length(raw_matches) == 0) return(character(0))

  # Extract just the DOI portion
  dois <- sub("doi\\s*=\\s*[{\"]?\\s*", "", raw_matches, ignore.case = TRUE, perl = TRUE)
  # Clean trailing braces/quotes
  dois <- gsub("[}\",\\s]+$", "", dois, perl = TRUE)
  trimws(dois)
}
```

### Duplicate Detection Query
```r
#' Get existing DOIs in a notebook for duplicate detection
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @return Character vector of bare DOIs already in the notebook
get_notebook_dois <- function(con, notebook_id) {
  result <- DBI::dbGetQuery(con, "
    SELECT DISTINCT doi FROM abstracts
    WHERE notebook_id = ? AND doi IS NOT NULL AND doi != ''
  ", list(notebook_id))
  tolower(result$doi)
}
```

### Import Run DB Schema
```sql
CREATE TABLE IF NOT EXISTS import_runs (
  id VARCHAR PRIMARY KEY,
  notebook_id VARCHAR NOT NULL,
  name VARCHAR NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  total_count INTEGER NOT NULL DEFAULT 0,
  imported_count INTEGER NOT NULL DEFAULT 0,
  failed_count INTEGER NOT NULL DEFAULT 0,
  skipped_count INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (notebook_id) REFERENCES notebooks(id)
);

CREATE TABLE IF NOT EXISTS import_run_items (
  id VARCHAR PRIMARY KEY,
  run_id VARCHAR NOT NULL,
  doi VARCHAR NOT NULL,
  status VARCHAR NOT NULL,  -- 'success', 'not_found', 'api_error', 'malformed', 'duplicate'
  error_reason VARCHAR,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (run_id) REFERENCES import_runs(id) ON DELETE CASCADE
);
```

### Time Estimate Formula
```r
#' Estimate import time based on DOI count
#' @param doi_count Number of DOIs to fetch (after deduplication)
#' @param batch_size DOIs per batch (default 50)
#' @param delay_per_batch Seconds between batches (default 0.1)
#' @param api_time_per_batch Estimated API response time (default 1.5 seconds)
#' @return Formatted time string
estimate_import_time <- function(doi_count, batch_size = 50, delay_per_batch = 0.1, api_time_per_batch = 1.5) {
  n_batches <- ceiling(doi_count / batch_size)
  total_seconds <- n_batches * (api_time_per_batch + delay_per_batch)

  if (total_seconds < 60) {
    paste0("~", ceiling(total_seconds), " seconds")
  } else {
    paste0("~", ceiling(total_seconds / 60), " minutes")
  }
}
```

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Shiny async with futures/promises | ExtendedTask + mirai (Shiny 1.8+) | Cleaner API, built-in cancellation support |
| shinyProgress for progress bars | File-based progress + custom polling | Works across process boundaries with mirai |
| Full BibTeX parsing (rbibutils/bib2df) | Regex DOI extraction only | Lighter, no new dependencies, Phase 36 handles full parsing |

## Open Questions

1. **Sidebar vs Modal for import entry point**
   - What we know: Context says "sidebar panel (always visible as a tab alongside other notebook panels like search)". The current search notebook uses `layout_columns(col_widths = c(4, 8))` without tabbed panels in the sidebar.
   - What's unclear: Whether "tab" means a literal tab within the Papers card, or a conceptual section. The sidebar is already dense.
   - Recommendation: Add an "Import DOIs" button to the Papers card header that opens a modal dialog. Keep import history as a collapsible section below the paper list. This satisfies "always accessible" while keeping the sidebar clean. The context says "sidebar panel" which we interpret as the import controls living in the left panel area, triggered by a button.

2. **Import progress: modal vs inline**
   - What we know: Context says "copy the network builder modal pattern." Network builder uses `showModal()` with progress bar + cancel button.
   - Recommendation: Use modal for progress (matches existing pattern). On completion, dismiss modal and show results summary inline in the sidebar.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `R/mod_citation_network.R` (ExtendedTask + progress modal pattern)
- Codebase analysis: `R/interrupt.R` (file-based interrupt/progress infrastructure)
- Codebase analysis: `R/utils_doi.R` (Phase 33 parse_doi_list)
- Codebase analysis: `R/api_openalex.R` (Phase 34 batch_fetch_papers)
- Codebase analysis: `R/db.R` (schema patterns, create_abstract)
- Codebase analysis: `R/mod_search_notebook.R` (UI layout, import workflow)

### Secondary (MEDIUM confidence)
- BibTeX format: DOI field is standard in modern .bib files, `doi = {value}` syntax is universal

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all libraries already in project
- Architecture: HIGH - patterns copied from existing modules
- Pitfalls: HIGH - based on actual codebase analysis, not hypothetical
- BibTeX parsing: MEDIUM - regex approach covers standard cases, edge cases may exist

**Research date:** 2026-02-26
**Valid until:** 2026-03-26 (stable, internal codebase patterns)
