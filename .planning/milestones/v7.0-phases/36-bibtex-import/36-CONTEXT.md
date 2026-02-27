# Phase 36: BibTeX Import - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can upload BibTeX (.bib) files for library migration. System extracts DOIs, enriches via OpenAlex batch API, and imports papers into the library. Entries without DOIs or without OpenAlex matches are skipped. Citation network seeding button is exposed but actual network analysis is Phase 37.

</domain>

<decisions>
## Implementation Decisions

### Metadata merge strategy
- OpenAlex wins when both sources have the same field (title, authors, year, etc.)
- BibTeX only fills gaps where OpenAlex has no value
- Entries WITHOUT a DOI field are skipped (not imported)
- Entries WITH a DOI but not found in OpenAlex are also skipped
- Store BibTeX abstract when OpenAlex enrichment succeeds but OpenAlex lacks an abstract; ignore other BibTeX-only fields (keywords, notes)

### Import diagnostics
- Reuse existing bulk import UI from Phase 35 — add "Upload .bib" option alongside paste/upload DOI lists
- Detailed breakdown in results: N entries parsed, N with DOIs, N enriched from OpenAlex, N skipped (no DOI), N skipped (not in OpenAlex), N duplicates, N imported
- Per-entry errors are collapsible — show error count as summary, expandable for details
- Staged progress indicator: "Parsing .bib file..." → "Enriching via OpenAlex (15/30)..." → "Importing..."
- Show warning for large files (e.g., "This file has X entries — import may take a while") but no hard entry/size limit

### BibTeX parsing scope
- Support all standard entry types (@article, @book, @inproceedings, @incollection, @phdthesis, @mastersthesis, @techreport, @misc, @unpublished, etc.)
- Strict DOI field only — only use the explicit `doi` field, don't mine URLs or notes
- Skip malformed entries gracefully — parse what's valid, report bad entries in diagnostics
- No file size or entry count limit, but warn user for larger libraries

### Citation network seeding
- Prepare data only — ensure imported papers have DOIs/OpenAlex IDs for future Phase 37 citation audit
- "Seed citation network" button available in BOTH import results (convenience after upload) AND library view (selective seeding later)
- Seeding is a separate user action, not automatic after import
- Tag imported papers with source = 'bibtex' to distinguish from DOI-bulk and search imports

### Claude's Discretion
- BibTeX parser library/implementation choice
- Exact field mapping from BibTeX to DB schema
- UI placement details within the existing bulk import modal
- Warning threshold for "large file" message

</decisions>

<specifics>
## Specific Ideas

- User wants both a quick-seed path (right from import results) and a selective path (from library view) for citation network seeding — supports both large and small library imports
- Warning for large files rather than hard limits — respect that some users have big reference libraries

</specifics>

<deferred>
## Deferred Ideas

- Citation network analysis and visualization — Phase 37 (Citation Audit)
- Importing entries without DOIs using BibTeX-only metadata — could be a future enhancement
- Mining DOIs from URL/note fields — potential future improvement to capture more entries

</deferred>

---

*Phase: 36-bibtex-import*
*Context gathered: 2026-02-26*
