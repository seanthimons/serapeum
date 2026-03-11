# Phase 54: Tooltip Layer - Research

**Researched:** 2026-03-11
**Domain:** Accessible UI tooltips in R Shiny with bslib
**Confidence:** HIGH

## Summary

Phase 54 adds accessible, keyboard-navigable tooltips to 12 buttons (6 toolbar + 6 sidebar) using `bslib::tooltip()`. bslib 0.9.0 provides a native wrapper around Bootstrap 5 tooltips with automatic keyboard accessibility via `tabindex="0"` for non-interactive elements. Bootstrap 5 tooltips natively comply with WCAG 2.2 Success Criterion 1.4.13 (Content on Hover or Focus) through dismissibility (Escape key), hoverability (pointer can move over tooltip), and persistence (remains until dismissed or focus removed). Dark mode theming is automatically inherited from the existing Catppuccin `bs_theme()` configuration with no custom CSS required.

Testing will be manual UAT only — bslib tooltip rendering requires full Shiny runtime and browser environment, not unit-testable with testthat alone.

**Primary recommendation:** Wrap each actionButton with `bslib::tooltip(actionButton(...), "message", placement = "bottom", options = list(delay = list(show = 300, hide = 100)))`. For the Export dropdown button, wrap the entire btn-group div. For dynamic keyword/journal filter elements, add `title` attributes server-side.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Tooltip coverage:** 6 toolbar buttons + 6 sidebar discovery buttons wrapped with `bslib::tooltip()`. New Search/Document Notebook buttons excluded (labels self-explanatory). Dynamic keyword pills and journal filter links use `title` attributes only.
- **Tooltip copy:** Approved text for all 12 buttons (max 15 words each, contextual tone explaining action and use case)
- **Tooltip behavior:**
  - No keyboard shortcuts in tooltip text — purely descriptive
  - Placement: below buttons (Bootstrap default)
  - Hover delay: ~300ms before showing to prevent accidental triggers in dense button grid
  - No custom dark mode CSS — trust Bootstrap/bslib theming (Catppuccin sets bg/fg via bs_theme())

### Claude's Discretion
- Exact `bslib::tooltip()` placement parameter if below causes overlap issues
- Whether Export dropdown button needs special wrapping (btn-group context)
- Title attribute text for dynamic keyword/journal filter buttons
- Any tooltip styling adjustments if UAT reveals contrast issues

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TOOL-05 | Every toolbar button has a bslib tooltip (max 15 words, keyboard-accessible) | bslib::tooltip() provides native Bootstrap 5 tooltips with automatic keyboard accessibility. Placement parameter controls positioning. Bootstrap tooltips inherit theme colors from bs_theme() for dark mode support. WCAG 2.2 compliance via native dismissibility (Escape key), hoverability, and persistence. |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bslib | 0.9.0 | Tooltip wrapper for Bootstrap 5 | Official Shiny UI toolkit, provides R-native tooltip() function with automatic accessibility features |
| Bootstrap | 5.x | Underlying tooltip component | Industry standard UI framework, WCAG 2.2 compliant tooltip implementation |
| testthat | 3.2.3 | Testing framework | Already project standard, but tooltips require manual UAT (not unit-testable) |

### Supporting
N/A — tooltips use existing bslib/Bootstrap stack with no additional dependencies.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bslib::tooltip() | HTML `title` attribute | title attributes are simpler but lack placement control, hover delay, and consistent dark mode theming. Bootstrap tooltips offer superior UX. |
| bslib::tooltip() | Custom JavaScript tooltip library | Adds dependency, maintenance burden, and risks breaking Bootstrap theme integration. bslib is already installed. |

**Installation:**
No new packages required. bslib 0.9.0 already installed in project.

## Architecture Patterns

### Pattern 1: Static Button Tooltip Wrapping
**What:** Wrap each actionButton with `bslib::tooltip()` in UI definition
**When to use:** All static toolbar and sidebar buttons

