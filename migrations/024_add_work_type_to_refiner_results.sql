-- Migration 024: Add work type metadata to refiner results
--
-- Research Refiner imports need to preserve OpenAlex type metadata when
-- accepted papers are copied into abstract notebooks.

ALTER TABLE refiner_results ADD COLUMN IF NOT EXISTS work_type VARCHAR;
ALTER TABLE refiner_results ADD COLUMN IF NOT EXISTS work_type_crossref VARCHAR;
