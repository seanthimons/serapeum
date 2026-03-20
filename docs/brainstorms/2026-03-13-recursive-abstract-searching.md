---
date: 2026-03-13
topic: recursive-abstract-searching
issue: https://github.com/seanthimons/serapeum/issues/11
milestone: v13.0 Search & Discovery
---

# Research Refiner — Recursive Abstract Searching

## The Problem

Serapeum's discovery tools (citation audit, network graph, seed search, query builder) are effective at generating large candidate pools. But users rapidly get overwhelmed by combinatorial explosion — 5 seeds x 100 nodes x 3 iterations produces thousands of papers. Most are topically *relevant* but not *useful*: foundational papers everyone already knows, tangential work, redundant findings. There's no way to separate signal from noise at scale without reading every abstract.

## What We're Building

A dedicated **Research Refiner** module (new sidebar entry) that scores, ranks, and triages a large pool of candidate papers against a user-defined anchor — returning the papers most *useful* to the research narrative, not just the most *relevant* to the field.

The refiner operates in two tiers:
- **Tier 1 (Metadata scoring)** — fast, cheap, no LLM cost. Composite score from citation velocity, FWCI, graph connectivity, recency, and a ubiquity penalty that suppresses foundational bloat.
- **Tier 2 (LLM-as-judge)** — optional, user-initiated. Embeds candidates, compares against anchors, and uses an LLM to evaluate narrative utility ("does this abstract add something the current set doesn't cover?").

## Core Concepts

### The Anchor

The anchor defines "what I'm looking for." Users can set any combination of:
- **Seed paper(s)** — one or more papers that define the research space
- **Natural language intent** — a description of the research question or narrative goal
- **Both** — seeds provide the embedding signal, intent provides the evaluative frame

### The Utility Score

Raw citation count is biased toward old, foundational papers. The utility score age-normalizes and structurally weights candidates:

```
utility_score = w1 * seed_connectivity       # How many anchors connect to this paper
             + w2 * bridge_score             # Connects otherwise disconnected clusters
             + w3 * citation_velocity        # citations_per_year, not raw count
             + w4 * fwci                     # Field-relative impact
             - w5 * ubiquity_penalty         # Cited by >X% of field = assumed knowledge
```

The **ubiquity penalty** is the key anti-bloat mechanism — papers that everyone cites are foundational, not discoveries. A 1995 paper with 5000 citations and a 2023 paper with 50 citations may have equal or inverted utility depending on the research question.

### Preset Modes

| Mode | Personality | Favors | Penalizes |
|------|------------|--------|-----------|
| **Discovery** | "Find what I'm missing" | Bridge papers, novel connections, emerging work | Foundational bloat, redundancy with existing set |
| **Comprehensive** | "Build the full picture" | High connectivity, seminal + recent, broad coverage | Nothing penalized heavily — widest net |
| **Emerging** | "What's new and rising" | Recent papers, high citation velocity, high FWCI | Old papers regardless of impact |

An **Advanced toggle** exposes individual weight sliders for each score component.

## Entry Paths

### Path A: "I already have candidates"

Source: citation audit results, network graph nodes, or query builder output. The candidate pool already exists — the refiner scores and ranks it. Zero additional OpenAlex API cost.

### Path B: "Start from seeds"

User provides seed paper(s) via DOI entry or bulk upload. The system fetches related/citing/cited papers from OpenAlex to build the candidate pool, then scores it. More creative freedom, higher API cost.

Both paths converge at the same scoring + ranking interface.

## Workflow

1. User opens **Research Refiner** from sidebar
2. **Sets the anchor** — seed paper(s), natural language intent, or both
3. **Selects candidate source** — existing results (Path A) or fetch from seeds (Path B)
4. **Chooses mode** — Discovery / Comprehensive / Emerging, with optional Advanced sliders
5. **Tier 1 runs** — metadata scoring across candidate pool. Fast, no LLM cost.
6. **Results displayed ranked** — scored list with composite utility score. User can review, accept, reject.
7. **At ~50-100 papers, modal nudge** — "Want to run deep analysis? This will embed and LLM-score these papers." Includes cost estimate.
8. **Tier 2 (optional)** — embed candidates, compare against anchors via similarity, LLM evaluates each for narrative utility
9. **User curates final set** — accepts papers into destination:
   - Import into an existing notebook (search or document)
   - Create a new notebook with accepted papers

## Three Interaction Workflows

### Batch Scoring
System scores everything in the background, presents a ranked list. User reviews top-N and accepts/rejects. Like citation audit but with intelligent ranking.

### Iterative Loop
Score → user reviews a batch → user feedback (accept/reject) refines scoring → next batch. The system learns what "useful" means for this notebook over successive rounds.

### One-Shot Prune
User says "clean this up" — system removes everything below a threshold. Undo available. Good for large noisy sets where the user trusts the scoring.

## Architecture Notes

- **Standalone module**: `mod_research_refiner.R` with dedicated sidebar button
- **Reuses citation audit infrastructure**: candidate fetching, batch OpenAlex calls, progress modals, result storage pattern
- **Scoring engine is a shared utility**: could be reused by citation audit or network graph in the future
- **Tier 2 uses existing ragnar/embedding pipeline**: no new embedding infrastructure needed
- **LLM evaluation reuses chat_completion()**: same cost tracking, model selection

## Key Decisions

- **Dedicated module, not embedded in search notebook**: clean separation, own sidebar entry
- **Two-tier scoring**: metadata first (free), LLM second (opt-in with cost transparency)
- **Ubiquity penalty**: actively suppress foundational bloat rather than just boosting recency
- **Preset modes with optional tuning**: opinionated defaults, power-user escape hatch
- **Notebook-agnostic output**: user chooses where accepted papers go (existing or new notebook)
- **Two entry paths**: reuse existing candidates (cheap) or fetch from seeds (flexible)

## Open Questions

- Exact weight defaults for each preset mode — needs tuning against the test seed paper set
- Ubiquity threshold — what percentage of field citation makes a paper "assumed knowledge"? May vary by field.
- Tier 2 LLM prompt design — how to frame "narrative utility" evaluation. Needs iteration.
- Should the iterative loop persist feedback across sessions, or is it session-only like keyword states?
- Bridge score calculation — requires graph structure. Only available when candidates come from network graph or citation audit, not from raw search results.

## Next Steps

→ Plan implementation, likely phased:
1. Tier 1 scoring engine + UI shell
2. Preset modes + Advanced sliders
3. Path A integration (citation audit / network graph as source)
4. Path B integration (seed-based fetching)
5. Tier 2 LLM evaluation
6. Iterative feedback loop
