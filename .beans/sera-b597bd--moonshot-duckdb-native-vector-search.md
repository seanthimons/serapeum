---
title: "moonshot: DuckDB Native Vector Search"
status: todo
type: task
priority: normal
tags:
  - db
  - server
created_at: 2026-02-10T04:06:38Z
updated_at: 2026-03-29T21:25:50Z
parent: sera-uf40
---

## Description
Move from R-based cosine similarity to in-database vector search for 100k+ chunk collections.

## Tasks
- [ ] Install DuckDB `vss` extension (manual install on Windows)
- [ ] Use `array_cosine_similarity()` in SQL
- [ ] Investigate HNSW index for approximate nearest neighbor
- [ ] Benchmark R-based vs DuckDB-native at scale

## References
- https://duckdb.org/docs/extensions/vss.html

## Note
This is a prerequisite for Full OpenAlex Corpus Ingestion.

<!-- migrated from beads: `serapeum-1774459563978-32-b597bda2` | github: https://github.com/seanthimons/serapeum/issues/42 -->
