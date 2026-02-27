# Phase 36: BibTeX Import - Research

**Researched:** 2026-02-26
**Domain:** BibTeX parsing, metadata extraction, and OpenAlex enrichment
**Confidence:** HIGH

## Summary

Phase 36 enables users to upload BibTeX (.bib) files for library migration by extracting DOIs, enriching via OpenAlex batch API, and importing papers into search notebooks. The phase leverages existing Phase 35 bulk import infrastructure (async mirai workers, progress tracking, import runs) and adds BibTeX parsing capabilities to extract DOIs and metadata. The recommended approach uses the `bib2df` R package for robust parsing, extracting DOIs for OpenAlex enrichment while preserving BibTeX metadata (particularly abstracts) when OpenAlex data is incomplete.

BibTeX parsing in R is a mature domain with two primary libraries: `bib2df` (simple, tibble-based) and `RefManageR` (comprehensive bibliography management). For this phase's focused use case (extract DOIs, parse metadata fields), `bib2df` is the standard choice due to its simplicity, rOpenSci peer review, and clean tibble output that maps directly to database columns.

**Primary recommendation:** Use `bib2df::bib2df()` for parsing, extract DOIs for OpenAlex batch enrichment, merge BibTeX abstracts when OpenAlex lacks them, and reuse Phase 35's import infrastructure for async execution and progress tracking.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Metadata merge strategy:**
- OpenAlex wins when both sources have the same field (title, authors, year, etc.)
- BibTeX only fills gaps where OpenAlex has no value
- Entries WITHOUT a DOI field are skipped (not imported)
- Entries WITH a DOI but not found in OpenAlex are also skipped
- Store BibTeX abstract when OpenAlex enrichment succeeds but OpenAlex lacks an abstract; ignore other BibTeX-only fields (keywords, notes)

**Import diagnostics:**
- Reuse existing bulk import UI from Phase 35 — add "Upload .bib" option alongside paste/upload DOI lists
- Detailed breakdown in results: N entries parsed, N with DOIs, N enriched from OpenAlex, N skipped (no DOI), N skipped (not in OpenAlex), N duplicates, N imported
- Per-entry errors are collapsible — show error count as summary, expandable for details
- Staged progress indicator: "Parsing .bib file..." → "Enriching via OpenAlex (15/30)..." → "Importing..."
- Show warning for large files (e.g., "This file has X entries — import may take a while") but no hard entry/size limit

**BibTeX parsing scope:**
- Support all standard entry types (@article, @book, @inproceedings, @incollection, @phdthesis, @mastersthesis, @techreport, @misc, @unpublished, etc.)
- Strict DOI field only — only use the explicit `doi` field, don't mine URLs or notes
- Skip malformed entries gracefully — parse what's valid, report bad entries in diagnostics
- No file size or entry count limit, but warn user for larger libraries

**Citation network seeding:**
- Prepare data only — ensure imported papers have DOIs/OpenAlex IDs for future Phase 37 citation audit
- "Seed citation network" button available in BOTH import results (convenience after upload) AND library view (selective seeding later)
- Seeding is a separate user action, not automatic after import
- Tag imported papers with source = 'bibtex' to distinguish from DOI-bulk and search imports

### Claude's Discretion

- BibTeX parser library/implementation choice
- Exact field mapping from BibTeX to DB schema
- UI placement details within the existing bulk import modal
- Warning threshold for "large file" message

### Deferred Ideas (OUT OF SCOPE)

- Citation network analysis and visualization — Phase 37 (Citation Audit)
- Importing entries without DOIs using BibTeX-only metadata — could be a future enhancement
- Mining DOIs from URL/note fields — potential future improvement to capture more entries

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BULK-03 | User can upload a .bib file for DOI extraction and import | bib2df parses .bib to tibble with DOI column; Phase 35 file upload infrastructure |
| BULK-07 | .bib metadata preserved when OpenAlex enrichment fails (merge-not-replace) | User decision: OpenAlex wins, BibTeX fills gaps (specifically abstracts); requires conditional merge logic |
| BULK-08 | User can feed .bib file into citation network for seeding | Imported papers have DOIs/OpenAlex IDs; "Seed citation network" button in results/library view |

