-- Migration 019: Retroactive index creation for prompt_versions
--
-- Migration 018 was missing a trailing semicolon on its second CREATE INDEX,
-- which caused the migration runner to silently skip it. This migration
-- retroactively creates the index using IF NOT EXISTS (safe for databases
-- where 018 was already patched).

CREATE INDEX IF NOT EXISTS idx_prompt_versions_slug_date ON prompt_versions(preset_slug, version_date DESC);
