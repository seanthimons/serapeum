-- Migration 010: Add Multi-Seed Citation Network Support
--
-- Adds columns to support multi-seed citation networks:
--  - citation_networks.seed_paper_ids: JSON array of seed paper IDs
--  - citation_networks.source_notebook_id: Tracks which notebook seeded the network
--  - network_nodes.is_overlap: Boolean flag for papers reachable from 2+ seeds

-- Add seed_paper_ids column to store JSON array of seed papers
ALTER TABLE citation_networks ADD COLUMN IF NOT EXISTS seed_paper_ids VARCHAR;

-- Add source_notebook_id to track which notebook created this network
ALTER TABLE citation_networks ADD COLUMN IF NOT EXISTS source_notebook_id VARCHAR;

-- Add is_overlap column to network_nodes for overlap detection
ALTER TABLE network_nodes ADD COLUMN IF NOT EXISTS is_overlap BOOLEAN DEFAULT FALSE;
