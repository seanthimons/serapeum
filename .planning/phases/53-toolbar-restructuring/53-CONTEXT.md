# Phase 53: Toolbar Restructuring - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Restructure the search notebook toolbar from a single-row horizontal button strip into a full-width 3x2 grid with icon+text labels, unified color scheme, and semantic grouping. Remove the "Papers" header label, relocate the result count to the keywords panel, and widen the paper list panel from 4/12 to 5/12 columns.

</domain>

<decisions>
## Implementation Decisions

### Button labels
- All 6 buttons get icon + descriptive text (2-3 words)
- Labels: **Import**, **Edit Search**, **Citation Network**, **Export** (dropdown kept), **Refresh**, **Load More**
- Export keeps its dropdown (BibTeX / CSV) — single button, not split

### Grid layout
- 3x2 grid replaces the current single-row horizontal toolbar
- Row 1 (input/discovery): Import | Edit Search | Citation Network
- Row 2 (output/data): Export | Refresh | Load More
- Equal-width buttons per row — each button takes 1/3 of the row
- Full-width grid stretches across the entire card header

### Grid spacing
- Row gap: tight (4px / gap-1) — feels like a single toolbar block
- Column gap: small (gap-1 or gap-2) — slight separation between buttons in the same row

### Color assignments
- Lavender (primary outline) for meaningful actions: Import, Citation Network, Export, Load More
- Gray (secondary outline) for support actions: Edit Search, Refresh
- If lavender + gray looks odd in practice, fallback to all-lavender — flag for UAT

### Papers label
- Remove "Papers" span entirely from card_header
- The 3x2 button grid IS the card header content — no label needed

### Result count relocation
- Remove "X of Y results" from the toolbar completely
- Add remaining count to keywords panel subheader: "92 papers | 30 keywords | **1.6M remaining**"
- Pretty-format the remaining count (e.g., 1.6M, 234K)
- Bold the remaining count for visibility

### Panel split
- Change col_widths from c(4, 8) to c(5, 7)
- Gives paper titles more room (fewer truncations, no horizontal scrollbar)
- Flag for UAT — verify abstract pane isn't cramped at 7/12

### Sort controls
- Sort radio buttons (Newest, Most cited, Impact, Most refs) stay below the button grid in card_body
- Current layout is lopsided with 4 options not filling the width — Claude figures out balanced layout

### Claude's Discretion
- Exact CSS for equal-width button grid (CSS Grid vs flexbox)
- Sort controls layout balancing (evenly spaced, justified, centered)
- Card header padding adjustments to fit the grid cleanly
- Column gap exact value (gap-1 vs gap-2) based on visual result
- Pretty-format threshold for remaining count (when to use K vs M)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- 76 icon wrapper functions in `R/theme_catppuccin.R` — all buttons already use these (icon_file_import, icon_edit, icon_share_nodes, icon_download, icon_rotate, icon_angles_down)
- Catppuccin color palette: `btn-outline-primary` maps to lavender, `btn-outline-secondary` maps to gray via bs_theme() custom properties
- `format_result_count()` helper exists for result display formatting

### Established Patterns
- Toolbar buttons: `actionButton(ns("id"), "Label", class = "btn-sm btn-outline-{color}", icon = icon_fn())`
- Export dropdown: `btn-group btn-group-sm` with `dropdown-toggle` — keep this pattern
- Keywords panel subheader at line ~200+: already shows "X papers | Y keywords" — append remaining count here

### Integration Points
- Card header at line 79-116: `d-flex justify-content-between` container — replace with grid container
- `col_widths = c(4, 8)` at line 75 — change to c(5, 7)
- `span("Papers")` at line 80 — remove
- Result count `textOutput(ns("result_count"))` at line 115 — relocate to keywords panel
- `format_result_count()` — needs new format for remaining count display in keywords subheader

</code_context>

<specifics>
## Specific Ideas

- The toolbar should feel like a cohesive control panel, not a scattered collection of buttons
- Equal-width buttons in a grid give the toolbar intentionality — it looks designed, not thrown together
- Lavender for "do something meaningful" vs gray for "adjust/retry" creates a subtle visual hierarchy without rainbow chaos
- The keywords panel subheader is an underutilized space that naturally fits the remaining count

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (panel split was folded in as a one-line related change)

</deferred>

---

*Phase: 53-toolbar-restructuring*
*Context gathered: 2026-03-10*
