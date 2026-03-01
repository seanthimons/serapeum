---
phase: 02-query-builder-sorting
verified: 2026-02-11T04:50:59Z
status: human_needed
score: 10/10 must-haves verified
re_verification: false
human_verification:
  - test: "End-to-end query builder flow with LLM generation"
    expected: "Natural language query generates valid OpenAlex filters, shows preview, creates notebook with results"
    why_human: "Requires LLM API interaction and visual confirmation of preview UI"
  - test: "Sort controls functionality across all sort options"
    expected: "Papers reorder correctly when selecting each sort option; missing metrics sink to bottom"
    why_human: "Visual confirmation of sort behavior and UI responsiveness"
  - test: "Filter validation rejects invalid attributes"
    expected: "Invalid filter names produce error notification with explanation"
    why_human: "LLM interaction required to trigger validation failure path"
---

# Phase 2: Query Builder + Sorting Verification Report

**Phase Goal:** Users can describe research interests in natural language and get validated OpenAlex queries, with sortable results

**Verified:** 2026-02-11T04:50:59Z

**Status:** human_needed

**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

#### Plan 02-01: Sort Controls

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Search results can be sorted by citation count (descending) | VERIFIED | list_abstracts accepts sort_by = "cited_by_count", SQL ORDER BY with DESC NULLS LAST |
| 2 | Search results can be sorted by FWCI (descending, nulls at bottom) | VERIFIED | sort_by = "fwci" with fwci DESC NULLS LAST clause |
| 3 | Search results can be sorted by outgoing citation count (descending) | VERIFIED | sort_by = "referenced_works_count" with DESC NULLS LAST |
| 4 | Search results can be sorted by year (descending, default) | VERIFIED | Default sort_by = "year" with year DESC, created_at DESC |
| 5 | Papers with missing FWCI display a dash instead of NA | VERIFIED | format_citation_metrics conditionally displays FWCI only if not null and not NA (line 228 mod_search_notebook.R) |

#### Plan 02-02: Query Builder

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can type a natural language research question and receive a generated OpenAlex query | VERIFIED | mod_query_builder_ui has textAreaInput for NL query, generate button calls chat_completion with LLM prompt |
| 2 | Generated query is shown to user for review before execution | VERIFIED | output query_preview renders explanation, search terms, filter string, and execute button (lines 141-164) |
| 3 | LLM-generated filters are validated against an allowlist before API call | VERIFIED | validate_openalex_filters called after LLM response (line 120), checks against 53-attribute allowlist |
| 4 | Invalid filters are rejected with an explanation message | VERIFIED | Validation failure shows showNotification with error message (lines 121-127) |
| 5 | Executing a generated query creates a search notebook with results | VERIFIED | execute_btn handler sets discovery_request, app.R consumer creates notebook and fetches OpenAlex results (lines 620-708) |

**Score:** 10/10 truths verified

### Required Artifacts

#### Plan 02-01: Sort Controls

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| R/db.R | list_abstracts with sort_by parameter | VERIFIED | Function signature at line 592, accepts sort_by with 4 valid options, switch statement builds ORDER BY clause with NULLS LAST |
| R/mod_search_notebook.R | Sort radio buttons in paper list header | VERIFIED | radioButtons at line 40-41, ns("sort_by"), 4 inline choices, wired to papers_data reactive at line 312-313 |

#### Plan 02-02: Query Builder

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| R/utils_filters.R | OpenAlex filter allowlist and validation function | VERIFIED | OPENALEX_FILTER_ALLOWLIST (53 attributes, line 5), validate_openalex_filters function (line 61), splits filter string and validates attribute names |
| R/mod_query_builder.R | Query builder Shiny module with LLM integration | VERIFIED | mod_query_builder_ui (line 3), mod_query_builder_server (line 32), LLM integration via chat_completion (line 89), validation (line 120), preview UI (line 141) |
| app.R | Query builder button, view routing, and producer-consumer wiring | VERIFIED | Sidebar button (line 48), view routing (line 241-243), UI rendering (line 457-458), module server init (line 546), consumer observeEvent (line 620-708) |

### Key Link Verification

#### Plan 02-01: Sort Controls

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| R/mod_search_notebook.R | R/db.R | list_abstracts with sort_by parameter | WIRED | Line 313: list_abstracts(con(), nb_id, sort_by = sort_by) with reactive dependency on input sort_by (line 312) |

