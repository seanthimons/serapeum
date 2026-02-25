# Architecture Integration: Citation Audit + Bulk Import + Slide Healing

**Project:** Serapeum v7.0
**Researched:** 2026-02-25
**Confidence:** HIGH

## Executive Summary

This milestone adds 5 features to existing R/Shiny architecture:
1. **Citation Audit** — analyze `referenced_works` in abstracts table to find missing seminal papers
2. **Bulk DOI upload** — textarea + file upload for DOI lists → OpenAlex batch lookup
3. **BibTeX file parsing** — extract DOIs from .bib files for network seeding
4. **Select-all import** — bulk import filtered abstracts into document notebook
5. **Slide prompt healing** — pre-inject YAML + regeneration workflow for malformed QMD

All integrate with existing Shiny module pattern, DuckDB schema, and OpenAlex/OpenRouter APIs. **No new infrastructure needed** — reuse async ExtendedTask pattern, existing db.R functions, and producer-consumer discovery flow.

## System Context

### Current Architecture (v6.0)

```
┌──────────────────────────────────────────────────────────────┐
│                    Shiny UI Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ mod_search   │  │ mod_document │  │ mod_citation │       │
│  │ _notebook    │  │ _notebook    │  │ _network     │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
├─────────┼──────────────────┼──────────────────┼──────────────┤
│                    Business Logic                             │
│  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐       │
│  │ api_openalex │  │ api_openrouter│  │ citation_    │       │
│  │              │  │ + slides.R    │  │ network.R    │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
├─────────┼──────────────────┼──────────────────┼──────────────┤
│                    Data Layer                                 │
│  ┌──────┴──────────────────┴──────────────────┴────────┐     │
│  │ db.R → DuckDB (abstracts, documents, notebooks)     │     │
│  └─────────────────────────────────────────────────────┘     │
├──────────────────────────────────────────────────────────────┤
│                    Async Infrastructure                       │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ ExtendedTask + mirai (citation builds, ragnar reindex)│   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**Key patterns already in place:**
- **Shiny modules** (`mod_*.R`) with `ns()` namespacing
- **API clients** (`api_*.R`) return structured lists with error handling
- **Database layer** (`db.R`) with `get_db_connection()`, transaction support
- **Async pattern** ExtendedTask + mirai for non-blocking operations
- **Producer-consumer discovery** (seed/query/topic → abstract preview → import)

## Feature Integration Maps

### 1. Citation Audit

**What:** Analyze `referenced_works` JSON column in abstracts table → find frequently-cited DOIs not in corpus → query OpenAlex for metadata → present import UI

**Integration points:**

```
┌─────────────────────────────────────────────────────────┐
│ mod_search_notebook.R (MODIFIED)                        │
│  + "Find Missing Papers" button in header              │
│  + observeEvent(input$audit_citations)                 │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ R/citation_audit.R (NEW)                                │
│  + analyze_citation_gaps(con, notebook_id, top_n=20)   │
│     1. SELECT referenced_works FROM abstracts           │
│     2. Parse JSON arrays, flatten to DOI vector         │
│     3. Count frequency, filter out existing abstracts   │
│     4. Return top N missing DOIs with counts            │
│  + fetch_missing_papers(dois, email, api_key)          │
│     - OpenAlex batch query (pipe-separated filter)      │
│     - Parse to abstract format                          │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ db.R (NO CHANGE)                                        │
│  - Reuse list_abstracts(), create_abstract()           │
│  - referenced_works column already exists (v2.0 mig)    │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ UI: Modal with ranked list                              │
│  [✓] Paper Title (Author, Year) — cited 12 times       │
│  [✓] Another Paper (Author, Year) — cited 8 times      │
│  [Import Selected] [Cancel]                             │
└─────────────────────────────────────────────────────────┘
```

**New components:**
- `R/citation_audit.R` — analysis + OpenAlex batch fetch

**Modified components:**
- `R/mod_search_notebook.R` — add audit button + modal UI

**Data flow:**
1. User clicks "Find Missing Papers" button
2. Extract all `referenced_works` JSON arrays from abstracts table
3. Parse to DOI list, count frequency across corpus
4. Filter out DOIs already in abstracts table (anti-join on DOI)
5. Batch fetch top 20 from OpenAlex (pipe-separated filter, max 50 per request)
6. Present checkbox list ranked by citation frequency
7. Import selected via existing `create_abstract()` workflow

**Complexity:** MEDIUM — requires JSON parsing, frequency analysis, batch API handling

---

### 2. Bulk DOI Upload

**What:** Textarea for pasting DOI list + file upload (.txt, .csv) → parse, validate, batch OpenAlex lookup → import to notebook

**Integration points:**

```
┌─────────────────────────────────────────────────────────┐
│ mod_search_notebook.R (MODIFIED)                        │
│  + "Bulk Import" dropdown option → "DOI List..."       │
│  + Modal with textarea + fileInput                      │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ R/utils_doi.R (MODIFIED)                                │
│  + parse_doi_list(text) — split by newline/comma/space │
│  + validate_doi_batch(dois) — filter valid, return list│
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ R/api_openalex.R (MODIFIED)                             │
│  + batch_fetch_works_by_doi(dois, email, api_key)      │
│     - Chunk into batches of 50 (OpenAlex limit)        │
│     - Build filter: doi:10.1234/a|10.5678/b             │
│     - Return parsed work list                           │
│     - Handle missing DOIs gracefully (warn, skip)       │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ ExtendedTask for async batch import                     │
│  - Progress bar updates per batch                       │
│  - Mirai isolated process for API calls                │
│  - Interrupt flag support for cancel                    │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ db.R (NO CHANGE)                                        │
│  - Reuse create_abstract() for each fetched paper      │
└─────────────────────────────────────────────────────────┘
```

**New components:**
- `parse_doi_list()` in utils_doi.R
- `validate_doi_batch()` in utils_doi.R
- `batch_fetch_works_by_doi()` in api_openalex.R

**Modified components:**
- `mod_search_notebook.R` — add bulk import modal UI + ExtendedTask observer

**Data flow:**
1. User clicks "Bulk Import" → "DOI List..."
2. Modal opens with textarea (placeholder: "10.1234/abc\n10.5678/def") + fileInput
3. Parse input: split by newline, comma, or whitespace
4. Normalize with `normalize_doi_bare()`, validate format
5. Deduplicate, filter out DOIs already in notebook
6. Chunk into batches of 50 (OpenAlex max per request)
7. Async ExtendedTask: batch fetch with progress updates
8. Import each fetched paper via `create_abstract()`
9. Show success notification: "Imported 47 papers, 3 DOIs not found"

**UI considerations:**
- Show validation errors inline (invalid DOI format)
- Preview valid DOI count before import
- Progress modal with cancel button (mirai interrupt flag)

**Complexity:** MEDIUM — parsing, batching, async handling

---

### 3. BibTeX File Parsing

**What:** File upload (.bib) → parse with bib2df → extract DOIs → same batch import flow as #2

**Integration points:**

```
┌─────────────────────────────────────────────────────────┐
│ mod_search_notebook.R (MODIFIED)                        │
│  + "Bulk Import" dropdown option → "BibTeX File..."    │
│  + fileInput(accept = ".bib")                           │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ R/utils_bibtex.R (NEW)                                  │
│  + parse_bibtex_file(filepath)                          │
│     - Uses bib2df::bib2df(filepath)                     │
│     - Extract DOI column from tibble                    │
│     - Normalize with normalize_doi_bare()               │
│     - Return cleaned DOI vector                         │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ Same batch fetch flow as #2                             │
│  - batch_fetch_works_by_doi()                           │
│  - ExtendedTask for async import                        │
│  - db.R create_abstract() for persistence               │
└─────────────────────────────────────────────────────────┘
```

**New components:**
- `R/utils_bibtex.R` with `parse_bibtex_file()`
- Add `bib2df` to DESCRIPTION dependencies

**Modified components:**
- `mod_search_notebook.R` — add .bib file upload modal

**Data flow:**
1. User uploads .bib file
2. Parse with `bib2df::bib2df(filepath)` → tibble
3. Extract `DOI` column (may be NA, URL, or bare format)
4. Normalize with `normalize_doi_bare()`, filter valid
5. Pass DOI vector to existing batch import flow (#2)
6. Show results: "Found 32 DOIs in BibTeX, imported 28 papers, 4 not found"

**BibTeX library choice:**
- **bib2df** (rOpenSci) — converts to tibble, actively maintained (2026)
- Alternative: `bibtex::read.bib()` (returns list, harder to extract DOIs)
- `RefManageR::ReadBib()` — more complex, overkill for DOI extraction

**Complexity:** LOW — thin wrapper over bib2df, reuses DOI batch import

---

### 4. Select-All Import

**What:** Checkbox to select all filtered abstracts → bulk import into document notebook

**Integration points:**

```
┌─────────────────────────────────────────────────────────┐
│ mod_search_notebook.R (MODIFIED)                        │
│  + Checkbox above paper list: "Select all (N papers)"  │
│  + Reactive: selected_papers_rv()                       │
│     - If select_all checked: filtered_papers()          │
│     - Else: papers with individual checkboxes           │
│  + Import button: observeEvent(input$import_abstracts)  │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ R/db.R (NO CHANGE)                                      │
│  - Reuse create_abstract() in loop                      │
│  - Wrap in transaction for atomicity                    │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ UI updates                                              │
│  - Move "Hide predatory journals" into Filter modal     │
│  - Replace with select-all checkbox                     │
│  - Individual checkboxes remain for manual selection    │
└─────────────────────────────────────────────────────────┘
```

**New components:** NONE

**Modified components:**
- `mod_search_notebook.R` — UI refactor + select-all reactive logic

**Data flow:**
1. User applies filters (year, keyword, journal quality)
2. Filtered paper list updates
3. "Select all (47 papers)" checkbox above list
4. User checks select-all OR individual papers
5. Click "Import to Document Notebook" dropdown → select notebook
6. Loop through selected papers, call `create_abstract()` for each
7. Transaction ensures all-or-nothing (if one fails, rollback)
8. Toast notification: "Imported 47 papers to [Notebook Name]"

**UI refactor:**
- Current: predatory journal toggle outside filter modal
- New: move toggle into filter modal, reclaim space for select-all checkbox

**Complexity:** LOW — pure UI + reactive logic, no new backend code

---

### 5. Slide Prompt Healing

**What:** Pre-inject YAML template into prompt + regeneration workflow to fix malformed QMD

**Integration points:**

```
┌─────────────────────────────────────────────────────────┐
│ R/slides.R (MODIFIED)                                   │
│  + build_slides_prompt() modifications:                 │
│     - System prompt includes YAML template              │
│     - "Output YAML exactly as shown below:"             │
│     - Example YAML block in prompt                      │
│  + heal_qmd_yaml(qmd_content, theme) — NEW             │
│     - Detect malformed YAML (missing ---, wrong indent) │
│     - Replace with correct template                     │
│     - Preserve slide content below YAML                 │
│       ↓                                                 │
├─────────────────────────────────────────────────────────┤
│ mod_slides.R (MODIFIED)                                 │
│  + "Regenerate" button in preview modal                 │
│  + textAreaInput for healing instructions              │
│     - Placeholder: "Fix the YAML", "Fix table 3"       │
│  + observeEvent(input$regenerate_slides)                │
│     - Append healing instruction to original prompt     │
│     - Call generate_slides() with amended messages      │
│     - Update preview with healed QMD                    │
└─────────────────────────────────────────────────────────┘
```

**New components:**
- `heal_qmd_yaml()` function in slides.R (fallback fixer)

**Modified components:**
- `build_slides_prompt()` in slides.R — inject YAML template
- `mod_slides.R` — add regeneration UI + observer

**Prompt changes:**

**Before:**
```
System: You are an expert presentation designer. Generate a Quarto RevealJS
presentation in valid .qmd format.

