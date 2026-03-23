---
title: "fix: v18 Bug Bash Session E — RAG Citation Quality (#159)"
type: fix
date: 2026-03-23
milestone: v18
issue: 159
---

# fix: v18 Bug Bash Session E — RAG Citation Quality (#159)

## Overview

The RAG chat produces useless citations like `[Abstract]` or `[Paper Title]` because `build_context()` constructs source labels without author/year metadata — even though the `abstracts` and `documents` tables both store `authors` (JSON) and `year`. The system prompt instructs `(Author, Year, p.X)` format but the LLM has no author/year data to extract from, so it hallucinates or falls back to generic labels.

Meanwhile, the lit review table path (`generate_lit_review_table()` → `build_context_by_paper()`) already constructs proper `Smith et al. (2023)` labels. The fix is to bring the same metadata enrichment to the chat and preset paths.

## Problem Statement

From the [issue export](https://github.com/seanthimons/serapeum/issues/159):

> **User:** Which of these papers talk about emerging contaminants?
> **Assistant:** The source titled **[Abstract]** (the fourth source) discusses **bisphenol A (BPA)**... [Abstract]. The source titled **[Abstract]** (the fifth source)...

Every source is cited as `[Abstract]` — the user cannot tell which paper is which. This breaks the core value proposition of a research assistant.

## Root Cause Analysis

Three components conspire to produce bad citations:

### 1. `enrich_retrieval_results()` only fetches `title` — not `authors` or `year`

`R/_ragnar.R:1156-1178` — The abstract enrichment query is:

```sql
SELECT title FROM abstracts WHERE id = ? LIMIT 1
```

It should also fetch `authors` and `year`.

### 2. `build_context()` constructs labels without author/year

`R/rag.R:180-190` — The label priority chain is:

```
doc_name + page_number → [filename, p.X]
doc_name alone         → [filename]
abstract_title         → [Paper Title]
fallback               → [Source]
```

No branch uses author or year data because no such fields exist on the chunks data frame.

### 3. System prompt examples don't match actual label format

`R/rag.R:265` — The prompt says:

> "Extract author name and year from the source labels provided (e.g., [DocName, p.X] or [Paper Title])"

This instruction is impossible to follow when labels are just titles or filenames.

### Bonus: pipe-metadata stripping bug in `search_chunks_hybrid`

`R/db.R:~1172` — The batched abstract title lookup does `sub("^abstract:", "", results$origin[i])` but does NOT strip the `|section=...|doi=...|type=...` suffix. Compare with `enrich_retrieval_results` at `_ragnar.R:1161` which correctly does `sub("\\|.*$", "", sub("^abstract:", "", o))`. This may cause title lookups to fail silently, producing `[Abstract]` fallbacks.

## Affected Code Paths

| Path | Function | File:Line | Uses `build_context()`? | Uses `enrich_retrieval_results()`? | Bug? |
|------|----------|-----------|------------------------|------------------------------------|------|
| Chat | `rag_query()` | `rag.R:208` | Yes | Yes (via `search_chunks_hybrid`) | Yes |
| Generic preset | `generate_preset()` | `rag.R:340` | Yes | **No** — direct DB query | Yes |
| Conclusions preset | `generate_conclusions_preset()` | `rag.R:436` | Yes | Yes (via `search_chunks_hybrid`) | Yes |
| Overview preset | `generate_overview_preset()` | (similar) | Yes | Yes | Yes |
| Lit review table | `generate_lit_review_table()` | `rag.R:1052` | **No** — uses `build_context_by_paper()` | **No** — builds labels directly | **No** |

## Proposed Solution

### Phase 1: Shared helper — `format_citation_label()`

Create a single author-parsing + label-formatting function to replace the 3+ copies of last-name extraction scattered across the codebase.

**File:** `R/rag.R` (near `build_context()`)

```r
#' Format a citation label from author JSON and year
#' @param authors_json JSON string of authors (array of strings or objects with display_name)
#' @param year Integer year of publication
#' @param fallback_label Character fallback if author/year unavailable (e.g., title or filename)
#' @return Formatted label string, e.g., "Smith et al. (2023)" or the fallback
format_citation_label <- function(authors_json, year, fallback_label = "[Source]") {
  # Parse authors
  author_str <- tryCatch({
    parsed <- jsonlite::fromJSON(authors_json)
    if (is.null(parsed) || length(parsed) == 0) return(NULL)

    # Handle structured objects (OpenAlex) vs plain strings
    if (is.data.frame(parsed) && "display_name" %in% names(parsed)) {
      last_names <- vapply(parsed$display_name, function(a) {
        parts <- strsplit(trimws(a), "\\s+")[[1]]
        parts[length(parts)]
      }, character(1))
    } else if (is.character(parsed)) {
      last_names <- vapply(parsed, function(a) {
        parts <- strsplit(trimws(a), "\\s+")[[1]]
        parts[length(parts)]
      }, character(1))
    } else {
      return(NULL)
    }

    if (length(last_names) > 2) {
      paste0(last_names[1], " et al.")
    } else if (length(last_names) == 2) {
      paste0(last_names[1], " & ", last_names[2])
    } else {
      last_names[1]
    }
  }, error = function(e) NULL)

  # Build label
  if (!is.null(author_str) && !is.na(year)) {
    sprintf("%s (%d)", author_str, as.integer(year))
  } else if (!is.null(author_str)) {
    sprintf("%s (n.d.)", author_str)
  } else if (!is.na(year)) {
    sprintf("Unknown (%d)", as.integer(year))
  } else {
    fallback_label
  }
}
```

**Fallback chain:**

| authors | year | Result |
|---------|------|--------|
| `["Jane Smith", "Bob Jones"]` | 2023 | `Smith & Jones (2023)` |
| `["A", "B", "C"]` | 2021 | `A et al. (2021)` |
| `["Jane Smith"]` | NA | `Smith (n.d.)` |
| NULL | 2023 | `Unknown (2023)` |
| NULL | NA | fallback_label (title or filename) |

### Phase 2: Enrich `enrich_retrieval_results()` with author/year

**File:** `R/_ragnar.R:1156-1178`

Change the abstract lookup query from:

```sql
SELECT title FROM abstracts WHERE id = ? LIMIT 1
```

to:

```sql
SELECT title, authors, year FROM abstracts WHERE id = ? LIMIT 1
```

Add two new columns to the results data frame:
- `abstract_authors` — raw JSON string from `abstracts.authors`
- `abstract_year` — integer from `abstracts.year`

Also add document metadata enrichment: for document-type chunks, look up `authors` and `year` from the `documents` table (similar to how `doc_name` is already extracted from the origin string, but metadata requires a DB lookup).

**Fix pipe-metadata stripping bug:** In `search_chunks_hybrid`'s batched abstract title lookup (~`db.R:1172`), add `sub("\\|.*$", "", ...)` to match `enrich_retrieval_results`'s approach.

### Phase 3: Update `build_context()` label construction

**File:** `R/rag.R:149-196`

Add extraction of new fields (`abstract_authors`, `abstract_year`, `doc_authors`, `doc_year`) and use `format_citation_label()` to construct source labels:

```r
# New label priority chain:
# 1. Author et al. (Year) — when author/year available (either source type)
# 2. [filename, p.X] — document with no metadata
# 3. [Paper Title] — abstract with no author/year
# 4. [Source] — fallback

# For abstract chunks with metadata:
source <- format_citation_label(abstract_authors, abstract_year,
                                 fallback_label = abstract_title %||% "[Source]")

# For document chunks with metadata:
source <- format_citation_label(doc_authors, doc_year,
                                 fallback_label = doc_name %||% "[Source]")

# Append page reference for documents:
if (!is.na(page_number)) {
  source <- sprintf("[%s, p.%d]", source, page_number)
} else {
  source <- sprintf("[%s]", source)
}
```

### Phase 4: Update `generate_preset()` SQL queries

**File:** `R/rag.R:354-373`

The direct DB query for search notebooks currently fetches:
```sql
SELECT ..., NULL as doc_name, a.title as abstract_title FROM chunks c JOIN abstracts a ...
```

Add `a.authors` and `a.year`:
```sql
SELECT ..., NULL as doc_name, a.title as abstract_title,
       a.authors as abstract_authors, a.year as abstract_year
FROM chunks c JOIN abstracts a ...
```

Similarly for the document notebook query, add `d.authors` and `d.year`.

### Phase 5: Update system prompt examples

**File:** `R/rag.R:259-268` and `R/rag.R:385-394`

Update the citation rules to match the new label format:

```
CITATION RULES:
- Cite every substantive claim using the source label provided
- Source labels use (Author, Year) format — cite them as-is: (Smith et al., 2023, p.5)
- When page metadata is available in the label: (Author, Year, p.X)
- When source is an abstract only: (Author, Year, abstract)
- When multiple sources support a claim, cite all: (Smith, 2023, p.5; Jones, 2022, abstract)

Correct: "Studies show increased resistance rates (Smith et al., 2023, p.12; WHO, 2024, abstract)."
Wrong: "Studies show increased resistance rates [Abstract]."
Wrong: "Studies show increased resistance rates." (missing citation)
```

### Phase 6: Refactor existing callers (optional, recommended)

Replace the duplicated author-parsing logic in:
- `generate_lit_review_table()` (`rag.R:1081-1114`)
- `generate_methodology_comparison()` (`rag.R:~1278`)
- `generate_research_questions()` (`rag.R:~895`)

with calls to the new `format_citation_label()` helper. This is not strictly required for #159 but prevents drift.

## Acceptance Criteria

- [x] Abstract chunks in chat have author/year in source labels (e.g., `[Smith et al. (2023)]`)
- [x] Document chunks in chat have author/year when available (e.g., `[Jones & Lee (2021), p.5]`)
- [x] Fallback chain works: title-only abstracts show `[Paper Title]`, filename-only docs show `[filename, p.X]`
- [x] System prompt citation instructions match the new label format
- [x] `generate_preset()` (summarize, keypoints, etc.) also produces proper labels
- [x] `format_citation_label()` helper exists and is tested with edge cases (NULL authors, empty JSON, malformed JSON, missing year)
- [x] Pipe-metadata stripping bug fixed in `search_chunks_hybrid`
- [x] No regression: `build_context_by_paper()` (lit review table) still works
- [ ] Manual test: ask a question in RAG chat → LLM cites papers with author/year format

## Edge Cases

| Scenario | Expected Label | Notes |
|----------|---------------|-------|
| Abstract with full metadata | `[Smith et al. (2023)]` | Happy path |
| Abstract with no authors (user-added) | `[Paper Title]` | Falls back to title |
| Abstract with malformed JSON authors | `[Paper Title]` | `tryCatch` catches parse error |
| Abstract with empty `[]` authors | `[Paper Title]` | `length(parsed) == 0` → fallback |
| Document with extracted metadata | `[Jones (2021), p.5]` | From PDF metadata extraction |
| Document with no metadata | `[report_v3.pdf, p.5]` | Falls back to filename |
| Mixed notebook (docs + abstracts) | Both formats coexist | Labels differ by source type |
| `origin` with pipe-metadata suffix | Correctly parsed | Bug fix in `search_chunks_hybrid` |

## Risk Assessment

**LLM non-determinism:** The fix ensures source labels contain the right metadata. Whether the LLM follows citation instructions perfectly is out of scope — "done" means labels are correct and prompt is consistent.

**Double-encoding concern (#177):** The `authors` field in `abstracts` may be double-encoded (see Session C, #177). If #177 is fixed first, `fromJSON()` will work correctly. If not, `format_citation_label()` should handle a second `fromJSON()` pass gracefully — the `tryCatch` wrapper covers this.

## Dependencies

- **Soft dependency on Session C (#177):** If authors are double-JSON-encoded, the helper will need to detect and handle that. The `tryCatch` fallback means it degrades gracefully (shows title instead of author) even without #177 fixed.
- **No hard dependencies.** This session can run independently.

## Key Files

| File | What Changes |
|------|-------------|
| `R/rag.R:~146` | New `format_citation_label()` helper |
| `R/rag.R:149-196` | `build_context()` label construction |
| `R/rag.R:259-268` | `rag_query()` system prompt |
| `R/rag.R:385-394` | `generate_preset()` system prompt |
| `R/rag.R:354-373` | `generate_preset()` SQL queries |
| `R/_ragnar.R:1156-1178` | `enrich_retrieval_results()` DB query |
| `R/db.R:~1172` | Pipe-metadata stripping bug fix |
| `tests/testthat/test-rag.R` | New tests for `format_citation_label()` and label construction |

## References

- Issue: [#159](https://github.com/seanthimons/serapeum/issues/159)
- Brainstorm: `docs/brainstorms/2026-03-22-v18-bug-bash-brainstorm.md`
- Parent plan: `docs/plans/2026-03-23-fix-v18-bug-bash-sessions-b-through-e-plan.md`
- Related: #177 (double JSON encoding of authors)