</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bib2df | 1.1.1 (CRAN) | Parse BibTeX to tibble | rOpenSci peer-reviewed, simple tibble output, handles all standard entry types |
| Phase 35 infrastructure | N/A | Async import, progress tracking | Proven pattern from bulk DOI import (mirai workers, ExtendedTask, import_runs schema) |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| RefManageR | 1.4.0 (CRAN) | Alternative BibTeX parser | If comprehensive bibliography management needed (out of scope for Phase 36) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bib2df | RefManageR | RefManageR offers comprehensive bibliography management (search, modify, export) but is overkill for simple DOI extraction. bib2df's focused scope and tibble output are better matched to this phase. |
| bib2df | Custom regex parser | Phase 35 implemented basic `extract_dois_from_bib()` regex parser. For Phase 36, bib2df provides robust handling of malformed entries, multi-line fields, and edge cases that regex struggles with. |

**Installation:**
```r
install.packages("bib2df")
```

## Architecture Patterns

### Recommended Integration Structure

```
R/
├── bulk_import.R         # Phase 35 foundation
│   ├── extract_dois_from_bib()       # Existing regex parser (Phase 35)
│   ├── parse_bibtex_metadata()       # NEW: bib2df wrapper (Phase 36)
│   ├── merge_bibtex_openalex()       # NEW: Metadata merge logic
│   └── run_bulk_import()             # Existing async orchestrator
├── mod_bulk_import.R     # Phase 35 UI module
│   └── [Add .bib tab to existing upload modal]
└── db.R
    └── create_abstract() # Existing, supports all needed fields
```

### Pattern 1: Parse BibTeX with bib2df

**What:** Use `bib2df::bib2df()` to parse .bib file content into a tibble with DOI column

**When to use:** User uploads a .bib file in the bulk import modal

**Example:**
```r
# Source: https://docs.ropensci.org/bib2df/reference/bib2df.html
library(bib2df)

parse_bibtex_metadata <- function(bib_file_path) {
  # bib2df returns tibble with columns: CATEGORY, BIBTEXKEY, AUTHOR, TITLE,
  # YEAR, JOURNAL, BOOKTITLE, ABSTRACT, DOI, etc.
  # NA for missing fields
  result <- tryCatch({
    bib2df(bib_file_path)
  }, error = function(e) {
    # Malformed file — return empty tibble
    tibble::tibble()
  })

  # Filter to entries with DOI (user decision: skip entries without DOI)
  if (nrow(result) > 0 && "DOI" %in% names(result)) {
    result <- result[!is.na(result$DOI), ]
  }

  result
}
```

**Note:** bib2df handles author lists as nested data frames when `separate_names = TRUE` (default). For storing authors in DB, collapse to JSON string using existing pattern from Phase 35 (`jsonlite::toJSON(authors)`).

### Pattern 2: Merge BibTeX and OpenAlex Metadata

**What:** Conditional merge where OpenAlex wins for all fields except when OpenAlex lacks a value

**When to use:** After OpenAlex batch fetch, before `create_abstract()` call

**Example:**
```r
merge_bibtex_openalex <- function(openalex_paper, bibtex_row) {
  # OpenAlex wins for all fields it provides
  # BibTeX fills gaps (specifically: abstract when OpenAlex has none)

  result <- openalex_paper  # Start with OpenAlex data

  # Fill abstract gap if OpenAlex lacks it but BibTeX has it
  if ((is.null(result$abstract) || is.na(result$abstract) || result$abstract == "") &&
      !is.null(bibtex_row$ABSTRACT) && !is.na(bibtex_row$ABSTRACT)) {
    result$abstract <- bibtex_row$ABSTRACT
  }

  # User decision: ignore other BibTeX-only fields (keywords, notes)

  result
}
```

