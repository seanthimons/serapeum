-- Add extraction_method column to preserve how figures were extracted
-- (image_type is reserved for vision-derived semantic classification)
ALTER TABLE document_figures ADD COLUMN IF NOT EXISTS extraction_method VARCHAR;
