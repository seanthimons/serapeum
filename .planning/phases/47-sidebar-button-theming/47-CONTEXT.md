# Phase 47: Sidebar & Button Theming - Context

**Gathered:** 2026-03-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Apply the Phase 45 design system policy (semantic colors, icon wrappers, button variants) to all buttons, sidebar, and icons across the entire Serapeum app. Update the live CSS to match the validated design system. This phase changes existing UI elements — no new features or capabilities.

</domain>

<decisions>
## Implementation Decisions

### Sidebar button hierarchy
- **Reorder buttons** (top to bottom): New Search Notebook → New Document Notebook → Import Papers → Discover from Paper → Explore Topics → Build a Query → Citation Network → Citation Audit
- **Solid fill** for both notebook creation buttons (Search and Document) — these are the primary sidebar actions
- **Rainbow outline colors** for discovery/utility buttons — keep distinct colors per action for quick visual scanning. Researcher to explore which color per action looks good in both Latte and Mocha themes. Reassign to avoid semantic conflicts (e.g., citation network should NOT be danger-red).
- **Import Papers** needs a distinct color — researcher to explore beyond the standard 6 semantic colors (possibly Catppuccin peach, sky, or other palette colors as one-off custom classes)
- **Subtle divider** (thin line or extra spacing) between notebook creation buttons and discovery buttons
- **Remove "Notebooks" title text** at top of sidebar to reclaim vertical space
- THEM-02: Citation audit sidebar button must be readable in light mode (currently btn-outline-secondary with low contrast)

### Document notebook title bar
- **Keep current icon+text styling** for preset buttons (Overview, Key Points, Methodology, Lit Review, Slides) — enough space when sidebar collapses
- **Wrap to two rows** on tight screens — buttons reflow naturally, nothing hidden
- **Move delete button** closer to notebook title, extend chat window up for better vertical usage
- **Embed Papers** stays `btn-outline-primary` (lavender outline)
- **Send** stays `btn-primary` (solid lavender, main action)
- **Export dropdown**: researcher to evaluate if `btn-outline-secondary` is correct per semantic policy or should change. Claude's discretion.

### Search notebook title bar
- **Same styling rules** as document notebook — consistent treatment across both notebook types
- Same hierarchy: Send = primary (solid), presets = outline-primary, export = outline-secondary (pending researcher evaluation)

### Full app button theming
- **Search/execute buttons** (in discovery modules: seed discovery, query builder, topic explorer, search notebook "Search" button) change from `btn-success` (green) to `btn-primary` (lavender) — search is a primary action, not a confirmation
- **"Add to Notebook" buttons** in search results keep `btn-outline-success` (green) — adding is a positive/constructive action, green connotes "yes, add this"
- **Stop/Cancel buttons** (bulk import, citation network build) keep `btn-warning` (yellow) — caution/interruption fits
- **Delete buttons** keep `btn-outline-danger` or `btn-danger` as appropriate — destructive actions use red per policy
- THEM-02 applies to sidebar button only, not the in-module "Run Audit" button

### Icon wrapper migration
- **Full app migration** — replace ALL raw `icon()` calls with semantic wrappers across every module (~80+ replacements, ~10 files)
- **Wrap everything** including decorative/status icons (coins, brain, file-pdf, seedling, etc.) — researcher to catalog all icons and propose wrapper names
- **Citation audit icon** stays distinct (`magnifying-glass-chart`) — it's specialized analysis, not general search
- **Loading via global environment** — app.R already sources theme_catppuccin.R, so wrappers are available everywhere. No per-module sourcing needed.

### Info color migration
- **Update catppuccin_dark_css()** in R/theme_catppuccin.R: change `--bs-info` from `MOCHA$blue` to `MOCHA$sapphire`
- **Update bs_theme() in app.R**: add explicit `info = LATTE$sapphire` parameter (currently unset, falls back to Bootstrap default teal)
- Both light and dark mode will use Catppuccin sapphire for info

### Claude's Discretion
- Exact sidebar divider styling (border, margin, padding)
- Export dropdown button final color (outline-secondary vs alternative)
- Responsive breakpoint for two-row title bar wrap
- Custom CSS class implementation for non-standard sidebar button colors (e.g., peach, sky)
- Hover/focus state adjustments for new button colors
- Order of file changes during implementation

</decisions>

<specifics>
## Specific Ideas

- User wants visual distinctiveness in sidebar — the rainbow approach helps users quickly find the action they want by color muscle memory
- Import Papers color should be unique from other sidebar buttons — explore Catppuccin palette colors beyond the 6 Bootstrap semantic roles
- Delete button should be visually close to notebook title (spatial proximity = related actions)
- Chat window should extend up when delete button moves, reclaiming vertical space

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/theme_catppuccin.R`: 20 icon wrappers (icon_save, icon_delete, etc.), MOCHA/LATTE color constants, catppuccin_dark_css(), generate_swatch_html()
- `www/swatch.html`: Visual reference for all design system components in both themes

### Established Patterns
- `bslib::bs_theme()` in app.R configures light mode colors; `catppuccin_dark_css()` overrides for dark mode
- All modules use `shiny::icon()` for icons and Bootstrap btn-* classes for buttons
- `page_sidebar()` with `sidebar()` in app.R for main navigation
- Title bars use `div(class = "d-grid gap-2")` or flexbox for button layouts

### Integration Points
- **app.R:57-62**: `bs_theme()` call — add `info = LATTE$sapphire`
- **app.R:160-189**: Sidebar button definitions — reorder, recolor, add divider
- **R/theme_catppuccin.R:261**: `catppuccin_dark_css()` — change `MOCHA$blue` to `MOCHA$sapphire` for `--bs-info`
- **R/mod_document_notebook.R:69-116**: Document notebook title bar buttons
- **R/mod_search_notebook.R:70-99**: Search notebook title bar buttons
- **R/mod_seed_discovery.R:242**: Search button `btn-success` → `btn-primary`
- **R/mod_query_builder.R:176**: Search button `btn-success` → `btn-primary`
- **R/mod_topic_explorer.R:56**: Search button `btn-success` → `btn-primary`
- **R/mod_citation_audit.R**: Citation audit buttons (verify light mode readability)
- **R/mod_citation_network.R**: Network module buttons
- **R/mod_bulk_import.R**: Import module buttons
- **R/mod_slides.R**: Slide module buttons
- **R/mod_settings.R**: Settings module buttons
- **R/mod_about.R**: About page buttons

### Files to Modify (estimated)
All `R/mod_*.R` files + `app.R` + `R/theme_catppuccin.R` + `www/custom.css` (if needed for custom sidebar button colors)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 47-sidebar-button-theming*
*Context gathered: 2026-03-05*
