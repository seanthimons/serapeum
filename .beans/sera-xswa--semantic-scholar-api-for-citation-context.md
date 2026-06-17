---
title: Semantic Scholar API for Citation Context
status: todo
type: feature
priority: high
created_at: 2026-03-29T21:42:26Z
updated_at: 2026-03-29T21:42:26Z
parent: sera-ogi9
---

S2AG provides paper lookup by DOI with open access PDF detection and semantic paper IDs. Third fallback for PDF discovery, plus a pathway to future enrichment (citation context, influential citations, TLDR summaries).

## Extractability
Data only — endpoint + field mapping.

## Effort
Low (~20 min)

## How to Adapt
- Endpoint: GET https://api.semanticscholar.org/graph/v1/paper/DOI:{doi}?fields=paperId,externalIds,openAccessPdf,url,isOpenAccess
- Key fields: openAccessPdf.url, openAccessPdf.status (GOLD/GREEN), isOpenAccess
- Rate limit: 100 req/min

## Why
Third fallback for PDF discovery. Also provides a pathway to future enrichment — S2AG has citation context, influential citations, and TLDR summaries (fields not used by source repo but available).

<!-- migrated from beads: `serapeum-xswa` -->
