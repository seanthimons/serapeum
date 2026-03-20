# Requirements: Serapeum v16.0

**Defined:** 2026-03-18
**Core Value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings

## v16.0 Requirements

Requirements for Content & Output Quality milestone. Each maps to roadmap phases.

### Slide Themes

- [x] **THME-01**: User sees color swatches (bg/fg/accent) next to each built-in theme in the dropdown
- [x] **THME-02**: User can upload a custom `.scss` file as a slide theme
- [x] **THME-03**: Uploaded themes are stored in `data/themes/` and persist across sessions
- [x] **THME-04**: User can manage (list/delete) uploaded custom themes
- [ ] **THME-05**: User can type a freeform description to generate a theme via AI
- [ ] **THME-06**: AI returns structured JSON (8-9 variables), app templates into valid `.scss`
- [ ] **THME-07**: AI-generated themes validated for hex colors and real font names before saving
- [x] **THME-08**: User can manually customize theme via color pickers (bg/text/accent/link) and font selector
- [x] **THME-09**: Base theme selector determines starting point for custom themes
- [ ] **THME-10**: AI-generated values populate color picker fields for manual tweaking
- [x] **THME-11**: Font selector offers curated list of widely-available professional fonts
- [x] **THME-12**: Custom themes applied via `theme: [base, custom.scss]` in QMD frontmatter

### Prompt Editing

- [ ] **PRMT-01**: User can view the system/task prompt for each AI preset
- [ ] **PRMT-02**: User can edit the system/task prompt for each AI preset
- [ ] **PRMT-03**: RAG plumbing is hidden; only instruction text is exposed with a read-only description of what the machinery does
- [ ] **PRMT-04**: Edited prompts stored in DuckDB with date-versioned slugs
- [ ] **PRMT-05**: User can recall previous prompt versions by date
- [ ] **PRMT-06**: User can reset any preset prompt to the hardcoded default

### Citation Traceability

- [x] **CITE-01**: All AI preset system prompts instruct the LLM to cite with page numbers (e.g., `[Author, p.X]`)
- [x] **CITE-02**: Slide generation prompt instructs LLM to include page numbers in footnote references

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Audio Output

- **AUDIO-01**: User can generate NotebookLM-style audio overviews of notebook content (#22)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Quarto .bib citation pipeline | Page metadata already flows through context; prompt engineering achieves traceability without infrastructure change |
| Mini-preview slide rendering | Static color swatches are sufficient; rendering sample QMD adds complexity for marginal benefit |
| Free-text font input | Curated list prevents broken themes from unavailable fonts |
| Audio overview (#22) | Already deferred to "Future ideas" milestone — very high effort, medium impact |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| THME-01 | Phase 59 | Complete |
| THME-02 | Phase 59 | Complete |
| THME-03 | Phase 59 | Complete |
| THME-04 | Phase 59 | Complete |
| THME-05 | Phase 61 | Pending |
| THME-06 | Phase 61 | Pending |
| THME-07 | Phase 61 | Pending |
| THME-08 | Phase 60 | Complete |
| THME-09 | Phase 59 | Complete |
| THME-10 | Phase 60 | Pending |
| THME-11 | Phase 60 | Complete |
| THME-12 | Phase 58 | Complete |
| PRMT-01 | Phase 63 | Pending |
| PRMT-02 | Phase 63 | Pending |
| PRMT-03 | Phase 63 | Pending |
| PRMT-04 | Phase 62 | Pending |
| PRMT-05 | Phase 63 | Pending |
| PRMT-06 | Phase 63 | Pending |
| CITE-01 | Phase 57 | Complete |
| CITE-02 | Phase 57 | Complete |

**Coverage:**
- v16.0 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 after roadmap creation — all 20 requirements mapped*
