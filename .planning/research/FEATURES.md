# Feature Landscape: Search Notebook Toolbar UX

**Domain:** Academic search interface with filtering and result management
**Researched:** 2026-03-06
**Overall confidence:** MEDIUM-HIGH (WebSearch verified with design system documentation)

## Executive Summary

Search notebook toolbars serve dual roles: providing actions on the result set (export, refresh, load more) and navigating between related views (edit, seed network). Modern UX patterns favor icon+text for comprehension over icon-only for space efficiency, particularly for infrequent users. Load More buttons outperform infinite scroll for goal-oriented academic search where users need control and position awareness. Document type filtering in scholarly tools uses checkboxes for multi-select with chips for active filter display. Tooltips for icon buttons are accessibility requirements (WCAG 2.2), not nice-to-haves. Button ordering follows workflow (import → edit → analyze → export) rather than strict CRUD, with visual grouping via spacing/separators. Refresh and Load More are distinct mental models: Refresh = retry/update existing; Load More = fetch additional/expand.

## Pattern 1: Button Labeling (Icon-Only vs Icon+Text)

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Icon+text for all buttons | Text labels reduce ambiguity — "In the battle of clarity between icons and labels, labels always win" | Low | Icon-only increases cognitive load, fails on touch (no hover) |
| Tooltips for icon-only | WCAG 2.2 requirement (1.4.13) for accessibility | Medium | Must be keyboard-accessible, not just hover |
| Standardized icons | Universal symbols (trash, export, refresh) with consistent meaning | Low | Non-standard icons require text regardless |
| Consistent sizing | All buttons same height/weight for scannable toolbar | Low | Visual rhythm matters for comprehension |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Icon+text with brand colors | Topics button pattern: icon+label+semantic color | Medium | Serapeum already has 76 semantic icon wrappers (v10.0) |
| Adaptive labels (mobile collapse) | Show text on desktop, icon-only on mobile with tooltips | High | Responsive design tradeoff — not needed for desktop app |
| Icon position consistency | Always left-of-text or always above-text | Low | Left-of-text is dominant pattern in 2026 |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Icon-only toolbar without tooltips | Inaccessible, fails WCAG 2.2 | Add text labels OR keyboard-accessible tooltips |
| Tooltips with critical information | Tooltips are supplementary, not required reading | Put requirements in visible UI, not tooltips |
| Rely on hover for labels | Touch devices have no hover state | Permanent text labels or tap-accessible tooltips |
| Technical jargon in tooltips | "Invoke BFS traversal" vs "Build citation network" | Use plain language under 15 words |

