# Requirements: Serapeum

**Defined:** 2026-02-18
**Core Value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings

## v4.0 Requirements

Requirements for v4.0 Stability + Synthesis. Each maps to roadmap phases.

### Bug Fixes

- [ ] **BUGF-01**: User sees seed paper in abstract search results when using seed discovery (#110)
- [ ] **BUGF-02**: User sees a single confirmation modal when removing an abstract or blocking a journal (#111)
- [ ] **BUGF-03**: User can verify cost tracking table updates after each LLM request (#116)
- [ ] **BUGF-04**: User sees correct paper count after refresh following removals (#86)

### Tech Debt

- [ ] **DEBT-01**: Ragnar store connection in search_chunks_hybrid is properly closed after use (#117)
- [ ] **DEBT-02**: Section_hint metadata is encoded in PDF ragnar origins for accurate section-filtered retrieval (#118)
- [ ] **DEBT-03**: Dead code (with_ragnar_store, register_ragnar_cleanup) is removed or repurposed (#119)

### UI Polish

- [ ] **UIPX-01**: User can dismiss duplicate toast notifications — PR #112 landed
- [ ] **UIPX-02**: User can collapse keywords panel to save vertical space — PR #115 landed
- [ ] **UIPX-03**: Tooltip stays within graph container and doesn't overlap side panel (#79)
- [ ] **UIPX-04**: Citation network background color renders correctly (#89)
- [ ] **UIPX-05**: Settings page two-column layout is visually balanced

### Synthesis

- [ ] **SYNTH-01**: User can generate a unified Overview that combines summary and key points in a single output (#98)
- [ ] **SYNTH-02**: User can generate a Literature Review Table showing a structured comparison matrix of papers across dimensions (methodology, findings, sample size, limitations) (#99)
- [ ] **SYNTH-03**: User can generate research questions derived from the papers in their notebook using PICO framework (#102)

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### AI Output Presets

- **AIOP-01**: Rethink conclusion synthesis as split presets for faster responses (#88)
- **AIOP-02**: Methodology Extractor preset (#100)
- **AIOP-03**: Gap Analysis Report preset (#101)
- **AIOP-04**: Argument Map / Claims Network preset (#104)
- **AIOP-05**: Annotated Bibliography export APA/MLA (#105)
- **AIOP-06**: Teaching Materials Generator (#106)

### Discovery & Workflow

- **DISC-01**: Select all papers to import into document notebook (#85)
- **DISC-02**: Bulk upload for network analysis/seeding (#113)
- **DISC-03**: Export from network graph to abstract search and vice versa (#84)
- **DISC-04**: Citation Audit — find missing seminal papers (#103)
- **DISC-05**: Chat UX busy spinners and progress messages (#87)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Custom columns for Lit Review Table | Differentiator, not table stakes — validate demand with fixed columns first |
| Recursive abstract searching (#11) | High complexity, future milestone |
| PDF image pipeline (#44) | Epic-level effort, future milestone |
| Local model support (#8) | Significant architecture change, future |
| Audio overview (#22) | Experimental, low priority |
| Full OpenAlex corpus ingestion (#41) | Moonshot — very high complexity |
| Cross-notebook search | Contradicts per-notebook isolation goal |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUGF-01 | — | Pending |
| BUGF-02 | — | Pending |
| BUGF-03 | — | Pending |
| BUGF-04 | — | Pending |
| DEBT-01 | — | Pending |
| DEBT-02 | — | Pending |
| DEBT-03 | — | Pending |
| UIPX-01 | — | Pending |
| UIPX-02 | — | Pending |
| UIPX-03 | — | Pending |
| UIPX-04 | — | Pending |
| UIPX-05 | — | Pending |
| SYNTH-01 | — | Pending |
| SYNTH-02 | — | Pending |
| SYNTH-03 | — | Pending |

**Coverage:**
- v4.0 requirements: 15 total
- Mapped to phases: 0
- Unmapped: 15

---
*Requirements defined: 2026-02-18*
*Last updated: 2026-02-18 after initial definition*
