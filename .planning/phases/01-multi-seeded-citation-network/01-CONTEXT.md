# Phase 1: Multi-Seeded Citation Network - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning
**Source:** MULTI-PAPER-SEEDING-GAP.md + discuss-phase

<domain>
## Phase Boundary

Extend the citation network from single-seed to multi-seed architecture. Users can send all papers from a document notebook (or BibTeX import) as seeds for a combined citation network. The network includes a discovery + import workflow: users can see which network papers are missing from their notebook and import them directly. This phase does NOT merge the citation audit module into the network — the audit remains a separate feature.

</domain>

<decisions>
## Implementation Decisions

### Seed Selection
- Two entry points for seeding the network:
  1. **BibTeX import** — finish the existing stub button in `mod_bulk_import.R:810-815` that currently only shows a notification
  2. **Document notebook toolbar** — new button alongside Import/Export/Edit/Refresh that sends papers to the citation network tab
- All papers in the notebook become seeds (no per-paper selection)
- Clicking either button auto-switches to the Citation Network tab
- Network does NOT auto-build — user adjusts controls (depth, direction, node cap) then clicks "Build Network", same workflow as single seed

### Network Merging
- BFS runs from each seed paper independently
- Per-seed node cap using the existing slider (max 200 per seed)
- No overall hard ceiling — vis.js handles ~2,000 nodes smoothly; typical notebooks (5-20 papers) won't exceed this
- Deduplicate papers reachable from multiple seeds
- Year-based color gradient (viridis palette) is preserved — no color-by-seed-origin

### Seed & Overlap Visualization
- All seed papers get star shape (same as current single-seed behavior)
- Papers reachable from 2+ seeds get diamond shape (indicates shared/important papers)
- Regular papers remain dots
- Small legend in graph corner: star = seed, diamond = multi-seed overlap, dot = regular — build on existing collapsible legend structure
- Tooltips remain unchanged (title, authors, year, citations) — no seed-connection info in tooltips

### Discovery + Import Workflow
- After building a network, the right side panel becomes tabbed:
  - **"Paper Details" tab** — current behavior (shows details when clicking a node)
  - **"Missing Papers" tab** — lists network nodes NOT in the originating notebook, with import buttons
- "Missing Papers" determined by a DuckDB set-difference query (network node paper_ids vs notebook abstracts), not by running the full citation audit module
- Imported papers go into the originating notebook (the one that provided the seeds)
- This is explicitly NOT a full audit integration — it's a lightweight discovery + import workflow

### Build Workflow
- Fresh build each time — no incremental seed addition to existing graphs
- Existing progress modal reused, with per-seed progress messages: "Processing seed 3/10... Depth 2/2"
- Same ExtendedTask + mirai async pattern as current single-seed builds

</decisions>

<specifics>
## Specific Ideas

- The gap analysis document (MULTI-PAPER-SEEDING-GAP.md) describes the architectural gap: `current_seed_id()` accepts one ID, needs to become `current_seed_ids()` (reactive list)
- BULK-08 was marked complete in v7.0 but is actually a stub — the "Seed Citation Network" button at `mod_bulk_import.R:685` only shows a notification
- A structured debate concluded that "Network Discovery + Import" (lightweight gap check + import buttons) delivers 80% of a unified view's value at 20% of the cost, while preserving modularity and reversibility
- User noted that multi-seed overlap visualization "will take many iterations to get correct: user-tests will be helpful here"

</specifics>

<deferred>
## Deferred Ideas

- **AUDIT-09**: Export citation gaps as BibTeX — remains a separate future feature for the citation audit module
- **AUDIT-10**: Multi-level backward citation mining (depth=2+ references of references) — future audit enhancement
- **Full unified view**: Merging network and audit into one interface was debated and deferred — too high cost/complexity for Phase 1, but the lightweight discovery + import workflow is a stepping stone
- **Color-by-seed-origin**: Coloring nodes by which seed they came from was considered but deferred — year-based coloring is more useful for understanding temporal citation structure
- **Incremental seed addition**: Adding seeds to an existing graph without rebuilding was considered but deferred — adds complex state management

</deferred>

---

*Phase: 01-multi-seeded-citation-network*
*Context gathered: 2026-03-01*
