# Phase 33: DOI Parsing Utilities - Research

**Researched:** 2026-02-25
**Domain:** DOI parsing, validation, and normalization utilities in R
**Confidence:** HIGH

## Summary

Phase 33 implements bulk DOI parsing infrastructure to support Phase 35 (DOI Import), Phase 36 (BibTeX Import), and Phase 37 (Citation Audit). The project already has single-DOI normalization (`normalize_doi_bare()` in `R/utils_doi.R`) and validation (`is_valid_doi()`) functions, but lacks batch processing capabilities needed for pasting lists, CSV uploads, and BibTeX extraction workflows.

This phase extends existing DOI utilities with batch parsing that handles mixed input formats (URLs, bare DOIs, comma/newline-separated lists), structural validation, deduplication, and categorized error reporting. The output is a structured list with `$valid` (normalized DOIs), `$invalid` (data frame with error reasons), and `$duplicates` (data frame with counts).

**Primary recommendation:** Extend existing `R/utils_doi.R` with a new `parse_doi_list()` function that reuses existing `normalize_doi_bare()` and `is_valid_doi()` infrastructure. Use base R string functions (`strsplit`, `grepl`, `gsub`) for portability, avoiding new dependencies. Return structured list format enables upstream modules to display granular feedback (Phase 35 import UI, Phase 37 citation audit).

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Recognize DOI URL patterns: `https://doi.org/...`, `http://doi.org/...`, `https://dx.doi.org/...`, `http://dx.doi.org/...`
- Do NOT parse publisher-specific URLs (nature.com, sciencedirect.com, etc.)
- Split input on newlines and commas only — no space/tab/semicolon splitting
- Recognize and strip `doi:` and `DOI:` prefix scheme (e.g., `doi:10.1234/abc`)
- Expect clean input (one DOI per line or comma-separated) — no freeform text extraction
- Accept both single DOI string and character vector input — auto-detect
- Return structured list with three components:
  - `$valid` — character vector of normalized (bare, lowercase) DOIs
  - `$invalid` — data frame with columns: `original` (input string), `reason` (categorized error)
  - `$duplicates` — data frame with columns: `doi` (normalized), `count` (occurrences)
- Deduplicate valid DOIs — return unique set in `$valid`, report removed dupes in `$duplicates`
- Normalize all DOIs to lowercase (matches OpenAlex handling)
- No library/database checking — parsing only, Phase 35 handles library dedup
- Structural validation: DOI must match pattern `10.NNNN/suffix` (numeric registrant prefix, non-empty suffix)
- Categorized error reasons per invalid entry: `missing_prefix`, `invalid_registrant`, `empty_suffix`, `unrecognized_format`
- Auto-fix common issues: trim whitespace, strip trailing periods/commas, handle `DOI: ` with extra space
- Silently ignore empty lines and whitespace-only lines (no error reporting for blanks)

### Claude's Discretion
- Exact regex patterns for DOI matching
- Internal function decomposition (single function vs helper pipeline)
- Test fixture design and edge case selection
- Whether to use base R or tidyverse for string manipulation

### Deferred Ideas (OUT OF SCOPE)
- **BibTeX DOI extraction → Phase 36 (FLAGGED FOR REVIEW):** Phase 36 must reuse Phase 33's DOI parser for extracted DOIs rather than building a separate DOI resolver. This was explicitly discussed — single parsing pipeline, not multiple resolvers.
- Publisher-specific URL parsing (nature.com, sciencedirect.com embeds) — add to backlog if users request it
- Freeform text DOI extraction (from paragraphs/abstracts) — future enhancement if needed

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BULK-01 | User can paste a list of DOIs (one per line, comma-separated, or URL format) | Input format recognition (newline/comma splitting), URL prefix stripping |
| BULK-02 | User can upload a CSV/text file of DOIs | Same parsing function handles file content after read, batch processing |
| BULK-03 | User can upload a .bib file for DOI extraction and import | Phase 36 extracts DOIs from BibTeX, feeds to Phase 33 parser (reuse not rebuild) |
| AUDIT-06 | User can import individual missing papers with one click | Single-DOI input support, same validation as batch |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Base R | 4.5.1+ | String manipulation, regex | Zero dependencies, installed with R |
| `strsplit()` | base | Split on delimiters | Built-in, vectorized, handles newlines/commas |
| `grepl()` | base | Pattern matching (validation) | Fast, perl=TRUE for complex patterns |
| `gsub()` | base | Pattern replacement (normalization) | Existing project usage in `utils_doi.R` |
| testthat | 3.x | Unit testing | Already used in project (`tests/testthat/`) |

