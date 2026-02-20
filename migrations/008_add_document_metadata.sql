-- Migration 008: Add metadata columns to documents table for DOI injection
-- Supports Literature Review Table (Phase 28)
ALTER TABLE documents ADD COLUMN title VARCHAR;
ALTER TABLE documents ADD COLUMN authors VARCHAR;
ALTER TABLE documents ADD COLUMN year INTEGER;
ALTER TABLE documents ADD COLUMN doi VARCHAR;
ALTER TABLE documents ADD COLUMN abstract_id VARCHAR;
