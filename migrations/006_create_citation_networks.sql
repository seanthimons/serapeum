-- Migration 006: Create Citation Networks Tables
--
-- Three-table schema for storing citation network graphs:
--  - citation_networks: Network metadata (seed paper, settings, timestamps)
--  - network_nodes: Paper nodes with metadata and pre-computed layout positions
--  - network_edges: Citation relationships (directed edges)
--
-- Note: DuckDB doesn't support CASCADE on foreign keys, so delete_network()
-- in db.R manually deletes nodes and edges before deleting the network.

-- Main networks table
CREATE TABLE citation_networks (
  id VARCHAR PRIMARY KEY,
  name VARCHAR NOT NULL,
  seed_paper_id VARCHAR NOT NULL,
  seed_paper_title VARCHAR NOT NULL,
  direction VARCHAR NOT NULL,
  depth INTEGER NOT NULL,
  node_limit INTEGER NOT NULL,
  palette VARCHAR DEFAULT 'viridis',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Network nodes table (papers in the graph)
CREATE TABLE network_nodes (
  network_id VARCHAR NOT NULL,
  paper_id VARCHAR NOT NULL,
  is_seed BOOLEAN DEFAULT FALSE,
  title VARCHAR NOT NULL,
  authors VARCHAR,
  year INTEGER,
  venue VARCHAR,
  doi VARCHAR,
  cited_by_count INTEGER DEFAULT 0,
  x_position DOUBLE,
  y_position DOUBLE,
  PRIMARY KEY (network_id, paper_id),
  FOREIGN KEY (network_id) REFERENCES citation_networks(id)
);

-- Network edges table (citation links)
CREATE TABLE network_edges (
  network_id VARCHAR NOT NULL,
  from_paper_id VARCHAR NOT NULL,
  to_paper_id VARCHAR NOT NULL,
  PRIMARY KEY (network_id, from_paper_id, to_paper_id),
  FOREIGN KEY (network_id) REFERENCES citation_networks(id)
);

-- Indexes for query performance
CREATE INDEX idx_network_nodes_network_id ON network_nodes(network_id);
CREATE INDEX idx_network_edges_network_id ON network_edges(network_id);