**Sources:**
- NN/G Icon Usability: [https://www.nngroup.com/articles/icon-usability/](https://www.nngroup.com/articles/icon-usability/)
- UX Myths: Icons enhance usability: [https://uxmyths.com/post/715009009/myth-icons-enhance-usability](https://uxmyths.com/post/715009009/myth-icons-enhance-usability)
- WCAG Accessible Tooltips 2026: [https://www.thewcag.com/examples/tooltips](https://www.thewcag.com/examples/tooltips)

---

## Pattern 2: Load More vs Infinite Scroll vs Pagination

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Load More button at result set end | Academic search is goal-oriented — users need control over loading | Low | "Load More works well... it asks: Want to see more results?" |
| Visual distinction from refresh | Different action, different affordance | Low | Refresh = retry; Load More = expand |
| Position awareness | Users track "seen N of M results" | Medium | Load More preserves scroll position unlike pagination |
| Disable when exhausted | Show "All results loaded" state | Low | Prevents confusion when no more available |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Load More with brand styling | Topics button pattern: icon+text+color (e.g., sapphire for info) | Low | Already planned for v11.0 |
| Result count in button | "Load More (50 available)" | Low | Sets expectation for batch size |
| Batch size control | Let user choose 25/50/100 per load | Medium | Power user feature, adds complexity |
| Sticky Load More | Bottom-fixed button for long result lists | Medium | Mobile pattern, less useful for desktop scroll |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Infinite scroll | "Users may not know how much content is left to explore" — bad for academic findability | Load More button with explicit control |
| Auto-load without cap | Performance degrades, memory leaks with large datasets | Load More or auto-load with fallback button |
| Pagination for search results | Disrupts flow, "Users may not know how much content is left" | Load More for continuous discovery |
| Load More overlapping footer | Sticky elements must not overlap essential UI | Fixed positioning with safe zones |

**Sources:**
- Pagination vs Infinite Scroll vs Load More (Medium): [https://ashishmisal.medium.com/pagination-vs-infinite-scroll-vs-load-more-data-loading-ux-patterns-in-react-53534e23244d](https://ashishmisal.medium.com/pagination-vs-infinite-scroll-vs-load-more-data-loading-ux-patterns-in-react-53534e23244d)
- UI Cheat Sheet: Pagination, infinite scroll, load more (UX Collective): [https://uxdesign.cc/ui-cheat-sheet-pagination-infinite-scroll-and-the-load-more-button-e5c452e279a8](https://uxdesign.cc/ui-cheat-sheet-pagination-infinite-scroll-and-the-load-more-button-e5c452e279a8)
- Sticky CTA Best Practices 2026: [https://easyappsecom.com/guides/sticky-add-to-cart-best-practices.html](https://easyappsecom.com/guides/sticky-add-to-cart-best-practices.html)

---

## Pattern 3: Document Type Faceted Filtering

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Checkboxes for multi-select | Standard pattern: "Checkboxes should be used to display multi-select facets" | Low | Already used in Serapeum |
| Article/Review/Preprint | Core scholarly types — PubMed, Google Scholar, Semantic Scholar all filter these | Low | Serapeum already filters these |
| Active filter chips | "Show active filters prominently as tags or chips with clear remove button (X)" | Medium | Chips above results, horizontal scroll on mobile |
| Clear All option | Batch removal when multiple filters active | Low | Reduces click fatigue |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Expanded document types | Book Chapter, Conference Paper, Dataset, Editorial, Letter, Erratum | Low-Medium | OpenAlex supports ~15 types; prioritize by user frequency |
| Type-specific badges | Visual distinction in results (e.g., [PREPRINT] badge) | Low | Serapeum already has OA/citation badges (v1.1) |
| Chip color coding | Semantic colors per filter type (e.g., peach for document type, sky for quality) | Medium | Catppuccin palette already in place (v10.0) |
| Collapsible filter panels | Minimize filter UI when not in use | Low | Already done for Journal Quality card (v1.2 UIPX-01) |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Radio buttons for document type | "Academic search requires multi-select" — users want Article+Review+Preprint | Checkboxes for multi-select |
| Chips without remove button | "Each chip should have a clear remove button (X)" | Removable chips with X icon |
| Desktop-only filter sidebar | "Faceted interfaces designed for desktop overwhelm mobile screens" | Collapsible panels or drawer on mobile |
| Auto-apply filters | For complex multi-select, instant apply causes UI churn | Apply button or debounced update |

**Sources:**
- PatternFly Filter Guidelines: [https://www.patternfly.org/patterns/filters/design-guidelines/](https://www.patternfly.org/patterns/filters/design-guidelines/)
- Filter UX for SaaS (Eleken): [https://www.eleken.co/blog-posts/filter-ux-and-ui-for-saas](https://www.eleken.co/blog-posts/filter-ux-and-ui-for-saas)
- NN/G Filters vs Facets: [https://www.nngroup.com/articles/filters-vs-facets/](https://www.nngroup.com/articles/filters-vs-facets/)
- PubMed Filters (Columbia): [https://library.cumc.columbia.edu/kb/pubmed-filter-topic-investigation](https://library.cumc.columbia.edu/kb/pubmed-filter-topic-investigation)

---

## Pattern 4: Tooltip Content Guidelines

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Under 15 words | "Keep text under 15 words for optimal readability" | Low | Sentence case, plain language |
| Describe action, not UI | "Build citation network" not "Click this button" | Low | Focus on outcome, not mechanics |
| Keyboard accessible | WCAG 2.2 1.4.13: Appear on focus, not just hover | Medium | aria-describedby + focus events |
| Dismissible | User can close or move past without disrupting flow | Low | ESC key or click outside |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Keyboard shortcut hints | "Export (Ctrl+E)" in tooltip | Low | Power user accelerator |
| Contextual help links | Tooltip with "Learn more" link to docs | Medium | For complex features like citation network |
| Dynamic content | "Load More (50 available)" updates as results change | Medium | Requires reactive state |
| Delay on appearance | 400ms hover delay prevents tooltip spam during cursor movement | Low | Standard UX pattern |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Tooltips for critical info | "Do not use tooltips to display critical information" | Required info goes in visible UI |
| Hover-only tooltips | Fails on touch, inaccessible to keyboard users | Show on focus too, or use permanent labels |
| Multi-paragraph tooltips | Tooltips are supplementary, not documentation | Link to help docs for long explanations |
| Technical jargon | Increases cognitive load, excludes non-expert users | Plain language: "Retry search" not "Re-invoke OpenAlex API" |

**Sources:**
- NN/G Tooltip Guidelines: [https://www.nngroup.com/articles/tooltip-guidelines/](https://www.nngroup.com/articles/tooltip-guidelines/)
- Tooltip Best Practices (Scandiweb): [https://scandiweb.com/blog/tooltip-best-practices/](https://scandiweb.com/blog/tooltip-best-practices/)
- WCAG 1.4.13 Content on Hover or Focus: [https://www.wcag.com/authors/1-4-13-content-on-hover-or-focus/](https://www.wcag.com/authors/1-4-13-content-on-hover-or-focus/)

---

## Pattern 5: Button Grouping and Ordering

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Group by function | "Buttons should be grouped by function" — separates import/edit from analyze/export | Low | Visual spacing or separators |
| Left-to-right workflow | Import → Edit → Analyze → Export follows task sequence | Low | Left-aligned toolbar, workflow order |
| Primary action prominence | Most important action (e.g., Refresh, Load More) gets visual weight | Low | Color, size, or position distinction |
| Consistent spacing | Equal gaps within groups, larger gaps between groups | Low | 8px intra-group, 16px inter-group (common pattern) |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Separator lines | "Separators distinguish semantic groups of toolbar items" | Low | Vertical dividers between Import/Edit/Export clusters |
| Frequency-based order | Most-used actions leftmost (after respecting workflow) | Medium | Requires usage analytics |
| Action + status pairing | "Refresh" button + "Last updated: 2m ago" timestamp | Medium | Communicates outcome of refresh operation |
| Responsive button groups | Collapse low-priority buttons into "More" menu on narrow screens | High | Mobile optimization, not needed for desktop app |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| All buttons ungrouped | "May seem chaotic and confusing without grouping" | Group by function with spacing/separators |
| Alphabetical order | Ignores task flow and frequency | Workflow order (import → edit → export) |
| Mix icon+text and icon-only | "Mixing them side by side creates confusion" | Consistent labeling across toolbar |
| CRUD acronym ordering | Create-Read-Update-Delete ignores actual user workflow | Task sequence: Import → Edit → Seed → Export |

**Sources:**
- Telerik Toolbar Guidelines: [https://www.telerik.com/design-system/docs/components/toolbar/usage/](https://www.telerik.com/design-system/docs/components/toolbar/usage/)
- Telerik ToolBar Separators: [https://www.telerik.com/blazor-ui/documentation/components/toolbar/separators](https://www.telerik.com/blazor-ui/documentation/components/toolbar/separators/)
- Workflow Designer Toolbar: [https://servicedesk.esr.nhs.uk/help/topic/com.ibm.sccd.doc/workflow_adv/c_workflow_toolbar_button.html](https://servicedesk.esr.nhs.uk/help/topic/com.ibm.sccd.doc/workflow_adv/c_workflow_toolbar_button.html)

---

## Pattern 6: Refresh vs Load More Mental Models

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Distinct icons | Refresh = circular arrow; Load More = down arrow or plus | Low | Visual disambiguation |
| Distinct labels | "Refresh" (retry) vs "Load More" (expand) | Low | Text clarifies intent |
| Distinct placement | Refresh in toolbar; Load More at result set end | Low | Positional convention |
| Loading states | Refresh shows spinner; Load More shows count/progress | Medium | Communicate long operations |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Timestamp for Refresh | "Last updated: 2m ago" next to Refresh button | Low | "Include timestamp to inform users on outcome of refresh" |
| Count for Load More | "Load More (50 available)" | Low | Sets expectation |
| Retry on failure | Refresh auto-retries failed requests with backoff | Medium | User expects Refresh to fix transient errors |
| Pull-to-refresh gesture | Mobile pattern for Refresh (not Load More) | High | Desktop app doesn't need gesture |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Same icon for both | "Refresh = update existing; Load More = fetch additional" — distinct concepts | Circular arrow (refresh) vs down/plus (load more) |
| Refresh appends results | Users expect Refresh to replace, not accumulate | Refresh = clear + reload; Load More = append |
| Load More at top | "Load More at bottom of page" is universal expectation | Bottom placement preserves scroll position |
| Auto-refresh without notice | "Communicate when something new is available" | Manual refresh with timestamp, or notification |

**Sources:**
- Pull to Refresh UI Pattern: [https://ui-patterns.com/patterns/pull-to-refresh](https://ui-patterns.com/patterns/pull-to-refresh)
- To Refresh or Not to Refresh (Centre Centre): [https://articles.centercentre.com/refresh-or-not/](https://articles.centercentre.com/refresh-or-not/)
- Cloudscape Loading and Refreshing: [https://cloudscape.design/patterns/general/loading-and-refreshing/](https://cloudscape.design/patterns/general/loading-and-refreshing/)
- UX Pattern Analysis Loading (Pencil & Paper): [https://www.pencilandpaper.io/articles/ux-pattern-analysis-loading-feedback](https://www.pencilandpaper.io/articles/ux-pattern-analysis-loading-feedback)

---

## Feature Dependencies

```
Icon+Text Buttons → Tooltips (supplementary, not required)
Load More Button → Disabled State (when exhausted)
Active Filter Chips → Clear All (when multiple active)
Button Groups → Separators (visual hierarchy)
Refresh Button → Timestamp (communicates last update)
Load More Button → Result Count (sets expectation)
```

---

## MVP Recommendation for v11.0

### Prioritize (High Value, Low-Medium Complexity):

1. **Icon+text for all toolbar buttons** (Import, Edit, Seed Network, Export, Refresh, Load More)
   - Rationale: Table stakes for comprehension, already using icon+text for Topics button
   - Complexity: Low — icon wrappers already exist in theme_catppuccin.R

2. **Split Refresh vs Load More**
   - Rationale: Distinct mental models, prevents confusion
   - Complexity: Low — separate button logic, different icons
   - Design: Refresh = circular arrow + "Refresh"; Load More = down arrow + "Load More" with Topics button styling

3. **Tooltips for all toolbar buttons**
   - Rationale: WCAG 2.2 accessibility requirement, under 15 words
   - Complexity: Low — Shiny bslib supports tooltips via `bslib::tooltip()`

4. **Button grouping with separators**
   - Rationale: Visual hierarchy for Import|Edit|Seed Network|Export|Refresh
   - Complexity: Low — CSS borders or spacing

5. **Active filter chips for document types**
   - Rationale: Table stakes for faceted search, modern pattern
   - Complexity: Medium — requires chip UI + remove handler

### Defer for Future Milestones:

- **Expanded document types beyond article/review/preprint**: Low priority until user requests
- **Sticky Load More**: Desktop app doesn't benefit from mobile pattern
- **Dynamic tooltips with shortcuts**: Power user feature, adds complexity
- **Batch size control for Load More**: Adds UI complexity, unclear user demand

---

## Complexity Assessment

| Pattern | Complexity | Rationale |
|---------|------------|-----------|
| Icon+text buttons | Low | Icon wrappers exist, just add text to existing buttons |
| Load More vs Infinite Scroll | Low | Load More button is simpler than infinite scroll logic |
| Tooltips | Low | Shiny bslib has built-in tooltip support |
| Active filter chips | Medium | New UI component + remove logic |
| Button grouping | Low | CSS spacing or separator elements |
| Refresh vs Load More split | Low | Separate handlers, different icons |
| Expanded document types | Low-Medium | OpenAlex API supports ~15 types; UI just adds checkboxes |
| Keyboard-accessible tooltips | Medium | Requires aria-describedby + focus event handlers |

---

## Phase-Specific Warnings

| UX Pattern | Likely Pitfall | Mitigation |
|------------|---------------|------------|
| Icon+text buttons | Horizontal space constraints on narrow screens | Test at 1024px width; collapse to icon-only with tooltips if needed |
| Load More button | Performance with large result sets (500+ papers) | Virtual scrolling or batch limits |
| Active filter chips | Horizontal overflow with many active filters | Horizontal scroll or multi-row wrap |
| Tooltips | Tooltip positioning near viewport edges | Use bslib tooltip auto-placement |
| Button ordering | Conflicting user workflows (frequency vs task sequence) | User testing to validate Import → Edit → Seed → Export order |
| Refresh vs Load More | Users confuse retry with fetch-more | Strong visual distinction (icon + color + label) |

---

## Open Questions (Flag for Validation)

- **Document type priorities**: Which types beyond article/review/preprint do Serapeum users need? (Low confidence — no user research data)
- **Button ordering**: Is Import → Edit → Seed Network → Export the actual user workflow, or do users Edit more than Import? (Medium confidence — assumes left-to-right task flow)
- **Load More batch size**: Should Serapeum load 25, 50, or 100 papers per Load More click? (Low confidence — WebSearch suggests 50 is common but no scholarly-specific data)
- **Sticky Load More**: Would desktop users benefit from bottom-sticky positioning for long result lists? (Low confidence — pattern is mobile-first)

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Icon+text vs icon-only | HIGH | NN/G research + design system docs converge on icon+text for clarity |
| Load More vs infinite scroll | HIGH | Multiple sources confirm Load More for goal-oriented search |
| Tooltips (content + accessibility) | HIGH | WCAG 2.2 is authoritative; 15-word guideline from multiple sources |
| Document type filters | MEDIUM | PubMed/Google Scholar patterns documented, but Serapeum user needs unverified |
| Button ordering | MEDIUM | Workflow order is standard pattern but frequency data is missing |
| Refresh vs Load More mental models | HIGH | Cloudscape Design System + UX Pattern Analysis are authoritative sources |

---

*Research complete: 2026-03-06. All findings verified with design system documentation or UX research sources. LOW confidence areas flagged for user testing or analytics validation.*
