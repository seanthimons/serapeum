# Requirements: Serapeum v11.0

**Defined:** 2026-03-06
**Core Value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings

## v11.0 Requirements

Requirements for Search Notebook UX milestone. Each maps to roadmap phases.

### Toolbar

- [x] **TOOL-01**: All toolbar buttons display icon+text labels (no icon-only buttons)
- [x] **TOOL-02**: Buttons reordered by workflow: Import → Edit → Seed Network → Export → Refresh → Load More
- [x] **TOOL-03**: Buttons harmonized with Catppuccin semantic color system (primary=lavender, info=sapphire, etc.)
- [x] **TOOL-04**: Visual grouping with separators between action groups (import/edit, discovery, export, data)
- [x] **TOOL-05**: Every toolbar button has a bslib tooltip (max 15 words, keyboard-accessible)
- [x] **TOOL-06**: "Papers" label removed from toolbar area

### Pagination

- [x] **PAGE-01**: Refresh button retries current search (replaces results, resets cursor)
- [x] **PAGE-02**: Load More button fetches next page of results (appends, advances cursor)
- [x] **PAGE-03**: Load More styled like Topics button (icon+text+sapphire color)
- [x] **PAGE-04**: Load More hidden when no more results available
- [x] **PAGE-05**: Cursor state resets when search query or filters change
- [x] **PAGE-06**: OpenAlex cursor-based pagination in API client (replaces offset-based)

### Document Types

- [x] **DTYPE-01**: Full 16-type OpenAlex taxonomy exposed as filter options
- [x] **DTYPE-02**: Distribution panel showing type counts moved above filter checkboxes
- [x] **DTYPE-03**: Type badge styling for each document type in search results

### Year Filter

- [ ] **YEAR-01**: Year slider and histogram visually aligned (CSS fix for #143)

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Filtering UX

- **FILT-01**: Active filter chips displayed above results with remove buttons
- **FILT-02**: "Clear All" button when multiple filters active

## Out of Scope

| Feature | Reason |
|---------|--------|
| Custom color themes | Breaks accessibility (WCAG contrast), maintenance burden — Catppuccin only |
| Infinite scroll | Goal-oriented academic search needs explicit control and position awareness |
| Document type collapsible groups | 16 types manageable in flat list; grouping adds complexity without clear value |
| Analytics instrumentation | Would inform button ordering validation but adds scope — defer to v11.1 |
| Load More batch size setting | Start with existing page size; add setting only if users request |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TOOL-01 | Phase 53 | Complete |
| TOOL-02 | Phase 53 | Complete |
| TOOL-03 | Phase 53 | Complete |
| TOOL-04 | Phase 53 | Complete |
| TOOL-05 | Phase 54 | Complete |
| TOOL-06 | Phase 53 | Complete |
| PAGE-01 | Phase 51 | Complete |
| PAGE-02 | Phase 52 | Complete |
| PAGE-03 | Phase 52 | Complete |
| PAGE-04 | Phase 52 | Complete |
| PAGE-05 | Phase 51 | Complete |
| PAGE-06 | Phase 50 | Complete |
| DTYPE-01 | Phase 55 | Complete |
| DTYPE-02 | Phase 55 | Complete |
| DTYPE-03 | Phase 55 | Complete |
| YEAR-01 | Phase 56 | Pending |

**Coverage:**
- v11.0 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-06*
*Last updated: 2026-03-06 after roadmap creation (100% coverage)*
