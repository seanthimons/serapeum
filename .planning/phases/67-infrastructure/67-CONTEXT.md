# Phase 67: Infrastructure - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Make fresh-install database initialization succeed with no migration SQL errors by auditing and fixing idempotency across the existing startup path. This phase covers both versioned migration SQL and overlapping schema/bootstrap behavior in `R/db.R` when that overlap affects fresh-install safety. It does not introduce new product features or replace the migration system.

</domain>

<decisions>
## Implementation Decisions

### Audit Scope
- **D-01:** Audit both `migrations/*.sql` and overlapping schema setup in `R/db.R`. The phase is not limited to standalone SQL files because fresh-install behavior currently depends on the interaction between `init_schema(con)` and `run_pending_migrations(con)`.
- **D-02:** Treat the startup path in `get_db_connection()` as the real contract to harden: `init_schema(con)` runs first, then `run_pending_migrations(con)`. Fixes should make that path safe on a blank database and on subsequent reruns.

### Fresh-Install Strategy
- **D-03:** Keep the current startup architecture for this phase rather than refactoring to a migration-only bootstrap. The goal is to make the existing `init_schema()` + migrations model reliable, not to redesign ownership between them.
- **D-04:** Migration SQL must become idempotent against tables or columns that may already exist because `init_schema()` or earlier migrations created them. Use `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, or equivalent defensive syntax where DuckDB supports it.

### Verification Bar
- **D-05:** Add an automated regression test that exercises the real fresh-install startup path with the actual migration set, not only isolated unit tests of the migration runner.
- **D-06:** Verification must include a rerun/idempotency check: after the fresh database initializes successfully once, running the same startup path again must complete without migration errors.

### Cleanup Breadth
- **D-07:** Broad cleanup is allowed within the migration/idempotency domain. If old migrations, bootstrap behavior, or `init_schema()` overlap are inconsistent or misleading, clean them up as part of this phase rather than limiting changes to the single first failing statement.
- **D-08:** Keep cleanup inside the infrastructure boundary. Broader database redesign, unrelated schema work, or new capabilities remain out of scope.

### the agent's Discretion
- Exact division of responsibility between SQL-file fixes and small `R/db.R` / `R/db_migrations.R` cleanup needed to support idempotency
- Whether some `init_schema()` ad-hoc migrations should be removed, consolidated, or left in place once the startup path is proven safe
- Exact test shape and fixture strategy, as long as it proves fresh install plus rerun behavior with real migrations

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements and roadmap
- `.planning/ROADMAP.md` — Phase 67 goal and success criteria for fresh-install migration idempotency
- `.planning/REQUIREMENTS.md` — `INFR-01` requirement definition and milestone scope
- `.planning/STATE.md` — Current milestone state and note that Phase 67 needs a hands-on read of all migration SQL files

### Migration implementation
- `R/db.R` — Startup path via `get_db_connection()` and overlapping schema/bootstrap logic in `init_schema()`
- `R/db_migrations.R` — Migration tracker, bootstrap behavior, and pending migration execution semantics
- `migrations/001_bootstrap_existing_schema.sql` — Baseline marker migration
- `migrations/002_create_topics_table.sql` — Existing idempotent table/index creation pattern
- `migrations/003_create_cost_log.sql` — Existing idempotent table/index creation pattern
- `migrations/004_create_blocked_journals.sql` — Existing idempotent table/index creation pattern
- `migrations/005_add_doi_column.sql` — Non-idempotent column-add pattern to audit/fix
- `migrations/006_create_citation_networks.sql` — Non-idempotent table/index creation to audit/fix
- `migrations/007_add_section_hint.sql` — Existing `ADD COLUMN IF NOT EXISTS` pattern
- `migrations/008_add_document_metadata.sql` — Non-idempotent column-add pattern to audit/fix
- `migrations/009_add_import_source_column.sql` — Existing `ADD COLUMN IF NOT EXISTS` pattern
- `migrations/010_add_multi_seed_support.sql` — Existing `ADD COLUMN IF NOT EXISTS` pattern
- `migrations/011_add_fwci_to_audit_results.sql` — Existing `ADD COLUMN IF NOT EXISTS` pattern
- `migrations/012_add_duration_ms_to_cost_log.sql` — Non-idempotent column-add pattern to audit/fix
- `migrations/013_create_providers.sql` — Table creation + seed pattern to preserve
- `migrations/014_create_document_figures.sql` — Existing idempotent table creation pattern
- `migrations/015_add_extraction_method.sql` — Existing `ADD COLUMN IF NOT EXISTS` pattern
- `migrations/016_add_presentation_hint.sql` — Existing `ADD COLUMN IF NOT EXISTS` pattern
- `migrations/017_create_oa_usage_log.sql` — Existing idempotent table creation pattern
- `migrations/018_create_prompt_versions.sql` — Non-idempotent table creation to audit/fix
- `migrations/019_retroactive_prompt_versions_index.sql` — Prior corrective migration showing migration hygiene debt
- `migrations/020_add_community_to_network_nodes.sql` — Existing `ADD COLUMN IF NOT EXISTS` pattern

### Verification
- `tests/testthat/test-db-migrations.R` — Existing migration runner tests and the nearest current coverage for startup/migration behavior
- `tests/testthat/test-db.R` — Current startup/schema tests using `get_db_connection()` and `init_schema()`
- `.planning/research/FEATURES.md` — Milestone research calling out migration idempotency as a Phase 67 concern
- `.planning/research/PITFALLS.md` — Existing guardrails for keeping cleanup structural rather than workaround-driven

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `get_db_connection()` in `R/db.R`: the real startup entry point to harden for fresh installs
- `init_schema()` in `R/db.R`: already creates a substantial base schema and contains historical ad-hoc migration behavior
- `get_applied_migrations()`, `bootstrap_existing_database()`, and `run_pending_migrations()` in `R/db_migrations.R`: existing migration runner infrastructure to preserve
- `tests/testthat/test-db-migrations.R`: existing migration test harness with temp migration directories and in-memory DuckDB setup

### Established Patterns
- Versioned SQL migrations live in `migrations/NNN_description.sql`
- Idempotent migration style already exists in several files via `IF NOT EXISTS` and `ON CONFLICT DO NOTHING`
- Startup currently assumes `init_schema()` may create objects before versioned migrations run
- Bootstrap migration `001` is a marker, not a schema-building migration for fresh installs

### Integration Points
- `R/db.R` startup flow is where fresh installs enter the system
- `R/db_migrations.R` controls migration ordering, bootstrap detection, and recording
- Migration SQL files under `migrations/` are the primary repair surface
- `tests/testthat/test-db-migrations.R` and `tests/testthat/test-db.R` are the primary verification surfaces for Phase 67

</code_context>

<specifics>
## Specific Ideas

- Broad cleanup is explicitly allowed, but only inside the migration/idempotency boundary
- Strong verification is required: a real fresh-install startup test plus a rerun test, not only isolated migration-unit assertions
- Keep the existing startup model in place for this phase rather than turning this into a migration-system redesign

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 67-infrastructure*
*Context gathered: 2026-03-27*
