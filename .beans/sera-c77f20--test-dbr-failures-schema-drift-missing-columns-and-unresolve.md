---
title: "test-db.R failures: schema drift — missing columns and unresolved function"
status: completed
type: bug
priority: high
tags:
  - pr-review
created_at: 2026-03-20T20:17:02Z
updated_at: 2026-03-24T18:36:47Z
---

**Source:** PR #163 review — test suite run (2026-03-20)

Multiple failures in `test-db.R` from two root causes:

### 1. `cleanup_figure_files` not found (test-db.R:73)
`delete_notebook()` now calls `cleanup_figure_files()` (from `R/pdf_images.R`), but the test helper setup doesn't source that file. The function is unavailable in the test environment.

**Error:**
```
Error in cleanup_figure_files(id): could not find function "cleanup_figure_files"
```

### 2. Schema drift — `documents` and `abstracts` tables missing new columns
Tests create in-memory DuckDB and run migrations, but the `INSERT INTO documents` and `INSERT INTO abstracts` statements reference columns (`doi`, and potentially others) that don't exist in the test DB schema. Migrations may not be running in order, or recent migrations haven't been added to the test setup.

**Errors:**
```
Binder Error: Table "abstracts" does not have a column with name "doi"
Binder Error: Table "documents" ... (column mismatch)
```

**Affected tests:** test-db.R lines 73, 88, 105, 143, 164, 187, 210, 258 + test-embedding.R:29

**Fix:**
1. Source `R/pdf_images.R` (or at least `cleanup_figure_files`) in the test helper
2. Ensure test DB setup runs all migrations including the latest ones that add `doi` and other columns

**Pre-existing:** These failures exist on the branch prior to the PR #163 fixes.

<!-- migrated from beads: `serapeum-1774459567411-185-c77f2077` | github: https://github.com/seanthimons/serapeum/issues/214 -->
