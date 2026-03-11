# Phase 54: Tooltip Layer - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Add accessible, keyboard-navigable tooltips to all toolbar buttons (search notebook) and sidebar discovery buttons (app-level). Tooltips describe each button's action in contextual tone. Dynamic buttons (keyword/journal filters) use `title` attribute fallback. Tooltips must work in both light and dark modes and comply with WCAG 2.2.

</domain>

<decisions>
## Implementation Decisions

### Tooltip coverage
- **Toolbar buttons (6):** Import, Edit Search, Cit Network, Export, Refresh, Load More — wrapped with `bslib::tooltip()`
- **Sidebar discovery buttons (6):** Import Papers, Discover from Paper, Explore Topics, Build a Query, Citation Network, Citation Audit — wrapped with `bslib::tooltip()`
- **Excluded:** New Search Notebook, New Document Notebook (labels are self-explanatory)
- **Dynamic buttons:** Keyword pills and journal filter links use `title` attributes (not `bslib::tooltip()`)

### Tooltip copy (approved)
Contextual tone — describes what the button does and when/why you'd use it. Max 15 words.

**Toolbar:**
- Import: "Add papers by pasting DOIs or uploading a BibTeX file"
- Edit Search: "Change your search query, filters, or discovery method"
- Cit Network: "Build a citation network from a seed paper in your results"
- Export: "Download your current papers as BibTeX or CSV"
- Refresh: "Re-run your current search to check for new results"
- Load More: "Fetch the next batch of results from OpenAlex"

**Sidebar:**
- Import Papers: "Add papers by pasting DOIs or uploading a BibTeX file"
- Discover from Paper: "Find related work by using a known paper as a seed"
- Explore Topics: "Browse OpenAlex topic hierarchies to find research areas"
- Build a Query: "Use AI to help construct an effective search query"
- Citation Network: "Visualize citation relationships between papers"
- Citation Audit: "Check your collection for missing references and gaps"

### Tooltip behavior
- No keyboard shortcuts in tooltip text — purely descriptive
- Placement: below buttons (Bootstrap default)
- Hover delay: ~300ms before showing to prevent accidental triggers when mousing across dense button grid
- No custom dark mode CSS — trust Bootstrap/bslib theming (Catppuccin sets bg/fg via bs_theme())

### Claude's Discretion
- Exact `bslib::tooltip()` placement parameter if below causes overlap issues
- Whether Export dropdown button needs special wrapping (btn-group context)
- Title attribute text for dynamic keyword/journal filter buttons
- Any tooltip styling adjustments if UAT reveals contrast issues

</decisions>

<specifics>
## Specific Ideas

- Toolbar has a dense 3x2 CSS grid — the 300ms delay prevents tooltip flicker when mousing across buttons
- Import Papers (sidebar) and Import (toolbar) do the same thing — share identical tooltip text
- User wants to review tooltip copy during UAT, not just trust defaults

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bslib::tooltip()` — available in bslib, not yet used anywhere in the codebase
- 76 icon wrapper functions in `R/theme_catppuccin.R` — all buttons already use these
- Catppuccin theme via `bs_theme()` — Bootstrap tooltips inherit theme colors automatically

### Established Patterns
- Toolbar buttons: `actionButton(ns("id"), "Label", class = "btn-sm btn-outline-{color}", icon = icon_fn())` at `mod_search_notebook.R:92-125`
- Sidebar buttons: `actionButton("id", "Label", class = "btn-outline-{color}", icon = icon_fn())` at `app.R:167-193`
- Export dropdown: `btn-group btn-group-sm` with `dropdown-toggle` — may need special tooltip wrapping
- Dynamic elements already use `title` attribute: OA badges (`title = oa_badge$tooltip`), citation counts, quality flags

### Integration Points
- Toolbar card_header grid: `mod_search_notebook.R:88-126` — wrap each actionButton with `bslib::tooltip()`
- Sidebar buttons: `app.R:167-193` — wrap each discovery actionButton with `bslib::tooltip()`
- Dynamic keyword pills: rendered in server-side `render_keyword_pill()` — add `title` attribute
- Journal filter links: rendered in paper list items — already have some `title` attributes

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 54-tooltip-layer*
*Context gathered: 2026-03-11*
