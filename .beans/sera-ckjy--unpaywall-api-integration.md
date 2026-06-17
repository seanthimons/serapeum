---
title: Unpaywall API Integration
status: todo
type: feature
priority: high
created_at: 2026-03-29T21:42:16Z
updated_at: 2026-03-29T21:42:16Z
parent: sera-ogi9
---

Free API (100k req/day) that resolves DOIs to open access locations with license info. No API key needed, just polite email.

## Extractability
Data only — endpoint + field mapping.

## Effort
Low (~30 min)

## How to Adapt
- Endpoint: GET https://api.unpaywall.org/v2/{doi}?email=thimons.sean@epa.gov
- Key fields: is_oa, best_oa_location.url_for_pdf, best_oa_location.url_for_landing_page, best_oa_location.license
- Fallback: iterate oa_locations[] if best_oa_location is null

## Why
Serapeum's quality filter already checks OA status via OpenAlex. Unpaywall is the authoritative OA source and would improve PDF URL discovery for the document import pipeline.

<!-- migrated from beads: `serapeum-ckjy` -->
