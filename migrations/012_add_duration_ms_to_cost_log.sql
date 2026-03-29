-- Add latency tracking to cost_log
-- Phase 1 already captures duration_ms on every provider call;
-- this column lets log_cost() persist it.
-- Existing rows will have NULL (pre-migration, no latency data).
ALTER TABLE cost_log ADD COLUMN IF NOT EXISTS duration_ms INTEGER;