Output format requirements:
- Start with YAML frontmatter (title, format: revealjs)
- Use # for section titles...
```

**After:**
```
System: You are an expert presentation designer. Generate a Quarto RevealJS
presentation in valid .qmd format.

CRITICAL: Start with this YAML frontmatter EXACTLY as shown:
---
title: "Your Title Here"
format:
  revealjs:
    theme: dark
---

Output format requirements:
- Keep YAML exactly as shown above (only change title)
- Use # for section titles...
```

**Healing workflow:**
1. User generates slides
2. LLM returns malformed YAML (common with smaller models)
3. Quarto render fails
4. User clicks "Regenerate" button
5. Enters healing instruction: "Fix the YAML indentation"
6. System appends to original prompt: "The previous output had errors. Fix: [instruction]. Regenerate the entire presentation with corrections."
7. Call `chat_completion()` with amended messages (includes history context)
8. Apply `heal_qmd_yaml()` as fallback (regex-based YAML replacement)
9. Preview updated QMD

**Complexity:** LOW — prompt engineering + simple UI addition

---

## Component Architecture

### New Files

| File | Purpose | LOC Est. |
|------|---------|----------|
| `R/citation_audit.R` | Citation gap analysis + batch fetch | ~150 |
| `R/utils_bibtex.R` | BibTeX parsing wrapper | ~50 |

### Modified Files

| File | Changes | Complexity |
|------|---------|------------|
| `R/mod_search_notebook.R` | + Audit button + bulk import modals + select-all checkbox | MEDIUM (~200 LOC) |
| `R/api_openalex.R` | + `batch_fetch_works_by_doi()` | LOW (~80 LOC) |
| `R/utils_doi.R` | + `parse_doi_list()`, `validate_doi_batch()` | LOW (~60 LOC) |
| `R/slides.R` | + YAML template in prompt + `heal_qmd_yaml()` | LOW (~100 LOC) |
| `R/mod_slides.R` | + Regeneration UI + observer | LOW (~80 LOC) |

### Dependencies

**New R packages:**
- `bib2df` — BibTeX parser (rOpenSci, CRAN, active 2026)
  - Alternative: `bibtex` (CRAN, last updated 2025-07-22)
  - Recommendation: **bib2df** for tibble output (easier DOI extraction)

**No infrastructure changes:**
- DuckDB schema unchanged (all columns exist)
- Async pattern reuses ExtendedTask + mirai
- OpenAlex API within rate limits (polite pool, batch requests)

---

## Data Flow Diagrams

### Citation Audit Flow

```
User clicks "Find Missing Papers"
    ↓
