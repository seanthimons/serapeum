---
title: "dev: Figure storage schema & DB helpers (Stage 2)"
status: completed
type: task
priority: high
created_at: 2026-03-09T14:41:07Z
updated_at: 2026-03-22T16:54:18Z
parent: sera-mgb9
---

## Stage 2 of Epic #44: Figure Storage & Association

### Problem

Extracted figures need persistent storage (filesystem for image files, DuckDB for metadata) so they survive across sessions and can be queried by downstream stages (caption extraction, filtering, UI, slide generation).

### Database Schema

```sql
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
```

### File Storage Layout

```
data/figures/
  {notebook_id}/
    {document_id}/
      fig_{page}_{index}.png
      fig_{page}_{index}.png
      ...
```

### DB Helper Functions

- `db_insert_figure(con, figure_data)` — insert a single figure row
- `db_insert_figures_batch(con, figures_df)` — bulk insert from extraction pipeline
- `db_get_figures_for_document(con, document_id)` — all figures for one PDF
- `db_get_figures_for_notebook(con, notebook_id)` — all figures across a notebook
- `db_get_slide_figures(con, notebook_id, document_ids)` — non-excluded figures for slide generation
- `db_update_figure(con, figure_id, ...)` — update caption, description, exclusion status
- `db_delete_figures_for_document(con, document_id)` — cascade delete (DB rows + files)

### File Utilities

- `create_figure_dir(notebook_id, document_id)` — ensure directory exists
- `save_figure(image_data, notebook_id, document_id, page, index)` — write PNG, return relative path
- `cleanup_figure_files(notebook_id, document_id)` — delete directory and contents
- Wire into existing document deletion flow so removing a document cascades to its figures

### Deliverables

- [ ] Add `document_figures` table to `init_db()` in `db.R`
- [ ] All DB helper functions listed above
- [ ] File storage utilities
- [ ] Cascade delete wired into existing document removal
- [ ] Unit tests for DB operations and file management
- [ ] Handle migration: existing databases get the new table on next `init_db()` call

### Depends On

- Stage 1 (#38) — produces the images to store

### Blocks

- Stage 3 (#28) — caption extraction writes to this schema
- Stage 4 — filtering updates quality_score in this schema
- Stage 5 — vision model writes llm_description to this schema
- Stage 6 (#37) — UI reads from this schema
- Stage 7 (#29) — slide injection queries this schema

### Part of

Epic #44 — PDF Image Pipeline (extraction -> slides)

<!-- migrated from beads: `serapeum-1774459566005-124-07f2dbb1` | github: https://github.com/seanthimons/serapeum/issues/146 -->
