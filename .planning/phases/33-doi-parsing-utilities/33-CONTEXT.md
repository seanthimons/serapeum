# Phase 33: DOI Parsing Utilities - Context

**Gathered:** 2026-02-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Provide robust DOI parsing, validation, and normalization utility functions for downstream bulk import (Phases 35-36) and citation audit (Phase 37) workflows. This is a pure infrastructure phase — no UI. Functions live in R utility files and are called by Shiny modules in later phases.

</domain>

<decisions>
## Implementation Decisions

### Input Formats
- Recognize DOI URL patterns: `https://doi.org/...`, `http://doi.org/...`, `https://dx.doi.org/...`, `http://dx.doi.org/...`
- Do NOT parse publisher-specific URLs (nature.com, sciencedirect.com, etc.)
- Split input on newlines and commas only — no space/tab/semicolon splitting
- Recognize and strip `doi:` and `DOI:` prefix scheme (e.g., `doi:10.1234/abc`)
- Expect clean input (one DOI per line or comma-separated) — no freeform text extraction
- Accept both single DOI string and character vector input — auto-detect

### Output Structure
- Return structured list with three components:
  - `$valid` — character vector of normalized (bare, lowercase) DOIs
  - `$invalid` — data frame with columns: `original` (input string), `reason` (categorized error)
  - `$duplicates` — data frame with columns: `doi` (normalized), `count` (occurrences)
- Deduplicate valid DOIs — return unique set in `$valid`, report removed dupes in `$duplicates`
- Normalize all DOIs to lowercase (matches OpenAlex handling)
- No library/database checking — parsing only, Phase 35 handles library dedup

### Error Behavior
- Structural validation: DOI must match pattern `10.NNNN/suffix` (numeric registrant prefix, non-empty suffix)
- Categorized error reasons per invalid entry: `missing_prefix`, `invalid_registrant`, `empty_suffix`, `unrecognized_format`
- Auto-fix common issues: trim whitespace, strip trailing periods/commas, handle `DOI: ` with extra space
- Silently ignore empty lines and whitespace-only lines (no error reporting for blanks)

### Claude's Discretion
- Exact regex patterns for DOI matching
- Internal function decomposition (single function vs helper pipeline)
- Test fixture design and edge case selection
- Whether to use base R or tidyverse for string manipulation

</decisions>

<specifics>
## Specific Ideas

- Parser should be reusable by Phase 36 (BibTeX import) — BibTeX extractor pulls DOI strings and feeds them into this same parser, not a separate resolver
- Phase 37 (Citation Audit) may validate individual DOIs, so single-DOI input support matters

</specifics>

<deferred>
## Deferred Ideas

- **BibTeX DOI extraction → Phase 36 (FLAGGED FOR REVIEW):** Phase 36 must reuse Phase 33's DOI parser for extracted DOIs rather than building a separate DOI resolver. This was explicitly discussed — single parsing pipeline, not multiple resolvers.
- Publisher-specific URL parsing (nature.com, sciencedirect.com embeds) — add to backlog if users request it
- Freeform text DOI extraction (from paragraphs/abstracts) — future enhancement if needed

</deferred>

---

*Phase: 33-doi-parsing-utilities*
*Context gathered: 2026-02-25*