### Existing Project Functions
| Function | Location | Purpose | Reuse Strategy |
|----------|----------|---------|----------------|
| `normalize_doi_bare()` | `R/utils_doi.R` (L14-32) | Strips URL prefixes, validates, lowercases | Call within batch parser for each DOI |
| `is_valid_doi()` | `R/utils_doi.R` (L41-46) | Crossref regex validation | Use for categorized error messages |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Base R `strsplit()` | stringr `str_split()` | stringr more readable but adds tidyverse dependency; base R sufficient for simple delimiter splitting |
| Base R `grepl()` | stringi `stri_detect()` | stringi faster on large datasets but adds dependency; project has <1M DOIs, base R fine |
| Manual parsing | rcrossref package | rcrossref validates DOIs via API but requires network and rate limiting; structural validation sufficient for Phase 33 |

**Installation:**
No new packages required. Uses base R and existing project infrastructure.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── utils_doi.R          # Existing: normalize_doi_bare(), is_valid_doi()
│                        # NEW: parse_doi_list(), split_doi_input(), categorize_doi_error()
└── mod_*.R              # Shiny modules (consume parse_doi_list in Phase 35/36/37)

tests/testthat/
├── test-utils_citation.R   # Existing
└── test-utils_doi.R        # NEW: test parse_doi_list() with edge cases
```

### Pattern 1: Batch Processing with Categorized Errors

**What:** Parse function accepts mixed input (string or vector), splits on delimiters, normalizes each entry, categorizes failures, returns structured list.

**When to use:** Bulk import workflows where user needs granular feedback (N valid, N invalid with reasons, N duplicates).

**Example:**
```r
# Source: Adapted from existing normalize_doi_bare() pattern
parse_doi_list <- function(input) {
  # Auto-detect: string or character vector
  if (length(input) == 1) {
    input <- split_doi_input(input)  # Split on newlines and commas
  }

  # Pre-process: trim, remove empty, auto-fix trailing punctuation
  input <- trimws(input)
  input <- input[nchar(input) > 0]  # Silently drop empty lines
  input <- gsub("[.,;]$", "", input)  # Strip trailing punctuation

  # Track original input for error reporting
  original_input <- input

  # Normalize each DOI (reuses existing normalize_doi_bare)
  normalized <- sapply(input, normalize_doi_bare, USE.NAMES = FALSE)

  # Separate valid from invalid
  valid_idx <- !is.na(normalized)
  valid_dois <- normalized[valid_idx]
  invalid_input <- original_input[!valid_idx]

  # Categorize errors for invalid entries
  invalid_reasons <- sapply(invalid_input, categorize_doi_error, USE.NAMES = FALSE)

  # Detect duplicates in valid set
  dup_table <- table(valid_dois)
  duplicates <- dup_table[dup_table > 1]

  # Return structured list
  list(
    valid = unique(valid_dois),  # Deduplicated
    invalid = data.frame(
      original = invalid_input,
      reason = invalid_reasons,
      stringsAsFactors = FALSE
    ),
    duplicates = data.frame(
      doi = names(duplicates),
      count = as.integer(duplicates),
      stringsAsFactors = FALSE
    )
  )
}
```

### Pattern 2: Delimiter Splitting with Regex

**What:** Use regex character class `[\n,]` to split on newlines OR commas in a single operation.

**When to use:** User may paste different formats (comma-separated from CSV, newline-separated from text list).

**Example:**
```r
# Source: R-bloggers strsplit tutorial
split_doi_input <- function(input) {
  # Split on newline OR comma
  # Use fixed=FALSE for regex, perl=TRUE for performance
  parts <- strsplit(input, "[\n,]+", perl = TRUE)[[1]]

  # Trim whitespace from each part
  trimws(parts)
}
```

### Pattern 3: Categorized Error Messages

**What:** Instead of returning NA for all invalid DOIs, categorize the error (missing prefix, invalid registrant, etc.) for user feedback.

**When to use:** Bulk import UI needs to show "10 invalid: 7 missing '10.' prefix, 3 malformed suffixes" instead of generic "10 failed".

**Example:**
```r
categorize_doi_error <- function(doi_string) {
  # Already trimmed and non-empty at this point

  # Check for DOI prefix
  if (!grepl("^10\\.", doi_string, perl = TRUE)) {
    return("missing_prefix")
  }

  # Check for valid registrant (4-9 digits after 10.)
  if (!grepl("^10\\.\\d{4,9}/", doi_string, perl = TRUE)) {
    return("invalid_registrant")
  }

  # Check for non-empty suffix
  if (grepl("^10\\.\\d{4,9}/$", doi_string, perl = TRUE)) {
    return("empty_suffix")
  }

  # If we got here, unrecognized format
  return("unrecognized_format")
}
```

### Anti-Patterns to Avoid

- **Parsing publisher URLs (nature.com, sciencedirect.com):** Out of scope per CONTEXT.md. DOI resolver proxies exist but vary by publisher. If users request this, Phase 36+ can extract DOIs from publisher metadata APIs, not URL parsing.
- **Whitespace splitting:** User constraint prohibits splitting on spaces/tabs. `DOI: 10.1234/abc` should parse as one DOI, not two (`DOI:` and `10.1234/abc`).
- **Database deduplication in parser:** Parser reports duplicates within the input list, but does NOT check if DOI exists in library. Phase 35 handles library deduplication separately.
- **Freeform text extraction:** User constraint specifies "clean input" (one DOI per line). Don't build regex to extract DOIs from sentences like "see also doi:10.1234/abc and 10.5678/xyz".

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| URL decoding (`%2F` → `/`) | Custom URL decoder | `utils::URLdecode()` | Handles all percent-encoded characters, tested against edge cases |
| Case folding (Unicode) | Manual `tolower()` | Base R `tolower()` is sufficient | DOI spec uses ASCII case folding; Unicode edge cases rare in DOIs |
| Regex optimization | Custom finite automaton | `perl = TRUE` flag in grepl/gsub | Perl regex engine faster than base POSIX, especially for complex patterns |
| Duplicate detection | Manual loop with seen set | `table()` + filtering | Vectorized, handles counts automatically |

**Key insight:** DOIs have well-defined structure (10.NNNN/suffix) but messy real-world input (URLs, extra spaces, trailing punctuation). Existing `normalize_doi_bare()` handles most normalization; batch parser just needs to orchestrate splitting, normalization, error categorization, and deduplication.

## Common Pitfalls

### Pitfall 1: Case Sensitivity Mismatches

**What goes wrong:** Treating `10.1234/ABC` and `10.1234/abc` as different DOIs causes duplicate imports or missed deduplication.

**Why it happens:** DOI spec says DOIs are case-insensitive (10.1234/ABC resolves same as 10.1234/abc), but databases may store exact case. OpenAlex lowercases all DOIs; Crossref preserves case.

**How to avoid:** Project decision (v2.0) stores DOIs lowercase to match OpenAlex. Parser MUST lowercase all DOIs (`tolower()`) after validation. Existing `normalize_doi_bare()` already does this (L24).

**Warning signs:** Users report "duplicate DOI" errors when importing same paper with different case. Test fixtures should include mixed-case DOIs.

### Pitfall 2: Trailing Punctuation from Copy-Paste

**What goes wrong:** Users copy "10.1234/abc." from PDF (sentence-ending period) or "10.1234/abc," from CSV. Parser treats as invalid DOI because suffix ends with period/comma.

**Why it happens:** DOI suffix can contain periods (e.g., `10.1234/j.abc.2023.01.001`) but CONTEXT.md specifies "auto-fix common issues" including trailing punctuation.

**How to avoid:** Pre-process input with `gsub("[.,;]$", "", input)` to strip trailing `.`, `,`, `;` before validation. This is safe because DOI suffixes never intentionally END with these characters (they're used internally but not at the end).

**Warning signs:** User reports "valid DOI rejected" with trailing punctuation. Test fixtures: `"10.1234/abc."`, `"10.1234/abc,"`, `"10.1234/abc;"`

### Pitfall 3: Whitespace Splitting When User Meant Space-Separated Words

**What goes wrong:** CONTEXT.md says "split on newlines and commas only — no space/tab/semicolon splitting". But `doi: 10.1234/abc` with space after colon should parse as ONE DOI, not fail because of space.

**Why it happens:** `doi:` prefix stripping in `normalize_doi_bare()` uses `gsub("^doi:\\s*", "", doi)` which handles optional whitespace. But if parser splits on spaces first, it would break `doi: 10.1234/abc` into two tokens: `doi:` and `10.1234/abc`.

**How to avoid:** NEVER split on spaces. Only split on `[\n,]+` pattern. Let `normalize_doi_bare()` handle `doi: ` prefix with the `\s*` pattern.

**Warning signs:** User pastes `doi: 10.1234/abc` (with space) and gets invalid error. Test fixture: `"doi: 10.1234/abc"` (space after colon).

### Pitfall 4: Empty Lines Creating Noise in Error Reports

**What goes wrong:** User pastes list with blank lines (formatting from Excel, etc.). Parser reports "N invalid: N empty lines" which clutters UI.

**Why it happens:** `strsplit()` preserves empty strings when consecutive delimiters appear (e.g., `"a\n\nb"` splits to `["a", "", "b"]`).

**How to avoid:** CONTEXT.md specifies "silently ignore empty lines". After splitting, filter with `input <- input[nchar(input) > 0]`. Do this AFTER trimming whitespace so `"   \n   "` also gets removed.

**Warning signs:** UI shows "5 invalid DOIs" but user only pasted 3 DOIs (2 blank lines counted). Test fixtures: `"10.1234/abc\n\n10.5678/xyz"` (blank line in middle).

### Pitfall 5: URL-Encoded DOIs from Web Scraping

**What goes wrong:** User scrapes DOI URLs and gets `https://doi.org/10.1234%2Fabc` (slash encoded as `%2F`). Parser fails to match `10.NNNN/suffix` pattern.

