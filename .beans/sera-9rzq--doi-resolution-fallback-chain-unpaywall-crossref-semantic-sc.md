---
title: DOI Resolution Fallback Chain (Unpaywall → Crossref → Semantic Scholar)
status: todo
type: feature
priority: high
created_at: 2026-03-29T21:42:12Z
updated_at: 2026-03-29T21:42:12Z
parent: sera-ogi9
blocked_by:
  - sera-ckjy
  - sera-o4zn
  - sera-xswa
---

Create a 3-tier DOI resolver that tries Unpaywall first (OA detection + PDF URLs), falls back to Crossref (publisher metadata + text-mining links), then Semantic Scholar (open access PDFs). Includes LRU cache and per-service rate limiting.

## Extractability
Adapt — no code is directly portable, rewrite resolution logic in R with httr2.

## Effort
Medium

## How to Adapt
1. Create R/api_doi_resolver.R with three functions: resolve_via_unpaywall(doi), resolve_via_crossref(doi), resolve_via_s2ag(doi)
2. Wrap in resolve_doi(doi) that tries each in order, returns first success
3. Cache results in DuckDB table (doi_resolutions: doi, pdf_url, landing_url, source, is_oa, license, resolved_at)
4. API details:
   - Unpaywall: GET https://api.unpaywall.org/v2/{doi}?email={email} — use best_oa_location.url_for_pdf
   - Crossref: GET https://api.crossref.org/works/{doi} — check message.link[] for intended-application: text-mining
   - Semantic Scholar: GET https://api.semanticscholar.org/graph/v1/paper/DOI:{doi}?fields=openAccessPdf,url,isOpenAccess

## Why
Serapeum currently has NO DOI resolution beyond OpenAlex. When OpenAlex lacks a PDF URL or OA location, there's no fallback. This chain would dramatically improve full-text retrieval success rates.

## Dependencies
Depends on sub-issues for Unpaywall (#2), Crossref (#3), and Semantic Scholar (#4) individual API clients.

<!-- migrated from beads: `serapeum-9rzq` -->
