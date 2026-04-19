---
title: DOI Normalization Logic Review
status: todo
type: task
priority: low
created_at: 2026-03-29T21:42:44Z
updated_at: 2026-03-29T21:42:44Z
parent: sera-ogi9
---

Source repo strips https://doi.org/, dx.doi.org/, doi: prefixes, lowercases, and trims. Serapeum already has normalize_doi_bare() in utils_doi.R that does the same thing with a Crossref-recommended regex.

## Extractability
Inspiration only.

## Effort
None — serapeum's version is already better.

## Evaluation
No action needed. Serapeum's normalize_doi_bare() uses a Crossref-recommended regex that is more thorough than the source repo's simpler approach. This issue exists for tracking/completeness — close immediately if no gaps are found during DOI resolver integration.

## Action
When implementing the DOI Resolution Fallback Chain, verify that normalize_doi_bare() handles all edge cases encountered by the new API sources. If gaps are found, patch utils_doi.R.

<!-- migrated from beads: `serapeum-yybu` -->
