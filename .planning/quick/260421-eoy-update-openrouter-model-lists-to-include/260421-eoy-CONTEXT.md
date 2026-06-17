# Quick Task 260421-eoy: Update OpenRouter model lists to include current embedding models - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Task Boundary

Update all three model category defaults (embedding, chat, rerank) by fetching current models from OpenRouter API. Add CISA-country provider filtering toggle. Expand KNOWN_EMBED_DIMS with hybrid caching approach.

</domain>

<decisions>
## Implementation Decisions

### Scope of Update
- Update all three model categories: embedding, chat, and rerank defaults
- All live in the same area of code (api_openrouter.R, api_provider.R, api_rerank.R)

### Source of Truth
- Use live OpenRouter API fetch to determine current models
- Add config.yml toggle to always check model endpoints on startup (user noted the app should be doing this already)
- The dynamic list_*_models() functions already exist but defaults are stale

### Dimension Table
- Hybrid approach: keep KNOWN_EMBED_DIMS as fast-path lookup, probe unknowns via test embedding, cache probe results in DB
- OpenRouter API does NOT expose embedding dimensions in /models response metadata
- Existing `detect_embedding_dimension()` already has probe fallback — just needs DB caching layer

### CISA-Country Filter
- Add `compliance.cisa_filter: true/false` toggle in config.yml
- When enabled, filter out models from providers headquartered in CISA-designated adversary nations
- Research needed: which providers/countries to block, how to map provider prefixes to countries

</decisions>

<specifics>
## Specific Ideas

- User wants to understand why model lists aren't fetched on app startup — investigate and add config option
- CISA filter should be a simple boolean toggle, not a complex compliance framework
- Config.yml is the right place (consistent with existing pattern)

</specifics>

<canonical_refs>
## Canonical References

- OpenRouter /models API endpoint (architecture.modality field for filtering)
- CISA known-adversary nation list (needs research)

</canonical_refs>
