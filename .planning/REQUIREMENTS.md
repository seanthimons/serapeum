# Requirements: Serapeum v7.0

**Defined:** 2026-02-25
**Core Value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings

## v7.0 Requirements

Requirements for v7.0 Citation Audit + Quick Wins. Each maps to roadmap phases.

### Citation Audit

- [x] **AUDIT-01**: User can trigger citation gap analysis on a search notebook
- [x] **AUDIT-02**: System analyzes backward references (papers cited BY collection) using referenced_works
- [x] **AUDIT-03**: System analyzes forward citations (papers that CITE the collection) via OpenAlex cited_by
- [x] **AUDIT-04**: Missing papers are ranked by citation frequency (threshold: 2+ references)
- [x] **AUDIT-05**: User sees ranked list with title, author, year, and citation count
- [x] **AUDIT-06**: User can import individual missing papers with one click
- [x] **AUDIT-07**: Analysis runs async with progress indicator and cancellation

### Bulk Import

- [ ] **BULK-01**: User can paste a list of DOIs (one per line, comma-separated, or URL format)
- [ ] **BULK-02**: User can upload a CSV/text file of DOIs
- [x] **BULK-03**: User can upload a .bib file for DOI extraction and import
- [ ] **BULK-04**: System batch-queries OpenAlex (50 DOIs per request) with rate limiting
- [ ] **BULK-05**: Import runs async with progress bar showing N/total papers fetched
- [ ] **BULK-06**: User sees import results (N imported, N failed, N duplicates skipped)
- [x] **BULK-07**: .bib metadata preserved when OpenAlex enrichment fails (merge-not-replace)
- [x] **BULK-08**: User can feed .bib file into citation network for seeding (#113)

### Select-All Import

- [ ] **SLCT-01**: User can select all filtered abstracts with a single checkbox
- [ ] **SLCT-02**: User can import all selected abstracts into a document notebook
- [ ] **SLCT-03**: Batch import shows progress for large selections (>50 papers)

### Slide Healing

- [ ] **SLIDE-01**: Slide generation prompt includes proper YAML template structure
- [ ] **SLIDE-02**: User can click Regenerate to re-attempt failed slide generation
- [ ] **SLIDE-03**: User can provide specific healing instructions (e.g., "fix YAML", "fix CSS")
- [ ] **SLIDE-04**: System limits healing to 2 retries, then falls back to template YAML

## v7.x Requirements

Deferred to future release. Tracked but not in current roadmap.

### Citation Audit Enhancements

- **AUDIT-08**: User-configurable citation frequency threshold slider
- **AUDIT-09**: Export citation gaps as BibTeX for use in other tools
- **AUDIT-10**: Multi-level backward citation mining (depth=2+ references of references)

### Bulk Import Enhancements

- **BULK-09**: Title+author fallback matching when .bib entries lack DOIs
- **BULK-10**: RIS file format support alongside BibTeX

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Citation context analysis (supporting/contrasting) | Requires full-text PDF analysis, blocked on #44 PDF image pipeline |
| Cross-notebook citation audit | Contradicts per-notebook isolation architecture |
| Temporal citation trends | Requires additional UI complexity, defer to v8+ |
| Journal impact weighting | Requires external journal metrics data source |
| Automatic prompt healing (no user trigger) | 2024 research shows LLM self-correction without feedback has low success rates |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUDIT-01 | Phase 37 | Complete |
| AUDIT-02 | Phase 37 | Complete |
| AUDIT-03 | Phase 37 | Complete |
| AUDIT-04 | Phase 37 | Complete |
| AUDIT-05 | Phase 37 | Complete |
| AUDIT-06 | Phase 37 | Complete |
| AUDIT-07 | Phase 37 | Complete |
| BULK-01 | Phase 35 | Pending |
| BULK-02 | Phase 35 | Pending |
| BULK-03 | Phase 36 | Complete |
| BULK-04 | Phase 35 | Pending |
| BULK-05 | Phase 35 | Pending |
| BULK-06 | Phase 35 | Pending |
| BULK-07 | Phase 36 | Complete |
| BULK-08 | Phase 36 | Complete |
| SLCT-01 | Phase 38 | Pending |
| SLCT-02 | Phase 38 | Pending |
| SLCT-03 | Phase 38 | Pending |
| SLIDE-01 | Phase 39 | Pending |
| SLIDE-02 | Phase 39 | Pending |
| SLIDE-03 | Phase 39 | Pending |
| SLIDE-04 | Phase 39 | Pending |

**Coverage:**
- v7.0 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0
- Coverage: 100%

**Foundation requirements:**
- Phase 33 (DOI Parsing Utilities): Enables BULK-01, BULK-02, BULK-03, AUDIT-06
- Phase 34 (OpenAlex Batch API): Enables BULK-04, BULK-05, AUDIT-02, AUDIT-03, AUDIT-06

---
*Requirements defined: 2026-02-25*
*Last updated: 2026-02-25 after roadmap creation*
