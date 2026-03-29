-- Migration 018: Create Prompt Versions Table
--
-- Stores user-edited prompts for AI presets with date versioning.
-- Composite PK (preset_slug, version_date) enforces one version per preset per day.
-- Absence of a row means the app falls back to the hardcoded default in R/rag.R.

CREATE TABLE IF NOT EXISTS prompt_versions (
  preset_slug  VARCHAR   NOT NULL,
  version_date DATE      NOT NULL,
  prompt_text  TEXT      NOT NULL,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (preset_slug, version_date)
);

CREATE INDEX IF NOT EXISTS idx_prompt_versions_slug ON prompt_versions(preset_slug);
CREATE INDEX IF NOT EXISTS idx_prompt_versions_slug_date ON prompt_versions(preset_slug, version_date DESC);
