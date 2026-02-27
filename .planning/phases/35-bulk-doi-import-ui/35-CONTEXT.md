# Phase 35: Bulk DOI Import UI - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can paste DOI lists or upload .bib files for batch import into search notebooks. The sidebar panel parses input, previews results (valid/invalid/duplicate counts), fetches papers from OpenAlex via Phase 34's batch_fetch_papers(), and displays categorized results. Import runs are named, persisted in DB, and shown as collapsible history.

</domain>

<decisions>
## Implementation Decisions

### Import entry point & layout
- Sidebar panel (always visible as a tab alongside other notebook panels like search)
- Supports both textarea (for pasting raw DOI lists) and .bib file upload
- .bib file upload extracts DOIs from BibTeX entries and runs them through the same batch import pipeline
- .bib entries without a DOI field are skipped and reported as "no DOI found" in results
- Preview step before import: shows categorized breakdown (N valid new, N already in notebook, N malformed with reasons, time estimate)
- Time estimate always shown in preview based on DOI count and batch size
- Warn with prominent styling at 200+ DOIs (show estimated time)
- No hard upper limit on DOIs — just warnings. User can always cancel mid-import
- No file size limit for .bib uploads, but warn at 500+ entries with time estimate

### Progress & async feedback
- Copy the network builder modal pattern for progress display (existing app pattern)
- Cancel button to abort mid-import — papers already fetched are kept, remaining batches skipped
- Warn before navigating away if import is running (confirmation dialog)
- Auto-refresh notebook document list when import completes — imported papers appear immediately

### Results summary & error display
- Inline summary replaces the import form in the sidebar after completion
- Counts: N imported, N failed, N duplicates skipped
- Errors categorized by type: "Malformed (3)", "Not found in OpenAlex (2)", "API error (1)" — expandable to see individual DOIs per category
- "Retry failed DOIs" button re-runs only not_found and api_error DOIs
- Import history kept as collapsible log (like billing history pattern) — not reset on new import
- Each import run tagged with user-provided name + date slug (e.g., "Ozone treatment - 2026-02-26")
- Optional name field above import button; auto-generates from date if blank

### Duplicate & conflict handling
- Skip duplicates silently, report count in results summary (expandable to see which DOIs)
- Duplicate detection during preview step (before API calls) — saves API calls for known duplicates
- Only check current notebook for duplicates — same paper can exist in multiple notebooks independently

### Import run persistence
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

</decisions>

<specifics>
## Specific Ideas

- Progress display should match the existing network builder modal pattern — user is already familiar with that async feedback style
- Import history styled like billing history — collapsible log entries, most recent on top
- Each run labeled as "[User name] - [date]" for easy scanning in history

</specifics>

<deferred>
## Deferred Ideas

- BibTeX metadata enrichment (using .bib title/author/year when OpenAlex doesn't have the paper) — Phase 36
- Title-based matching for .bib entries without DOIs — Phase 36
- "Undo import" (delete run + remove imported papers) — future enhancement
- Cross-notebook duplicate awareness ("also exists in Notebook X") — future enhancement

</deferred>

---

*Phase: 35-bulk-doi-import-ui*
*Context gathered: 2026-02-26*
