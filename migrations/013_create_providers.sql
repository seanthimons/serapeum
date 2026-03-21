-- Provider management for multi-endpoint support
-- Each provider is an OpenAI-compatible API endpoint (OpenRouter, Ollama, LM Studio, vLLM, etc.)
CREATE TABLE IF NOT EXISTS providers (
  id VARCHAR PRIMARY KEY,
  name VARCHAR NOT NULL,
  base_url VARCHAR NOT NULL,
  api_key VARCHAR,
  provider_type VARCHAR NOT NULL DEFAULT 'openai-compatible',
  timeout_chat INTEGER DEFAULT 300,
  timeout_embed INTEGER DEFAULT 600,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed OpenRouter as the built-in default provider
INSERT INTO providers (id, name, base_url, provider_type, is_default, timeout_chat, timeout_embed)
VALUES ('openrouter', 'OpenRouter', 'https://openrouter.ai/api/v1', 'openrouter', TRUE, 120, 60)
ON CONFLICT DO NOTHING;
