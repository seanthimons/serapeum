# Serapeum — Research Discovery Platform

## What This Is

Serapeum is a local-first research assistant built with R/Shiny that helps researchers find, filter, and synthesize academic papers. It combines document notebooks (upload PDFs, chat with RAG) and search notebooks (OpenAlex paper search, quality filtering) with LLM-powered chat and slide generation. Three discovery modes — seed paper lookup, LLM-assisted query building, and topic hierarchy browsing — provide multiple entry points for finding relevant research. Quality-of-life features include per-request cost tracking, dynamic model selection, interactive keyword filtering, and journal quality controls with personal blocklists.

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
- ✓ Per-request LLM cost tracking (COST-01) — v1.1
- ✓ Session cost total in UI (COST-02) — v1.1
- ✓ Cost history and trends (COST-03) — v1.1
- ✓ Expanded model selection with pricing (MODL-01) — v1.1
- ✓ Model details in settings (MODL-02) — v1.1
- ✓ Keyword include filter (KWRD-01) — v1.1
- ✓ Keyword exclude filter (KWRD-02) — v1.1
- ✓ Visual keyword state distinction (KWRD-03) — v1.1
- ✓ Real-time keyword filtering (KWRD-04) — v1.1
- ✓ Predatory journal warning badges (JRNL-01) — v1.1
- ✓ Predatory journal filter toggle (JRNL-02) — v1.1
- ✓ Personal journal blocklist (JRNL-03) — v1.1
- ✓ Blocklist management (JRNL-04) — v1.1

- ✓ Fix 401 error on OpenAlex topic searches #59 (BUGF-01) — v1.2
- ✓ User-friendly API error messages #65 (BUGF-02) — v1.2
- ✓ Prevent tab-swap OpenAlex re-request #68 (BUGF-03) — v1.2
- ✓ Collapsible Journal Quality card #73 (UIPX-01) — v1.2
- ✓ Fix block badge misalignment #72 (UIPX-02) — v1.2

### Active

## Current Milestone: v2.0 Discovery Workflow & Output

**Goal:** Make discovery modes fluid and interconnected, add DOI visibility, and enable research output export (citations, synthesis).

**Target features:**
- DOI on abstract preview (#66)
- Export abstract to seeded paper search (#67)
- Seeded search same view as abstract preview (#71)
- Citation network graph (#53)
- Citation export (#64)
- Export synthesis outputs (#49)

### Out of Scope

- Recursive abstract searching (#11) — high complexity, future milestone
- PDF image pipeline (#44) — epic-level effort, future milestone
- Local model support (#8) — significant architecture change, future
- Conclusion synthesis (#27) — depends on better document understanding first
- Audio overview (#22) — experimental, low priority
- Bulk DOI/.bib import (#24) — deferred, needs UX design
- Rich output preview (#50) — deferred, build export first
- Additional synthesis outputs (#63) — deferred, build export first

## Context

Shipped v1.1 with ~11,400 LOC R across 17 modified files (+1,569 / -287 from v1.0).
Tech stack: R + Shiny + bslib + DuckDB + OpenRouter + OpenAlex.
Architecture: Shiny module pattern (mod_*.R) with producer-consumer discovery modules.
mod_search_notebook.R reduced from 1,778 to ~1,410 lines through modularization (keyword filter, journal filter).
Three new modules added in v1.1: mod_cost_tracker.R, mod_keyword_filter.R, mod_journal_filter.R.
Cost tracking logs all LLM operations (chat, embedding, query building, slides) to cost_log table.
Dynamic model pricing fetched from OpenRouter API with curated provider filter.

## Constraints

- **Tech stack**: R + Shiny + bslib + DuckDB — no framework changes
- **API**: OpenRouter for LLM, OpenAlex for academic data — no new external services
- **Architecture**: Shiny module pattern (`mod_*.R`) — new features follow existing conventions
- **Local-first**: No server infrastructure; everything runs on user's machine

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fix #55 before new features | Abstract embedding broken = search chat broken | ✓ Good — unblocked all RAG testing |
| Startup wizard as discovery hub | Users need clear entry points | ✓ Good — three clear paths |
| All three discovery paths (seed, query, topic) | Serve different research workflows | ✓ Good — cohesive discovery experience |
| Producer-consumer pattern for discovery modules | Clean separation, reused across 3 modules | ✓ Good — reusable pattern |
| Migration versioning via schema_migrations table | DuckDB lacks PRAGMA user_version | ✓ Good — clean upgrade path |
| LLM filter validation against allowlist | Prevents injection of invalid OpenAlex filters | ✓ Good — safe query generation |
| 30-day cache TTL for topics | Topics change infrequently | ✓ Good — fast browsing |
| CSS injection for slide citations | Self-contained slides without external deps | ✓ Good |
| API functions return structured lists (v1.1) | Needed for cost metadata alongside content | ✓ Good — all callers updated |
| Mutable pricing_env for dynamic model pricing | Live pricing from API without breaking compat | ✓ Good — accurate cost estimates |
| Composable filter chain pattern (v1.1) | keyword → journal quality → display | ✓ Good — clean modular pipeline |
| Blocked journals always hidden, predatory toggleable | Blocking is explicit user intent | ✓ Good — intuitive UX |
| Separate modules for new features (v1.1) | Prevent monolith growth | ✓ Good — reduced main file by 368 lines |
| Defer Bulk Import to v1.2 | Stretch goal, all core v1.1 features shipped | ✓ Good — clean milestone |

---
*Last updated: 2026-02-12 after v2.0 milestone started*
