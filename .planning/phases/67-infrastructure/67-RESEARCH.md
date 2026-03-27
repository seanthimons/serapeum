# Phase 67: Infrastructure - Research

**Researched:** 2026-03-27
**Domain:** DuckDB startup schema bootstrap, versioned SQL migrations, fresh-install idempotency
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: Audit both `migrations/*.sql` and overlapping schema setup in `R/db.R`.
- D-02: Treat `get_db_connection()` as the real startup boundary to harden.
- D-03: Keep the current startup architecture for this phase.
- D-04: Migration SQL must be idempotent against tables, indexes, and columns already created by `init_schema()` or earlier migrations.
- D-05: Add an automated regression test that exercises the real startup path with the actual migration set.
- D-06: Verification must prove rerun behavior after a successful first initialization.
- D-07: Broad cleanup is allowed within the migration/idempotency boundary.
- D-08: Stay inside infrastructure scope.

### the agent's Discretion
- Whether any `R/db.R` ad-hoc migration fragments should be narrowed or aligned with versioned SQL
- Exact split between SQL-file edits and small runner/test harness changes
- Exact test shape, as long as it proves fresh install plus rerun behavior
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INFR-01 | SQL migrations are idempotent on fresh installs (CREATE TABLE IF NOT EXISTS audit) | Supported by migration-file audit, overlap analysis with `init_schema()`, and startup-path regression coverage that executes `get_db_connection()` twice against a clean DB |
</phase_requirements>

---

## Summary

Phase 67 is a migration hygiene and startup-contract hardening phase. The real failure mode is not the migration runner itself; it is that `get_db_connection()` always calls `init_schema(con)` before `run_pending_migrations(con)`, so fresh installs can hit collisions when versioned migrations try to create or alter objects that `init_schema()` already created.

The audit surface is concrete. `migrations/005_add_doi_column.sql`, `006_create_citation_networks.sql`, `008_add_document_metadata.sql`, `012_add_duration_ms_to_cost_log.sql`, and `018_create_prompt_versions.sql` all contain non-idempotent statements today. Several later migrations already demonstrate the correct pattern (`007`, `009`, `010`, `011`, `015`, `016`, `020`), so planning should reuse the repo's own style rather than invent a new convention.

The phase should be split into two executable slices. First, audit and fix the overlapping schema/migration surface: normalize the vulnerable migration SQL, confirm whether any `init_schema()` table definitions still need to be reconciled with migration assumptions, and preserve the bootstrap marker behavior in migration `001`. Second, add regression coverage that uses the real startup path with the actual migration directory, exercising a clean DB on first run and the same DB on second run.

**Primary recommendation:** Create two plans. Wave 1 fixes the migration and bootstrap surface; Wave 2 adds startup-path regression tests and documentation of the audit finding.

---

## Standard Stack

| Library | Purpose | Notes |
|---------|---------|-------|
| DuckDB via `DBI` | Startup schema + SQL migration execution | Existing runtime surface |
| Base R + testthat | Regression coverage for startup/migration behavior | Existing test harness already sources `db.R` and `db_migrations.R` |
| Existing migration runner in `R/db_migrations.R` | Ordered file execution and schema tracking | Infrastructure is adequate; SQL defensiveness is the weak point |

No new packages are needed.

---

## Architecture Patterns

### Startup Contract to Preserve
`R/db.R` currently defines the canonical startup path:

```r
con <- dbConnect(duckdb(), dbdir = path)
init_schema(con)
run_pending_migrations(con)
```

That ordering is a locked decision for this phase.

### Existing Idempotent Migration Style
The repo already contains good reference patterns:

- `migrations/002_create_topics_table.sql` uses `CREATE TABLE IF NOT EXISTS` and `CREATE INDEX IF NOT EXISTS`
- `migrations/007_add_section_hint.sql` uses `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`
- `migrations/009_add_import_source_column.sql`, `010_add_multi_seed_support.sql`, `011_add_fwci_to_audit_results.sql`, `015_add_extraction_method.sql`, `016_add_presentation_hint.sql`, and `020_add_community_to_network_nodes.sql` use the same defensive column-add approach
- `migrations/019_retroactive_prompt_versions_index.sql` shows the intended corrective style

### Fresh-Install Risk Pattern
The risky migrations currently look like this:

- `005_add_doi_column.sql`: `ALTER TABLE abstracts ADD COLUMN doi VARCHAR;`
- `006_create_citation_networks.sql`: `CREATE TABLE ...` and `CREATE INDEX ...` with no `IF NOT EXISTS`
- `008_add_document_metadata.sql`: five non-idempotent `ALTER TABLE documents ADD COLUMN ...`
- `012_add_duration_ms_to_cost_log.sql`: non-idempotent `ALTER TABLE cost_log ADD COLUMN duration_ms INTEGER;`
- `018_create_prompt_versions.sql`: non-idempotent `CREATE TABLE prompt_versions (...)`

