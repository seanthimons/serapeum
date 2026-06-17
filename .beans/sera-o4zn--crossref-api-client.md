---
title: Crossref API Client
status: todo
type: feature
priority: high
created_at: 2026-03-29T21:42:21Z
updated_at: 2026-03-29T21:42:21Z
parent: sera-ogi9
---

Direct Crossref metadata lookup by DOI. Returns publisher links, text-mining URLs, license info, and richer bibliographic metadata than OpenAlex provides for some records.

## Extractability
Data only — endpoint + field mapping.

## Effort
Low (~30 min)

## How to Adapt
- Endpoint: GET https://api.crossref.org/works/{doi}
- Key fields: message.URL, message.link[] (filter for content-type: application/pdf), message.license[].URL
- Rate limit: 50 req/sec (very generous)
- Add User-Agent header with email for polite pool

## Why
Serapeum has NO direct Crossref integration. OpenAlex proxies some Crossref data but loses fields like text-mining links and license details. Crossref is the canonical DOI registrar.

<!-- migrated from beads: `serapeum-o4zn` -->
