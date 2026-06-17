---
title: CORE API for Open Access Aggregation
status: todo
type: feature
priority: normal
created_at: 2026-03-29T21:42:39Z
updated_at: 2026-03-29T21:42:39Z
parent: sera-ogi9
---

Aggregates 200M+ open access documents. POST-based search with optional API key for higher limits. CORE often has full text and download URLs for papers that aren't OA through the publisher — good complement to Unpaywall.

## Extractability
Data only — endpoint + field mapping.

## Effort
Low-Medium

## How to Adapt
- Search: POST https://api.core.ac.uk/v3/search/works with {q: query, limit: 100, exclude_without_fulltext: true}
- Work details: GET https://api.core.ac.uk/v3/works/{id}
- Key fields: downloadUrl (direct PDF), fullText (sometimes inline), doi
- Optional: CORE_API_KEY env var for higher rate limits

## Why
CORE often has full text and download URLs for papers that aren't OA through the publisher. Good complement to Unpaywall.

<!-- migrated from beads: `serapeum-rnn8` -->
