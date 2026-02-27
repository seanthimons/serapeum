# Plan 35-01 Summary: DB Schema + Business Logic

**Status:** Complete
**Completed:** 2026-02-26

## What Was Built

Backend infrastructure for bulk DOI imports:
1. **DuckDB schema** — `import_runs` and `import_run_items` tables in `init_schema()` with 7 CRUD helper functions
2. **BibTeX DOI extraction** — `extract_dois_from_bib()` using base R regex to pull DOIs from .bib content
3. **Duplicate detection** — `get_notebook_dois()` queries existing DOIs in a notebook for pre-import filtering
4. **Import orchestration** — `run_bulk_import()` designed for mirai worker execution, handles API calls + DB persistence
5. **Progress reporting** — `write_import_progress()` / `read_import_progress()` for cross-process progress
6. **Time estimation** — `estimate_import_time()` returns human-readable time strings

## Key Files

### Created
- `R/bulk_import.R` — All business logic functions (6 exported functions)
- `tests/testthat/test-bulk_import.R` — 32 tests covering BibTeX extraction, time estimation, progress I/O, duplicate detection

### Modified
- `R/db.R` — Added `import_runs` + `import_run_items` tables and 7 CRUD helpers

## Self-Check: PASSED

- [x] import_runs and import_run_items tables created in init_schema
- [x] All 7 DB helpers work (create, read, update, delete)
- [x] extract_dois_from_bib handles standard .bib formats
- [x] get_notebook_dois returns lowercase DOI vector
- [x] estimate_import_time returns human-readable strings
- [x] Progress file round-trips correctly
- [x] All 32 tests pass

## Decisions Made

- Used base R regex for BibTeX extraction (no new dependencies)
- Progress file format: `"batch|total_batches|found|failed|message"` (separate from citation network's BFS-oriented format)
- Import run created in main session before launching mirai worker (avoids FK issues with worker DB connection)
- Worker opens its own DB connection from db_path parameter (mirai workers can't share connections)
