# Requirements: Serapeum v20.0

**Defined:** 2026-03-27
**Core Value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings

## v20.0 Requirements

Requirements for Shiny Reactivity Cleanup. Each maps to roadmap phases.

### Reactive Guards

- [x] **GARD-01**: App does not crash when provider or model is NULL in query builder (req() guard)
- [x] **GARD-02**: fig_refresh counter reads inside observe() blocks use isolate() to prevent infinite loops
- [x] **GARD-03**: match_aa_model() and section_filter have input validation with safe fallback values

### Observer Lifecycle

- [x] **LIFE-01**: Slide chip handler observers are destroyed before re-creation on each modal open
- [x] **LIFE-02**: Figure action observers are destroyed and re-registered on re-extraction
- [x] **LIFE-03**: renderUI in document notebook does not repeatedly query list_documents() during processing
- [x] **LIFE-04**: Observer lifecycle and resource paths are cleaned up in slides and notebook modules

### Error Handling

- [ ] **ERRH-01**: Error toast notifications appear above synthesis modal (not behind it)
- [ ] **ERRH-02**: Error handling patterns are consistent between document and search notebook presets

### Infrastructure

- [ ] **INFR-01**: SQL migrations are idempotent on fresh installs (CREATE TABLE IF NOT EXISTS audit)

## Future Requirements

Deferred to future milestones. Tracked but not in current roadmap.

### Refiner Hardening (v19 epic)

- **REFN-01**: Batch abstract embedding in research refiner (200 API calls → ~1)
- **REFN-02**: O(n^2) deduplication fix in candidate fetching
- **REFN-03**: Full UI re-render fix on every accept/reject

### Citation Network (v22 epic)

- **CITN-01**: Node sizing selector reset fix
- **CITN-02**: Persist FWCI data with saved citation networks
- **CITN-03**: Citation audit frequency/sort_by stale state fixes

### UX & Onboarding (v23 epic)

- **UXON-01**: N+1 DB queries in enrich_retrieval_results()
- **UXON-02**: Slides healing bypasses resolve_model_for_operation()

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| New features or UI additions | This is a stability/hardening milestone only |
| Ragnar connection leak fix | Flagged by research but not in beads epic; defer to v19 or standalone |
| Poller destroy on all exit paths | Out of scope unless encountered during LIFE-04 work |
| reactlog integration as dev tool | Dev-only utility, not a requirement — optional for verification |
| Performance optimizations beyond renderUI fix | Performance work belongs in v19 (Refiner) or standalone |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| GARD-01 | Phase 64 | Complete |
| GARD-02 | Phase 64 | Complete |
| GARD-03 | Phase 64 | Complete |
| LIFE-01 | Phase 65 | Complete |
| LIFE-02 | Phase 65 | Complete |
| LIFE-03 | Phase 65 | Complete |
| LIFE-04 | Phase 65 | Complete |
| ERRH-01 | Phase 66 | Pending |
| ERRH-02 | Phase 66 | Pending |
| INFR-01 | Phase 67 | Pending |

**Coverage:**
- v20.0 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-03-27 — traceability populated after roadmap creation*
