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

### Option A: Migrate vector-search layer to LanceDB

**Rejected for now.**

LanceDB does have an official R package (`lancedb/lancedb`, `r/` subdirectory), built on
Rust bindings via [extendr](https://extendr.github.io/). It is not yet on CRAN and must be
installed from GitHub source:

```r
remotes::install_github("lancedb/lancedb", subdir = "r")
```

This requires a Rust toolchain (`cargo ≥ 1.70`) to compile. For a local-first app targeting
non-developer users, asking them to install Rust before using Serapeum is a higher barrier than
the DuckDB VSS extension.

Additional considerations:

- Switching would require replacing the entire `ragnar` stack (`R/_ragnar.R`) that handles
  semantic chunking, embedding, and VSS + BM25 retrieval. ragnar is already installed and working.
- LanceDB's R package is not yet released on CRAN; adopting it introduces a non-standard install
  step and ties the app to a pre-release package with a less-stable API surface.
- LanceDB's hybrid (vector + BM25) search is available (`lancedb_hybrid_search()`), but
  integration would require rewriting all chunking, origin-encoding, and notebook-filtering
  logic that ragnar currently provides.

LanceDB is worth revisiting when its R package reaches CRAN with binary releases (no Rust
required on the user machine).

### Option B: Migrate relational data to RSQLite

**Not warranted.**

- DuckDB is already installed and stays as a dependency through `ragnar`.
- RSQLite provides no new capability for this workload.
- Migration would require rewriting DuckDB-specific query patterns (`information_schema`,
  `EXCLUDED` in UPSERTs, `shutdown = TRUE` disconnect, temp-table bulk inserts) with no
  user-visible benefit.
- SQLite's WAL mode is no better than DuckDB for a single-user, single-Shiny-process app.

### Option C: Keep DuckDB (chosen)

**Adopted.**

The two original concerns addressed:

1. **VSS extension** — The VSS extension is not bundled; it must be installed via DuckDB's
   extension loader. However, `ragnar` calls `INSTALL vss` and `LOAD vss` internally when
   creating or connecting to a store, so end users never need to do this manually. The download
   happens once and is cached by DuckDB. The only edge case is a fully air-gapped environment,
   where the extension can be pre-downloaded and installed from a local path.

2. **Single-writer limitation** — Serapeum is a local-first, single-user application running
   in a single Shiny R process. Concurrent write contention cannot occur in this deployment
   model. If Serapeum ever adds multi-user support (e.g., Posit Connect with multiple concurrent
   sessions), this decision should be revisited.

---

## Comparison

| Criterion | DuckDB + ragnar (current) | LanceDB R pkg |
|-----------|--------------------------|---------------|
| On CRAN with binary | ✅ Both `duckdb` and `ragnar` | ❌ GitHub-only, compile from source |
| Rust toolchain required | ❌ No | ✅ Yes (cargo ≥ 1.70) |
| VSS requires extra step | One-time DuckDB extension download (handled by ragnar) | No extension; built-in |
| Hybrid search (VSS + BM25) | ✅ via ragnar | ✅ via `lancedb_hybrid_search()` |
| Analytical SQL for notebooks/abstracts | ✅ Native DuckDB | ⚠️ Separate DB still needed |
| R DBI compatibility | ✅ Full | N/A (own API) |
| API stability | ✅ CRAN-released | ⚠️ Pre-release |
| Migration cost | N/A (in place) | High — full `_ragnar.R` rewrite |

---

## Future Considerations

- **LanceDB (CRAN release):** When the LanceDB R package reaches CRAN with pre-compiled binaries
  (no Rust required for end users), it becomes a viable option for the vector-search layer.
  At that point, evaluate whether replacing ragnar provides a meaningful reduction in external
  dependencies.
- **Multi-user deployment:** If concurrent write throughput becomes a bottleneck, consider
  moving the relational tables to PostgreSQL (via RPostgres) with a connection pool. The DBI
  abstraction in `R/db.R` makes this straightforward.
- **Moonshot #42 (DuckDB Native Vector Search):** The ragnar integration already provides VSS +
  BM25 hybrid retrieval on top of DuckDB. This moonshot is effectively complete.

---

## Summary

DuckDB + ragnar remains the right choice for Serapeum's current needs:

- Both are on CRAN with pre-compiled binaries — no Rust or extra system toolchains needed.
- The DuckDB VSS extension is managed transparently by ragnar; users never interact with it.
- The single-writer limitation is not a concern for a local-first, single-user app.
- LanceDB's R package exists but requires Rust to compile and is not yet on CRAN; adoption
  cost outweighs the benefit today.
- Migrating the vector-search layer to LanceDB would require a full rewrite of `R/_ragnar.R`
  and all related chunking/retrieval logic.