#### Plan 02-02: Query Builder

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| R/mod_query_builder.R | R/utils_filters.R | validate_openalex_filters | WIRED | Line 120: validation called after LLM response parsing |
| R/mod_query_builder.R | R/api_openrouter.R | chat_completion for LLM query generation | WIRED | Line 89: chat_completion called with API key, model, and formatted messages |
| app.R | R/mod_query_builder.R | Producer-consumer observeEvent | WIRED | Line 546: module server returns discovery_request reactive; line 620: consumer observeEvent creates notebook and fetches results |

### Requirements Coverage

| Requirement | Status | Supporting Truths |
|-------------|--------|-------------------|
| DISC-06: Rich sorting for search results | SATISFIED | Truths 1-5 from Plan 02-01 (sort by citations, FWCI, refs, year; graceful NULL handling) |
| DISC-03: Meta-prompt query builder | SATISFIED | Truths 1-5 from Plan 02-02 (NL input, LLM generation, validation, preview, execution) |

### Anti-Patterns Found

No blocker anti-patterns detected.

**Scanned files:**
- R/db.R (commit 4758768)
- R/mod_search_notebook.R (commit 4758768)
- R/utils_filters.R (commit 1ea4b6c)
- R/mod_query_builder.R (commit 1ea4b6c)
- app.R (commit 51ae420)

**Findings:**
- All "placeholder" mentions are UI textAreaInput placeholder text (not TODO comments)
- No empty implementations (return null, return {}, return [])
- No console.log-only handlers
- All functions have substantive implementations
- SQL placeholders are proper parameterized query patterns (not anti-pattern)

### Human Verification Required

The following items require human testing as they involve LLM interaction, visual UI confirmation, and end-to-end flow validation:

#### 1. Query Builder End-to-End Flow

**Test:**
1. Start app: "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" app.R
2. Click "Build a Query" button in sidebar
3. Enter: "Recent machine learning papers on transformers with high citation impact"
4. Click "Generate Query"
5. Verify preview shows with explanation, search terms, and filter string
6. Click "Create Search Notebook"
7. Verify notebook created with papers

**Expected:**
- Preview UI renders with structured explanation (not raw JSON)
- Filter string contains only valid OpenAlex filters (e.g., publication_year, cited_by_count, has_abstract)
- Search notebook created with 1-50 papers from OpenAlex
- Papers display with citation metrics (no raw "NA" values)

**Why human:**
Requires OpenRouter API key configuration, LLM API call, visual confirmation of preview UI rendering, and verification that OpenAlex API call succeeds.

#### 2. Sort Controls Functionality

**Test:**
1. Open any search notebook with multiple papers (or create one via query builder)
2. Click "Most cited" sort option
3. Verify papers reorder with highest cited_by_count at top
4. Click "Impact (FWCI)" sort option
5. Verify papers with FWCI values appear at top, papers without FWCI at bottom
6. Click "Most refs" sort option
7. Verify papers reorder by referenced_works_count descending
8. Click "Newest" sort option
9. Verify papers reorder by year descending (default)

**Expected:**
- Papers reorder immediately on sort option change (no page refresh)
- Papers with missing metrics sink to bottom when sorting by that metric
- Sort controls remain inline and visible above paper list

**Why human:**
Visual confirmation of UI responsiveness and correct sort behavior. Need to observe that papers with NULL metrics appear at bottom, not top or middle.

#### 3. Filter Validation Error Path

**Test:**
1. Modify R/mod_query_builder.R system prompt to REMOVE has_abstract from allowed filters list
2. Restart app
3. Enter query: "Papers with abstracts on climate change"
4. Click "Generate Query"
5. Verify error notification appears if LLM generates has_abstract:true filter
6. Verify error message explains which filter is invalid

**Expected:**
- Error notification shows: "Invalid filter 'has_abstract': attribute not recognized..."
- Query preview does NOT render
- No search notebook created

**Why human:**
Requires LLM to generate an invalid filter (non-deterministic). Easier to test by intentionally limiting allowlist or manually triggering validation with a crafted filter string.

---

## Verification Summary

**All automated checks passed:**
- 10/10 observable truths verified in code
- 5/5 required artifacts exist, are substantive, and are wired
- 4/4 key links verified (all WIRED)
- 2/2 requirements satisfied
- No blocker anti-patterns
- All commits documented in SUMMARYs exist in git history

**Human verification needed:**
- Query builder end-to-end flow (LLM API interaction)
- Sort controls visual behavior
- Filter validation error handling

**Recommendation:** Phase 2 goal achieved from a code verification perspective. Human testing should focus on LLM prompt quality (does it generate good OpenAlex queries?) and edge cases (invalid filters, empty results, missing metrics).

---

_Verified: 2026-02-11T04:50:59Z_
_Verifier: Claude (gsd-verifier)_
