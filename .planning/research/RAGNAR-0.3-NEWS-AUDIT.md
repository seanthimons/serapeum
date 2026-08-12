# Ragnar 0.3.0 NEWS audit

**Audit date:** 2026-08-12

**Repository commit audited:** `271dced49deaf4c70a7081a139626dc8adb95040`

**Upstream release:** [`ragnar` 0.3.0](https://github.com/tidyverse/ragnar/releases/tag/v0.3.0) (`5926c75`)

**Scope:** Every item under **New features** and **Minor improvements and fixes** in the current upstream [`NEWS.md`](https://github.com/tidyverse/ragnar/blob/main/NEWS.md). The breaking-changes section is outside this audit's requested scope.

## Executive conclusion

Serapeum already locks and runs `ragnar` 0.3.0 and `mirai` 2.6.0. The audit found **no Serapeum production code or tests that can safely be removed because of the Ragnar 0.3.0 NEWS changes**.

The apparent overlaps are not equivalent:

- Ragnar's vectorized `ragnar_retrieve()` concatenates per-query retrieval results and deduplicates them, but does not re-rank them. Serapeum separately retrieves VSS and BM25 results for every reformulated query, then uses Reciprocal Rank Fusion (RRF) to accumulate cross-list rank evidence. Replacing the local loop and `rrf_merge()` would change retrieval semantics and likely reduce quality.
- Ragnar's parallel `ragnar_store_ingest()` only supports version-2 stores and path-to-`MarkdownDocumentChunks` preparation. Serapeum deliberately uses version-1 stores, canonical database rows, stable source identity, page spans, cancellation, progress telemetry, and main-database synchronization. It is not a drop-in replacement.
- Ragnar's generalized retry policy and improved OpenAI errors apply to Ragnar's own `embed_*()` helpers. Serapeum bypasses those helpers through its provider abstraction, so no local retry/error code became redundant.

Two native fixes are already consumed without local changes:

1. `ragnar_retrieve_bm25()` now returns descending scores, which makes Serapeum's rank-based RRF input correct.
2. The required `mirai >= 2.5.1` constraint is satisfied by the locked and installed `mirai` 2.6.0.

The audit did identify two safe, unrelated dead-code removals in `R/_ragnar.R`, several stale documents/beans to adjust, a missing provider-layer retry policy, and a deployment-manifest gap. These are recorded separately so they are not misattributed to Ragnar 0.3.0.

## Recommended actions

### Do now

1. **Regenerate `manifest.json` from the current application dependency graph** (`serapeum-mp2r`). The tracked manifest contains neither a `ragnar` nor a `mirai` package entry, even though both are runtime dependencies. Do not hand-edit the generated package records. Confirm the deployment workflow actually consumes this manifest, regenerate it with the project's deployment tooling, and verify both packages and their transitive dependencies are present.
2. **Add retry behavior to Serapeum's provider embedding request, not to the Ragnar wrapper** (`serapeum-0r3o`). Add a shared `httr2::req_retry()` policy in `provider_get_embeddings()` (or the common provider request builder if chat requests should receive the same policy). Cover 429, retryable 5xx/network failures, `Retry-After`, maximum attempts/time, and final structured error propagation. Do not couple Serapeum's provider API to `options(ragnar.embed.req_retry = ...)`; that option does not govern custom embed closures.
3. **Add a multi-query retrieval integration regression.** Pass at least two query variants through `retrieve_with_ragnar()` and assert that a repeated chunk appears once with accumulated RRF contributions. This locks the semantic reason the native vectorized API is not used.
4. **Add a small Ragnar contract test for BM25 ordering.** Assert that `metric_value` is non-increasing from `ragnar_retrieve_bm25()` under the locked version. This distinguishes the upstream ordering guarantee from Serapeum's separate RRF ordering tests.

### Safe cleanup, but unrelated to the NEWS release

Tracked as `serapeum-ya20`:

1. **Remove the shadowed first `enrich_retrieval_results()` definition** at `R/_ragnar.R:1421-1498`. A second definition at `R/_ragnar.R:1505-1620` replaces it when the file is sourced, so no caller can reach the first definition. Keep the second definition and its stable-source enrichment behavior.
2. **Remove the unused `serapeum_metadata` attribute assignment** at `R/_ragnar.R:1397-1406`. The attribute is never read in the repository, and Ragnar's version-1 insertion casts/selects the declared store columns, discarding it. Keep the actual metadata encoding in `origin` at `R/_ragnar.R:1341-1382`.

These cleanups should be made in a focused change with the targeted Ragnar tests below; they should not be presented as code made obsolete by 0.3.0.

### Defer until a deliberate version-2 migration

- Evaluate `ragnar_store_ingest()` only after designing a version-2 store migration. The migration must preserve stable source IDs, document/abstract distinction, chunk index, section hint, page number/range, canonical `chunks` synchronization, model/schema staleness tracking, cancellation, progress reporting, and async observability.
- Re-evaluate custom origin encoding only if version-2 store schema columns can carry all required Serapeum metadata through insert, update, retrieval, deletion, and rebuild. The new `read_as_markdown(origin = ...)` argument alone is insufficient because it only customizes one origin string.
- Add a missing-`store@schema` regression only as part of that version-2 migration. The upstream fix applies specifically to version-2 insert/update behavior, while all current Serapeum stores and test fixtures intentionally use version 1.

## NEWS item-by-item disposition

### New features

| Ragnar 0.3.0 item | Local evidence | Disposition |
|---|---|---|
| `embed_azure_openai()` | No `ragnar::embed_*()` call exists. Serapeum uses the OpenAI-compatible provider path in `R/api_provider.R:162-200` through `make_embed_function()` at `R/_ragnar.R:199-228`. | **No overlap.** A future Azure provider is a product feature, not removable compatibility code. |
| `embed_snowflake()` | No Snowflake embedding integration or Ragnar embedding helper call exists. | **No overlap.** |
| `mcp_serve_store()` | No Ragnar MCP server or retrieval-tool registration exists. | **No overlap.** Potential future local-search surface only. |
| Vector queries in `ragnar_retrieve()` | `R/db.R:1246-1273` creates variants; `R/_ragnar.R:1632-1662` retrieves two ranked lists per query; `R/rag.R:10-75` performs cross-list RRF. Upstream explicitly documents that native results [are not re-ranked](https://github.com/tidyverse/ragnar/blob/v0.3.0/R/retrieve.R#L546-L567), and its implementation applies `lapply()`/row binding followed by distinctness. | **Retain local implementation.** Native vectorization does not replace RAG-Fusion ranking. |
| `ragnar_store_atlas()` | No embedding-atlas call or wrapper exists. Citation-network ForceAtlas code is unrelated. | **No overlap.** |
| Parallel `ragnar_store_ingest()` | `R/_ragnar.R:1007-1199` rebuilds from canonical DB content with custom metadata/progress/cancellation; document and abstract insertions also have application lifecycle behavior. Upstream ingest [requires version 2, paths, and `MarkdownDocumentChunks`](https://github.com/tidyverse/ragnar/blob/v0.3.0/R/ingest.R#L219-L252). | **Retain; future migration candidate only.** |

### Minor improvements and fixes

| Ragnar 0.3.0 item | Local evidence | Disposition |
|---|---|---|
| `embed_ollama()` defaults to `embeddinggemma` | Serapeum supports Ollama through a generic OpenAI-compatible endpoint and selects explicit model IDs; it does not call `embed_ollama()`. README examples currently use `nomic-embed-text`. | **No overlap.** Do not silently change the product default based on an unused helper default. |
| `embed_openai()` surfaces API errors | `provider_get_embeddings()` calls Serapeum's provider endpoint and propagates classified HTTP/response-body errors; `make_embed_function()` adds provider context. | **Already local, but not redundant. Retain.** The upstream fix is bypassed. |
| Generalized embedding request retry option | No `ragnar.embed.req_retry` option or Ragnar embed helper is used. `provider_get_embeddings()` currently performs once with no `req_retry()`. | **Adjust locally.** Add provider-layer retry; nothing can be removed. |
| Requires `mirai >= 2.5.1` | `renv.lock:2088-2090` locks 2.6.0; `renv.lock:2654` records Ragnar's minimum. Installed version is 2.6.0. | **Already satisfied. No change.** Fix `manifest.json` deployment drift separately. |
| `print(RagnarStore)` shows location | Serapeum does not parse or wrap store printing. | **No overlap.** |
| BM25 orders descending by score | Direct calls occur at `R/_ragnar.R:683`, `R/_ragnar.R:1650`, and `R/research_refiner.R:279`. No reverse-sort workaround exists. RRF deliberately treats row position as rank. | **Already inherited. No deletion.** Add a contract test. |
| Multi-query `ragnar_retrieve()` removes duplicates | Serapeum never calls `ragnar_retrieve()`. `rrf_merge()` deduplicates by hash while summing reciprocal-rank evidence from VSS, BM25, and all query variants. | **Retain local implementation and tests.** Native distinctness is not RRF. |
| Ellmer retrieval tool omits scores | No Ellmer Ragnar retrieval tool is registered. Downstream Serapeum code needs `rrf_score`, raw metrics, and in some paths embeddings. | **No overlap.** |
| Inspector UI improvements | No `ragnar_store_inspect()` call or UI wrapper exists. | **No overlap.** |
| Better local HTML link finding | No `ragnar_find_links()` call or workaround exists. | **No overlap.** |
| v2 insert/update handles missing `store@schema` | `get_ragnar_store()` explicitly creates `version = 1` at `R/_ragnar.R:258-262`; `insert_chunks_to_ragnar()` prepares the v1 `origin/hash/text` shape at `R/_ragnar.R:1384-1408`. Integration tests also explicitly create v1 fixtures. | **Inapplicable. Retain the v1 contract.** |
| YouTube transcript restoration/formatter | No `read_as_markdown()` or YouTube ingestion path exists. | **No overlap.** |
| `read_as_markdown(origin = ...)` | Serapeum constructs `MarkdownDocument` directly for chunking and encodes stable identity plus page/section metadata in origins. | **Not a replacement. Retain origin encoding.** |
| Non-ASCII plain-text reading fix | No `read_as_markdown()` plain-text ingestion path or encoding workaround exists. | **No overlap.** |
| Vignette heading fix | Serapeum is not a Ragnar documentation consumer at runtime and has no copied vignette. | **No overlap.** |
| Sentence-transformers example | No Ragnar sentence-transformers adapter or copied example exists. Generic OpenAI-compatible/local provider support is separate. | **No overlap.** |

## Local code that must remain

### Multi-query RRF retrieval

The relevant data flow is:

```text
original query
  -> generate_query_variants()
  -> for each query: VSS ranked list + BM25 ranked list
  -> rrf_merge() by chunk hash
  -> metadata enrichment
  -> optional reranking and limit
```

Ragnar's native path instead runs its VSS+BM25 union once per query, row-binds the results, and removes duplicates. Its own source notes that the union is not re-ranked. Serapeum's `tests/testthat/test-rrf-merge.R:9-116` verifies score accumulation, hash deduplication, descending RRF order, empty inputs, and many-list behavior. Those tests cover product semantics, not an upstream bug workaround.

### Provider embedding closure and runtime attachment

Keep the runtime `store@embed` assignments at:

- `R/_ragnar.R:265-266`
- `R/_ragnar.R:611-617`
- `R/db.R:1226-1229`
- `R/mod_research_refiner.R:558-560`

Ragnar 0.3.0 still serializes an embedding function into store metadata. None of the audited NEWS entries claims to fix serialization of closures that reference Serapeum functions/environments. The local provider abstraction also supports OpenRouter and arbitrary OpenAI-compatible local endpoints, which the Ragnar-specific helpers do not replace as a group.

### Rebuild and insertion lifecycle

Keep `rebuild_notebook_store()` and current insert paths. They provide behavior not present in `ragnar_store_ingest()`:

- DB-sourced abstracts and extracted PDF pages rather than a simple path list
- stable document/abstract IDs
- section hints and page spans for citations
- canonical main-DB chunk rows and indexed sentinels
- model/schema staleness markers
- application cancellation
- cross-process progress files/callbacks
- async task observability
- version-1 store compatibility

## Tests: retain, add, and run

### Retain

- `tests/testthat/test-rrf-merge.R`, especially hash deduplication at lines 58-73 and RRF ordering at lines 76-85.
- `tests/testthat/test-query-reformulation.R` for variant parsing and generation behavior.
- Version-1 store fixtures in:
  - `tests/testthat/test-ragnar-integration.R:44-47,88-91`
  - `tests/testthat/test-ragnar.R:169-185,220-225`
  - `tests/testthat/test-db-leak.R:45-55,103-118,215-224`
- Ragnar metadata, lifecycle, integration, and async-observability tests. Native ingestion does not cover Serapeum's application contract.

No existing Ragnar-related test is safe to delete because of 0.3.0.

### Add before code cleanup/adjustment

1. Multi-query `retrieve_with_ragnar()` integration: repeated hit is returned once and its RRF score contains contributions from every applicable list/query.
2. Native BM25 ordering contract: non-increasing `metric_value` under the locked Ragnar version.
3. Provider embedding retry tests: 429 with `Retry-After`, transient 503/network failure then success, maximum attempts, non-retryable 4xx, and preserved structured final error.
4. Manifest validation in deployment checks: runtime packages include at least `ragnar` and `mirai`, and manifest versions agree with `renv.lock` when both artifacts are retained.

### Targeted gates

```r
testthat::test_file('tests/testthat/test-rrf-merge.R')
testthat::test_file('tests/testthat/test-query-reformulation.R')
testthat::test_file('tests/testthat/test-ragnar-integration.R')
testthat::test_file('tests/testthat/test-ragnar.R')
testthat::test_file('tests/testthat/test-api-provider.R')
```

Run `test-db-leak.R` as well if store lifecycle, insert behavior, or the version contract changes. A full suite is justified for a version-2 migration or generated deployment-manifest change.

## Documentation and issue-tracker cleanup

### Refresh or mark historical

`.planning/RAGNAR_MIGRATION_PLAN.md` still describes a shared store, optional Ragnar/fallback behavior, direct `ragnar_retrieve()`, and direct `embed_openai()` use at several locations, including lines 17, 42, 54-55, 83, 101, 114-121, 163, 184, and 201-204. Current architecture instead has a hard dependency, per-notebook stores, Ragnar as the sole backend, a provider abstraction, and split VSS/BM25 RRF. Add an archival banner or refresh it to point at `.planning/PROJECT.md:143-155` as current truth.

The generated/point-in-time codebase maps are also stale in places:

- `.planning/codebase/ARCHITECTURE.md:13,107-108`
- `.planning/codebase/CONCERNS.md:120-132`
- `.planning/codebase/STACK.md:23-24,47,69`
- `.planning/codebase/INTEGRATIONS.md:65`
- `.planning/codebase/STRUCTURE.md:105-109`

In particular, `STACK.md` incorrectly says no `renv.lock` is committed and that Ragnar is optional.

### Beans

- `.beans/sera-cb7da5--perf-batch-abstract-embedding-in-research-refiner-200-api-ca.md:21-29` appears superseded: current Refiner code/tests implement batching and cache behavior (`tests/testthat/test-refiner.R:478-584,628-703`). Close it with verification or rewrite it narrowly as a benchmark/comparison against native ingestion.
- `.beans/apj0--*.md` remains valid because its model/provider-aware batch-limit concern is not solved by Ragnar's generalized retry policy.
- `.beans/sera-793bd7--*.md` records the custom origin solution as completed but retains unchecked acceptance boxes and stale line references. Update its evidence; do not delete the origin implementation.

## Dependency and deployment evidence

- `renv.lock:2635-2638`: `ragnar` 0.3.0.
- `renv.lock:2654`: `mirai (>= 2.5.1)` imported by Ragnar.
- `renv.lock:2088-2090`: `mirai` 2.6.0.
- Local project library verification: `packageVersion('ragnar') == '0.3.0'` and `packageVersion('mirai') == '2.6.0'`.
- `manifest.json`: no package entry named `ragnar` and no package entry named `mirai`. Its only `mirai` strings are in other packages' `Suggests` fields. The file was added on 2026-01-30 and has not tracked the subsequent Ragnar overhaul.

## Primary sources

- [Ragnar 0.3.0 release notes](https://github.com/tidyverse/ragnar/releases/tag/v0.3.0)
- [Current upstream NEWS](https://github.com/tidyverse/ragnar/blob/main/NEWS.md)
- [Ragnar 0.3.0 retrieval implementation](https://github.com/tidyverse/ragnar/blob/v0.3.0/R/retrieve.R)
- [Ragnar 0.3.0 parallel ingestion implementation](https://github.com/tidyverse/ragnar/blob/v0.3.0/R/ingest.R)
- [PR #153: multi-query duplicate removal](https://github.com/tidyverse/ragnar/pull/153)

## Audit coverage

The audit fanned out over upstream NEWS/source, all 48 `R/*.R` runtime files, `app.R`, setup/configuration, scripts, migrations, lock/deployment metadata, tests, `.beans/`, current architecture documents, historical plans, and repository history/blame. Searches found no applicable local implementation for Azure, Snowflake, MCP serving, Atlas, Inspector, link crawling, YouTube transcripts, non-ASCII plain-text reading, vignette formatting, or the sentence-transformers example.
