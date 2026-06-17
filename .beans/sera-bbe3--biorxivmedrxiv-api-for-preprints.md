---
title: bioRxiv/medRxiv API for Preprints
status: todo
type: feature
priority: normal
created_at: 2026-03-29T21:42:35Z
updated_at: 2026-03-29T21:42:35Z
parent: sera-ogi9
---

Simple JSON API to fetch recent preprints by date range and category. 68 subject categories across both servers.

## Extractability
Data only — single endpoint, simple JSON response.

## Effort
Low (~30 min)

## How to Adapt
- Endpoint: GET https://api.biorxiv.org/details/biorxiv/{fromDate}/{toDate} (same pattern for medrxiv)
- Returns: doi, title, authors, date, category, abstract, version, type (new/revision)
- Rate limit: 5 req/min

## Why
Serapeum can search OpenAlex for preprints but has no direct preprint server access. bioRxiv/medRxiv APIs return structured data with abstracts, version tracking, and publication status.

<!-- migrated from beads: `serapeum-bbe3` -->
