-- Add presentation_hint column to document_figures
-- Values: "hero", "supporting", "reference" (from vision model)
ALTER TABLE document_figures ADD COLUMN IF NOT EXISTS presentation_hint VARCHAR;
