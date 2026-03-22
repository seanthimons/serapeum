# Phase 62: Prompt Storage Schema - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

DuckDB schema for date-versioned prompt history. A new `prompt_versions` table stores user-edited prompts for all AI presets, enabling the Phase 63 prompt editing UI. This phase creates the migration only — no UI, no prompt loading logic.

</domain>

<decisions>
## Implementation Decisions

### Table schema
- Table name: `prompt_versions`
- Composite primary key: (`preset_slug`, `version_date`)
- Columns: `preset_slug VARCHAR NOT NULL`, `version_date DATE NOT NULL`, `prompt_text TEXT NOT NULL`, `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`
- One version per preset per day — editing the same preset twice in one day overwrites (UPSERT)
- No separate `is_active` flag — the most recent `version_date` per slug is the active version

### Preset identification
- Use existing preset type strings as slugs: summarize, keypoints, studyguide, outline, conclusions, research_questions, literature_review, methodology, gap_analysis, slides
- No enum constraint in the schema — new presets can be added without migration
- Slugs match the keys used in `generate_preset()` and dedicated generator functions in R/rag.R

### Default handling
- No rows seeded for defaults — absence of a row means "use the hardcoded default from R/rag.R"
- Phase 63 UI will query the table; if no row exists for a preset, it shows the hardcoded prompt
- "Reset to default" (PRMT-06) simply deletes all rows for that preset slug

### Migration
- Migration file: `011_create_prompt_versions.sql`
- Follows existing pattern: 3-digit prefix, `apply_migration()` in R/db_migrations.R
- Single CREATE TABLE statement + composite primary key constraint

### Claude's Discretion
- Whether to add an index on `preset_slug` alone (likely unnecessary given small table size)
- Exact UPSERT syntax (INSERT OR REPLACE vs ON CONFLICT)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Migration system
- `R/db_migrations.R` — Migration runner, `apply_migration()` pattern, semicolon-split execution
- `migrations/` directory — Existing migrations 001-010, naming convention `NNN_description.sql`

### Prompt structure
- `R/rag.R` — All AI preset prompts (system_prompt variables), preset type keys in `generate_preset()`, dedicated generator functions

### Requirements
- `.planning/REQUIREMENTS.md` — PRMT-04 (date-versioned slugs), PRMT-06 (reset to default)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/db_migrations.R`: `apply_migration()` handles transaction wrapping, semicolon splitting, and version tracking — new migration just needs a SQL file
- `migrations/` directory: 10 existing migrations; next is 011
- `R/db.R`: DBI-based query helpers used throughout the app

### Established Patterns
- Migrations are plain SQL files named `NNN_description.sql`
- `run_pending_migrations()` auto-discovers and applies on startup
- DuckDB requires each SQL statement executed separately (handled by `apply_migration()`)
- Composite keys used elsewhere (e.g., `schema_migrations` has single PK, but `cost_log` uses auto-increment)

### Integration Points
- Phase 63 will add R functions to read/write `prompt_versions` table
- Phase 63 UI will call those functions to load active prompts and save edits
- `generate_preset()` and dedicated generators in R/rag.R will eventually check for custom prompts before using hardcoded defaults

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. The schema is straightforward: store versioned prompt text keyed by preset slug and date.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 62-prompt-storage-schema*
*Context gathered: 2026-03-20*
