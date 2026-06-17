---
title: Add indexes to prompt_versions table
status: todo
type: task
priority: critical
tags:
  - db
  - pr-review
  - server
created_at: 2026-03-22T00:22:37Z
updated_at: 2026-03-25T21:44:01Z
parent: sera-yn90
---

**Source:** PR #221 review (round 1, finding #4)

`migrations/011_create_prompt_versions.sql` creates `prompt_versions` without indexes on `preset_slug` or `(preset_slug, version_date)`. All CRUD operations in `prompt_helpers.R` query by these columns.

**Fix:** Add after the CREATE TABLE:
```sql
CREATE INDEX idx_prompt_versions_slug ON prompt_versions(preset_slug);
CREATE INDEX idx_prompt_versions_slug_date ON prompt_versions(preset_slug, version_date DESC);
```

<!-- migrated from beads: `serapeum-1774459567657-195-a7e1b502` | github: https://github.com/seanthimons/serapeum/issues/225 -->
