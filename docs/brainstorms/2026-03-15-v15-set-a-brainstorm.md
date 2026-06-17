---
date: 2026-03-15
topic: v15-set-a-ai-infrastructure
---

# v15 Set A: OA Usage Tracking + Retrieval Quality

## What We're Building

Three parallel workstreams that form the foundation of the v15 AI Infrastructure milestone.

### #157: OpenAlex Usage Tracking

OpenAlex migrated from the old `mailto` polite pool to a freemium API key model (Feb 2026). Free keys get $1/day credit. Serapeum still uses the legacy `mailto` parameter and doesn't read any usage headers.

**Three layers:**

1. **Migration nudge** — Detect users with `mailto` but no `api_key`. Prompt them to create a free OA API key at openalex.org/settings/api.
2. **Usage tracking** — Parse response headers (`X-RateLimit-Remaining`, `X-RateLimit-Credits-Used`, `cost_usd` in response meta) from every OA response. Log to DB. Full breakdown in Cost Tracker tab mirroring the OpenRouter section.
3. **Warning system** — Sidebar percentage badge showing daily budget consumed. Color shifts yellow → red as budget depletes. One-time toast at ~90% usage threshold.

**Not building:** Confirmation modals or hard gates on expensive operations. Warning only for now.

**OA endpoint cost reference (per 1,000 calls):**

| Operation | Cost |
|-----------|------|
| Singleton (by ID/DOI) | Free |
| List + Filter | $0.10 |
| Full-text search | $1.00 |
| Semantic search | $1.00 |
| PDF download | $10.00 |

**Daily free tier ($1/day):** Unlimited singletons, 10K list+filter, 1K searches, 100 PDF downloads.

**Response headers to parse:**
- `X-RateLimit-Limit` — daily budget total
- `X-RateLimit-Remaining` — balance remaining
- `X-RateLimit-Credits-Used` — this request's cost
- `X-RateLimit-Reset` — seconds until midnight UTC reset
- `cost_usd` in response meta object

**OA also provides:** `/rate-limit` endpoint for full account status and openalex.org/settings/usage dashboard.

### #12 + #48: Retrieval Quality (resolves both issues)

Current pipeline: `query → ragnar (VSS + BM25 hybrid) → notebook filter → section filter → top-k → LLM`

Problem: retrieval quality isn't sharp enough for high-quality synthesis, especially in small-notebook scenarios (3 PDFs, no citation network). Citation/audit signals from #142 don't help here.

**Three techniques committed:**

1. **Query reformulation (RAG-Fusion style)** — Generate 3-5 query variants via a fast LLM call, run each through ragnar's separate `ragnar_retrieve_vss()` and `ragnar_retrieve_bm25()`, RRF-merge all ranked lists. Catches synonyms and angle differences that single-query retrieval misses. Adds one small-model LLM call (~200-400ms).
2. **Split VSS/BM25 with RRF fusion** — ragnar exposes separate retrieval methods with independent `cosine_distance` and `bm25` scores. Running both per query variant gives 6-10 independent ranked lists. RRF (`score = Σ 1/(k + rank_i)`) finds consensus relevance across all signals.
3. **Contextual chunk headers** — Prepend paper title + section hint to chunk text at index time. Helps disambiguate chunks from different papers during retrieval and gives the LLM better citation context. Requires re-indexing existing notebooks.

**Deferred:** Cross-encoder reranker (adds a third API key — Cohere/Jina — which conflicts with local-first philosophy; can be added later as optional power-user feature). FILCO-style span filtering (on the fence). Citation proximity, audit frequency, overlap boost (these are #142 Phases 2-5, only relevant when networks exist).

**Target pipeline:**
```
User query
  → OpenRouter (fast model): generate 3-5 query variants
  → For each variant:
      → ragnar_retrieve_vss(top_k=20)   → ranked list A₁, A₂, A₃...
      → ragnar_retrieve_bm25(top_k=20)  → ranked list B₁, B₂, B₃...
  → RRF merge all lists: score = Σ 1/(k + rank_i)
  → Deduplicate by chunk content
  → Take top-k
  → LLM
```

**Side fix discovered:** `_ragnar.R:1051` — abstract chunks are labeled `[Abstract]` instead of the actual paper title. This is the root cause of #159 (chat doesn't reference papers correctly). The contextual chunk headers work will fix this.

## Why This Approach

- **Query reformulation** specifically addresses the small-notebook problem where a single query misses relevant chunks due to vocabulary mismatch (the #159 "emerging contaminants" example). Biggest win for retrieval recall.
- **Split VSS/BM25 + RRF** leverages ragnar's existing separate retrieval methods to find consensus relevance across multiple independent signals. No external API needed.
- **Contextual headers** are low effort and improve both retrieval (better embeddings) and generation (better citations) simultaneously.
- These three techniques stack multiplicatively, require zero new API keys, and work without any external infrastructure (no citation network required).
- **Reranker deferred** — evaluated Cohere Rerank 4 Pro ($0.05/1M, ELO 1629), Voyage 2.5, Jina v2. Adding a third API key conflicts with local-first philosophy. RRF + reformulation gets ~70-80% of reranker quality gain. Reranker can be added later as optional power-user feature.

## Key Decisions

- **Reranker**: Deferred. Evaluated Cohere Rerank 4 Pro, Voyage 2.5, Jina v2 — all require a new API key. Can be added later as optional power-user feature.
- **Query reformulation model**: Use a fast/cheap model (e.g., flash-lite) since it's generating search variants, not user-facing text.
- **Re-indexing UX**: Leverage existing missing-index detection path. Extend it to detect stale stores (no contextual headers) and surface the same "please re-index" prompt. No new UI needed.
- **#12 resolution**: Reranker deferred. RRF + query reformulation used instead. No new API key needed.
- **#48 resolution**: Retrieval quality improves via query reformulation + RRF + contextual headers. No user-facing document selection controls needed.
- **#142 update**: Query reformulation + RRF is new Phase 1. Cross-encoder reranker moved to optional future phase. Citation/audit signals remain later phases.
- **Warning not gating**: OA budget warnings only — no confirmation modals or hard blocks on expensive operations.

## Resolved Questions

- **Reranker provider**: Deferred. Cohere Rerank 4 Pro was the top pick (ELO 1629, $0.05/1M, 614ms) but adding a third API key conflicts with local-first philosophy. Optional later.
- **Ragnar separate scores**: Yes — `ragnar_retrieve()` returns both `cosine_distance` and `bm25` columns. Plus `ragnar_retrieve_vss()` and `ragnar_retrieve_bm25()` exist as separate functions. Full RRF is possible.

## Open Questions

- FILCO-style span filtering: revisit after reformulation + RRF are in and we can measure quality delta.

## Next Steps

→ Plan implementation for #157 (OA usage tracking) — independent, can start immediately
→ Plan implementation for retrieval quality (#12/#48 → feeding into #142 Phase 1) — reranker + query reformulation + contextual headers
→ Update #142 issue to reflect revised phase ordering
→ Close #12 and #48 with resolution notes pointing to the implementation plan
