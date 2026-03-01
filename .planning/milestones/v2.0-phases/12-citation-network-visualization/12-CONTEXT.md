# Phase 12: Citation Network Visualization - Context

**Gathered:** 2026-02-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can visually explore citation relationships through interactive network graphs to discover related papers. The network is seeded from a paper and shows forward/backward citations as a force-directed graph. Saved graphs are first-class sidebar objects persisted in DuckDB.

</domain>

<decisions>
## Implementation Decisions

### Graph Layout & Visual Style
- Force-directed cluster layout (Connected Papers style) — related papers cluster together, seed paper centered
- Node size represents citation count (more-cited = larger)
- Node color uses a multicolor gradient for publication year (cool to warm: older = cool, newer = warm)
- Color palette must be colorblind-friendly — default to viridis or magma
- Palette toggle in settings to switch between different colorblind-friendly palettes
- Seed paper distinguished with a distinct border ring AND different shape (star/diamond)
- No labels on nodes by default — clean graph, labels appear on hover
- Edges show directional arrows indicating citation direction (A cites B)
- Always-visible legend panel showing color = year range, size = citation count

### Interaction & Navigation
- Hover: highlight connected edges AND show tooltip with paper details (title, authors, year, citation count)
- Click: opens a side panel with full abstract detail (title, authors, year, journal, DOI link, abstract text, citation count)
- Side panel includes an "Explore from here" button that rebuilds the network around the selected paper as new seed
- Standard pan/zoom for graph navigation

### Network Scope & Loading
- User toggle for citation direction: forward citations (papers citing the seed), backward citations (papers the seed cites), or both
- User slider for network depth: 1-3 hops from seed paper
- Node cap adjustable by user (range ~25-200) — keeps performance controllable
- When exceeding node cap, trim by keeping most-cited papers first (surfaces influential work)
- Progressive graph building — nodes appear and settle into position as data arrives from OpenAlex
- Citation graph data persisted in DuckDB — instant reload across sessions
- Saved graphs appear in sidebar like notebooks (first-class objects)
- User names graphs when saving (prompted for a name)
- Delete saved graphs instantly from sidebar (no confirmation dialog)

### Entry Points & Integration
- Two entry points: sidebar "New Network" option and from seeded paper search
- Network graph takes over the full content area (like switching to a notebook)
- Saved networks get their own dedicated section in sidebar, separate from notebooks
- From sidebar: mini search dialog (like seed paper search) to find and select the seed paper
- From seeded paper search: "Network" icon on each result card AND "Explore Citations" button in detail view

### Claude's Discretion
- Graph background (dark vs light — pick what works best with colorblind palettes)
- Exact spacing, typography, and panel sizing
- Loading skeleton/spinner design during progressive build
- Exact node shape for seed paper (star vs diamond vs other)
- Physics/force parameters for the layout algorithm
- Hover tooltip positioning and styling

</decisions>

<specifics>
## Specific Ideas

- **Connected Papers** is the primary inspiration — force-directed similarity graph with clean visual design
- Graphs should feel like first-class objects in the app, not throwaway views — saved in sidebar, named by user, persisted in database
- Colorblind accessibility is a priority — viridis/magma palettes, settings toggle for alternatives
- Progressive build creates a more engaging experience than a loading spinner

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-citation-network-visualization*
*Context gathered: 2026-02-12*