### Pattern 3: Extend Phase 35 Import Flow for BibTeX

**What:** Reuse existing async import infrastructure, add BibTeX parsing stage before DOI extraction

**When to use:** User selects "Upload File" tab and chooses a .bib file

**Flow:**
```
1. User uploads .bib file
2. UI detects .bib extension (file$name ends with ".bib")
3. Parse with bib2df → tibble
4. Extract DOI column → character vector
5. Preview: N entries, N with DOIs, N without DOIs (skipped)
6. User confirms → run_bulk_import()
7. OpenAlex batch fetch (Phase 34 infrastructure)
8. Merge BibTeX metadata for abstract gaps
9. create_abstract() with source = 'bibtex' tag
10. Results modal: categorized counts + "Seed citation network" button
```

**Note:** Phase 35 already has progress tracking ("Parsing .bib file..." can be added as initial stage), import_runs schema, and ExtendedTask for async execution.

### Pattern 4: Citation Network Seeding Preparation

**What:** Ensure imported papers have DOIs and OpenAlex IDs for Phase 37 citation audit

**When to use:** All BibTeX imports (seeding is user action, not automatic)

**Implementation:**
```r
# In create_abstract() call:
create_abstract(
  con = con,
  notebook_id = notebook_id,
  paper_id = openalex_paper$paper_id,  # OpenAlex ID (required for citation audit)
  doi = openalex_paper$doi,            # DOI (required for citation audit)
  # ... other fields ...
)

# No special "source" column in abstracts table — use metadata tracking
# If source tracking needed, add to import_run_items table instead
```

**Note:** Phase 37 will query abstracts by DOI to fetch referenced_works and cited_by from OpenAlex. Phase 36 only needs to ensure these fields are populated.

### Anti-Patterns to Avoid

- **Custom regex BibTeX parser:** Phase 35's `extract_dois_from_bib()` is sufficient for DOI-only extraction, but full metadata parsing with regex fails on multi-line fields, nested braces, and malformed entries. Use bib2df for robust parsing.
- **Automatic citation network seeding:** User decision specifies seeding is a separate user action. Don't auto-trigger network analysis after import.
- **Importing entries without DOIs:** User decision: skip entries lacking DOI field. Don't attempt title+author fuzzy matching (deferred to future enhancement).
- **Mining DOIs from URL/note fields:** User decision: strict DOI field only. Don't regex search other fields (deferred to future enhancement).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BibTeX parsing | Custom regex parser | bib2df | Handles malformed entries, multi-line fields, nested braces, escape sequences, all entry types. Regex fails on real-world .bib files from Zotero/Mendeley. |
| Author name parsing | Split on "and" + manual cleanup | bib2df with separate_names=TRUE | BibTeX author format is complex (von/Jr parts, organizations, Unicode). bib2df handles all cases. |
| Large file warnings | Manual file size checks | Entry count threshold | .bib files are text (small on disk), but can have thousands of entries. Warn based on parsed entry count, not bytes. |
| Progress tracking | Custom file polling | Phase 35 infrastructure | write_import_progress() / read_import_progress() already implemented and tested. |

**Key insight:** BibTeX format is deceptively complex. Multi-line fields, nested braces, escape sequences, and Unicode handling make regex-based parsing fragile. bib2df is battle-tested with real-world .bib files from major citation managers.

## Common Pitfalls

### Pitfall 1: Assuming BibTeX Files Are Well-Formed

**What goes wrong:** Real-world .bib files from Zotero, Mendeley, EndNote have malformed entries (unclosed braces, invalid field names, encoding issues). Parser crashes or silently drops entries.

