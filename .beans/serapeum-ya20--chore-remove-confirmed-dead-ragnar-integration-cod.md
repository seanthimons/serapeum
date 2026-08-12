---
# serapeum-ya20
title: 'chore: remove confirmed dead Ragnar integration code'
status: todo
type: task
priority: low
tags:
    - ragnar
    - cleanup
created_at: 2026-08-12T18:31:29Z
updated_at: 2026-08-12T18:31:29Z
---

## Problem

`R/_ragnar.R` contains a shadowed first definition of `enrich_retrieval_results()` (approximately lines 1421-1498) and assigns an unused `serapeum_metadata` attribute (approximately lines 1397-1406). Neither cleanup is caused by Ragnar 0.3.0, but both were confirmed during the audit.

## Source

See `.planning/research/RAGNAR-0.3-NEWS-AUDIT.md`.

## Acceptance criteria

- Remove only the shadowed first function definition; retain the current stable-source enrichment definition.
- Remove only the unused attribute assignment/comment; retain origin metadata encoding.
- Add or retain a multi-query RRF integration regression documenting why native vector retrieval is not a replacement.
- Run Ragnar, RRF, query reformulation, integration, and DB leak tests.
