-- Migration 005: Add DOI Column to Abstracts Table
--
-- DOI (Digital Object Identifier) enables:
-- - BibTeX/RIS citation export
-- - Seeded discovery workflows (use paper as seed)
-- - CrossRef API lookups
-- - Duplicate detection
--
-- Existing papers will have NULL DOI until backfilled via OpenAlex API.

ALTER TABLE abstracts ADD COLUMN doi VARCHAR;

-- Index for fast DOI lookups (export workflows, duplicate detection)
CREATE INDEX IF NOT EXISTS idx_abstracts_doi ON abstracts(doi);
