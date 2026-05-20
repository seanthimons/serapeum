---
# eaqk
title: 'refiner: persist fetched candidate embeddings across rescoring runs'
status: completed
type: task
priority: high
tags:
    - server
    - test
created_at: 2026-04-21T04:06:29Z
updated_at: 2026-04-21T04:06:29Z
parent: sera-dast
---

Implemented persistent embedding reuse for the Research Refiner temp-candidate path. Added DuckDB-backed refiner embedding cache keyed by paper_id + embed_model + abstract hash, migrated the temp scoring path to reuse cached vectors and only embed cache misses, and added tests covering cache round-trip plus no-reembed reuse on subsequent runs.
