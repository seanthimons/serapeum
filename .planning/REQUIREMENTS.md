# Requirements: Serapeum

**Defined:** 2026-02-12
**Core Value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings

## v2.1 Requirements

Requirements for v2.1 Polish & Analysis. Each maps to roadmap phases.

### Year Filtering

- [ ] **YEAR-01**: User can filter search results by year range using an interactive slider
- [ ] **YEAR-02**: User can see a histogram of paper distribution by year on the slider
- [ ] **YEAR-03**: User can filter citation network nodes by year range using the same slider pattern
- [ ] **YEAR-04**: Papers with unknown years are handled gracefully (shown with indicator, optional include/exclude)

### Conclusion Synthesis

- [ ] **SYNTH-01**: User can trigger conclusion synthesis from search notebook chat (preset button)
- [ ] **SYNTH-02**: User can trigger conclusion synthesis from document notebook chat (preset button)
- [ ] **SYNTH-03**: RAG retrieval targets conclusion/limitations/future work sections specifically
- [ ] **SYNTH-04**: Synthesis aggregates positions across papers and proposes future research directions
- [ ] **SYNTH-05**: All synthesis output displays prominent disclaimers ("AI-generated, verify before use")

### Progress & Cancellation

- [ ] **PROG-01**: User sees a progress modal with live status during citation network build
- [ ] **PROG-02**: User can cancel a running citation network build via stop button
- [ ] **PROG-03**: Cancelled builds display partial results (accumulated nodes so far)

### UI Polish

- [ ] **UIPX-01**: Synthesis preset buttons have distinct, meaningful icons (#61, #62)
- [ ] **UIPX-02**: App has a favicon (#33)
- [ ] **UIPX-03**: Sidebar layout reclaims space (move costs link, remove redundant elements) (#81)

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Year Filtering

- **YEAR-05**: Auto-refresh citation network graph on year filter change (deferred — causes janky UX, apply on button click instead)
- **YEAR-06**: Non-contiguous year ranges (e.g., 2000-2005 OR 2020-2025) (deferred — UI complexity)

### Synthesis

- **SYNTH-06**: Consensus meter visualization across papers (deferred — requires structured answer extraction)
- **SYNTH-07**: Automated research gap identification (deferred — overpromise risk, frame as "proposed" not authoritative)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| histoslider package | Adds React.js dependency for minimal UX gain over native Shiny slider + custom histogram |
| Agentic RAG for synthesis | v2.1 uses fixed pipeline; agentic RAG is future architecture |
| Tooltip overflow fix (#79) | Deferred to separate fix sprint, complex CSS stacking context issue |
| Network ↔ abstract export (#84) | High complexity, separate milestone |
| Bulk DOI import (#24) | Needs UX design, separate milestone |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| YEAR-01 | — | Pending |
| YEAR-02 | — | Pending |
| YEAR-03 | — | Pending |
| YEAR-04 | — | Pending |
| SYNTH-01 | — | Pending |
| SYNTH-02 | — | Pending |
| SYNTH-03 | — | Pending |
| SYNTH-04 | — | Pending |
| SYNTH-05 | — | Pending |
| PROG-01 | — | Pending |
| PROG-02 | — | Pending |
| PROG-03 | — | Pending |
| UIPX-01 | — | Pending |
| UIPX-02 | — | Pending |
| UIPX-03 | — | Pending |

**Coverage:**
- v2.1 requirements: 15 total
- Mapped to phases: 0
- Unmapped: 15 ⚠️

---
*Requirements defined: 2026-02-12*
*Last updated: 2026-02-12 after initial definition*