**Example:**
```r
# Source: https://rstudio.github.io/bslib/reference/tooltip.html
tooltip(
  actionButton(ns("open_bulk_import"), "Import",
               class = "btn-sm btn-outline-primary",
               style = "white-space: nowrap;",
               icon = icon_file_import()),
  "Add papers by pasting DOIs or uploading a BibTeX file",
  placement = "bottom",
  options = list(delay = list(show = 300, hide = 100))
)
```

### Pattern 2: Button Group Tooltip Wrapping
**What:** Wrap entire btn-group container for dropdown buttons (Export)
**When to use:** Dropdown toggles inside btn-group (Bootstrap tooltip docs require `container: 'body'` for button groups)

**Example:**
```r
# Source: https://getbootstrap.com/docs/5.3/components/tooltips/
tooltip(
  div(
    class = "btn-group btn-group-sm w-100",
    tags$button(
      class = "btn btn-outline-primary dropdown-toggle w-100",
      `data-bs-toggle` = "dropdown",
      icon_download(), " Export"
    ),
    tags$ul(
      class = "dropdown-menu",
      tags$li(downloadLink(ns("download_bibtex"), ...))
    )
  ),
  "Download your current papers as BibTeX or CSV",
  placement = "bottom",
  options = list(
    delay = list(show = 300, hide = 100),
    container = "body"  # Prevents clipping in button groups
  )
)
```

### Pattern 3: Dynamic Element Title Attributes
**What:** Add `title` attributes to server-rendered HTML elements (keyword pills, journal links)
**When to use:** Elements created dynamically in server code that cannot be wrapped with bslib::tooltip()

**Example:**
```r
# Server-side rendering with title attribute
tags$span(
  class = "badge bg-info",
  title = "Click to filter results by this keyword",  # Browser native tooltip
  keyword_text
)
```

### Recommended Project Structure
No structural changes — tooltips integrated into existing module UI definitions:
```
R/
├── mod_search_notebook.R    # Toolbar tooltips (6 buttons)
├── app.R                     # Sidebar tooltips (6 buttons)
└── [server modules]          # Title attributes for dynamic elements
```

### Anti-Patterns to Avoid

- **Don't wrap non-interactive elements with tooltip:** bslib adds `tabindex="0"` automatically, but buttons are already focusable. Wrapping plain text/spans creates confusing keyboard tab stops.
- **Don't use placement="auto" in dense grids:** Auto-placement can cause tooltips to jump positions unpredictably. Fixed placement (bottom) provides consistent UX.
- **Don't omit delay in high-density button layouts:** Zero-delay tooltips flicker annoyingly when user mouses across toolbar. 300ms delay prevents accidental triggers.
- **Don't specify title or placement in options list:** bslib reserves these parameters. Use dedicated `placement` argument and `...` for tooltip content.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Custom tooltip positioning | JavaScript to calculate coordinates and reposition on scroll | bslib::tooltip() with placement parameter | Bootstrap Popper.js handles all edge cases: viewport boundaries, scrolling containers, dynamic content changes |
| Keyboard accessibility | tabindex management, focus trap, Escape key handler | bslib::tooltip() automatic behavior | bslib adds tabindex="0" automatically, Bootstrap handles Escape dismissal and focus management per WCAG 2.2 |
| Dark mode tooltip theming | Custom CSS with [data-bs-theme="dark"] selectors | bs_theme() color inheritance | Bootstrap tooltips automatically inherit bg/fg colors from theme. Catppuccin dark mode CSS already sets --bs-tooltip-bg/--bs-tooltip-color |
| Tooltip delay timing | setTimeout/clearTimeout logic with hover event handlers | options = list(delay = list(show = 300, hide = 100)) | Bootstrap tooltip delay is battle-tested across millions of sites, handles rapid hover/unhover correctly |

**Key insight:** Accessible tooltips are deceptively complex. WCAG 2.2 Success Criterion 1.4.13 requires three conditions (dismissible, hoverable, persistent) that Bootstrap already implements. Custom solutions commonly fail keyboard navigation, Escape key dismissal, or screen reader announcements. bslib::tooltip() provides a zero-config accessible implementation.

## Common Pitfalls

