---
title: "feat: Citation Audit — find missing seminal papers"
status: completed
type: task
priority: high
created_at: 2026-02-15T21:07:30Z
updated_at: 2026-03-03T02:08:27Z
---

## Summary

Add a feature that analyzes imported papers and identifies **highly-cited works missing from the collection**. Output: list of frequently-cited papers (by title/author/year) that appear in references but aren't in the notebook, ranked by citation frequency.

## Why

Researchers fear missing "seminal papers" that reviewers expect. Current system searches forward from a seed, but misses foundational works cited by many papers. This identifies **must-read papers** by citation network centrality.

**Pain points solved:**
- "Am I missing important papers?"
- "Which references appear most frequently across my collection?"
- Systematic review completeness check

## How it differs

- **Citation Network Graph** → visual exploration of citation relationships
- **Citation Audit** → actionable checklist of missing papers with one-click import

## Implementation notes

- **No LLM needed** — pure data analysis
- Algorithm:
  1. Extract all referenced DOIs from corpus (`abstracts.referenced_works`)
  2. Count frequency of each DOI
  3. Filter out DOIs already in `abstracts` table
  4. Rank by frequency
  5. Query OpenAlex for title/author of top 10-20 missing works
- Add to Search Notebook as "Find Missing Papers" button
- Export list with DOIs → one-click import via existing DOI lookup

## Complexity/Impact

- **Complexity:** Medium
- **Impact:** High
- **Risk:** Very Low (no LLM, pure data analysis, objective and verifiable)
- **Workflow stage:** Discovery & Triage

## Related

- Part of epic: AI Output Overhaul
- Builds on existing citation network code and `referenced_works` data

<!-- migrated from beads: `serapeum-1774459565174-86-1731c579` | github: https://github.com/seanthimons/serapeum/issues/103 -->
