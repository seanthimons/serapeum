# Requirements: Serapeum v10.0

**Defined:** 2026-03-04
**Core Value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings

## v10.0 Requirements

Requirements for v10.0 Theme Harmonization & AI Synthesis. Each maps to roadmap phases.

### Tech Debt

- [x] **DEBT-01**: Connection leak in search_chunks_hybrid is fixed (#117)
- [x] **DEBT-02**: Dead code removed — with_ragnar_store() and register_ragnar_cleanup() (#119)

### Design System

- [x] **DSGN-01**: Global color/theme policy document defines button semantics (primary/secondary/danger/success/warning), icon-action mappings, and sidebar theming rules (#138)
- [x] **DSGN-02**: Visual swatch sheet rendered in both light and dark mode showing all button variants, icon mappings, sidebar colors, and badge styles — validated before any code changes
- [x] **DSGN-03**: All buttons across app follow the documented semantic color scheme
- [x] **DSGN-04**: Icon usage is consistent — same action uses same icon everywhere

### Bug Fixes

- [x] **BUGF-01**: Citation audit can add multiple papers without error (#134)
- [x] **BUGF-02**: Papers added via citation audit appear in the abstract notebook (#133)

### UI Theming

- [x] **THEM-01**: Sidebar colors adapt correctly to both light and dark mode (#137)
- [x] **THEM-02**: Citation audit button is readable in light mode (#137)
- [x] **THEM-03**: Import papers button has a distinct color from primary buttons (#137)
- [x] **THEM-04**: Abstract notebook buttons follow global theme — either all icons or all icon+text, consistent hover states (#139)
- [x] **THEM-05**: Button bar uses available title bar space effectively (#139)

### AI Synthesis — Methodology Extractor

- [x] **METH-01**: User can generate a Methodology Extractor report from document notebook (#100)
- [x] **METH-02**: Report extracts structured fields: study design, data sources, sample characteristics, statistical methods, tools/instruments
- [x] **METH-03**: Extraction uses section-targeted RAG to prioritize Methods/Materials sections
- [x] **METH-04**: Report includes per-paper citations linking findings to source documents
- [x] **METH-05**: AI disclaimer banner is shown on generated output

### AI Synthesis — Gap Analysis Report

- [ ] **GAPS-01**: User can generate a Gap Analysis Report from document notebook (#101)
- [ ] **GAPS-02**: Report identifies methodological gaps, geographic gaps, population gaps, measurement gaps, and theoretical gaps
- [ ] **GAPS-03**: Report highlights contradictory findings across papers with citations
- [ ] **GAPS-04**: Extraction uses section-targeted RAG to prioritize Discussion/Limitations/Future Work sections
- [ ] **GAPS-05**: AI disclaimer banner is shown on generated output
- [ ] **GAPS-06**: Minimum paper threshold enforced (at least 3 papers required)

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### AI Output Overhaul (remaining from epic #107)

- **SYNT-01**: Rethink conclusion synthesis as split presets (#88)
- **SYNT-02**: Argument Map / Claims Network preset (#104)
- **SYNT-03**: Annotated Bibliography export (#105)
- **SYNT-04**: Teaching Materials Generator (#106)

### Network ↔ Notebook Export

- **XPRT-01**: Export from network graph to abstract search + vice versa (#84)

### UI Enhancements

- **UIEN-01**: Changing citation node size by new calculation metric (#135)
- **UIEN-02**: Themes for slides need better descriptions (#132)
- **UIEN-03**: UI for viewing/editing prompts for research outputs (#120)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Custom color themes / user-defined palettes | Breaks WCAG accessibility, dilutes Catppuccin brand. Light/dark only. |
| Per-preset color customization | Conflicts with semantic color meaning (danger=red, success=green) |
| Global "Regenerate All" presets | Expensive, slow, unclear UX. Keep per-preset regenerate. |
| Methodology extraction from all sections | Methods section is authoritative; other sections increase false positives |
| Gap analysis on single paper | Gaps are comparative — require multiple papers. Single-paper = limitations summary. |
| Live theme preview | Fixed Catppuccin palette means preview adds complexity for no value |
| Prompt template refactor | 7 presets is manageable with cloned pattern. Revisit at 10+. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEBT-01 | Phase 44 | ✅ Complete |
| DEBT-02 | Phase 44 | ✅ Complete |
| DSGN-01 | Phase 45 | Complete |
| DSGN-02 | Phase 45 | Complete |
| DSGN-03 | Phase 47 | Complete |
| DSGN-04 | Phase 47 | Complete |
| BUGF-01 | Phase 46 | Complete |
| BUGF-02 | Phase 46 | Complete |
| THEM-01 | Phase 47 | Complete |
| THEM-02 | Phase 47 | Complete |
| THEM-03 | Phase 47 | Complete |
| THEM-04 | Phase 47 | Complete |
| THEM-05 | Phase 47 | Complete |
| METH-01 | Phase 48 | Complete |
| METH-02 | Phase 48 | Complete |
| METH-03 | Phase 48 | Complete |
| METH-04 | Phase 48 | Complete |
| METH-05 | Phase 48 | Complete |
| GAPS-01 | Phase 49 | Pending |
| GAPS-02 | Phase 49 | Pending |
| GAPS-03 | Phase 49 | Pending |
| GAPS-04 | Phase 49 | Pending |
| GAPS-05 | Phase 49 | Pending |
| GAPS-06 | Phase 49 | Pending |

**Coverage:**
- v10.0 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-04*
*Last updated: 2026-03-04 after roadmap creation*