**Why it happens:** Citation managers export .bib programmatically and sometimes introduce errors (especially with Unicode, special characters, or user-edited entries).

**How to avoid:** Use bib2df which is fault-tolerant. Wrap in tryCatch to handle complete parse failures. Track "N entries parsed" vs "N entries in file" to detect silent drops.

**Warning signs:** User reports "imported 0 papers" from a .bib file with hundreds of entries. Check for parse errors in diagnostics.

### Pitfall 2: Not Tracking BibTeX-Specific Diagnostics

**What goes wrong:** User uploads .bib with 500 entries, sees "10 imported" with no explanation. Confusion and support burden.

**Why it happens:** BibTeX entries without DOIs, entries with DOIs not in OpenAlex, and malformed entries all result in skipped imports but aren't distinguished in results.

**How to avoid:** User decision specifies detailed diagnostics: "N entries parsed, N with DOIs, N enriched from OpenAlex, N skipped (no DOI), N skipped (not in OpenAlex)".

**Warning signs:** Generic "X failed" message without breakdown by failure reason.

### Pitfall 3: Case-Insensitive Field Name Handling

**What goes wrong:** BibTeX field names are case-insensitive ("DOI" = "doi" = "Doi"), but R tibble column names from bib2df are UPPERCASE. Direct access to `result$doi` returns NULL.

**Why it happens:** bib2df normalizes field names to UPPERCASE for consistency.

**How to avoid:** Always access bib2df output with UPPERCASE column names: `result$DOI`, `result$ABSTRACT`, `result$TITLE`.

**Warning signs:** `is.na(result$doi)` is always TRUE even though DOI field exists in .bib file.

### Pitfall 4: Author List Serialization

**What goes wrong:** bib2df returns author lists as nested data frames or character vectors. Storing directly in DB fails or creates unreadable JSON.

**Why it happens:** BibTeX author format is structured (FirstName LastName), and bib2df preserves this structure.

**How to avoid:** Follow Phase 35 pattern: collapse authors to JSON string using `jsonlite::toJSON()` before `create_abstract()` call. For display, parse back to list.

**Warning signs:** Database stores author field as `[[{"family":"Smith","given":"John"}]]` instead of `[{"family":"Smith","given":"John"}]`.

### Pitfall 5: Large File Memory Explosion

**What goes wrong:** User uploads .bib with 10,000 entries. bib2df loads entire file into memory. OpenAlex batch fetch creates 200+ HTTP requests. Shiny session runs out of memory or times out.

**Why it happens:** No streaming parser for BibTeX in R. Batch API requires all DOIs upfront for deduplication.

**How to avoid:** User decision: no hard limit, but warn for large files. Threshold at 200+ entries ("This file has X entries — import may take a while"). Phase 35 infrastructure already handles async execution and cancellation.

**Warning signs:** App becomes unresponsive during .bib upload or import hangs indefinitely.

## Code Examples

Verified patterns from official sources and Phase 35 implementation:

### Parse BibTeX File and Extract DOIs

```r
# Source: https://docs.ropensci.org/bib2df/reference/bib2df.html
library(bib2df)

# Parse .bib file
bib_data <- bib2df("references.bib")

# Extract DOIs (column is UPPERCASE)
dois <- bib_data$DOI[!is.na(bib_data$DOI)]

# Count diagnostics
total_entries <- nrow(bib_data)
entries_with_doi <- sum(!is.na(bib_data$DOI))
entries_without_doi <- total_entries - entries_with_doi
```

### Merge BibTeX Abstract When OpenAlex Lacks It

