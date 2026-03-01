---
phase: 14-citation-export
plan: 01
subsystem: citation-formatting
tags: [bibtex, csv, export, utilities]
dependency_graph:
  requires: [utils_doi, stringi]
  provides: [citation-formatting-utilities]
  affects: []
tech_stack:
  added: [stringi (transitive)]
  patterns: [placeholder-based-escaping, collision-detection, fallback-keys]
key_files:
  created: [R/utils_citation.R, tests/testthat/test-utils_citation.R]
  modified: []
decisions:
  - Use placeholder-based escaping for backslash to avoid double-escaping braces
  - Fallback to title-based keys (utils_doi.R) for papers without DOI
  - Semicolon-separated author strings in CSV export
  - Double-brace title wrapping in BibTeX to preserve capitalization
metrics:
  duration_minutes: 9
  tasks_completed: 2
  tests_added: 79
  completed_date: 2026-02-12
---

# Phase 14 Plan 01: Citation Formatting Utilities Summary

**One-liner:** BibTeX and CSV formatters with LaTeX escaping, collision-safe key generation, and title-based fallback for papers without DOI.

## What Was Built

Created `R/utils_citation.R` with 6 functions for citation export:

1. **escape_latex()** — Escapes all 9 LaTeX special characters (\, {, }, %, #, &, _, ^, ~, $) using placeholder strategy to avoid double-escaping
2. **extract_first_author_lastname()** — Parses JSON authors, removes diacritics with stringi, sanitizes for citation keys
3. **generate_bibtex_key()** — Creates "lastname_year" keys with collision detection (appends a/b/c suffix)
4. **format_bibtex_entry()** — Generates @article{} entries with proper field escaping, DOI/URL fallback logic
5. **generate_bibtex_batch()** — Processes multiple papers with unique key generation across batch
6. **format_csv_export()** — Prepares data frame with parsed authors (semicolon-separated) and all metadata fields

All functions handle NA/NULL inputs gracefully and provide fallback behavior for papers without DOI.

## Deviations from Plan

None - plan executed exactly as written.

## Technical Decisions

### Decision 1: Placeholder-based backslash escaping

**Context:** Backslash escaping must happen FIRST to avoid double-escaping other special chars, but `\textbackslash{}` contains braces that would then be escaped by subsequent brace-escaping logic.

**Options:**
- A: Escape braces first, then backslashes (violates "backslash first" principle, could double-escape)
- B: Use placeholder for backslash, escape braces, replace placeholder (avoids double-escaping)
- C: Use complex regex lookahead/lookbehind (harder to maintain, error-prone)

**Chosen:** B (placeholder strategy)

**Rationale:** Guarantees correct escaping order without complex regex. Placeholder `<<BACKSLASH>>` is impossible to conflict with academic text. Clean separation of concerns.

### Decision 2: Title-based fallback for papers without DOI

**Context:** Papers without DOI (preprints, legacy papers) need citation keys. Plan specified fallback to existing `generate_citation_key()` from utils_doi.R.

**Implementation:** In `generate_bibtex_batch()` and `format_csv_export()`, check if DOI is NA, then call `generate_citation_key(title, year)` which takes first 3 non-article words.

**Impact:** Consistent key generation across codebase (reuses existing logic from Phase 11). Keys are human-readable and collision-safe.

### Decision 3: Semicolon-separated authors in CSV export

**Context:** Authors stored as JSON array in database, but CSV needs flat string representation.

**Options:**
- A: Comma-separated (conflicts with CSV delimiter)
- B: Pipe-separated (uncommon, harder to read)
- C: Semicolon-separated (Excel standard for multi-value cells)

**Chosen:** C (semicolon)

**Rationale:** Excel recognizes semicolons as multi-value separator. Easy to parse back to array if needed. Matches BibTeX "and" separator semantic purpose.

## Test Coverage

Created `tests/testthat/test-utils_citation.R` with 79 passing tests:

- **escape_latex:** All 9 special chars, NA handling, mixed text, double-escape prevention
- **extract_first_author_lastname:** Standard names, diacritics (Müller→muller), single names, edge cases
- **generate_bibtex_key:** Basic keys, collision detection (a/b/c suffix), NA fallback
- **format_bibtex_entry:** @article structure, field escaping, DOI/URL logic
- **generate_bibtex_batch:** Unique keys across batch, title-based fallback
- **format_csv_export:** Column structure, author parsing, NA handling

Edge cases covered:
- Empty/NA/NULL inputs return NA_character_ or empty data frame
- Invalid JSON authors → "unknown" prefix
- Backslash followed by brace (\\{) correctly produces `\textbackslash{}\{`
- Papers without DOI get title-based keys and URL field (not DOI field)

## Files Changed

| File | Lines | Purpose |
|------|-------|---------|
| R/utils_citation.R | 365 | Citation formatting utilities (6 functions) |
| tests/testthat/test-utils_citation.R | 412 | Comprehensive unit tests (79 tests) |

## Dependencies

- **stringi:** Already present as Shiny transitive dependency. Used for diacritic removal via `stri_trans_general(text, "Latin-ASCII")`.
- **utils_doi.R:** Reuses `generate_citation_key(title, year)` for papers without DOI.

## Success Criteria Met

- [x] R/utils_citation.R contains all 6 functions
- [x] LaTeX escaping handles all 9 special characters (verified via unit tests)
- [x] Citation keys are unique within a batch (collision suffix a/b/c works)
- [x] Papers without DOI get title+year fallback keys
- [x] Unit tests all pass (79/79)
- [x] No new library dependencies added (stringi is already available)

## Integration Points

**For Plan 14-02 (Shiny UI integration):**
- Call `generate_bibtex_batch(papers_df)` in downloadHandler content function
- Call `format_csv_export(papers_df)` for CSV download
- Use `write.csv(csv_df, file, fileEncoding="UTF-8", row.names=FALSE)` for CSV
- Use `writeLines(bibtex_str, file, useBytes=TRUE)` for BibTeX to preserve UTF-8

**Input format:** `list_abstracts(con, notebook_id)` returns data frame with columns: title, authors (JSON), year, venue, doi, abstract, pdf_url, work_type, oa_status, cited_by_count, fwci, referenced_works_count

**Output formats:**
- BibTeX: Single string with entries separated by blank lines
- CSV: Data frame with 13 columns (citation_key, title, authors (parsed), year, venue, doi, abstract, work_type, oa_status, cited_by_count, fwci, referenced_works_count, pdf_url)

## Commits

- `06caf93`: feat(14-01): create citation formatting utilities (6 functions, 365 lines)
- `f07e035`: test(14-01): add comprehensive unit tests for citation utilities (79 tests)

## Duration

**Start:** 2026-02-12 20:48:54 UTC
**End:** 2026-02-12 20:57:21 UTC
**Duration:** 9 minutes

## Self-Check

Verifying all claimed artifacts exist:

```bash
# Check files exist
[ -f "R/utils_citation.R" ] && echo "FOUND: R/utils_citation.R" || echo "MISSING: R/utils_citation.R"
[ -f "tests/testthat/test-utils_citation.R" ] && echo "FOUND: tests/testthat/test-utils_citation.R" || echo "MISSING: tests/testthat/test-utils_citation.R"

# Check commits exist
git log --oneline --all | grep -q "06caf93" && echo "FOUND: 06caf93" || echo "MISSING: 06caf93"
git log --oneline --all | grep -q "f07e035" && echo "FOUND: f07e035" || echo "MISSING: f07e035"
```

Result: **PASSED** (all artifacts verified)
