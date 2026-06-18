# PRD: RAG Retrieval Precision

**Status:** Resolved implementation model
**Author:** Sean
**Date:** 2026-06-17
**Amended:** 2026-06-18
**Owner area:** `R/rag.R`, `R/db.R`, `R/_ragnar.R`, `R/api_rerank.R`

## Problem

A general chat interface (Claude/ChatGPT) gives precise answers about an
uploaded document because the *entire* document sits in the model's context
window. Serapeum, like any RAG system, only shows the model a handful of
retrieved chunks. When the right evidence is not in those chunks, or there is
not enough of it, answers come back vague or wrong. Users experience this as
"the chat app could answer this, why can't my app?"

The architecture is fundamentally sound: hybrid VSS + BM25, RRF merge, and
RAG-Fusion query reformulation already exist. The precision gap comes from four
specific issues in the current retrieval and chunking path.

## Current Behavior

Chat path: `rag_query()` -> `search_chunks_hybrid(limit = 5)` ->
`retrieve_with_ragnar(top_k = limit * 2)` -> `rrf_merge()` -> notebook and
section filtering -> `head(results, limit)` -> `build_context()` -> LLM.

Chunking path: `chunk_with_ragnar()` chunks each PDF page independently with
`ragnar::markdown_chunk(target_size = 1600, target_overlap = 0.5)`, stores the
page in `page_number`, and encodes page/source metadata in `origin`.

## Findings

### F1 - Only 5 Chunks Reach the Model

`rag_query()` hard-codes `limit = 5`. `retrieve_with_ragnar()` pulls `top_k =
limit * 2` per retrieval list, RRF-merges, then returns `head(results, 5)`.
Final context is about five 1600-character chunks. Any answer needing more than
five passages cannot be assembled. This is the primary precision cap.

### F2 - Reranker Exists but Is Not Wired Into Retrieval

`R/api_rerank.R` defines `rerank()`, referenced from `api_provider.R`,
`cost_tracking.R`, and `mod_settings.R`, but it is not called in the retrieval
path (`R/rag.R`, `R/db.R`, `R/_ragnar.R`). Final selection is pure RRF score
with no cross-encoder relevance pass.

### F3 - Page-By-Page Chunking Splits Cross-Page Answers

Each page is chunked in isolation, so a fact spanning a page boundary lives in
no single chunk and no chunk carries cross-page context. The 50% overlap helps
within a page but does nothing across page boundaries. Citations depend on
`page_number`, so cross-page chunking must preserve page-level attribution.

### F4 - Notebook and Section Filtering Are Applied After Retrieval

`search_chunks_hybrid()` filters notebook membership and section hints after
retrieval. Per-notebook ragnar stores make notebook filtering mostly a safety
net, but applying filters after a small candidate pool can still remove needed
evidence. Section filtering also depends on separate DB lookup by content prefix,
which can drift from the ragnar metadata.

## Goals

- Materially increase answer precision on single-document and multi-document
  questions, measured against before/after retrieval-recall tests.
- Use evidence Serapeum already has, especially the reranker, before adding new
  retrieval infrastructure.
- Preserve accurate source attribution, including page ranges for chunks that
  span pages.
- Keep upload-time chunking and rebuild-time chunking identical by routing both
  through one shared chunking pipeline.

## Non-Goals

- Replacing ragnar or the embedding/provider stack.
- Re-architecting per-notebook stores.
- Aggregation/global-question support ("count every mention of X"); top-k
  retrieval is structurally weak for those questions and needs separate design.

## Proposed Changes

1. **Widen candidate retrieval, then rerank.** Retrieve enough VSS and BM25
   results to produce up to 40 unique candidates after RRF, notebook filtering,
   and section filtering. Run `rerank()` on that candidate pool and keep 12
   final chunks for chat context.
2. **Make rerank default-on with explicit fallback behavior.** Reranking is on
   by default using the configured rerank model. If rerank fails in interactive
   chat, continue with the RRF order and show a user-visible warning. If rerank
   fails in background or preset paths, log the failure and continue with the RRF
   order without interrupting the job.
3. **Cross-page chunk documents through a shared pipeline.** Replace per-page
   PDF chunking with document-level chunking that can span page boundaries while
   mapping every chunk back to its first page and full page range.
4. **Rebuild canonical chunks and ragnar stores together.** Rebuilding a
   document notebook must delete and recreate the canonical `chunks` rows for
   documents from `documents.full_text`, then rebuild the per-notebook ragnar
   store from those same chunk rows. Rebuild is destructive for derived chunks
   and indexes; `documents.full_text` remains the durable source.
5. **Use stable source identity in ragnar metadata.** Document and abstract
   origins/metadata must include Serapeum internal source IDs. Filenames and
   titles are display labels only and must not be used as identity for
   filtering, enrichment, deletion, or citation lookup.
