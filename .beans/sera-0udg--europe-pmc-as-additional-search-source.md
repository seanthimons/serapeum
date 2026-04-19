---
title: Europe PMC as Additional Search Source
status: todo
type: feature
priority: normal
created_at: 2026-03-29T21:42:30Z
updated_at: 2026-03-29T21:42:30Z
parent: sera-ogi9
---

REST API for life sciences literature. 14 biomedical categories, MeSH term support, full-text search, OA filtering. Serapeum focuses on OpenAlex which is broad but thin on biomedical full-text. Europe PMC has has_fulltext:y filtering and direct XML access to full articles.

## Extractability
Adapt — needs new R driver function (api_europepmc.R or extend api_openalex.R).

## Effort
Medium

## How to Adapt
- Endpoint: GET https://www.ebi.ac.uk/europepmc/webservices/rest/search?query={query} AND has_fulltext:y&format=json&pageSize={n}&sort=date desc
- Field mapping to abstracts table: title, authorString (parse by comma), pubYear, doi, pmcid, isOpenAccess, citedByCount
- Would need a new driver function in api_openalex.R or a new api_europepmc.R

## Why
Serapeum focuses on OpenAlex which is broad but thin on biomedical full-text. Europe PMC has has_fulltext:y filtering and direct XML access to full articles.

<!-- migrated from beads: `serapeum-0udg` -->
