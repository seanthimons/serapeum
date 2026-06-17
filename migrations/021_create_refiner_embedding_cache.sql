CREATE TABLE IF NOT EXISTS refiner_embedding_cache (
  paper_id VARCHAR NOT NULL,
  embed_model VARCHAR NOT NULL,
  abstract_hash VARCHAR NOT NULL,
  embedding VARCHAR NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (paper_id, embed_model)
);

CREATE INDEX IF NOT EXISTS idx_refiner_embedding_cache_model
ON refiner_embedding_cache (embed_model);
