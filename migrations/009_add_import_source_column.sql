-- Phase 36: Add source column to import_runs to distinguish import types
-- Values: 'doi_bulk' (default for backward compat), 'bibtex'
-- Note: For fresh databases, init_schema() already includes this column.
-- This migration handles existing databases that lack it.
ALTER TABLE import_runs ADD COLUMN IF NOT EXISTS source VARCHAR DEFAULT 'doi_bulk';