**Why it happens:** Web browsers and scripts may URL-encode DOI suffixes when constructing URLs.

**How to avoid:** Decode URLs before stripping prefixes. Add `doi <- utils::URLdecode(doi)` before normalization. This is safe because DOI suffixes may contain URL-encodable characters like parentheses, but are stored unencoded in databases.

**Warning signs:** User reports "valid DOI URL rejected" when pasting from browser. Test fixture: `"https://doi.org/10.1234%2Fabc"`

## Code Examples

Verified patterns from official sources and existing project code:

### Existing DOI Normalization (Project Code)

```r
# Source: R/utils_doi.R (lines 14-32)
normalize_doi_bare <- function(doi) {
  if (is.null(doi) || is.na(doi) || doi == "") return(NA_character_)

  # Remove common URL prefixes
  doi <- gsub("^https?://doi\\.org/", "", doi, ignore.case = TRUE)
  doi <- gsub("^https?://dx\\.doi\\.org/", "", doi, ignore.case = TRUE)
  doi <- gsub("^doi:\\s*", "", doi, ignore.case = TRUE)
  doi <- trimws(doi)

  # Lowercase (DOI is case-insensitive but lowercase is convention)
  doi <- tolower(doi)

  # Validate format: must start with "10."
  if (!grepl("^10\\.", doi)) {
    return(NA_character_)
  }

  doi
}
```