### Pitfall 1: Tooltip Content Lost in Dropdown Menus
**What goes wrong:** When wrapping a dropdown button with tooltip(), the dropdown menu stops working or the tooltip doesn't appear.
**Why it happens:** Bootstrap dropdowns require specific HTML structure. bslib::tooltip() wraps the trigger element, which can break `data-bs-toggle="dropdown"` event handling.
**How to avoid:** Wrap the entire btn-group container (not just the button) and add `options = list(container = "body")` to prevent clipping.
**Warning signs:** Dropdown doesn't open on click, or tooltip appears but is cut off by parent container.

### Pitfall 2: Tooltip Text Truncated in Dark Mode
**What goes wrong:** Tooltip background doesn't expand to fit text, causing truncation or unreadable text due to poor contrast.
**Why it happens:** Bootstrap tooltip uses `white-space: nowrap` by default. Long messages (>15 words) exceed max-width and wrap incorrectly.
**How to avoid:** Keep tooltip text under 15 words (user constraint already enforces this). For longer content, use bslib::popover() instead.
**Warning signs:** Tooltip text breaks mid-word, or tooltip appears as a thin vertical strip.

### Pitfall 3: Flicker When Mousing Across Button Grid
**What goes wrong:** Tooltips appear and disappear rapidly as user moves cursor across toolbar, creating annoying flicker.
**Why it happens:** Default Bootstrap delay is 0ms. Toolbar uses 3x2 CSS grid with 0.5rem gap — small enough that cursor crosses multiple buttons quickly.
**How to avoid:** Set `options = list(delay = list(show = 300, hide = 100))` — 300ms show delay prevents accidental triggers, 100ms hide delay provides smooth transition.
**Warning signs:** Tooltips pop up for buttons user didn't intend to hover over, creating visual noise.

### Pitfall 4: Keyboard Focus Not Visible
**What goes wrong:** User tabs through buttons but can't tell which button has focus because tooltip doesn't appear until hover.
**Why it happens:** Bootstrap tooltip default trigger is `'hover focus'`, but focus-visible CSS may not be styled correctly.
**How to avoid:** Trust Bootstrap defaults (trigger includes focus). Test with Tab key navigation — tooltip should appear on focus. If focus ring is invisible, add `:focus-visible` styles to button classes, not tooltip config.
**Warning signs:** Keyboard navigation works but user can't see which button is focused.

### Pitfall 5: Title Attribute Conflicts
**What goes wrong:** Both bslib::tooltip() and title attribute on same element causes duplicate tooltips or browser native tooltip competing with Bootstrap tooltip.
**Why it happens:** Browsers show native tooltips for title attributes. Bootstrap tooltips suppress this by default, but conflicts can occur if title is added after tooltip initialization.
**How to avoid:** For static buttons, use bslib::tooltip() ONLY (no title attribute). For dynamic elements that can't use bslib::tooltip(), use title attribute ONLY.
**Warning signs:** Two tooltips appear simultaneously, or browser native yellow tooltip shows instead of themed Bootstrap tooltip.

## Code Examples

Verified patterns from official sources:

### Toolbar Button with Tooltip
```r
# Source: https://rstudio.github.io/bslib/reference/tooltip.html
# Wrap actionButton in card_header grid
tooltip(
  actionButton(ns("refresh_search"), "Refresh",
               class = "btn-sm btn-outline-secondary",
               style = "white-space: nowrap;",
               icon = icon_rotate()),
  "Re-run your current search to check for new results",
  placement = "bottom",
  options = list(delay = list(show = 300, hide = 100))
)
```

### Sidebar Discovery Button with Tooltip
```r
# Source: https://rstudio.github.io/bslib/reference/tooltip.html
# Wrap actionButton in sidebar d-grid
tooltip(
  actionButton("import_papers", "Import Papers",
               class = "btn-outline-peach",
               icon = icon_file_import()),
  "Add papers by pasting DOIs or uploading a BibTeX file",
  placement = "bottom",
  options = list(delay = list(show = 300, hide = 100))
)
```