```r
# After OpenAlex batch_fetch_papers()
for (i in seq_along(openalex_papers)) {
  paper <- openalex_papers[[i]]

  # Find matching BibTeX entry by DOI
  bib_row <- bib_data[tolower(bib_data$DOI) == tolower(paper$doi), ]

  # Fill abstract gap
  if (nrow(bib_row) > 0 &&
      (is.null(paper$abstract) || is.na(paper$abstract) || paper$abstract == "") &&
      !is.na(bib_row$ABSTRACT[1])) {
    paper$abstract <- bib_row$ABSTRACT[1]
  }

  # Store with existing Phase 35 pattern
  create_abstract(con, notebook_id, paper$paper_id, paper$title,
                  paper$authors, paper$abstract, paper$year, paper$venue,
                  paper$pdf_url, doi = paper$doi)
}
```

### Extend Phase 35 UI for .bib Upload

```r
# In mod_bulk_import.R preview logic (observeEvent(input$preview_btn)):

# Detect .bib file
if (!is.null(input$doi_file)) {
  file <- input$doi_file
  ext <- tolower(tools::file_ext(file$name))

  if (ext == "bib") {
    # Parse with bib2df
    bib_data <- tryCatch(
      bib2df::bib2df(file$datapath),
      error = function(e) {
        showNotification("Failed to parse .bib file. Check for malformed entries.",
                         type = "error")
        return(NULL)
      }
    )

    if (is.null(bib_data)) return()

    # Extract DOIs
    dois <- bib_data$DOI[!is.na(bib_data$DOI)]
    entries_without_doi <- sum(is.na(bib_data$DOI))

    # Store metadata for later merge
    bib_metadata_store(bib_data)  # ReactiveVal to pass to import worker

    # Continue with existing Phase 35 preview flow
    parsed <- parse_doi_list(dois)
    # ... rest of preview logic ...
  }
}
```

### Add "Seed Citation Network" Button to Results Modal

```r
# In mod_bulk_import.R show_results_modal():

footer_buttons <- list(modalButton("Close"))

# Add seeding button if papers were imported
if (result$imported_count > 0) {
  footer_buttons <- c(
    list(actionButton(ns("seed_network"), "Seed Citation Network",
                      class = "btn-outline-primary", icon = icon("project-diagram"))),
    footer_buttons
  )
}

# Handler (deferred to Phase 37 — just prep UI hook)
observeEvent(input$seed_network, {
  # Phase 37: Launch citation audit on imported papers
  showNotification("Citation network seeding will be implemented in Phase 37",
                   type = "message")
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Regex DOI extraction | bib2df full parsing | Phase 36 | Enables metadata merge (abstracts), handles malformed entries gracefully |
| Synchronous imports | ExtendedTask + mirai workers | Phase 35 (v7.0) | Large .bib files (1000+ entries) import without blocking UI |
| Manual progress polling | write/read_import_progress | Phase 35 (v7.0) | Real-time progress updates during batch API calls |
| Single DOI requests | Batch API (50 DOIs/request) | Phase 34 (v7.0) | 50x fewer API calls, faster imports, lower rate limit risk |

**Deprecated/outdated:**
- `extract_dois_from_bib()` regex parser (Phase 35): Sufficient for DOI-only extraction but can't extract titles/authors/abstracts. Keep for backward compatibility, use bib2df for Phase 36 metadata needs.

## Open Questions

1. **Large file warning threshold**
   - What we know: User decision says "warn for large files" with no hard limit
   - What's unclear: Specific entry count threshold (100? 200? 500?)
   - Recommendation: Start with 200 entries (4 OpenAlex batches, ~10 seconds). User can proceed regardless. Adjust based on user feedback.

2. **Source tracking for citation network context**
   - What we know: User decision says "tag imported papers with source = 'bibtex'"
   - What's unclear: No `source` column in abstracts table. Add to schema or track in import_runs metadata?
   - Recommendation: Add `source VARCHAR` column to abstracts table via migration. Values: 'search', 'bibtex', 'doi_bulk', 'manual'. Enables filtering in Phase 37 citation audit ("only analyze BibTeX imports").

3. **Duplicate handling across import methods**
   - What we know: Phase 35 detects duplicates within a single import run
   - What's unclear: If user imports same .bib twice, how to communicate "you already imported these"?
   - Recommendation: Existing `get_notebook_dois()` handles this. Results will show "N duplicates (already in notebook)" as expected. No change needed.

## Validation Architecture

> NOTE: config.json does not specify `workflow.nyquist_validation`, but Serapeum has extensive test coverage. Including this section for completeness.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat (R standard testing framework) |
| Config file | tests/testthat.R (exists in project) |
| Quick run command | `Rscript -e 'testthat::test_file("tests/testthat/test-bulk_import.R")'` |
| Full suite command | `Rscript -e 'testthat::test_dir("tests/testthat")'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BULK-03 | Parse .bib and extract DOIs | unit | `testthat::test_file("tests/testthat/test-bulk_import.R", filter="bib2df")` | ❌ Wave 0 |
| BULK-07 | Merge BibTeX abstract when OpenAlex lacks it | unit | `testthat::test_file("tests/testthat/test-bulk_import.R", filter="merge")` | ❌ Wave 0 |
| BULK-08 | Papers have DOIs/OpenAlex IDs for seeding | integration | Manual verification (Phase 37 will validate) | ❌ Phase 37 |

