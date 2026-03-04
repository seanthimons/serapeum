# Database Stack Decision: Retaining DuckDB

**Date:** 2026-03-04
**Issue:** [#120 — Migration away from duckDB to LanceDB](https://github.com/seanthimons/serapeum/issues/120)
**Status:** Resolved — DuckDB retained

---

## Background

The issue raised two concerns about the current DuckDB-based database stack:

1. **Single-writer limitation** — DuckDB permits concurrent reads but serialises writes.
2. **VSS extension complexity** — Installing the vector-similarity-search (VSS) extension adds friction for new users.

---

## Current Stack (as of v3.0)

Serapeum uses two distinct database layers:

| Layer | Technology | Files | Purpose |
|-------|-----------|-------|---------|
| Relational data | DuckDB 1.3.2 | `data/notebooks.duckdb` | Notebooks, documents, abstracts, quality cache, cost tracking, etc. |
| Vector search | ragnar + DuckDB 1.3.2 | `data/ragnar/<notebook_id>.duckdb` | Semantic chunking, VSS + BM25 hybrid retrieval |

The ragnar package (tidyverse/ragnar) requires DuckDB ≥ 1.3.1, so DuckDB is a hard dependency regardless of the relational layer choice.

---

## Options Evaluated

### Option A: Migrate to LanceDB

**Rejected.**

- No native R package exists for LanceDB as of 2026-03.
- Would require Python interop (via `reticulate`) or a self-hosted REST API, adding significant operational complexity and contradicting the local-first, no-extra-installs goal.
- LanceDB is a Python-first library; R bindings are not on the official roadmap.

### Option B: Migrate relational data to RSQLite

**Not warranted.**

- DuckDB is already installed and stays as a dependency through `ragnar`.
- RSQLite provides no new capability that DuckDB lacks for this workload.
- Migration would require rewriting several DuckDB-specific query patterns (`information_schema.tables`, `EXCLUDED` pseudo-table in UPSERTs, `shutdown = TRUE` disconnect, temp-table-based bulk inserts) without user-visible benefit.
- SQLite's single-writer WAL mode is no better than DuckDB for a single-user, single-Shiny-process app.

### Option C: Keep DuckDB (chosen)

**Adopted.**

The two original concerns are already resolved:

1. **VSS extension** — DuckDB 1.3.2 bundles VSS internally. No separate extension download or install step is required. The `ragnar` package wraps all VSS operations; application code never calls `INSTALL 'vss'` or `LOAD 'vss'` manually.

2. **Single-writer limitation** — Serapeum is a local-first, single-user application running in a single Shiny R process. Concurrent write contention cannot occur in this deployment model. If Serapeum ever adds multi-user support (e.g., Posit Connect with multiple concurrent sessions), this decision should be revisited.

---

## Why DuckDB Is a Good Fit Here

| Criterion | DuckDB |
|-----------|--------|
| Extra installs beyond R package | None — fully self-contained |
| VSS/vector support | Bundled in 1.3.2 |
| Analytical SQL (GROUP BY, window fns, JSON) | Native |
| Local file-based storage | Single `.duckdb` file |
| R DBI compatibility | Full |
| Hard dependency of `ragnar` | Yes — always present |

---

## Future Considerations

- **Multi-user deployment:** If concurrent write throughput becomes a bottleneck under multi-session load, consider moving the relational tables to PostgreSQL (via RPostgres) with a connection pool. The DBI abstraction in `R/db.R` would make this straightforward.
- **LanceDB (R):** Should an official R LanceDB package become available, it would be worth re-evaluating for the vector-search layer to potentially eliminate the ragnar/DuckDB dependency for that use case.
- **Moonshot #42 (DuckDB Native Vector Search):** The ragnar integration already provides VSS + BM25 hybrid retrieval on top of DuckDB. This moonshot is effectively complete — no further work needed.

---

## Summary

DuckDB remains the right choice for Serapeum's current needs:

- No additional software or manual extension installs are required.
- The single-writer limitation is not a concern for a local-first, single-user app.
- LanceDB has no viable R bindings today.
- DuckDB is an inescapable dependency via `ragnar` regardless of any relational-layer migration.
