---
title: "moonshot: Full OpenAlex Corpus Ingestion"
status: todo
type: task
priority: normal
tags:
  - db
  - server
created_at: 2026-02-10T04:06:33Z
updated_at: 2026-03-29T21:25:51Z
parent: sera-uf40
---

## Description
Download and index the entire OpenAlex dataset (300+ GB) for offline, unlimited local search.

## Tasks
- [ ] Set up storage infrastructure for 300+ GB dataset
- [ ] Download OpenAlex snapshot (S3 bucket or data dump)
- [ ] Design schema for local DuckDB/PostgreSQL storage
- [ ] Build incremental update pipeline (OpenAlex updates weekly)
- [ ] Index abstracts and metadata for fast full-text search
- [ ] Generate embeddings for semantic search (requires massive compute)
- [ ] Build efficient query interface matching OpenAlex API

## Challenges
- **Storage:** 300+ GB compressed, much larger uncompressed
- **Compute:** Embedding 200M+ abstracts is expensive (weeks of GPU time or $$$ API costs)
- **Updates:** Keeping in sync with weekly OpenAlex releases
- **Infrastructure:** Need robust ETL pipeline

## References
- OpenAlex Data Snapshot: https://docs.openalex.org/download-all-data/openalex-snapshot
- AWS S3 bucket: `s3://openalex`

## Prerequisites
- DuckDB Native Vector Search for querying at scale

<!-- migrated from beads: `serapeum-1774459563953-31-fee8f875` | github: https://github.com/seanthimons/serapeum/issues/41 -->
