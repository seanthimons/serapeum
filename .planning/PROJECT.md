# Serapeum — Research Discovery Platform

## What This Is

Serapeum is a local-first research assistant built with R/Shiny that helps researchers find, filter, and synthesize academic papers. It combines document notebooks (upload PDFs, chat with RAG) and search notebooks (OpenAlex paper search, quality filtering) with LLM-powered chat and slide generation. Three discovery modes — seed paper lookup, LLM-assisted query building, and topic hierarchy browsing — provide multiple entry points for finding relevant research.

## Core Value

Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — all from a guided startup experience.

## Requirements

### Validated

- ✓ Document notebooks with PDF upload and RAG chat — existing
- ✓ Search notebooks via OpenAlex with keyword filtering — existing
- ✓ Quality filtering (retraction watch, predatory journals/publishers) — existing
- ✓ Quarto slide deck generation from chat — existing
- ✓ Settings page with model configuration and API key validation — existing
- ✓ Deferred embedding workflow with "Embed Papers" button — existing
- ✓ Document type filters and OA/citation badges — existing
- ✓ Database migration versioning (INFRA-01) — v1.0
- ✓ Topics table schema (INFRA-02) — v1.0
- ✓ Fix abstract embedding #55 (DISC-01) — v1.0
- ✓ Seed paper search #25 (DISC-02) — v1.0
- ✓ Meta-prompt query builder #10 (DISC-03) — v1.0
- ✓ OpenAlex topics & discovery #40 (DISC-04) — v1.0
- ✓ Startup wizard UI #43 (DISC-05) — v1.0
- ✓ Rich sorting for search results #54 (DISC-06) — v1.0
- ✓ Fix slide generation citation size #51 (DISC-07) — v1.0

### Active

(None yet — define in next milestone)

### Out of Scope

- Citation network graph (#53) — deferred to future milestone
- Recursive abstract searching (#11) — high complexity, future milestone
- PDF image pipeline (#44) — epic-level effort, future milestone
- Local model support (#8) — significant architecture change, future
- Conclusion synthesis (#27) — depends on better document understanding first
- Audio overview (#22) — experimental, low priority

## Context

Shipped v1.0 with 9,856 LOC R across 42 modified files.
Tech stack: R + Shiny + bslib + DuckDB + OpenRouter + OpenAlex.
Architecture: Shiny module pattern (mod_*.R) with producer-consumer discovery modules.
Known issue: mod_search_notebook.R is 1,760 lines — new features must be separate modules.
Known bug: Seed discovery ("Discover from Paper") prompts for email even when already configured.

## Constraints

- **Tech stack**: R + Shiny + bslib + DuckDB — no framework changes
- **API**: OpenRouter for LLM, OpenAlex for academic data — no new external services
- **Architecture**: Shiny module pattern (`mod_*.R`) — new features follow existing conventions
- **Local-first**: No server infrastructure; everything runs on user's machine

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fix #55 before new features | Abstract embedding broken = search chat broken, blocks testing new discovery features | ✓ Good — unblocked all RAG testing |
| Startup wizard as discovery hub | Users need clear entry points; current flow requires knowing what to do | ✓ Good — three clear paths |
| All three discovery paths (seed, query, topic) | They serve different research workflows; together they form a complete loop | ✓ Good — cohesive discovery experience |
| Include sorting (#54) in this milestone | Sorting enhances discovery results view — natural fit with new search features | ✓ Good — low effort, high value |
| Defer citation graph (#53) | Medium complexity, better as standalone milestone after discovery paths work | — Pending |
| Producer-consumer pattern for discovery modules | Discovery modules output reactive requests consumed by app.R to create notebooks | ✓ Good — clean separation, reused across 3 modules |
| Migration versioning via schema_migrations table | DuckDB doesn't support PRAGMA user_version; file-based SQL migrations | ✓ Good — clean upgrade path |
| LLM filter validation against allowlist | Prevents injection of invalid OpenAlex filter attributes | ✓ Good — safe query generation |
| 30-day cache TTL for topics | Topics change infrequently, reduces API load | ✓ Good — fast browsing after first fetch |
| CSS injection for slide citations | Inline in YAML frontmatter for self-contained slides | ✓ Good — no external dependencies |

---
*Last updated: 2026-02-11 after v1.0 milestone*
