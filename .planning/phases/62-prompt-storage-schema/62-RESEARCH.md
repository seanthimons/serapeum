# Phase 62: Prompt Storage Schema - Research

**Researched:** 2026-03-20
**Domain:** DuckDB schema migration (R/DBI)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Table name: `prompt_versions`
- Composite primary key: (`preset_slug`, `version_date`)
- Columns: `preset_slug VARCHAR NOT NULL`, `version_date DATE NOT NULL`, `prompt_text TEXT NOT NULL`, `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`
- One version per preset per day — editing the same preset twice in one day overwrites (UPSERT)
- No separate `is_active` flag — the most recent `version_date` per slug is the active version
- Use existing preset type strings as slugs: summarize, keypoints, studyguide, outline, conclusions, research_questions, literature_review, methodology, gap_analysis, slides
- No enum constraint in the schema — new presets can be added without migration
- Slugs match the keys used in `generate_preset()` and dedicated generator functions in R/rag.R
- No rows seeded for defaults — absence of a row means "use the hardcoded default from R/rag.R"
- Migration file: `011_create_prompt_versions.sql`
- Follows existing pattern: 3-digit prefix, `apply_migration()` in R/db_migrations.R
- Single CREATE TABLE statement + composite primary key constraint

### Claude's Discretion
- Whether to add an index on `preset_slug` alone (likely unnecessary given small table size)
- Exact UPSERT syntax (INSERT OR REPLACE vs ON CONFLICT)

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PRMT-04 | Edited prompts stored in DuckDB with date-versioned slugs | Migration 011 creates `prompt_versions` table with (`preset_slug`, `version_date`) composite PK, auto-applied by existing `run_pending_migrations()` on startup |
</phase_requirements>

## Summary

This phase adds a single DuckDB migration — `011_create_prompt_versions.sql` — to create a `prompt_versions` table. The table stores user-edited AI preset prompts keyed by a preset slug and a date, enabling date-versioned history retrieval and one-row-per-day-per-preset semantics via UPSERT.

The migration system is fully in place (`run_pending_migrations()` in `R/db_migrations.R` auto-discovers and applies files named `NNN_description.sql` on startup). Migration 010 is the current head, so this migration is number 011. No R code changes are needed in this phase — Phase 63 will add the read/write functions.

**Primary recommendation:** Write `migrations/011_create_prompt_versions.sql` following the exact pattern of migrations 003 and 006 (CREATE TABLE with explicit PRIMARY KEY constraint). Use `INSERT OR REPLACE` for the UPSERT semantics required by the one-version-per-day-per-preset rule.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DuckDB (via DBI) | already installed | Relational storage for prompt history | App's existing database engine |
| R/db_migrations.R | project file | Migration runner | Already handles transaction wrapping, semicolon splitting, version tracking |

No new packages required. This phase is pure SQL + one migration file.

## Architecture Patterns

### Recommended Project Structure

```
migrations/
├── 001_bootstrap_existing_schema.sql
├── ...
├── 010_add_multi_seed_support.sql
└── 011_create_prompt_versions.sql   ← NEW
```

No R source changes in this phase.

### Pattern 1: DuckDB Composite Primary Key

**What:** Inline PRIMARY KEY constraint on two columns inside the CREATE TABLE statement.

**When to use:** Any time a table's natural key is a tuple (as seen in `network_nodes` and `network_edges` in migration 006).

**Example (from migrations/006_create_citation_networks.sql):**
```sql
CREATE TABLE network_nodes (
  network_id VARCHAR NOT NULL,
  paper_id   VARCHAR NOT NULL,
  ...
  PRIMARY KEY (network_id, paper_id),
  FOREIGN KEY (network_id) REFERENCES citation_networks(id)
);
```

Applied to this phase:
```sql
-- migrations/011_create_prompt_versions.sql
-- Migration 011: Create Prompt Versions Table
--
-- Stores user-edited prompts for AI presets with date versioning.
-- One version per preset slug per day; most recent version_date is active.
-- Absence of a row means "use hardcoded default from R/rag.R".

CREATE TABLE prompt_versions (
  preset_slug  VARCHAR   NOT NULL,
  version_date DATE      NOT NULL,
  prompt_text  TEXT      NOT NULL,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (preset_slug, version_date)
);
```

### Pattern 2: UPSERT in DuckDB

