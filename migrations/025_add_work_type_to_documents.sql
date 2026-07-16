-- Add OpenAlex work type metadata to documents imported from abstracts.
-- Idempotent because fresh/newer databases may have these columns from init_schema().
ALTER TABLE documents ADD COLUMN IF NOT EXISTS work_type VARCHAR;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS work_type_crossref VARCHAR;