That is why the planner must explicitly cover overlap analysis in `R/db.R`, not just grep migration files.

### Regression Harness Direction
Existing tests already cover migration helper behavior (`tests/testthat/test-db-migrations.R`) and startup/schema setup (`tests/testthat/test-db.R`), but they do not yet prove the full fresh-install contract end-to-end. The correct regression shape is:

1. Create a temp DuckDB file
2. Invoke `get_db_connection()` so `init_schema()` plus `run_pending_migrations()` run through the real entrypoint
3. Assert migration tracker state and representative tables/columns
4. Close the connection and invoke `get_db_connection()` again against the same database
5. Assert second-run startup is safe and leaves the schema valid

---

## Exact Audit Surface

| File | Current Risk | What Planning Must Cover |
|------|--------------|--------------------------|
| `R/db.R` | Creates base tables and ad-hoc migration columns before versioned migrations run | Confirm overlap with vulnerable migration files |
| `R/db_migrations.R` | Assumes SQL files are safe to re-run against current schema | Preserve runner behavior; only adjust if tests expose a real bootstrap edge |
| `migrations/005_add_doi_column.sql` | Non-idempotent column add | Convert to `ADD COLUMN IF NOT EXISTS` |
| `migrations/006_create_citation_networks.sql` | Three tables and two indexes created without `IF NOT EXISTS` | Make all table/index creation defensive |
| `migrations/008_add_document_metadata.sql` | Five non-idempotent column adds | Normalize all five to `IF NOT EXISTS` |
| `migrations/012_add_duration_ms_to_cost_log.sql` | Non-idempotent column add | Convert to `IF NOT EXISTS` |
| `migrations/018_create_prompt_versions.sql` | Non-idempotent table creation | Make table creation defensive |
| `tests/testthat/test-db-migrations.R` | Good helper coverage but missing end-to-end startup/rerun proof | Add a real fresh-install and rerun test using actual migrations |
| `tests/testthat/test-db.R` | Exercises `get_db_connection()` but not migration idempotency outcomes | Extend or add tests to cover blank DB startup with migrations fully applied |

---

## Common Pitfalls

### Pitfall 1: Fixing Only the First Known Offender
**What goes wrong:** A narrow fix to one migration may unblock one startup path while leaving later migrations capable of failing on the next clean install.
**How to avoid:** The plan must enumerate the full risky migration list and require a repo-wide audit of all migration statements in scope.

### Pitfall 2: Forgetting `init_schema()` Overlap
**What goes wrong:** Changing SQL files alone without checking `R/db.R` can leave bootstrap-owned tables or columns semantically out of sync with the migration layer.
**How to avoid:** Every execution task touching migrations should read `R/db.R` and `R/db_migrations.R` first.

### Pitfall 3: Testing Only Helper Paths
**What goes wrong:** `apply_migration()` unit tests can pass while the app still fails on first-run startup because the runner is fine but the startup sequence conflicts.
**How to avoid:** Add at least one regression test that calls `get_db_connection()` on a clean DB file and then repeats that call.

---

## Validation Architecture

| Property | Value |
|----------|-------|
| Framework | testthat |
| Config file | `tests/testthat.R` |
| Quick run command | `"C:\\Program Files\\R\\R-4.5.1\\bin\\Rscript.exe" -e "testthat::test_file('tests/testthat/test-db-migrations.R')"` |
| Focused startup-path command | `"C:\\Program Files\\R\\R-4.5.1\\bin\\Rscript.exe" -e "testthat::test_file('tests/testthat/test-db.R')"` |
| Full suite command | `"C:\\Program Files\\R\\R-4.5.1\\bin\\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Notes |
|--------|----------|-----------|-------|
| INFR-01 | Clean startup on a brand-new DB applies all migrations without SQL errors | integration | Must call `get_db_connection()` using the real migration directory |
| INFR-01 | Second startup against the same DB succeeds without duplicate-object errors | integration | Must re-open the same DB after first-run success |
| INFR-01 | Vulnerable migrations are written with idempotent syntax | structural + integration | Structural grep checks support, but passing startup-path tests are the real gate |

---

## Sources

- `R/db.R`
- `R/db_migrations.R`
- `migrations/005_add_doi_column.sql`
- `migrations/006_create_citation_networks.sql`
- `migrations/008_add_document_metadata.sql`
- `migrations/012_add_duration_ms_to_cost_log.sql`
- `migrations/018_create_prompt_versions.sql`
- `migrations/019_retroactive_prompt_versions_index.sql`
- `tests/testthat/test-db-migrations.R`
- `tests/testthat/test-db.R`
- `.planning/phases/67-infrastructure/67-CONTEXT.md`

---

**Research date:** 2026-03-27