**What:** `INSERT OR REPLACE INTO` replaces a row when the primary key already exists. DuckDB also supports the standard `INSERT INTO ... ON CONFLICT (cols) DO UPDATE SET ...` syntax.

**When to use:** One-version-per-day-per-preset requirement: editing a preset twice in one day must overwrite, not append.

**Discretion recommendation:** Use `INSERT OR REPLACE` — it is shorter, supported by DuckDB, and matches the intended semantics (replace the whole row). `ON CONFLICT DO UPDATE` is more precise if partial column updates were needed, but they are not needed here.

**Usage pattern (for Phase 63 reference):**
```sql
INSERT OR REPLACE INTO prompt_versions (preset_slug, version_date, prompt_text)
VALUES (?, ?, ?);
```

### Pattern 3: Retrieving the Active Version

**What:** `MAX(version_date)` per slug, then join back for the text.

**When to use:** Phase 63 will need to read the currently active prompt.

**Example:**
```sql
SELECT prompt_text
FROM prompt_versions
WHERE preset_slug = ?
ORDER BY version_date DESC
LIMIT 1;
```

Or for all presets at once:
```sql
SELECT pv.preset_slug, pv.prompt_text
FROM prompt_versions pv
INNER JOIN (
  SELECT preset_slug, MAX(version_date) AS latest
  FROM prompt_versions
  GROUP BY preset_slug
) latest ON pv.preset_slug = latest.preset_slug
         AND pv.version_date = latest.latest;
```

### Anti-Patterns to Avoid

- **Adding a separate `is_active` boolean:** The design decision locks this out. `MAX(version_date)` is the canonical active-version query. A flag would require update logic and risks inconsistency.
- **Seeding default rows:** Hardcoded defaults live in R/rag.R. The table is empty on first run; Phase 63 falls back to R defaults when no row exists.
- **Using `TEXT` as a DuckDB type worry:** DuckDB maps `TEXT` to `VARCHAR` internally — it is valid syntax and preferred for long prompt strings over a fixed-length `VARCHAR(N)`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Migration tracking | Custom version tracking | `apply_migration()` in db_migrations.R | Already handles transactions, semicolon splitting, version recording, idempotency |
| Date-keyed versioning | Ad-hoc JSON blob in a single row | Proper `DATE` column as part of PK | SQL-native querying, ordering, and date range retrieval |
| UPSERT logic | Two-step SELECT + INSERT/UPDATE in R | `INSERT OR REPLACE` in SQL | Atomic, no race condition |

**Key insight:** The migration runner already handles all the complexity of running SQL on startup safely. The only deliverable for this phase is the `.sql` file itself.

## Common Pitfalls

### Pitfall 1: Multiple SQL Statements Need Semicolons, But Trailing Semicolons Are Safe

**What goes wrong:** `apply_migration()` splits on semicolons and filters empty strings, so a trailing semicolon produces an empty statement that is discarded. This is safe. However, comments on the same line as a statement can cause issues if the comment-stripping regex (which only removes `^\\s*--` full-line comments) is not accounted for.

**How to avoid:** Keep comments on their own lines (full-line `--` comments), not inline after SQL. The migration runner in `R/db_migrations.R` strips only full-line comment rows before splitting on `;`.

### Pitfall 2: DuckDB Does Not Support `CASCADE` on Foreign Keys

**What goes wrong:** DuckDB silently accepts `REFERENCES` syntax but does not enforce or cascade deletes. This is documented in migration 006's header comment.

**Relevance:** `prompt_versions` has no foreign keys (slugs are untyped strings), so this pitfall does not apply — but note it for Phase 63 if a cleanup function is needed.

### Pitfall 3: `TEXT` vs `VARCHAR` in DuckDB

**What goes wrong:** DuckDB normalises `TEXT` to `VARCHAR` internally. There is no fixed-length risk and no functional difference. Using `TEXT` in the DDL is fine and arguably clearer for long freeform content.

**How to avoid:** Non-issue; use `TEXT` for `prompt_text` for readability.

### Pitfall 4: Migration File Naming

**What goes wrong:** `run_pending_migrations()` regex is `^\\d{3}_.*\\.sql$` — exactly three leading digits. Using four digits (e.g., `0011_`) would silently skip the file.

**How to avoid:** Name the file `011_create_prompt_versions.sql`.

## Code Examples

### Exact SQL for the Migration File

