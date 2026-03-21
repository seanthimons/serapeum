-- Stage 2: Figure storage schema for PDF image pipeline (Epic #44)
CREATE TABLE IF NOT EXISTS document_figures (
  id VARCHAR PRIMARY KEY,
  document_id VARCHAR NOT NULL,
  notebook_id VARCHAR NOT NULL,
  page_number INTEGER NOT NULL,
  file_path VARCHAR NOT NULL,
  extracted_caption VARCHAR,
  llm_description VARCHAR,
  figure_label VARCHAR,
  width INTEGER,
  height INTEGER,
  file_size INTEGER,
  image_type VARCHAR,
  quality_score REAL,
  is_excluded BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (document_id) REFERENCES documents(id),
  FOREIGN KEY (notebook_id) REFERENCES notebooks(id)
);