### Sampling Rate

- **Per task commit:** `testthat::test_file("tests/testthat/test-bulk_import.R")` (new BibTeX tests only)
- **Per wave merge:** Full `test-bulk_import.R` suite (includes Phase 35 regression tests)
- **Phase gate:** Full testthat suite (`testthat::test_dir("tests/testthat")`)

### Wave 0 Gaps

- [ ] `tests/testthat/test-bulk_import.R` — Add tests for `parse_bibtex_metadata()` and `merge_bibtex_openalex()`
- [ ] `tests/testthat/fixtures/test.bib` — Sample .bib file with various entry types, malformed entries, entries with/without DOIs
- [ ] Install bib2df: `install.packages("bib2df")` — Phase 35 tests run without it

## Sources

### Primary (HIGH confidence)

- [bib2df CRAN Documentation](https://docs.ropensci.org/bib2df/) - Parsing .bib to tibble, field structure
- [bib2df GitHub](https://github.com/ropensci/bib2df) - rOpenSci peer-reviewed package
- [RefManageR CRAN](https://cran.r-project.org/web/packages/RefManageR/) - Alternative BibTeX parser
- [BibTeX Fields Reference](https://www.bibtex.com/e/entry-types/) - Standard field mapping (author, title, abstract, journal, year)
- Phase 35 implementation (`R/bulk_import.R`, `R/mod_bulk_import.R`) - Async import infrastructure, progress tracking, import_runs schema
- Phase 34 implementation (`R/api_openalex.R::batch_fetch_papers`) - OpenAlex batch API with rate limiting

### Secondary (MEDIUM confidence)

- [rOpenSci BibTeX Tools Roundup](https://ropensci.org/blog/2020/05/07/rmd-citations/) - Ecosystem overview (bib2df vs RefManageR tradeoffs)
- [bibtexparser (Python)](https://bibtexparser.readthedocs.io/) - Fault-tolerant parsing approach (ParsingFailedBlock pattern)
- [BibTeX Format Specification](https://www2.cs.arizona.edu/~collberg/Teaching/07.231/BibTeX/bibtex.html) - Field syntax, entry types

### Tertiary (LOW confidence)

- WebSearch: "BibTeX malformed entries error handling" - General best practices for graceful degradation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - bib2df is rOpenSci peer-reviewed, Phase 35 infrastructure is battle-tested in production
- Architecture: HIGH - Reusing proven Phase 35 patterns (ExtendedTask, mirai workers, import_runs schema)
- Pitfalls: MEDIUM - Based on bib2df documentation and general BibTeX parsing knowledge; need real-world .bib testing

**Research date:** 2026-02-26
**Valid until:** 2026-03-26 (30 days for stable domain)
