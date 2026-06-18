-- Migration 023: Add page_range Column to Chunks Table
--
-- Cross-page document chunks keep page_number as the first page for backward
-- compatibility and store the full citation span in page_range.

ALTER TABLE chunks ADD COLUMN IF NOT EXISTS page_range VARCHAR;
