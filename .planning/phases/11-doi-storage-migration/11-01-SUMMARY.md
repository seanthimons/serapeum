---
phase: 11-doi-storage-migration
plan: 01
subsystem: database-schema-migration
tags: [doi, storage, migration, normalization, backfill]

dependency_graph:
  requires:
    - existing migration infrastructure (db_migrations.R)
    - OpenAlex API DOI extraction (api_openalex.R:181-186)
  provides:
    - DOI column in abstracts table
    - normalize_doi_bare() utility function
    - DOI storage on paper save
    - backfill_dois() for legacy papers
  affects:
    - 12-citation-export (requires DOI for BibTeX/RIS generation)
    - 13-seeded-discovery (uses DOI as seed for discovery)

tech_stack:
  added:
    - migrations/005_add_doi_column.sql (ALTER TABLE abstracts ADD COLUMN doi)
    - R/utils_doi.R (DOI normalization and citation key generation)
  patterns:
    - bare DOI storage format (10.xxxx/yyyy, not https://doi.org/...)
    - nullable column for backward compatibility
    - batch backfill via OpenAlex API (50 papers/batch)

key_files:
  created:
    - migrations/005_add_doi_column.sql
    - R/utils_doi.R
  modified:
    - R/db.R (create_abstract, backfill_dois, get_doi_backfill_status)
    - R/mod_search_notebook.R (pass doi to create_abstract)

decisions:
  - Store DOI in bare format (10.xxxx/yyyy) not URL format for BibTeX compatibility
  - Use nullable column to avoid migration failures on existing databases
  - Separate normalize_doi_bare() from existing normalize_doi() to avoid naming conflict
  - Batch backfill for performance (50 papers at a time, not synchronous in migration)

metrics:
  duration: 4 minutes
  tasks_completed: 2
  files_created: 2
  files_modified: 2
  commits: 2
  completed_date: 2026-02-12
---

# Phase 11 Plan 01: DOI Storage Infrastructure Summary

**One-liner:** Added DOI column to abstracts table with normalization utilities and batch backfill for legacy papers

## What Was Built

### Migration 005: DOI Column Addition
- Added nullable `doi VARCHAR` column to abstracts table
- Created index on DOI column for fast lookups in export workflows
- Migration applies cleanly to both fresh and existing databases

### DOI Normalization Utilities (R/utils_doi.R)
Three exported functions for DOI handling:

1. **normalize_doi_bare()** - Strips URL prefixes (https://doi.org/, https://dx.doi.org/, doi:), lowercases, validates "10." prefix, returns bare DOI format (10.xxxx/yyyy) for storage
2. **is_valid_doi()** - Validates DOI using Crossref-recommended regex pattern (matches 99.3% of DOIs)
3. **generate_citation_key()** - Fallback for legacy papers without DOI (title_words_year format)

### Updated create_abstract() Function
- Added `doi` parameter to function signature
- Normalizes DOI before INSERT using normalize_doi_bare()
- Handles NULL/NA/empty DOI gracefully (stores as NA_character_)

### DOI Save Path Integration
- mod_search_notebook.R now passes `doi = paper$doi` to create_abstract()
- OpenAlex API already extracts DOI at api_openalex.R:181-186 (strips https://doi.org/ prefix)
- New papers automatically have DOI stored in normalized bare format

### Background Backfill Functions
Two functions added to R/db.R:

1. **backfill_dois()** - Fetches DOIs from OpenAlex API for papers with NULL DOI in batches of 50, normalizes with normalize_doi_bare(), updates database
2. **get_doi_backfill_status()** - Returns counts (total_papers, has_doi, missing_doi) for UI progress tracking

## Deviations from Plan

None - plan executed exactly as written.

## Key Technical Decisions

### Decision 1: Bare DOI vs URL Format
**Context:** OpenAlex returns DOI as full URL (https://doi.org/10.xxxx/yyyy). Should we store URL or bare DOI?

**Decision:** Store bare DOI format (10.xxxx/yyyy) in database, generate URL on display.

**Rationale:** BibTeX export expects bare DOI in `doi` field. Citation managers expect bare format. Crossref API accepts both but recommends bare. Storage efficiency (shorter strings).

**Impact:** All DOI storage uses normalize_doi_bare() which strips URL prefix and returns bare format.

### Decision 2: Nullable vs NOT NULL Column
**Context:** DuckDB doesn't support adding NOT NULL columns to populated tables.

**Decision:** Use nullable DOI column, handle NULL in application code.

**Rationale:** Existing databases have thousands of papers without DOI. Migration with NOT NULL constraint would fail. Backfill is async (not synchronous in migration). Application code already handles NULL gracefully.

**Impact:** Migration 005 uses `ALTER TABLE abstracts ADD COLUMN doi VARCHAR` (no NOT NULL, no DEFAULT). create_abstract() stores NA_character_ for NULL/NA/empty DOI.

### Decision 3: Function Naming (normalize_doi_bare vs normalize_doi)
**Context:** api_openalex.R already has normalize_doi() function (line 417) that returns full URL format for API lookups.

**Decision:** Create separate normalize_doi_bare() function in utils_doi.R that returns bare format for storage.

**Rationale:** Avoid naming conflict and breaking changes. normalize_doi() serves different purpose (API lookups need full URL). normalize_doi_bare() serves storage needs (bare format). Clear naming convention.

**Impact:** No conflicts between functions. api_openalex.R continues using normalize_doi() for API. db.R uses normalize_doi_bare() for storage.

## Self-Check: PASSED

### Files Created
✓ FOUND: migrations/005_add_doi_column.sql
✓ FOUND: R/utils_doi.R

### Files Modified
✓ FOUND: R/db.R (create_abstract updated, backfill functions added)
✓ FOUND: R/mod_search_notebook.R (doi parameter added to create_abstract call)

### Commits
✓ FOUND: 1e3ea16 (Task 1: DOI storage infrastructure)
✓ FOUND: 911245d (Task 2: Wire DOI through save path and add backfill)

### Functions Exported
✓ FOUND: normalize_doi_bare() in utils_doi.R
✓ FOUND: is_valid_doi() in utils_doi.R
✓ FOUND: generate_citation_key() in utils_doi.R
✓ FOUND: backfill_dois() in db.R
✓ FOUND: get_doi_backfill_status() in db.R

### Key Integrations
✓ FOUND: doi parameter in create_abstract() signature (db.R:542)
✓ FOUND: normalize_doi_bare() call in create_abstract() (db.R:577)
✓ FOUND: doi = paper$doi in mod_search_notebook.R (line 1391)

All files exist, all functions implemented, all integrations complete.

## Next Steps

Phase 11 Plan 02 will add DOI display to abstract preview UI with graceful degradation for legacy papers (show citation key fallback when DOI is NULL).
