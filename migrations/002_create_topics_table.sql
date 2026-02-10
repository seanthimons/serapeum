-- Migration 002: Create Topics Table
--
-- Creates the topics table for storing OpenAlex topic hierarchy.
-- Topics have a 4-level hierarchy: domain > field > subfield > topic
--
-- This table will be populated by Phase 3 (Topic Explorer) and used for
-- topic-based paper discovery and exploration.

CREATE TABLE IF NOT EXISTS topics (
  topic_id VARCHAR PRIMARY KEY,
  display_name VARCHAR NOT NULL,
  description TEXT,
  keywords VARCHAR,
  works_count INTEGER DEFAULT 0,
  domain_id VARCHAR,
  domain_name VARCHAR,
  field_id VARCHAR,
  field_name VARCHAR,
  subfield_id VARCHAR,
  subfield_name VARCHAR,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_topics_domain ON topics(domain_id);

CREATE INDEX IF NOT EXISTS idx_topics_field ON topics(field_id);

CREATE INDEX IF NOT EXISTS idx_topics_subfield ON topics(subfield_id);

CREATE INDEX IF NOT EXISTS idx_topics_works_count ON topics(works_count DESC);
