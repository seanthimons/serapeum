# Multi-Paper Seeding for Gap Analysis: Status & Plan

**Date:** 2026-03-01
**Related Milestone:** v7.0 Citation Audit + Quick Wins
**Status:** NOT WIRED UP (stub only)

## What Was Promised

**BULK-08**: "User can feed .bib file into citation network for seeding (#113)"

Phase 36 (BibTeX Import) was supposed to let users take their imported BibTeX papers and use them as seeds for citation network analysis — enabling multi-paper gap discovery.

## What Was Actually Delivered

A **"Seed Citation Network" button** in the BibTeX import results modal that shows a notification and does nothing else.

### Evidence

- `R/mod_bulk_import.R:685` — Button rendered in results modal
- `R/mod_bulk_import.R:810-815` — Handler shows notification only:
  ```r
  observeEvent(input$seed_network, {
    showNotification(
      "Citation network seeding will be available after importing. Papers are ready for citation audit.",
      type = "message", duration = 5
    )
  })
  ```
- `36-VERIFICATION.md` notes: *"Full implementation deferred to Phase 37 (Citation Audit), but UI affordance is present"*
- Phase 37 did not implement this either

## Why It Wasn't Completed

1. **Architectural gap**: The citation network module (`mod_citation_network.R`) was built in v2.0 (Phase 12) with a **single-seed-paper architecture** — `current_seed_id()` accepts one OpenAlex paper ID, not a list.
2. **Scope deferral**: Phase 36 marked BULK-08 as "satisfied" based on the button existing, deferring the actual seeding logic to Phase 37.
3. **Phase 37 had a different focus**: Citation Audit analyzes papers *already in a notebook* for backward/forward citation gaps. It doesn't build a citation network graph from multiple seed papers — it's a different feature.
4. **No phase owned the gap**: The roadmap added a placeholder "Phase 1: multi-seeded citation network" but it was never planned or executed.

## What Multi-Paper Seeding Would Actually Require

### Current State
- Citation network: 1 seed paper → BFS crawl of cites/cited-by → vis.js graph
- Citation audit: All papers in a notebook → find frequently-referenced papers not in collection
- BibTeX import: Parses .bib → imports papers to notebook → stub button

### Required Changes

#### 1. Extend Citation Network to Accept Multiple Seeds
**File:** `R/mod_citation_network.R`
- Change `current_seed_id` (single reactive value) to `current_seed_ids` (reactive list)
- Modify `build_network()` to BFS from multiple starting nodes
- Merge/deduplicate the resulting graph (papers reachable from multiple seeds are more important)
- Update vis.js rendering to visually distinguish seed papers

#### 2. Wire BibTeX Import → Citation Network
**File:** `R/mod_bulk_import.R`
- Replace stub notification handler with actual logic
- After BibTeX import, collect OpenAlex paper IDs of successfully imported papers
- Pass those IDs to the citation network module as seeds
- Navigate user to the citation network view

#### 3. Add Multi-Seed Support to Citation Audit
**File:** `R/mod_citation_audit.R`
- Currently analyzes one notebook's papers. Could be extended to accept an arbitrary set of paper IDs as the "collection" to audit, not just a notebook.
- This would let BibTeX-imported papers be audited for citation gaps without first being organized into a notebook.

#### 4. UI Flow
- BibTeX import results → "Seed Citation Network" button → opens citation network view with all imported papers as seeds
- Citation network shows multi-seed graph with combined BFS
- User can toggle between network visualization and gap analysis views

### Estimated Scope
- **Small**: Just wire the button to pass imported paper IDs to citation audit (notebook-based). ~1 phase.
- **Medium**: Wire button + extend citation network for multi-seed BFS. ~2 phases.
- **Large**: Full multi-seed citation network + integrated gap analysis + new UI flows. ~3 phases.

## Recommendation

Start with the **small** approach: make the "Seed Citation Network" button navigate the user to the Citation Audit tab with the relevant notebook pre-selected (since BibTeX papers are imported into a notebook anyway). This closes the BULK-08 gap with minimal architectural change.

The full multi-seed citation network is a separate, larger feature that belongs in its own milestone (already placeholder'd as "Phase 1: multi-seeded citation network" in the roadmap).
