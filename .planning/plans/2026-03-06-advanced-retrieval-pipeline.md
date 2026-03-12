# Advanced Retrieval Pipeline: Reranking, RRF, and Structural Signals

**Date:** 2026-03-06
**Status:** Draft (Epic)
**Type:** Architecture / Multi-phase enhancement

## Problem

Serapeum's current retrieval pipeline uses ragnar's hybrid VSS + BM25 search, which is a solid baseline. However, the retrieved chunks are passed directly to the LLM for synthesis with no post-retrieval quality filtering. This creates two problems:

1. **Noise in context window**: Marginally relevant chunks dilute the LLM's synthesis — it hedges, adds filler, or conflates findings from loosely related content.
2. **Blind spots**: Text-only retrieval (embeddings + keywords) misses chunks that are relevant for *structural* reasons — papers that are citation-adjacent, frequently co-referenced, or bridge multiple subfields.

The question isn't whether retrieval is fast enough — it's whether the chunks we feed the LLM carry enough **informational substance** to produce dense, well-grounded synthesis.

## Current State

### What exists today

| Component | Location | What it does |
|-----------|----------|--------------|
| Hybrid search (VSS + BM25) | `R/db.R` `search_chunks_hybrid()` | Ragnar's built-in hybrid retrieval, fetches `limit * 2` results |
| Section-aware filtering | `R/db.R` lines 874-920 | Filters ragnar results by `section_hint` (conclusion, methods, etc.) |
| Citation network graph | `R/citation_network.R` | BFS traversal from seed papers, stores directed edges in `network_edges` |
| Multi-seed overlap detection | `R/citation_network.R` `fetch_multi_seed_citation_network()` | Flags papers reachable from 2+ seeds as `is_overlap` |
| Citation audit | `R/citation_audit.R` | Counts backward/forward citation frequency across notebook papers |
| FWCI scores | `abstracts` table | Field-Weighted Citation Impact from OpenAlex, stored but unused |
| Author metadata | `abstracts` table (JSON) | Author names stored as JSON array, not structured as a graph |
| Ragnar store per notebook | `R/_ragnar.R` | Isolated DuckDB-backed vector stores with origin metadata encoding |

### What doesn't exist yet

- Cross-encoder reranking
- Reciprocal Rank Fusion (RRF) across multiple signals
- Citation proximity as a retrieval signal
- Co-author network graph
- Any post-retrieval scoring or filtering beyond section hints

## Design

### Architecture overview

```
Query
  │
  ├─► VSS (embedding similarity)          ─┐
  ├─► BM25 (keyword match)                 ├─► RRF Fusion ─► Reranker ─► Top-k chunks ─► LLM
  ├─► Citation proximity (graph distance)  │
  └─► Audit frequency (co-reference count) ─┘
```

Each retrieval signal independently produces a ranked list. RRF merges them into a single ranking. An optional cross-encoder reranker refines the final ordering. The top-k chunks are passed to the LLM for synthesis.

### Phase 1: Cross-encoder reranker

**Biggest impact, smallest change.**

Modify `search_chunks_hybrid()` to:
1. Retrieve `limit * 4` candidates from ragnar (instead of `limit * 2`)
2. Send candidates + query to a reranking API (e.g., Cohere Rerank v3.5 via OpenRouter, or a dedicated rerank endpoint)
3. Return the top `limit` by reranker score

**Why this matters**: Bi-encoder embeddings compress query and document independently — they miss nuanced relevance. A cross-encoder jointly attends to query + passage, catching relationships that cosine similarity cannot.

**Impact by preset**:
- **Conclusions preset**: Better at distinguishing actual limitation paragraphs from discussion paragraphs that merely mention "limitation"
- **Research questions**: Better at identifying genuine gap acknowledgments vs. topical mentions
- **RAG chat**: General improvement in answer grounding
- **Lit review / methodology tables**: Minimal impact (these use section-aware DB queries, not RAG)

**Cost**: One additional API call per retrieval. Rerank APIs are cheap relative to chat completion calls already being made.

**Key decisions needed**:
- Which reranker provider/model? (Cohere, Jina, Voyage, or self-hosted?)
- Should reranking be optional (user toggle) or always-on?
- Cost logging: add a new cost category for rerank calls

### Phase 2: Citation proximity signal

**Leverage the graph you already built.**

For a given notebook, compute the shortest citation distance from each chunk's source paper to any seed paper in the notebook's citation network(s).

**Data flow**:
1. Look up `network_edges` for networks associated with this notebook (via `source_notebook_id`)
2. For each candidate chunk, find its source paper's `paper_id`
3. Compute hop distance to nearest seed: `score = 1 / (distance + 1)`
4. Papers not in any network get a neutral score (e.g., 0.5)

**What this catches that text search misses**:
- A methodologically adjacent paper that uses completely different terminology
- A foundational paper cited by many notebook papers but whose abstract doesn't match the query
- A contrasting study that disagrees with the seed — these are gold for gap analysis

**Prerequisite**: Needs a way to map chunk source IDs → OpenAlex paper IDs. Currently chunks reference `source_id` (internal document/abstract ID) and abstracts store `openalex_id`. The join path exists: `chunk.source_id → abstracts.id → abstracts.openalex_id → network_nodes.paper_id`.

### Phase 3: RRF fusion

**Now worth it — three genuinely independent signals.**

With VSS, BM25, and citation proximity producing independent ranked lists, Reciprocal Rank Fusion merges them:

