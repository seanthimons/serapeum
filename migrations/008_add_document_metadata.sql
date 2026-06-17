-- Migration 008: Add metadata columns to documents table for DOI injection
-- Supports Literature Review Table (Phase 28)
ALTER TABLE documents ADD COLUMN IF NOT EXISTS title VARCHAR;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS authors VARCHAR;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS year INTEGER;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS doi VARCHAR;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS abstract_id VARCHAR;
