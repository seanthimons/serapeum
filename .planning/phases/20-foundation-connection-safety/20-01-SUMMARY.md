---
phase: 20-foundation-connection-safety
plan: 01
subsystem: ragnar
tags: [tdd, helpers, metadata, path-construction]
dependencies:
  requires: []
  provides: [notebook-path-helper, origin-metadata-codec]
  affects: [ragnar-store-management]
tech_stack:
  added: []
  patterns: [pure-functions, defensive-validation, graceful-degradation]
key_files:
  created:
    - tests/testthat/test-ragnar-helpers.R
  modified:
    - R/_ragnar.R
decisions:
  - Use pipe-delimited format with key=value pairs for metadata encoding (human-readable, debuggable)
  - Decode gracefully falls back to "general" section on any parse failure (no-fail reads)
  - Path construction is pure function without DB lookups (FNDTN-01 requirement)
metrics:
  duration: 2m 17s
  completed: 2026-02-16
  tasks: 2
  commits: 2
  tests_added: 7
  tests_passing: 30
---

# Phase 20 Plan 01: Ragnar Path and Metadata Helpers Summary

**One-liner:** Pure helper functions for deterministic notebook-path construction and section-hint metadata encoding via pipe-delimited origin format

## What Was Built

Implemented three tested pure functions in `R/_ragnar.R` to support per-notebook ragnar stores and section-targeted RAG:

1. **get_notebook_ragnar_path(notebook_id)** - Constructs `data/ragnar/{notebook_id}.duckdb` paths deterministically without database lookups
2. **encode_origin_metadata(base_origin, section_hint, doi, source_type)** - Encodes metadata into pipe-delimited format: `base|section=X|doi=Y|type=Z`
3. **decode_origin_metadata(origin)** - Parses encoded format with graceful fallback to "general" section on malformed input

## Verification Results

All success criteria met:

- get_notebook_ragnar_path produces deterministic paths from notebook IDs without DB lookups (FNDTN-01)
- Metadata encode/decode round-trips section_hint, DOI, and source_type perfectly (FNDTN-02)
- Malformed origin strings gracefully fall back to "general" section (no crashes on bad data)
- All 30 tests pass: 7 new helper tests + 23 existing ragnar tests (no regression)

**Manual verification:**
```r
get_notebook_ragnar_path("test-uuid")
# => "data/ragnar/test-uuid.duckdb"

encoded <- encode_origin_metadata("test.pdf#page=1", "methods", "10.1234/test", "pdf")
# => "test.pdf#page=1|section=methods|doi=10.1234/test|type=pdf"

decoded <- decode_origin_metadata(encoded)
# => list(base_origin="test.pdf#page=1", section_hint="methods", doi="10.1234/test", source_type="pdf")

decode_origin_metadata("garbage")
# => list(section_hint="general", ...) # graceful fallback
```

## Deviations from Plan

None - plan executed exactly as written. TDD red-green cycle followed precisely.

## Implementation Notes

**Encoding format decision:** User chose pipe-delimited with `key=value` pairs for human readability and debuggability. Alternative JSON encoding was rejected as harder to visually inspect in DuckDB tools.

**Validation strategy:** Validate on write (encode checks non-empty section_hint and source_type), trust on read (decode only validates format, gracefully falls back). DOI is optional and omitted entirely from encoded string when NULL (not encoded as `doi=NA`).

**Path construction:** Hardcoded `data/ragnar/` directory structure. No config indirection needed since this is internal storage, not user-facing. Notebooks.id is already UUID (confirmed via user decision), so no new column needed.

## Task Breakdown

| Task | Type | Description | Commit | Duration |
|------|------|-------------|--------|----------|
| 1 | RED | Write failing tests for 3 helper functions | 3f55cc1 | ~1m |
| 2 | GREEN | Implement helpers to pass all tests | 48f4e50 | ~1m |

## Testing Coverage

**New test file:** `tests/testthat/test-ragnar-helpers.R` (7 test cases, 30 assertions total)

**get_notebook_ragnar_path:**
- Valid UUIDs produce expected paths
- Simple IDs work
- NULL throws error
- Empty string throws error

**encode_origin_metadata:**
- Full metadata encoding with all fields
- Default parameters (section="general", type="pdf")
- DOI omitted when NULL (not encoded as "NA")

**decode_origin_metadata:**
- Round-trip preserves all fields
- Handles missing DOI (returns NA_character_)
- Graceful fallback on malformed input (plain string, empty string)
- Handles DOIs with special characters (slashes, dots)

## Integration Points

**Provides for future plans:**
- `get_notebook_ragnar_path` enables FNDTN-03 (open/create per-notebook stores)
- `encode_origin_metadata` enables FNDTN-04 (store chunks with section hints)
- `decode_origin_metadata` enables SRCH-02 (section-targeted retrieval filters)

**No dependencies:** These are pure helper functions with no external state.

## Next Steps

With path and metadata helpers complete, the foundation is ready for:
- Plan 02: Connection safety (single-active-store pattern, DuckDB locking prevention)
- Future CRUD operations using these helpers

## Self-Check

Verifying all claimed artifacts exist and commits are real:

- File `tests/testthat/test-ragnar-helpers.R` exists: VERIFIED
- File `R/_ragnar.R` modified with 3 new functions: VERIFIED
- Commit `3f55cc1` (RED phase): VERIFIED
- Commit `48f4e50` (GREEN phase): VERIFIED
- All 7 new tests pass: VERIFIED (30 total tests passing)
- Functions callable without errors: VERIFIED

## Self-Check: PASSED

All artifacts delivered, all tests pass, all commits exist.