```
RRF_score(chunk) = Σ  1 / (k + rank_i)
                   i ∈ {vss, bm25, citation_proximity}
```

Where `k` is a constant (typically 60) that prevents any single signal from dominating.

**Why RRF over learned fusion**: RRF is parameter-free (besides k), requires no training data, and is robust to score scale differences between signals. With only 3 signals, there's no benefit to learning weights.

**Implementation consideration**: Ragnar currently returns a single fused score from its internal VSS+BM25 combination. To do proper RRF, we'd need either:
- (a) Access to separate VSS and BM25 ranks from ragnar (may require ragnar API changes or querying the store's DuckDB directly), or
- (b) Treat ragnar's hybrid result as one signal and add citation proximity as the second signal, making it a 2-signal RRF

Option (b) is simpler and still valuable. Option (a) is better if ragnar exposes separate scores.

### Phase 4: Audit frequency boost

**Zero new infrastructure — read from existing tables.**

When `citation_audit_results` exist for a notebook, use the `backward_count + forward_count` as a relevance weight:

- A paper cited by 5/8 notebook papers is a consensus dependency — its chunks should rank higher for synthesis queries
- A paper cited by 1/8 is peripheral — still retrievable but not boosted

**Signal**: Normalize frequency to [0, 1] range across the notebook's audit results. Add as a fourth RRF signal or as a score multiplier on the RRF output.

**Caveat**: Citation audits are user-initiated and may not exist for all notebooks. This signal gracefully degrades to absent (neutral weight) when no audit data exists.

### Phase 5: Overlap paper boost

**Smallest change, targeted impact.**

Papers flagged `is_overlap = TRUE` in `network_nodes` are reachable from 2+ seed papers. These bridging papers are disproportionately useful for:
- "Agreements & Disagreements" synthesis
- Cross-cutting theme identification
- Research gap analysis (they sit at the intersection of subfields)

**Implementation**: Binary boost (e.g., multiply RRF score by 1.3) for chunks from overlap papers. Simple, no new queries needed beyond checking the flag.

### Phase 6: Co-author network (future)

**Most effort, least marginal retrieval gain — but valuable for discovery.**

Author names are already stored as JSON in the `abstracts` table. Building a co-author graph requires:

1. **New table**: `co_author_edges (author_name_a, author_name_b, paper_count, notebook_id)`
2. **Build step**: Parse author JSON for all notebook papers, create edges between co-authors on the same paper
3. **Retrieval signal**: If a user has 3 papers by Author A's lab, and Author A co-authored with Author B, then Author B's other work should rank higher even if it doesn't match the query text

**Why deprioritize**: The signal is weaker than citation proximity for chunk-level retrieval. Its real value is in **paper discovery** (suggesting new papers to add to a notebook), not in ranking chunks within existing papers.

**Alternative**: Could integrate with the citation audit system — "papers by frequent co-authors not yet in your notebook" as a discovery recommendation.

## Impact by Serapeum feature

| Feature | Phase 1 (Reranker) | Phase 2 (Citation) | Phase 3 (RRF) | Phase 4 (Audit) | Phase 5 (Overlap) |
|---------|:--:|:--:|:--:|:--:|:--:|
| RAG chat | High | Medium | Medium | Low | Low |
| Conclusions preset | High | Medium | Medium | Medium | High |
| Research questions | High | High | High | Medium | High |
| Overview preset | Low | Low | Low | Low | Low |
| Lit review table | Low | Low | Low | Low | Low |
| Methodology extractor | Low | Medium | Low | Low | Low |

"Low" for overview/lit-review/methodology because those use full-content DB queries (all chunks), not RAG top-k retrieval.

## Open questions

1. **Reranker model selection**: Cohere Rerank v3.5 is the current gold standard, but requires a separate API key. Alternatives via OpenRouter? Or a local cross-encoder model?
2. **Ragnar internals**: Can we extract separate VSS and BM25 scores from ragnar, or only the fused score? This affects whether Phase 3 is 2-signal or 3-signal RRF.
3. **User control**: Should any of this be configurable (e.g., "use citation-aware retrieval" toggle), or always-on with graceful degradation?
4. **Performance budget**: Reranker adds ~200-500ms latency per query. Acceptable for preset generation (already slow), but worth considering for interactive RAG chat.
5. **Evaluation**: How do we measure whether synthesis quality actually improved? Side-by-side comparison of preset outputs before/after? User feedback mechanism?

## Dependencies

- Phase 1 depends on: choosing a reranker provider
- Phase 2 depends on: mapping chunk source IDs to OpenAlex paper IDs (join path exists but needs implementation)
- Phase 3 depends on: Phase 2 (need a third signal to make RRF worthwhile)
- Phase 4 depends on: Phase 3 (adds to existing RRF)
- Phase 5 depends on: Phase 3 (adds to existing RRF)
- Phase 6 depends on: nothing (independent), but retrieval integration depends on Phase 3

## References

- [Reciprocal Rank Fusion (Cormack et al., 2009)](https://dl.acm.org/doi/10.1145/1571941.1572114) — original RRF paper
- [Cohere Rerank](https://docs.cohere.com/docs/reranking) — cross-encoder reranking API
- [RAG Fusion](https://arxiv.org/abs/2402.03367) — multi-query + RRF approach
- [ColBERT v2](https://arxiv.org/abs/2112.01488) — late-interaction retrieval (potential future direction)