### Crossref DOI Validation (Project Code)

```r
# Source: R/utils_doi.R (lines 41-46)
is_valid_doi <- function(doi) {
  if (is.null(doi) || is.na(doi)) return(FALSE)

  # Crossref pattern: matches 74.4M out of 74.9M DOIs
  grepl("^10\\.\\d{4,9}/[-._;()/:a-z0-9]+$", doi, ignore.case = TRUE)
}
```

### Splitting on Multiple Delimiters (R-bloggers)

```r
# Source: https://www.r-bloggers.com/2024/04/exploring-strsplit-with-multiple-delimiters-in-r/
# Split on newline OR comma using character class
split_doi_input <- function(input) {
  parts <- strsplit(input, "[\n,]+", perl = TRUE)[[1]]
  trimws(parts)
}

# Example:
# split_doi_input("10.1234/abc, 10.5678/xyz\n10.9012/def")
# Returns: ["10.1234/abc", "10.5678/xyz", "10.9012/def"]
```

### URL Decoding Before Normalization

```r
# Source: R base documentation (utils::URLdecode)
# Handle URL-encoded DOIs from web scraping
normalize_doi_bare <- function(doi) {
  if (is.null(doi) || is.na(doi) || doi == "") return(NA_character_)

  # Decode URL encoding first (e.g., %2F -> /)
  doi <- utils::URLdecode(doi)

  # Then proceed with existing normalization...
  doi <- gsub("^https?://doi\\.org/", "", doi, ignore.case = TRUE)
  # ... rest of function
}
```

