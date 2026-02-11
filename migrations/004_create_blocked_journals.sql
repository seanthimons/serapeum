-- Migration 004: Create blocked_journals table
-- This table stores user's personal journal blocklist for quality filtering

CREATE TABLE IF NOT EXISTS blocked_journals (
  id INTEGER PRIMARY KEY,
  journal_name VARCHAR NOT NULL,
  journal_name_normalized VARCHAR NOT NULL,
  added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_blocked_journals_name ON blocked_journals(journal_name_normalized);