```sql
-- Source: migrating migrations/006_create_citation_networks.sql pattern
-- migrations/011_create_prompt_versions.sql
-- Migration 011: Create Prompt Versions Table
--
-- Stores user-edited prompts for AI presets with date versioning.
-- Composite PK (preset_slug, version_date) enforces one version per preset per day.
-- Absence of a row means the app falls back to the hardcoded default in R/rag.R.

CREATE TABLE prompt_versions (
  preset_slug  VARCHAR   NOT NULL,
  version_date DATE      NOT NULL,
  prompt_text  TEXT      NOT NULL,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (preset_slug, version_date)
)
```

### Optional: Index on preset_slug

Per the discretion note, an index on `preset_slug` alone is likely unnecessary — the table will hold at most a few hundred rows (10 presets × ~20 versions each). If added:

```sql
-- Only add if query profiling shows lookup cost; omit for simplicity
CREATE INDEX IF NOT EXISTS idx_prompt_versions_slug ON prompt_versions(preset_slug);
```

**Recommendation:** Omit the index for now. Add in a future migration if access patterns change.

### Known Preset Slugs (verified from R/rag.R)

From `generate_preset()` (inline list):
- `summarize`
- `keypoints`
- `studyguide`
- `outline`

From dedicated generators:
- `conclusions` (`generate_conclusions_preset`)
- `research_questions` (`generate_research_questions`)
- `literature_review` (`generate_lit_review_table`)
- `methodology` (`generate_methodology_extractor`)
- `gap_analysis` (`generate_gap_analysis`)
- `slides` (`mod_slides_server` — separate module)

No enum constraint is needed; these slugs are used as string keys in R call sites.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Ad-hoc `dbExecute` calls in app startup | Versioned `.sql` files + `run_pending_migrations()` | Migration 001 (historical) | Safe, idempotent, tracked — new table just needs a SQL file |

## Open Questions

1. **UPSERT syntax: `INSERT OR REPLACE` vs `ON CONFLICT DO UPDATE`**
   - What we know: Both are valid DuckDB syntax. `INSERT OR REPLACE` is simpler; `ON CONFLICT` allows updating specific columns only.
   - What's unclear: Neither matters for this phase (no UPSERT SQL in migration 011). Relevant when Phase 63 writes the R save function.
   - Recommendation: Decide in Phase 63. Document here that `INSERT OR REPLACE` is the preferred choice for full-row replacement.

2. **Index on `preset_slug`**
   - What we know: Table will be tiny (< 200 rows). DuckDB performs full scans efficiently at this size.
   - Recommendation: Omit. No evidence of need; can be added later.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat (R) |
| Config file | `tests/testthat/` directory (no separate config file — standard R package layout) |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-db-migrations.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PRMT-04 | `prompt_versions` table created by migration 011 | unit | `Rscript.exe -e "testthat::test_file('tests/testthat/test-db-migrations.R')"` | ❌ Wave 0 — new test needed in existing file |

### Sampling Rate

- **Per task commit:** `Rscript.exe -e "testthat::test_file('tests/testthat/test-db-migrations.R')"`
- **Per wave merge:** `Rscript.exe -e "testthat::test_dir('tests/testthat')"`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/testthat/test-db-migrations.R` — add test that `run_pending_migrations()` on a fresh in-memory DB creates the `prompt_versions` table with correct columns and PRIMARY KEY. The file exists; add a new `test_that` block to it.

## Sources

### Primary (HIGH confidence)

- `R/db_migrations.R` — Migration runner implementation, `apply_migration()`, `run_pending_migrations()`, comment-stripping logic
- `migrations/006_create_citation_networks.sql` — Composite PRIMARY KEY pattern (verified live)
- `migrations/003_create_cost_log.sql` — CREATE TABLE + CREATE INDEX pattern (verified live)
- `migrations/010_add_multi_seed_support.sql` — ALTER TABLE pattern (verified live)
- `R/rag.R` — All preset slugs verified by reading `generate_preset()` + top-level function names

### Secondary (MEDIUM confidence)

- DuckDB documentation on `INSERT OR REPLACE` — standard SQL extension, consistent with SQLite ancestry

### Tertiary (LOW confidence)

- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tooling is in-project and verified by reading source
- Architecture: HIGH — migration pattern is established and verified against 10 existing files
- Pitfalls: HIGH — derived from reading actual migration runner source code

**Research date:** 2026-03-20
**Valid until:** Stable — migration infrastructure changes are rare; valid until db_migrations.R is refactored
