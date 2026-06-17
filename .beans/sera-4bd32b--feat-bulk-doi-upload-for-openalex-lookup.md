---
title: "feat: Bulk DOI upload for OpenAlex lookup"
status: completed
type: task
priority: high
created_at: 2026-02-06T20:55:06Z
updated_at: 2026-03-04T17:37:32Z
---

**Effort:** High | **Impact:** Medium

Allow users to paste/upload a list of DOIs and fetch paper metadata from OpenAlex in bulk.

### Use Cases
- Import reading list from reference manager (Zotero, Mendeley export)
- Add specific papers from a syllabus or bibliography
- Recreate a literature review from existing DOI list

### Implementation Ideas
- [ ] Text area for pasting DOIs (one per line or comma-separated)
- [ ] CSV/TXT file upload option
- [ ] Parse and validate DOI format
- [ ] Batch query OpenAlex API (respect rate limits)
- [ ] Handle missing/invalid DOIs gracefully
- [ ] Progress indicator for large batches
- [ ] Add fetched papers to notebook

### OpenAlex API
- Filter by DOI: `filter=doi:<doi>`
- Can batch with pipe: `filter=doi:10.1234/abc|10.5678/def`
- Max ~50 DOIs per request recommended

**Moonshot feature** - useful but requires careful UX design for error handling.

<!-- migrated from beads: `serapeum-1774459563648-18-4bd32be6` | github: https://github.com/seanthimons/serapeum/issues/24 -->
