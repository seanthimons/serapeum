-- Cost tracking table for LLM API usage
CREATE TABLE IF NOT EXISTS cost_log (
  id VARCHAR PRIMARY KEY,
  session_id VARCHAR NOT NULL,
  operation VARCHAR NOT NULL,
  model VARCHAR NOT NULL,
  prompt_tokens INTEGER DEFAULT 0,
  completion_tokens INTEGER DEFAULT 0,
  total_tokens INTEGER DEFAULT 0,
  estimated_cost DOUBLE DEFAULT 0.0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for session queries (get all costs for current session)
CREATE INDEX IF NOT EXISTS idx_cost_log_session ON cost_log(session_id);

-- Index for date-range history queries
CREATE INDEX IF NOT EXISTS idx_cost_log_date ON cost_log(created_at);
