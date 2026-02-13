-- Migration 007: Add section_hint Column to Chunks Table
--
-- Adds section metadata to chunks for targeted RAG retrieval.
-- Enables filtering by paper sections (conclusion, limitations, future work, etc.)
-- for improved relevance in synthesis tasks.
--
-- Default value "general" ensures graceful degradation for existing chunks.

ALTER TABLE chunks ADD COLUMN IF NOT EXISTS section_hint VARCHAR DEFAULT 'general';