Extract referenced_works from abstracts table
    ↓
Parse JSON arrays → flatten to DOI list
    ↓
Count frequency across corpus
    ↓
Filter out DOIs already in abstracts (anti-join)
    ↓
Rank by frequency → top 20
    ↓
OpenAlex batch query (pipe-separated filter)
    ↓
Modal with checkbox list (ranked by citations)
    ↓
User selects papers to import
    ↓
Loop: create_abstract() for each selected
    ↓
Toast: "Imported 8 seminal papers"
```

### Bulk DOI Import Flow

```
User clicks "Bulk Import" → "DOI List" or "BibTeX File"
    ↓
[If DOI List] Parse textarea/file → normalize → validate
[If BibTeX] bib2df::bib2df() → extract DOI column → normalize
    ↓
Deduplicate, filter out existing DOIs
    ↓
Chunk into batches of 50
    ↓
ExtendedTask: batch_fetch_works_by_doi()
    ↓ (per batch)
OpenAlex API: filter=doi:A|B|C...
    ↓
Parse works, insert via create_abstract()
    ↓
Update progress bar: "Batch 2/5 — 20 papers imported"
    ↓
Toast: "Imported 87 papers, 3 DOIs not found"
```

### Slide Healing Flow

```
User generates slides
    ↓
LLM returns malformed YAML
    ↓