### Export Dropdown Button (btn-group) with Tooltip
```r
# Source: https://getbootstrap.com/docs/5.3/components/tooltips/ (container option)
# Wrap entire btn-group div to preserve dropdown functionality
tooltip(
  div(
    class = "btn-group btn-group-sm w-100",
    tags$button(
      class = "btn btn-outline-primary dropdown-toggle w-100",
      `data-bs-toggle` = "dropdown",
      icon_download(), " Export"
    ),
    tags$ul(
      class = "dropdown-menu",
      tags$li(downloadLink(ns("download_bibtex"), class = "dropdown-item",
                          icon_file_code(), " BibTeX (.bib)")),
      tags$li(downloadLink(ns("download_csv"), class = "dropdown-item",
                          icon_file_csv(), " CSV (.csv)"))
    )
  ),
  "Download your current papers as BibTeX or CSV",
  placement = "bottom",
  options = list(
    delay = list(show = 300, hide = 100),
    container = "body"  # Required for button groups
  )
)
```

### Dynamic Keyword Pill with Title Attribute
```r
# Source: Project pattern (server-side rendering)
# No bslib::tooltip() — use browser native title attribute
tags$span(
  class = "badge bg-info clickable",
  title = "Filter results by this keyword",  # Browser native tooltip
  onclick = "...",  # Filter logic
  keyword_text
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| HTML title attribute for all tooltips | bslib::tooltip() for static buttons, title for dynamic elements | bslib 0.5.0 (2023) | Better placement control, theming, hover delay. Dark mode support via Bootstrap theme integration. |
| Manual Bootstrap tooltip initialization via JavaScript | R-native bslib::tooltip() wrapper | bslib 0.5.0 (2023) | No custom JS required, automatic initialization, Shiny-aware (can update reactively with update_tooltip()) |
| trigger="hover" (keyboard inaccessible) | trigger="hover focus" (default) | Bootstrap 5.0 (2021) | WCAG 2.2 compliance out of the box. Keyboard users can tab to buttons and see tooltips. |

**Deprecated/outdated:**
- **shinyBS package:** Older Shiny tooltip library (Bootstrap 3 era). Use bslib::tooltip() instead — better accessibility, Bootstrap 5 support, maintained by Posit.
- **Custom Popper.js integration:** bslib already includes Popper.js via Bootstrap 5. Don't add separate Popper.js dependency.

## Open Questions

1. **Will 300ms delay feel too slow for power users?**
   - What we know: Bootstrap default is 0ms. User specifically requested ~300ms to prevent flicker in dense toolbar grid.
   - What's unclear: Whether this delay will feel sluggish for users who deliberately hover over buttons.
   - Recommendation: Implement 300ms, validate in UAT. If feedback indicates delay is too high, reduce to 150-200ms. Delay is a single-line options change.

2. **Do journal filter links need tooltips or are they self-explanatory?**
   - What we know: Context says "journal filter links" use title attributes. Current implementation may already have titles for truncated journal names.
   - What's unclear: Whether existing title attributes serve as tooltips or need new descriptive text.
   - Recommendation: Inspect existing journal link rendering code. If title already present (e.g., full journal name for truncated display), leave as-is. If no title, add "Filter by this journal" or similar.

## Validation Architecture

**Note:** workflow.nyquist_validation is not explicitly set to false in .planning/config.json (workflow object exists but nyquist_validation key absent), so validation architecture is INCLUDED per research protocol.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.2.3 |
| Config file | tests/testthat/ (standard testthat structure) |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-tooltips.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TOOL-05 | Tooltips keyboard accessible (tabindex="0" auto-added) | manual | UAT: Tab through buttons, verify tooltip appears on focus | ❌ Manual UAT only |
| TOOL-05 | Tooltips dismissible via Escape key | manual | UAT: Tab to button, press Escape, verify tooltip closes | ❌ Manual UAT only |
| TOOL-05 | Tooltips visible in dark mode with readable contrast | manual | UAT: Toggle dark mode, hover buttons, verify tooltip bg/fg readable | ❌ Manual UAT only |
| TOOL-05 | Tooltips positioned below buttons without overlap | manual | UAT: Hover each button, verify tooltip doesn't cover adjacent buttons | ❌ Manual UAT only |
| TOOL-05 | 300ms delay prevents flicker when mousing across toolbar | manual | UAT: Quickly drag cursor across toolbar buttons, verify no rapid flickering | ❌ Manual UAT only |

### Sampling Rate
- **Per task commit:** Manual UAT only (tooltips require full Shiny runtime + browser)
- **Per wave merge:** Manual UAT checklist
- **Phase gate:** Full UAT pass before `/gsd:verify-work` — all 12 tooltips visible, keyboard accessible, dark mode tested

### Wave 0 Gaps
**CRITICAL:** Tooltip behavior requires full Shiny app runtime and browser environment. testthat cannot:
- Simulate browser hover/focus events
- Render Bootstrap tooltip JavaScript
- Test dark mode theme CSS inheritance
- Verify WCAG 2.2 keyboard accessibility

**Validation Strategy:** Manual UAT ONLY
- [ ] **UAT Checklist** — Create checklist for verifying all 12 tooltips (6 toolbar + 6 sidebar) across light/dark modes with keyboard navigation
- [ ] **Shiny Smoke Test** — Per project CLAUDE.md: Start app with `shiny::runApp()`, wait for "Listening on", verify no startup crashes (catches missing icons, syntax errors)

**Why no unit tests:** bslib::tooltip() returns htmltools tag objects with Bootstrap data attributes. Testing requires:
1. Full Shiny app context (reactive inputs/outputs)
2. Browser JavaScript runtime (Bootstrap tooltip.js initialization)
3. CSS rendering (theme inheritance, positioning)
4. User interaction simulation (hover, focus, Escape key)

testthat alone cannot provide these. shinytest2 could provide screenshot-based regression testing but is out of scope for this phase (no existing shinytest2 infrastructure in project).

## Sources

### Primary (HIGH confidence)
- [bslib::tooltip() reference](https://rstudio.github.io/bslib/reference/tooltip.html) - Function signature, parameters, accessibility features
- [bslib Tooltips & Popovers article](https://rstudio.github.io/bslib/articles/tooltips-popovers/index.html) - Placement options, usage patterns
- [Bootstrap 5.3 Tooltips documentation](https://getbootstrap.com/docs/5.3/components/tooltips/) - Configuration options (delay, trigger, container), accessibility requirements
- [WCAG 1.4.13 Understanding Content on Hover or Focus](https://www.w3.org/WAI/WCAG21/Understanding/content-on-hover-or-focus.html) - Dismissible, hoverable, persistent requirements

### Secondary (MEDIUM confidence)
- [Posit Shiny blog: bslib tooltips announcement](https://shiny.posit.co/blog/posts/bslib-tooltips/) - Feature introduction, practical examples
- [bslib theming article](https://rstudio.github.io/bslib/articles/theming/index.html) - bs_theme() dark mode inheritance for tooltips
- [Sarah Higley: Tooltips in the time of WCAG 2.1](https://sarahmhigley.com/writing/tooltips-in-wcag-21/) - Deep dive on tooltip accessibility challenges and compliance

### Tertiary (LOW confidence)
- Web search results for "testthat shiny UI testing" - General shinytest2 mentions, not specific to tooltips

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - bslib 0.9.0 confirmed installed, Bootstrap 5 is project standard, testthat 3.2.3 confirmed
- Architecture: HIGH - Official bslib documentation with complete examples, Bootstrap tooltip options well-documented
- Pitfalls: MEDIUM - Bootstrap documentation covers button group container issue (HIGH), but delay flicker prevention is derived from user context (MEDIUM)
- WCAG compliance: HIGH - W3C official documentation for Success Criterion 1.4.13, verified Bootstrap implements all three requirements
- Testing: HIGH - Manual UAT requirement is clear, testthat limitations well-understood

**Research date:** 2026-03-11
**Valid until:** 2026-04-10 (30 days — bslib and Bootstrap are stable, WCAG standards don't change rapidly)
