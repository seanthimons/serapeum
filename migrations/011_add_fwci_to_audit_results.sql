-- Migration 011: Add FWCI column to citation_audit_results
-- Supports filtering/sorting audit results by field-weighted citation impact
-- Pattern matches v13's refiner_results table which already stores FWCI

ALTER TABLE citation_audit_results ADD COLUMN IF NOT EXISTS fwci DOUBLE;