### Duplicate Detection with table()

```r
# Source: R base documentation (table function)
# Detect duplicates in valid DOI set
detect_duplicates <- function(dois) {
  dup_table <- table(dois)
  duplicates <- dup_table[dup_table > 1]

  data.frame(
    doi = names(duplicates),
    count = as.integer(duplicates),
    stringsAsFactors = FALSE
  )
}

# Example:
# detect_duplicates(c("10.1234/abc", "10.5678/xyz", "10.1234/abc"))
# Returns: data.frame(doi = "10.1234/abc", count = 2)
```

### Auto-Fix Trailing Punctuation

```r
# Strip trailing periods, commas, semicolons
# Safe because DOI suffixes never intentionally end with these
preprocess_doi_input <- function(input) {
  input <- trimws(input)                    # Remove leading/trailing whitespace
  input <- gsub("[.,;]$", "", input)        # Strip trailing punctuation
  input <- input[nchar(input) > 0]          # Remove empty strings
  input
}

# Example:
# preprocess_doi_input(c("10.1234/abc.", "  10.5678/xyz,  ", "", "10.9012/def"))
# Returns: ["10.1234/abc", "10.5678/xyz", "10.9012/def"]
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single DOI validation only | Batch parsing with categorized errors | Phase 33 (2026-02) | Enables bulk import workflows (Phase 35/36/37) |
| dx.doi.org URL format | doi.org URL format | 2020 (DataCite) | Both still work; parser supports both via regex |
| Case-sensitive DOI storage | Lowercase normalization | v2.0 (2026-02-05) | Matches OpenAlex API, prevents duplicate imports |
| Ad-hoc validation in modules | Centralized utils_doi.R | v2.0 (2026-02-05) | Reusable across import/export/audit workflows |

**Deprecated/outdated:**
- dx.doi.org as "preferred" resolver: DataCite now recommends doi.org (both still work, parser supports both)
- Uppercase DOI display: Modern accessibility guidelines favor lowercase (case-insensitive internally, lowercase for display)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | None — tests run from `tests/testthat/` directory |
| Quick run command | `Rscript --vanilla -e "testthat::test_file('tests/testthat/test-utils_doi.R')"` |
| Full suite command | `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BULK-01 | Parse comma-separated DOI list | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| BULK-01 | Parse newline-separated DOI list | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| BULK-01 | Recognize DOI URL formats (doi.org, dx.doi.org) | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| BULK-01 | Strip doi: prefix with optional space | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| BULK-02 | Handle CSV file content (comma-separated) | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| BULK-03 | Parse DOIs extracted from .bib (Phase 36 integration) | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| AUDIT-06 | Parse single DOI string (one-click import) | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| Foundation | Normalize to lowercase | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| Foundation | Detect and report duplicates | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| Foundation | Categorize invalid DOIs (missing_prefix, invalid_registrant, empty_suffix, unrecognized_format) | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| Foundation | Auto-fix trailing punctuation | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| Foundation | Silently ignore empty lines | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |
| Foundation | Handle URL-encoded DOIs (%2F) | unit | `testthat::test_file('tests/testthat/test-utils_doi.R')` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `Rscript --vanilla -e "testthat::test_file('tests/testthat/test-utils_doi.R')"`
- **Per wave merge:** Full suite: `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-utils_doi.R` — covers all Foundation requirements (parsing, validation, normalization, error categorization)
- [ ] Test fixtures for edge cases: mixed formats, trailing punctuation, empty lines, URL encoding, duplicate detection

