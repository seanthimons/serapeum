-- Migration 020: Add community column to network_nodes
--
-- The community column tracks cluster membership (walktrap for single-seed,
-- seed origin for multi-seed). It was added to save_network() in R/db.R
-- but the corresponding schema migration was missing.

ALTER TABLE network_nodes ADD COLUMN IF NOT EXISTS community VARCHAR;
