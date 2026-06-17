---
title: "Epic: Advanced retrieval pipeline — reranking, RRF, and structural signals"
status: completed
type: feature
priority: high
tags:
  - epic
created_at: 2026-03-06T15:24:45Z
updated_at: 2026-03-22T16:54:11Z
---

## Overview

Upgrade Serapeum's retrieval pipeline from pure text-based search (VSS + BM25) to a multi-signal system that incorporates cross-encoder reranking, citation graph proximity, and co-reference frequency. The goal is **informational substance** — denser, better-grounded LLM synthesis by feeding it higher-quality chunks.

**Design doc**: [`docs/plans/2026-03-06-advanced-retrieval-pipeline.md`](docs/plans/2026-03-06-advanced-retrieval-pipeline.md)

## Problem

Current retrieval passes ragnar's hybrid search results directly to the LLM. This creates:
- **Noise**: marginally relevant chunks dilute synthesis quality (hedging, filler, conflation)
- **Blind spots**: text-only retrieval misses chunks relevant for *structural* reasons (citation-adjacent, frequently co-referenced, bridging subfields)

## Current retrieval architecture

```
Query → ragnar (VSS + BM25 hybrid) → section filter → top-k → LLM
```

## Target architecture

```
Query
  ├─► VSS (embedding similarity)          ─┐
  ├─► BM25 (keyword match)                 ├─► RRF Fusion ─► Reranker ─► top-k → LLM
  ├─► Citation proximity (graph distance)  │
  └─► Audit frequency (co-reference count) ─┘
```

## Phases

### Phase 1: Cross-encoder reranker
**Biggest impact, smallest change.** Retrieve `limit * 4` from ragnar, rerank with a cross-encoder, return top `limit`. Directly improves conclusions, research questions, and RAG chat quality.

- [ ] Choose reranker provider (Cohere, Jina, Voyage, or via OpenRouter)
- [ ] Add `rerank_chunks()` function
- [ ] Integrate into `search_chunks_hybrid()` 
- [ ] Add cost logging for rerank calls
- [ ] Evaluate: side-by-side preset output comparison

### Phase 2: Citation proximity signal
**Leverage existing `network_edges` table.** Score chunks by shortest citation distance from source paper to any seed paper.

- [ ] Build join path: `chunk.source_id → abstracts.openalex_id → network_nodes.paper_id`
- [ ] Implement hop-distance scoring: `1 / (distance + 1)`
- [ ] Handle papers not in any network (neutral score)
- [ ] Wire into retrieval as independent ranked list

### Phase 3: RRF fusion
**Now worth it with 3+ signals.** Merge independent ranked lists using `score = Σ 1/(k + rank_i)`.

- [ ] Decide: treat ragnar hybrid as 1 signal, or split VSS/BM25 (depends on ragnar API)
- [ ] Implement RRF scoring function
- [ ] Replace current retrieval with RRF-fused pipeline
- [ ] Benchmark: retrieval diversity before/after

### Phase 4: Audit frequency boost
**Zero new infra — reads from existing `citation_audit_results`.** Papers cited by many notebook papers get a relevance boost.

- [ ] Normalize `backward_count + forward_count` to [0, 1]
- [ ] Add as fourth RRF signal (or post-RRF multiplier)
- [ ] Graceful degradation when no audit data exists

### Phase 5: Overlap paper boost
**Binary boost for bridging papers.** Papers flagged `is_overlap = TRUE` in multi-seed networks are disproportionately useful for synthesis.

- [ ] Multiply RRF score by boost factor for overlap papers
- [ ] Evaluate impact on "Agreements & Disagreements" synthesis

### Phase 6: Co-author network (future / discovery)
**Most effort, least marginal retrieval gain — but valuable for paper discovery.**

- [ ] New `co_author_edges` table
- [ ] Parse existing author JSON to build edges
- [ ] Integration with citation audit for "papers by frequent co-authors not yet in your notebook"

## Impact by feature

| Feature | Reranker | Citation | RRF | Audit | Overlap |
|---------|:--:|:--:|:--:|:--:|:--:|
| RAG chat | High | Medium | Medium | Low | Low |
| Conclusions preset | High | Medium | Medium | Medium | High |
| Research questions | High | High | High | Medium | High |
| Overview preset | Low | Low | Low | Low | Low |
| Lit review table | Low | Low | Low | Low | Low |

## Existing infrastructure to leverage

- `network_edges` table with directed citation links
- `citation_audit_results` with backward/forward frequency counts
- `is_overlap` flag on `network_nodes`
- `fwci` scores in `abstracts` table (tiebreaker)
- `source_notebook_id` linking networks to notebooks
- Section-aware chunk retrieval with `section_hint`

## Open questions

1. **Reranker provider**: Cohere Rerank v3.5 (gold standard, separate API key) vs alternatives via OpenRouter?
2. **Ragnar internals**: Can we extract separate VSS/BM25 scores, or only fused?
3. **User control**: Always-on with graceful degradation, or configurable toggle?
4. **Latency budget**: Reranker adds ~200-500ms — acceptable for presets, worth considering for chat
5. **Evaluation method**: How to measure synthesis quality improvement?

<!-- migrated from beads: `serapeum-1774459565914-120-0e3bbaeb` | github: https://github.com/seanthimons/serapeum/issues/142 -->