Quarto render fails (error shown in modal)
    ↓
User clicks "Regenerate"
    ↓
Enters healing instruction: "Fix YAML indentation"
    ↓
System builds amended prompt:
  Original prompt + "Previous output had errors. Fix: [instruction]"
    ↓
chat_completion() with history context
    ↓
Apply heal_qmd_yaml() as fallback (regex-based)
    ↓
Preview updated QMD
    ↓
User downloads or re-renders
```

---

## Integration Patterns

### Pattern 1: Batch API Operations with Progress

**What:** Chunk large operations (50+ items) into batches, use ExtendedTask + mirai for async execution with progress updates

**When:** Bulk DOI import, citation audit fetch

**Implementation:**
```r
# In mod_search_notebook.R server
bulk_import_task <- ExtendedTask$new(function(dois, email, api_key) {
  mirai::mirai({
    batch_fetch_works_by_doi(dois, email, api_key)
  })
})

observeEvent(input$start_bulk_import, {
  # Parse and validate DOIs
  dois <- parse_doi_list(input$doi_textarea)
  valid_dois <- validate_doi_batch(dois)

  # Invoke async task
  bulk_import_task$invoke(valid_dois, cfg$email, cfg$api_key)
})

# Progress observer
observe({
  result <- bulk_import_task$result()
  if (!is.null(result)) {
    # Insert into DB
    lapply(result, function(work) {
      create_abstract(con(), notebook_id(), work$paper_id, ...)
    })
    showNotification("Import complete", type = "message")
  }
})
```

**Trade-offs:**
- Pro: Non-blocking UI, cancellable, progress feedback
- Con: Adds ~50 LOC per feature (task setup + observers)

---

### Pattern 2: Modal-Driven Workflows

**What:** Use `showModal()` for multi-step operations (input → validate → confirm → execute)

**When:** Citation audit, bulk import, slide regeneration

**Implementation:**
```r
observeEvent(input$audit_citations, {
  # Show loading modal
  showModal(modalDialog(
    title = "Analyzing Citations...",
    "Finding missing papers...",
    footer = NULL
  ))

  # Compute in background
  gaps <- analyze_citation_gaps(con(), notebook_id(), top_n = 20)

  # Replace with results modal
  removeModal()
  showModal(modalDialog(
    title = "Missing Papers",
    checkboxGroupInput(ns("papers_to_import"), NULL,
                       choices = format_gap_list(gaps)),
    footer = tagList(
      actionButton(ns("import_gaps"), "Import Selected"),
      modalButton("Cancel")
    )
  ))
})
```

**Trade-offs:**
- Pro: Familiar pattern in codebase, clean UX separation
- Con: Modal stacking (loading → results) can feel janky if slow

---

### Pattern 3: JSON Column Analysis

**What:** Query JSON column from DuckDB, parse in R, aggregate results

**When:** Citation audit (extract `referenced_works` arrays)

**Implementation:**
```r
analyze_citation_gaps <- function(con, notebook_id, top_n = 20) {
  # Fetch all referenced_works JSON arrays
  abstracts <- dbGetQuery(con, "
    SELECT paper_id, doi, referenced_works
    FROM abstracts
    WHERE notebook_id = ?
  ", list(notebook_id))

  # Parse JSON arrays, flatten to DOI list
  all_refs <- unlist(lapply(abstracts$referenced_works, function(json) {
    if (is.na(json) || json == "") return(character())
    refs <- jsonlite::fromJSON(json)
    # Extract DOI from OpenAlex URL: https://openalex.org/W123
    # Note: OpenAlex referenced_works are work IDs, not DOIs!
    # Need to query OpenAlex to get DOIs for these work IDs
    refs
  }))

  # Count frequency
  ref_counts <- table(all_refs)
  ref_counts <- sort(ref_counts, decreasing = TRUE)

  # Filter out papers already in corpus
  existing_ids <- abstracts$paper_id
  missing_refs <- ref_counts[!names(ref_counts) %in% existing_ids]

  # Top N
  top_missing <- head(missing_refs, top_n)

  # Fetch metadata from OpenAlex (batch query by work ID)
  fetch_missing_papers(names(top_missing), email, api_key)
}
```

**Trade-offs:**
- Pro: Leverages existing schema, no new columns needed
- Con: JSON parsing in R (slower than native DB query), work ID → DOI lookup needed

**CRITICAL DISCOVERY:** OpenAlex `referenced_works` stores **work IDs** (e.g., `https://openalex.org/W123`), NOT DOIs. Citation audit must:
1. Extract work IDs from `referenced_works` JSON
2. Batch query OpenAlex by work ID to get DOI/title/author
3. Filter out works already in corpus (match by work ID, not DOI)

---

## Build Order with Dependencies

Recommended phase order considering feature dependencies:

### Phase 1: Foundation (DOI utilities)
**Goal:** Add parsing and validation utilities for bulk operations

**Tasks:**
- Add `parse_doi_list()` to utils_doi.R
- Add `validate_doi_batch()` to utils_doi.R
- Write unit tests for parsing edge cases (URLs, bare DOIs, malformed)

**Why first:** All bulk import features depend on DOI parsing

**Deliverables:**
- `R/utils_doi.R` updated
- `tests/testthat/test-utils_doi.R` added

---

### Phase 2: OpenAlex Batch Fetch
**Goal:** Add batch API query support

**Tasks:**
- Add `batch_fetch_works_by_doi()` to api_openalex.R
- Chunk into batches of 50 (OpenAlex max)
- Handle missing DOIs gracefully (warn, skip)
- Write integration test with mock API

**Why second:** Citation audit and bulk import both need this

**Deliverables:**
- `R/api_openalex.R` updated
- `tests/testthat/test-api_openalex.R` updated

---

### Phase 3: Bulk DOI Import UI
**Goal:** Textarea + file upload → batch import workflow

**Tasks:**
- Add "Bulk Import" → "DOI List..." modal to mod_search_notebook.R
- ExtendedTask for async import with progress
- Wire up parse_doi_list() → batch_fetch_works_by_doi() → create_abstract()
- Handle errors (invalid DOIs, API failures, duplicate papers)

**Why third:** Validates batch fetch works before building on it

**Deliverables:**
- `R/mod_search_notebook.R` updated
- Manual test: import 20 DOIs from textarea

---

### Phase 4: BibTeX Import
**Goal:** .bib file upload → extract DOIs → reuse bulk import flow

**Tasks:**
- Add bib2df to DESCRIPTION
- Create `R/utils_bibtex.R` with `parse_bibtex_file()`
- Add "Bulk Import" → "BibTeX File..." modal
- Wire up to existing batch import flow (Phase 3)

**Why fourth:** Thin wrapper over Phase 3, low risk

**Deliverables:**
- `R/utils_bibtex.R` added
- `R/mod_search_notebook.R` updated
- Test fixture: sample.bib with 10 entries

---

### Phase 5: Citation Audit
**Goal:** Analyze referenced_works → find missing papers → import workflow

**Tasks:**
- Create `R/citation_audit.R`
- `analyze_citation_gaps()` — JSON parsing, frequency analysis, work ID extraction
- OpenAlex batch query by work ID (NOT DOI — critical distinction)
- Add "Find Missing Papers" button to mod_search_notebook.R
- Modal with ranked checkbox list
- Import selected via existing create_abstract()

**Why fifth:** Most complex, depends on batch fetch (Phase 2)

**Deliverables:**
- `R/citation_audit.R` added
- `R/mod_search_notebook.R` updated
- Manual test: audit notebook with 30+ papers

---

### Phase 6: Select-All Import
**Goal:** Checkbox to bulk-select filtered papers for import

**Tasks:**
- Add select-all checkbox above paper list
- Move predatory journal toggle into filter modal (UI refactor)
- Reactive: `selected_papers_rv()` merges select-all + individual checkboxes
- Import loop with transaction wrapper

**Why sixth:** Independent of other features, pure UI change

**Deliverables:**
- `R/mod_search_notebook.R` updated
- Manual test: select all 50 papers, import to notebook

---

### Phase 7: Slide Prompt Healing
**Goal:** Pre-inject YAML + regeneration workflow

**Tasks:**
- Update `build_slides_prompt()` with YAML template
- Add `heal_qmd_yaml()` fallback function
- Add "Regenerate" button + textarea to mod_slides.R
- Healing observer: amend prompt with instruction, re-call chat_completion()

**Why last:** Independent of all other features, lower priority

**Deliverables:**
- `R/slides.R` updated
- `R/mod_slides.R` updated
- Manual test: generate slides with small model, regenerate with healing

---

## Dependency Graph

```
Phase 1 (DOI utils)
    ├─→ Phase 2 (Batch fetch)
    │       ├─→ Phase 3 (DOI import)
    │       │       └─→ Phase 4 (BibTeX import)
    │       └─→ Phase 5 (Citation audit)
    │
    ├─→ Phase 6 (Select-all) — INDEPENDENT
    └─→ Phase 7 (Slide healing) — INDEPENDENT
```

**Parallelization opportunities:**
- Phase 6 and Phase 7 can be built in parallel with other phases
- Phase 4 can start as soon as Phase 3 is functional

---

## Risk Assessment

| Feature | Risk Level | Mitigation |
|---------|------------|------------|
| Citation Audit | MEDIUM | Work ID vs DOI confusion — verify OpenAlex response format early |
| Bulk DOI Import | LOW | Batch chunking well-documented, existing async pattern proven |
| BibTeX Parsing | LOW | bib2df is mature (rOpenSci), fallback to bibtex package if needed |
| Select-All Import | VERY LOW | Pure UI + existing backend, no new infrastructure |
| Slide Healing | LOW | Prompt engineering risk — test with multiple models early |

**Highest risk:** Citation audit work ID extraction — OpenAlex `referenced_works` returns work URLs, not DOIs. Must batch query by work ID to get metadata, then filter by work ID (not DOI) against corpus.

---

## Open Questions

1. **Citation audit performance:** With 100+ papers, JSON parsing for all `referenced_works` may be slow. Should we:
   - Cache analysis results in DB table?
   - Compute on-demand only (current plan)?
   - Use DuckDB JSON functions instead of R parsing?

2. **Bulk import deduplication:** If user imports same DOI twice:
   - Silently skip (current plan)?
   - Warn user in preview?
   - Update existing abstract metadata?

3. **BibTeX DOI quality:** Many .bib files have missing or malformed DOIs. Should we:
   - Fall back to title search if DOI missing?
   - Import only entries with valid DOIs (current plan)?
   - Show preview of skipped entries?

4. **Slide healing retry limit:** Should we:
   - Allow unlimited regenerations (current plan)?
   - Cap at 3 attempts to prevent cost runaway?
   - Track healing cost separately from original generation?

---

## Sources

**OpenAlex API:**
- [Batch DOI lookup with pipe-separated filter](https://blog.openalex.org/fetch-multiple-dois-in-one-openalex-api-request/) — Official guide, up to 50 DOIs per request
- [Filter entity lists](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/filter-entity-lists) — OpenAlex filter syntax
- [Work object](https://docs.openalex.org/api-entities/works/work-object) — `referenced_works` field documentation

**R Packages:**
- [bib2df package](https://docs.ropensci.org/bib2df/) — rOpenSci BibTeX parser, converts to tibble
- [bibtex package (CRAN)](https://cran.r-project.org/package=bibtex) — Alternative parser, updated 2025-07-22
- [rbibutils (CRAN)](https://cran.r-project.org/web/packages/rbibutils/rbibutils.pdf) — Updated 2026-01-21

**Shiny Patterns:**
- [ExtendedTask with mirai](https://mirai.r-lib.org/articles/shiny.html) — Official Shiny integration guide
- [Promises and progress bars](https://mirai.r-lib.org/articles/v3-promises.html) — Progress updates with mirai_map()
- [File upload control](https://shiny.posit.co/r/reference/shiny/latest/fileinput.html) — Official Shiny fileInput() docs

---

*Architecture research for Serapeum v7.0 milestone*
*Researched: 2026-02-25*
*Confidence: HIGH (existing architecture verified, OpenAlex API documented, R packages confirmed)*
