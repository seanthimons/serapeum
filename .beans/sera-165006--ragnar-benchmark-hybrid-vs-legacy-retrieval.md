---
title: "ragnar: Benchmark hybrid vs legacy retrieval"
status: completed
type: task
priority: high
created_at: 2026-02-15T20:45:55Z
updated_at: 2026-02-18T17:08:21Z
---

## Context
Part of ragnar migration Phase 6 (parent: #77).

## Description
Benchmark ragnar hybrid search (VSS + BM25) against the legacy brute-force cosine similarity search:

1. Prepare a test corpus (e.g., 50+ chunks from real PDFs/abstracts)
2. Define a set of 10+ test queries
3. Measure: retrieval latency (ms), result overlap, answer quality
4. Document findings

## Metrics to Capture
- **Speed**: Time per query for ragnar vs legacy (median, p95)
- **Quality**: Do ragnar results surface better chunks? (manual evaluation)
- **Recall**: How many relevant chunks does each method find in top-5?

## Notes
- This informs whether the legacy path can be fully removed
- If ragnar is significantly better, it validates the Phase 5 migration investment

<!-- migrated from beads: `serapeum-1774459565057-80-165006ad` | github: https://github.com/seanthimons/serapeum/issues/97 -->
