---
title: "[BUG] Import badge does not update status on citation mapping"
status: completed
type: bug
priority: high
created_at: 2026-03-12T20:42:42Z
updated_at: 2026-03-24T18:36:56Z
---

### Bug Description

On the citation mapping view, when importing papers, the import badge does not change to reflect the import status the way it does in citation analysis. The badge should update to show that a paper has already been imported (matching the behavior in the citation audit/analysis view).

### Steps to Reproduce

1. Open a citation network map
2. Select a paper to import
3. Import the paper
4. Observe that the import badge does not update to reflect the new status

### Expected Behavior

The import badge should update to reflect that the paper has been imported, consistent with how it works in the citation analysis view.

### Actual Behavior

The import badge remains unchanged after importing a paper from the citation mapping view.

<!-- migrated from beads: `serapeum-1774459566156-131-e6a68570` | github: https://github.com/seanthimons/serapeum/issues/154 -->
