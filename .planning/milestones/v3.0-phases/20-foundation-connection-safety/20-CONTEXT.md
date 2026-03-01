# Phase 20: Foundation & Connection Safety - Context

**Gathered:** 2026-02-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish deterministic path construction, metadata encoding, and connection lifecycle patterns for per-notebook ragnar stores. This is internal infrastructure — no new user-facing features. Outputs: path helpers, metadata encode/decode, version checks, connection cleanup hooks.

</domain>

<decisions>
## Implementation Decisions

### Version mismatch behavior
- Warn but allow use — don't block RAG features on incompatible ragnar version
- Minimal safety net: console warning + disable RAG if incompatible. No fancy UI — renv will handle this properly later
- Lazy check on first RAG use, not at startup. Cache result for session
- #TODO in code noting this could be replaced by renv version pinning

### Connection error handling
- Global notification (toast/banner) when store connection fails, not inline errors
- Aggressive cleanup: any error closes the connection. #TODO comment noting this could be relaxed to selective cleanup later
- Auto-retry on next feature use — no manual "Reconnect" button needed
- Close connections on browser tab close via Shiny's onSessionEnded

### Metadata encoding strategy
- Human-readable format in ragnar's origin field (pipe/colon-delimited key-value pairs)
- Three fields encoded: section_hint + DOI + source_type (PDF upload vs abstract embed)
- On decode failure: treat chunk as "general" (no section targeting), gracefully attempt correction
- Validate encoding on write only — trust format on read for performance

### Store path conventions
- Path pattern: `data/ragnar/{uuid}.duckdb` where UUID is per-notebook
- Add UUID column to notebooks table — existing notebooks will be purged (v3.0 fresh start), so no migration needed
- `data/ragnar/` directory created eagerly on app startup
- `data/` directory already gitignored — no changes needed

### Claude's Discretion
- Exact origin field delimiter syntax (pipes, colons, etc.)
- DuckDB connection pool implementation details
- Version comparison logic (semver parsing approach)
- Error message wording for global notifications

</decisions>

<specifics>
## Specific Ideas

- User mentioned renv is planned for package management — version check should be a minimal safety net, not a full solution
- Existing notebooks will be purged as part of v3.0 migration — no need for UUID migration, just add column for new notebooks
- Code should include #TODO markers on aggressive cleanup and version check patterns indicating these are intentionally simple and can be refined later

</specifics>

<deferred>
## Deferred Ideas

- renv setup for package namespace management — tooling todo, not in v3.0 scope

</deferred>

---

*Phase: 20-foundation-connection-safety*
*Context gathered: 2026-02-16*
