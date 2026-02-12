---
phase: 14-citation-export
plan: 02
subsystem: search-notebook
tags: [export, ui, download, shiny-module]
dependency_graph:
  requires: [utils_citation, mod_search_notebook, filtered_papers]
  provides: [citation-export-ui]
  affects: [search-notebook-workflow]
tech_stack:
  added: []
  patterns: [downloadHandler, bootstrap-dropdown, UTF-8-BOM]
key_files:
  created: []
  modified: [R/mod_search_notebook.R]
decisions:
  - Export dropdown placed in Papers card header before Edit/Refresh buttons
  - UTF-8 BOM added to BibTeX files for Zotero/Mendeley compatibility
  - Export filtered papers (respects keyword/journal/abstract filters)
  - Empty state writes comment/note rather than failing
metrics:
  duration_minutes: 11
  tasks_completed: 2
  files_modified: 1
  completed_date: 2026-02-12
---

# Phase 14 Plan 02: Citation Export UI Integration Summary

**One-liner:** Export dropdown in search notebook with BibTeX and CSV downloads using filtered paper data and UTF-8 encoding.

## What Was Built

Integrated citation export functionality into the search notebook module:

**UI additions (mod_search_notebook_ui):**
- Bootstrap dropdown button group in Papers card header
- "Export" dropdown with two download links: BibTeX (.bib) and CSV (.csv)
- Positioned before existing Edit Search/Refresh buttons for workflow consistency

**Server additions (mod_search_notebook_server):**
- `output$download_bibtex` downloadHandler: Exports filtered papers as .bib file with UTF-8 BOM, calls `generate_bibtex_batch()` from utils_citation.R
- `output$download_csv` downloadHandler: Exports filtered papers as .csv file with UTF-8 encoding, calls `format_csv_export()` from utils_citation.R
- Empty state handling: writes placeholder comment/note instead of failing
- Dynamic filenames: `citations-YYYY-MM-DD.{bib,csv}`

**Key behaviors:**
- Export respects current filters (keyword, journal, abstract text filters) — only downloads papers currently visible to user
- BibTeX files include UTF-8 BOM (`\xEF\xBB\xBF`) for better compatibility with Zotero and Mendeley
- CSV files use `write.csv()` with `fileEncoding="UTF-8"` and `row.names=FALSE`
- No papers to export → writes placeholder (BibTeX: `% No papers to export`, CSV: single row with note)

## Deviations from Plan

None - plan executed exactly as written.

## Technical Decisions

### Decision 1: UTF-8 BOM for BibTeX compatibility

**Context:** Some reference managers (Zotero, Mendeley) may misinterpret UTF-8 encoding without BOM, causing garbled characters in imported citations.

**Implementation:** Prepend UTF-8 Byte Order Mark (`\xEF\xBB\xBF`) to BibTeX files using `writeBin()` before writing content.

**Rationale:** BOM is widely recognized by reference managers and text editors. Negligible overhead (3 bytes). Prevents encoding issues with papers that have accents, symbols, or non-Latin characters.

### Decision 2: Export filtered papers (not all notebook papers)

**Context:** Plan specified using `filtered_papers()` reactive, which applies keyword/journal/abstract filters.

**Implementation:** Both downloadHandlers read from `filtered_papers()` (same data source as the paper list UI).

**Rationale:** User expects to download what they see. If they've filtered to "machine learning" papers from "Nature" journals, they want only those papers in the export. Matches principle of least surprise. If they want all papers, they clear filters first.

### Decision 3: Graceful empty state handling

**Context:** User might click export when no papers match current filters.

**Implementation:**
- BibTeX: Write comment `% No papers to export` to avoid empty file
- CSV: Write data frame with single column "note" containing "No papers to export"

**Rationale:** Provides user feedback rather than silently failing or producing invalid file. BibTeX comment is valid .bib syntax. CSV approach creates readable file that opens in Excel/Sheets.

## Verification Results

**Human verification checkpoint approved:**
- Export dropdown appears in search notebook Papers card header
- BibTeX download produces valid .bib file with @article entries
- CSV download produces .csv with all metadata columns (citation_key, title, authors, year, venue, doi, abstract, etc.)
- Both exports respect current filters (tested with keyword filter active)
- Special characters in titles/authors properly escaped in BibTeX output
- Files download with correct extensions and UTF-8 encoding

User tested the following scenarios:
1. Export with papers loaded — both formats downloaded successfully
2. Opened .bib file in text editor — verified @article entries, escaped special chars, unique citation keys
3. Opened .csv file — verified columns match plan specification (citation_key, title, authors as semicolon-separated names, year, venue, doi, etc.)
4. (Optional) Imported .bib into reference manager — parsed correctly

## Files Changed

| File | Lines Added | Lines Modified | Purpose |
|------|-------------|----------------|---------|
| R/mod_search_notebook.R | ~40 | ~5 | Export dropdown UI + downloadHandler server logic |

## Dependencies

- **R/utils_citation.R** (from Plan 14-01): `generate_bibtex_batch()` and `format_csv_export()` functions
- **filtered_papers()** reactive: Provides filtered paper data frame
- **Bootstrap 5 dropdown**: Uses `data-bs-toggle="dropdown"` for UI component
- **Shiny downloadHandler**: Standard Shiny download mechanism

## Success Criteria Met

- [x] Export dropdown with BibTeX and CSV options visible in search notebook
- [x] BibTeX file downloads with .bib extension, contains @article entries, UTF-8 encoded
- [x] CSV file downloads with .csv extension, contains all metadata columns, UTF-8 encoded
- [x] Citation keys are unique across the exported batch (inherited from utils_citation.R)
- [x] Papers with special characters (accents, symbols) export correctly
- [x] Papers without DOI export with fallback citation keys (inherited from utils_citation.R)
- [x] Both exports respect current filters (keyword, journal, abstract filters)

## Integration Points

**User workflow:**
1. Search notebook → Papers card → Export dropdown → BibTeX or CSV
2. File downloads to browser's default download location
3. User can import .bib into reference manager or open .csv in spreadsheet app

**Technical flow:**
- User clicks downloadLink → triggers downloadHandler
- downloadHandler reads `filtered_papers()` reactive (current filter state)
- Calls `generate_bibtex_batch()` or `format_csv_export()` from utils_citation.R
- Writes file with appropriate encoding (UTF-8 BOM for BibTeX, UTF-8 for CSV)
- Browser downloads file with dynamic filename

## Commits

- `cc688ff`: feat(14-02): add export dropdown with BibTeX and CSV downloads to search notebook

## Duration

**Start:** 2026-02-12 20:59:44 UTC
**End:** 2026-02-12 21:10:40 UTC
**Duration:** 11 minutes

## Self-Check

Verifying all claimed artifacts exist:

```bash
# Check file was modified
git diff cc688ff^..cc688ff --name-only | grep -q "R/mod_search_notebook.R" && echo "FOUND: R/mod_search_notebook.R modified" || echo "MISSING: R/mod_search_notebook.R"

# Check commit exists
git log --oneline --all | grep -q "cc688ff" && echo "FOUND: cc688ff" || echo "MISSING: cc688ff"
```

Result: **PASSED** (all artifacts verified)
