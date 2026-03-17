-- Track OpenAlex API usage from response headers
-- Supports the new freemium API key model (Feb 2026)
CREATE TABLE IF NOT EXISTS oa_usage_log (
  id VARCHAR PRIMARY KEY DEFAULT (gen_random_uuid()::VARCHAR),
  operation VARCHAR NOT NULL,
  endpoint VARCHAR,
  daily_limit DOUBLE,
  remaining DOUBLE,
  credits_used DOUBLE,
  cost_usd DOUBLE,
  reset_seconds INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