## Open Questions

1. **Should parser validate DOI registrant prefix against IANA registry?**
   - What we know: Crossref regex allows 4-9 digit registrants, covers 74.4M/74.9M DOIs. Some legacy DOIs (e.g., Wiley 10.1002) have non-standard formats.
   - What's unclear: Does validating against IANA registry (10.1000-10.99999 as of 2026) catch typos, or does it reject valid legacy DOIs?
   - Recommendation: SKIP IANA validation. Use Crossref regex (existing `is_valid_doi()`) which handles 99.3% of DOIs. If user reports rejected DOI, investigate and add to relaxed regex like Wiley pattern.

2. **Should parser handle DOI URLs with query parameters (e.g., `https://doi.org/10.1234/abc?locatt=label:secondary`)?**
   - What we know: Some DOI resolver services append query params for tracking or alternate representations.
   - What's unclear: How common are these in user workflows (copy-paste from browser, citation manager exports)?
   - Recommendation: YES, strip query params. Add `doi <- sub("\\?.*$", "", doi)` after URL decoding and before prefix stripping. Low risk (DOI suffixes can't contain `?`), handles edge case.

3. **Should deduplication be case-sensitive BEFORE normalization, to warn users about mixed-case input?**
   - What we know: DOIs are case-insensitive internally, stored lowercase in database. `10.1234/ABC` and `10.1234/abc` are same DOI.
   - What's unclear: Should parser warn "You have 10.1234/ABC twice (once uppercase, once lowercase)" or silently dedupe after lowercase?
   - Recommendation: SILENT deduplication. After normalization, dedupe with `unique()` and report counts in `$duplicates`. User sees "10.1234/abc: 2 occurrences" which is clear enough. Showing pre-normalization case differences adds UI complexity for rare edge case.

## Sources

### Primary (HIGH confidence)
- [Crossref DOI Regular Expressions](https://www.crossref.org/blog/dois-and-matching-regular-expressions/) - Official regex patterns, coverage statistics (74.4M/74.9M)
- [DOI Handbook - Case Insensitivity](https://www.doi.org/doi-handbook/HTML/case-insensitivity.html) - Official DOI spec on case folding and normalization
- [DataCite DOI Display Guidelines](https://support.datacite.org/docs/datacite-doi-display-guidelines) - Modern best practices (lowercase, accessibility)
- [R Base Documentation - grep](https://stat.ethz.ch/R-manual/R-devel/library/base/help/grep.html) - grepl/gsub performance (`perl = TRUE`)
- Existing project code: `R/utils_doi.R` (normalize_doi_bare, is_valid_doi), migration 005_add_doi_column.sql

### Secondary (MEDIUM confidence)
- [R-bloggers: strsplit with Multiple Delimiters](https://www.r-bloggers.com/2024/04/exploring-strsplit-with-multiple-delimiters-in-r/) - Character class syntax for newline/comma splitting
- [bib2df CRAN Package](https://cran.r-project.org/web/packages/bib2df/vignettes/bib2df.html) - BibTeX parsing for Phase 36 (extracts DOI field, feeds to Phase 33 parser)
- [Statology: R strsplit Multiple Delimiters](https://www.statology.org/r-strsplit-multiple-delimiters/) - Cross-verified with R-bloggers tutorial

### Tertiary (LOW confidence)
- None — all findings verified with official documentation or existing project code

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Uses existing project infrastructure (base R, testthat, utils_doi.R), zero new dependencies
- Architecture: HIGH - Extends proven single-DOI pattern to batch processing, reuses normalize_doi_bare() and is_valid_doi()
- Pitfalls: HIGH - Based on Crossref official regex issues, DOI spec case-insensitivity section, and common copy-paste errors from real-world workflows
- Edge cases: MEDIUM - URL encoding and query params identified as potential issues, but user workflows unclear; recommend implementing with low risk

**Research date:** 2026-02-25
**Valid until:** 2026-05-25 (90 days, DOI spec stable, R base functions stable)
