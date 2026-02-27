# Phase 38: Select-All Import - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a "select all" mechanism to search notebook results, enabling batch import of all filtered abstracts into a document notebook. Users can select all, deselect individual papers, and import the batch with progress tracking. Creating new search capabilities or modifying the search/filter system itself is out of scope.

</domain>

<decisions>
## Implementation Decisions

### Select-all behavior
- Select-all selects ALL papers matching current filters (not just visible/rendered papers)
- Tri-state checkbox: unchecked → indeterminate (some selected) → checked (all selected)
- Checkbox placed in the header row above search results (near result count/sort controls)
- Changing any filter resets the select-all state and clears all individual selections

### Merge with individual picks
- After select-all, clicking an individual paper's checkbox deselects just that paper (rest stay selected)
- Select-all checkbox transitions to indeterminate state when some papers are deselected
- If user has partial individual selections and clicks select-all, it adds the remaining unselected papers (additive, not toggle-off)
- Selection count displayed on the import button: "Import Selected (12)" — not a separate live counter

### Large batch UX
- Confirmation modal when importing 100+ papers: "You're about to import X papers. This may take a few minutes. Continue?"
- Import is cancellable mid-way — papers already imported stay, remaining are skipped
- Progress display matches the existing network graph building modal pattern
- After completion: categorized results summary (Imported: X, Duplicates skipped: Y, Failed: Z) with expandable details
- Uses ExtendedTask for large batches (50+ papers) per success criteria

### Import target flow
- Modal with notebook selector dropdown — user picks which document notebook to import into
- Include a "+ New Notebook" option that allows creating a notebook inline from the import modal
- Duplicates (papers already in target notebook) are skipped silently and reported in the results summary
- After import completes, user stays on the search results page (no auto-navigation)

### Claude's Discretion
- Exact checkbox styling and positioning within the header row
- How to efficiently track select-all state internally (set-based vs flag-based)
- ExtendedTask configuration and progress reporting implementation details
- Error handling for individual paper import failures within a batch
- How the "+ New Notebook" inline creation UI is implemented

</decisions>

<specifics>
## Specific Ideas

- Progress bar style should match the network graph building modal (user explicitly requested consistency)
- Button text updates dynamically: "Import Selected (N)" to show count without a separate display element
- The existing single-paper import flow already has a notebook selector modal — extend that pattern for batch

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 38-select-all-import*
*Context gathered: 2026-02-26*