6. **Preserve page-range citations.** Cross-page chunks store the first page in
   `page_number` for compatibility and also store explicit page-range metadata
   for formatting citations.
7. **Centralize section hints.** The shared chunking pipeline assigns
   `section_hint` once. Upload, rebuild, ragnar insertion, retrieval enrichment,
   and section filtering must consume that same value rather than recomputing or
   matching by content prefix.

## Resolved Design Model

- **Candidate pool:** the candidate pool is up to 40 unique chunks after RRF
  merge, notebook filtering, and section filtering. It is not "40 per query",
  "40 per retrieval method", or "40 before filters".
- **Final context:** chat receives 12 final chunks after reranking. If fewer
  than 12 filtered candidates exist, use all available candidates.
- **Default knobs:** candidate pool 40, final context 12, query reformulation
  on, rerank on.
- **RRF scope:** `retrieve_with_ragnar()` may fetch more than 40 raw VSS/BM25
  rows per query to survive deduplication, but downstream retrieval must expose
  the 40-candidate post-filter pool before rerank.
- **Rerank ordering:** rerank receives candidate text plus stable source
  metadata. Final chunk ordering follows rerank score when rerank succeeds and
  RRF score when rerank falls back.
- **Rechunking:** there is one shared document chunking output used by upload
  and rebuild. Rebuild deletes/recreates canonical document `chunks` rows and
  rebuilds the ragnar store from the same output.
- **Attribution:** `page_number` remains the first page of the chunk. New
  page-range metadata records the full span, including single-page ranges.
- **Identity:** retrieval enrichment prefers encoded document/abstract IDs from
  origin metadata. Filename matching is fallback-only for stale stores.

## Interface and Data Changes

Shared document chunking output must include:

- `content`
- `chunk_index`
- `page_number` (first page for compatibility)
- `page_range` (for example `12` or `12-13`)
- `section_hint`
- origin metadata containing source type and internal source ID

Canonical `chunks` storage must persist `page_range` and `section_hint` for
document chunks. Ragnar origins or companion metadata must encode enough
information to recover:

- `source_type`
- internal `source_id`
- `chunk_index`
- `page_number`
- `page_range`
- `section_hint`

Retrieval enrichment must parse encoded source IDs first, then use the main DB
to fetch display metadata (`filename`, title, authors, year, DOI). It must not
use filenames as primary identity for document filtering, status reconciliation,
deletion, or citation metadata lookup.

Citation formatting must display page ranges when present, fall back to a
single page when only `page_number` is present, and fall back to chunk number
when neither page field is available.

## Implementation Plan

Suggested branches off `main`, mergeable in either order after tests pass:

- **Branch A - Retrieval (F1, F2, F4):** widen retrieval to the 40-candidate
  post-filter pool, apply default-on rerank, return 12 final chunks, implement
  reranker fallback warnings/logging, and prefer ID-based metadata parsing in
  retrieval enrichment.
- **Branch B - Chunking and rebuild (F3):** introduce the shared chunking output,
  add/persist `page_range`, encode stable source IDs in ragnar metadata, update
  upload and rebuild to use the same chunking path, delete/recreate canonical
  document `chunks` rows during rebuild, rebuild ragnar stores from those rows,
  and bump `RAGNAR_INDEX_SCHEMA_VERSION` so stale stores are detected.

## Test Plan

- Add deterministic retrieval fixtures mapping questions to expected source
  document IDs and page-range evidence.
- Test recall at final context: expected evidence appears in the top 12 after
  RRF plus rerank.
- Test candidate semantics: notebook and section filters apply before the
  40-candidate rerank pool is finalized.
- Unit test page-range mapping for single-page chunks, cross-page chunks, empty
  pages, and fallback chunking.
- Unit test source-ID origin encoding/parsing for document and abstract chunks,
  including filename collisions and stale filename-only origins.
- Unit test citation formatting for page range, single page, and chunk-number
  fallback.
- Unit test reranker fallback: chat gets a warning and RRF order; background and
  preset paths log and continue.
- Unit test shared chunker consistency between upload and rebuild from the same
  `documents.full_text` input.
- Add qualitative UAT examples comparing current behavior with revised retrieval
  on questions previously missed.

## Success Metrics

- Retrieval recall@12 on a labeled question/evidence set improves versus the
  current baseline.
- Questions previously missed because evidence landed outside the top 5 now
  answer correctly with valid citations.
- Cross-page evidence is retrievable and cites the correct page range.
- Rebuilt notebooks have matching canonical `chunks` rows and ragnar store
  entries for document chunks.

## Assumptions

- Accuracy is favored over latency and cost.
- Existing document notebooks may be destructively rechunked and reindexed
  because `documents.full_text` is the durable source for document notebooks.
