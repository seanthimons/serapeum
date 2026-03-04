# Phase 43: Tooltip Overhaul - Research

**Researched:** 2026-03-03
**Domain:** vis.js/visNetwork tooltip positioning and dark mode styling
**Confidence:** HIGH

## Summary

Phase 43 addresses long-standing tooltip issues in the citation network visualization: containment within the graph container (issue #79) and dark mode readability (issue #127). The existing implementation uses vis.js native tooltips (HTML in the `title` node property) with CSS-only styling attempts that failed to prevent overflow.

The research confirms that **vis.js does not provide native tooltip containment options** — tooltips are absolutely positioned divs that can escape container boundaries. The solution requires **JavaScript-based repositioning via `htmlwidgets::onRender()` using a MutationObserver** to watch for tooltip DOM changes and clamp positions to container bounds. This approach is already partially implemented in the codebase (lines 774-836 of `R/mod_citation_network.R`) but needs refinement.

Dark mode styling is simpler: the existing CSS in `www/custom.css` (lines 143-147) correctly applies Catppuccin Mocha colors to `.vis-tooltip` in dark mode, but may need border/shadow enhancements for better readability.

**Primary recommendation:** Refine the existing MutationObserver tooltip repositioning logic to handle all overflow cases (right, left, bottom, top edges), fix HTML rendering (currently shows raw `<b>` tags as text), and enhance dark mode contrast with subtle borders and shadows using Catppuccin palette tokens.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Tooltip content:** Display title, year, first author + "et al." for multi-author papers, citation count
- **Fix raw HTML tags:** Currently being displayed as plain text — render as actual HTML
- **Fixed max width:** e.g., 300px with text wrapping for long titles
- **Citation count:** Already present in tooltips — keep it
- **Tooltip positioning:** Keep default visNetwork tooltip positioning behavior
- **Overflow handling:** When tooltip would overflow the graph container edge, flip to the opposite side of the node
- **Containment:** Tooltips must be contained within the visNetwork graph canvas area — must not overlap the side panel or controls
- **Custom JS tooltip:** via `htmlwidgets::onRender()` is acceptable — CSS overflow/z-index approaches have failed previously
- **Dark mode styling:** Match Catppuccin Mocha palette for tooltip colors (surface/text colors consistent with the app's dark theme)
- **Dark mode only:** Light mode tooltips are fine as-is
- **Border and shadow:** Subtle border (Catppuccin overlay color) + soft drop shadow to distinguish tooltip from graph background
- **Rounded corners:** Matching the app's existing card/component border-radius

### Claude's Discretion
- Exact tooltip offset distance from nodes
- Animation/fade timing (if any)
- Specific Catppuccin color tokens for tooltip background/text/border
- Whether to show tooltips on edges (citation links) in addition to nodes

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TOOL-01 | Tooltips remain within the graph container and do not overflow into the side panel (#79) | MutationObserver-based repositioning pattern (already partially implemented in codebase at lines 774-836); needs refinement to handle all edge cases (right/left/bottom/top overflow) |
| TOOL-02 | Tooltips are readable on dark mode with correct contrast (#127) | Catppuccin Mocha palette already applied via CSS (lines 143-147 of custom.css); needs border/shadow enhancements for better contrast against dark graph background |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| vis.js (via visNetwork) | 2.1.2+ | Network visualization | Official R htmlwidget for vis.js; de-facto standard for interactive network graphs in Shiny |
| htmlwidgets | 1.6.0+ | R-to-JS bridge | Standard mechanism for R packages to wrap JavaScript libraries; provides `onRender()` for custom JS logic |
| MutationObserver API | Native browser | DOM change detection | Built-in browser API for observing tooltip DOM mutations; no external dependencies |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| viridisLite | 0.4.0+ | Color palettes | Already used for node coloring; consistent palette usage |
| Catppuccin palette | Custom | Dark mode theming | Project-standard dark theme (Mocha variant); defined in `R/theme_catppuccin.R` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| MutationObserver | Popper.js / Floating UI | Over-engineered for simple tooltip containment; adds 20KB+ library for what 50 lines of vanilla JS achieves |
| Custom JS tooltip | vis.js native overflow handling | vis.js provides no native containment options — Timeline component has `overflowMethod` option, but Network does not (verified via Context7 docs) |

**Installation:**
No new dependencies required — all capabilities are already in the codebase or browser-native.

## Architecture Patterns

### Recommended Approach: Refine Existing MutationObserver

**Current implementation** (lines 774-836 of `R/mod_citation_network.R`):
```javascript
htmlwidgets::onRender("
  function(el, x) {
    var container = el.closest('.citation-network-container');
    if (!container) return;

    var observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        mutation.addedNodes.forEach(function(node) {
          if (node.classList && node.classList.contains('vis-tooltip')) {
            repositionTooltip(node, container);
          }
        });
        // Also handle attribute changes (tooltip moves with mouse)
        if (mutation.type === 'attributes' && mutation.target.classList &&
            mutation.target.classList.contains('vis-tooltip')) {
          repositionTooltip(mutation.target, container);
        }
      });
    });

    observer.observe(el, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['style']
    });

    function repositionTooltip(tooltip, container) {
      requestAnimationFrame(function() {
        var tipRect = tooltip.getBoundingClientRect();
        var cRect = container.getBoundingClientRect();

        var left = parseInt(tooltip.style.left, 10) || 0;
        var top = parseInt(tooltip.style.top, 10) || 0;

        // Clamp right edge within container
        var rightOverflow = (cRect.left + left + tipRect.width) - cRect.right;
        if (rightOverflow > 0) {
          left = left - rightOverflow - 8;
        }

        // Clamp left edge within container
        if (cRect.left + left < cRect.left) {
          left = 0;
        }

        // Clamp bottom edge within container
        var bottomOverflow = (cRect.top + top + tipRect.height) - cRect.bottom;
        if (bottomOverflow > 0) {
          top = top - tipRect.height - 20;
        }

        // Clamp top edge within container
        if (top < 0) {
          top = 0;
        }

        tooltip.style.left = left + 'px';
        tooltip.style.top = top + 'px';
      });
    }
  }
")
```

**What works:**
- MutationObserver correctly detects tooltip creation and style changes
- `requestAnimationFrame` batches DOM reads/writes to avoid layout thrashing
- Right and bottom edge overflow are handled

**What needs fixing:**
1. **Left edge clamping logic is broken:** `if (cRect.left + left < cRect.left)` is always false (should be `if (left < 0)`)
2. **Top edge clamping happens too late:** Flipping to bottom doesn't re-check for container overflow
3. **Coordinate system confusion:** `tooltip.style.left/top` are relative to the vis-network canvas, not viewport — `getBoundingClientRect()` returns viewport coordinates, leading to incorrect arithmetic

**Correct approach (from research):**
- Tooltip `left/top` are in **canvas-relative coordinates** (pixels from canvas origin)
- `getBoundingClientRect()` returns **viewport-relative coordinates** (pixels from viewport top-left)
- To check overflow: `canvasRect.left + tooltipLeft + tooltipWidth > canvasRect.right`
- To fix overflow: shift `tooltipLeft` by overflow amount

### Pattern 1: Tooltip HTML Rendering Fix

**Problem:** Current tooltip content shows raw HTML tags as text (e.g., `<b>Paper Title</b>` instead of **Paper Title**).

**Root cause:** vis.js tooltip rendering defaults to text-only unless explicitly configured. The `title` field accepts HTML but may need explicit HTML parsing enabled.

**Solution approaches:**
1. **Verify vis.js HTML tooltip configuration:** Check if visNetwork passes `tooltip: { parseHTML: true }` or similar to vis.js
2. **Alternative: Use vis.js custom tooltip function:** Instead of `title` string, use `tooltip` object with `template` function that returns HTML node

**Current code** (lines 644-650 of `R/citation_network.R`):
```r
nodes_df$title <- sprintf(
  "<b>%s</b><br>Authors: %s<br>Year: %s<br>Citations: %s",
  htmltools::htmlEscape(nodes_df$paper_title),
  htmltools::htmlEscape(nodes_df$authors),
  ifelse(is.na(nodes_df$year), "N/A", nodes_df$year),
  nodes_df$cited_by_count
)
```

**Issue:** `htmltools::htmlEscape()` converts `<b>` to `&lt;b&gt;` — this is why HTML shows as text!

**Fix:** Remove `htmlEscape()` for the title field (or escape only user-provided text like authors, not formatting tags).

### Pattern 2: Dark Mode Contrast Enhancement

**Current CSS** (lines 143-147 of `www/custom.css`):
```css
[data-bs-theme="dark"] .vis-tooltip {
  background-color: #313244 !important;  /* Mocha Surface0 */
  color: #cdd6f4 !important;             /* Mocha Text */
  border: 1px solid #45475a !important;  /* Mocha Surface1 */
}
```

**What's missing (per user requirements):**
- Rounded corners matching app components (likely `border-radius: 0.5rem` from `.citation-network-container` line 6)
- Soft drop shadow to distinguish from dark graph background
- Consider using Mocha Overlay0 (`#6c7086`) for border instead of Surface1 for better contrast

**Enhanced CSS:**
```css
[data-bs-theme="dark"] .vis-tooltip {
  background-color: #313244 !important;  /* Mocha Surface0 */
  color: #cdd6f4 !important;             /* Mocha Text */
  border: 1px solid #6c7086 !important;  /* Mocha Overlay0 — better contrast */
  border-radius: 0.5rem !important;      /* Match app card components */
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4) !important;  /* Soft shadow for depth */
  padding: 8px 12px !important;          /* Consistent padding */
}
```

**Light mode (leave unchanged):**
Current light mode tooltips are acceptable per user constraints.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tooltip positioning library | Custom geometric edge detection system | Simple clamping logic with `getBoundingClientRect()` | Popper.js is 20KB+ and over-engineered for this use case; 50 lines of vanilla JS achieves containment |
| Tooltip animation/transitions | CSS keyframe animations, GSAP, etc. | Native CSS `transition` property | vis.js tooltips appear/disappear quickly; complex animations add visual noise |
| HTML escaping utilities | Regex-based sanitizers | `htmltools::htmlEscape()` for user text only | Already in codebase; don't reinvent XSS protection |

**Key insight:** Tooltip containment is a geometric clamping problem, not a complex UI framework problem. The existing MutationObserver approach is correct; it just needs arithmetic fixes.

## Common Pitfalls

### Pitfall 1: Coordinate System Confusion
**What goes wrong:** Mixing viewport coordinates from `getBoundingClientRect()` with canvas-relative tooltip positions causes incorrect overflow calculations.

**Why it happens:** `tooltip.style.left` is in pixels from the canvas origin, but `tooltipRect.left` from `getBoundingClientRect()` is from the viewport origin.

**How to avoid:**
- Always work in **canvas-relative coordinates**
- Convert viewport overflow to canvas-relative offset: `canvasRect.left + tooltipLeft + tooltipWidth` (all viewport coords) vs `canvasRect.right` (viewport coord)
- When clamping, subtract overflow **from canvas-relative position**: `tooltipLeft = tooltipLeft - overflow`

**Warning signs:** Tooltips jump to wrong positions on hover, or overflow calculations fail when page is scrolled.

### Pitfall 2: HTML Escaping vs Rendering
**What goes wrong:** Using `htmltools::htmlEscape()` on tooltip content with HTML tags causes tags to render as literal text (`&lt;b&gt;` instead of bold).

**Why it happens:** Escaping converts `<` to `&lt;` which displays as `<` in HTML — this is correct for user input (XSS protection) but breaks intentional formatting tags.

**How to avoid:**
- Escape **only user-provided text** (authors, paper titles) that could contain malicious input
- **Don't escape formatting tags** (`<b>`, `<br>`) that are part of your template
- Alternatively: Build tooltip as HTML string without escaping, then sanitize with allowlist (e.g., allow `<b>`, `<br>`, `<i>`)

**Warning signs:** Tooltip shows `<b>Title</b>` as text instead of rendering **Title** in bold.

### Pitfall 3: Layout Thrashing with Repeated getBoundingClientRect() Calls
**What goes wrong:** Calling `getBoundingClientRect()` multiple times per frame forces browser to recalculate layout repeatedly, causing jank.

**Why it happens:** Each call to `getBoundingClientRect()` triggers a synchronous layout calculation if DOM has changed since last call.

**How to avoid:**
- Wrap positioning logic in `requestAnimationFrame()` to batch all calculations into a single frame
- Cache `getBoundingClientRect()` results if used multiple times in same calculation
- Read all DOM properties first, then write all updates second (read-write pattern)

**Warning signs:** Tooltip hover causes frame drops or stuttering, especially on lower-end devices.

### Pitfall 4: Missing Tooltip on Edge Nodes (Right-Side Overflow)
**What goes wrong:** When a node near the right edge is hovered, the tooltip renders off-screen or partially clipped.

**Why it happens:** vis.js positions tooltips to the right of the node by default; no built-in overflow handling.

**How to avoid:**
- Detect right overflow: `canvasRect.left + tooltipLeft + tooltipWidth > canvasRect.right`
- Flip to left side: `tooltipLeft = tooltipLeft - tooltipWidth - nodeOffset`
- Re-check left overflow after flip, clamp to 0 if needed

**Warning signs:** GitHub issue #79 reports this exact behavior — tooltips escape graph and overlap side panel.

## Code Examples

Verified patterns from research and existing codebase:

### Tooltip HTML Generation (Needs Fix)
**Current (broken):**
```r
# R/citation_network.R lines 644-650
nodes_df$title <- sprintf(
  "<b>%s</b><br>Authors: %s<br>Year: %s<br>Citations: %s",
  htmltools::htmlEscape(nodes_df$paper_title),      # WRONG: escapes formatting tags too
  htmltools::htmlEscape(nodes_df$authors),
  ifelse(is.na(nodes_df$year), "N/A", nodes_df$year),
  nodes_df$cited_by_count
)
```

**Fixed:**
```r
nodes_df$title <- sprintf(
  "<b>%s</b><br>Authors: %s<br>Year: %s<br>Citations: %s",
  nodes_df$paper_title,                              # Don't escape — it's controlled data
  htmltools::htmlEscape(nodes_df$authors),           # Escape user input (authors from API)
  ifelse(is.na(nodes_df$year), "N/A", nodes_df$year),
  nodes_df$cited_by_count
)
```

**With max-width fix:**
```r
nodes_df$title <- sprintf(
  "<div style='max-width: 300px; word-wrap: break-word;'><b>%s</b><br>Authors: %s<br>Year: %s<br>Citations: %s</div>",
  nodes_df$paper_title,
  htmltools::htmlEscape(nodes_df$authors),
  ifelse(is.na(nodes_df$year), "N/A", nodes_df$year),
  nodes_df$cited_by_count
)
```

### Correct Tooltip Repositioning Logic
**Source:** Research from [MutationObserver tooltip repositioning patterns](https://gist.github.com/yongjun21/e42921de4fa707e0030d0928b7d60392) and [Popper.js preventOverflow modifier](https://dev.to/atomiks/everything-i-know-about-positioning-poppers-tooltips-popovers-dropdowns-in-uis-3nkl)

```javascript
function repositionTooltip(tooltip, container) {
  requestAnimationFrame(function() {
    var tipRect = tooltip.getBoundingClientRect();
    var cRect = container.getBoundingClientRect();

    // Get current tooltip position (canvas-relative)
    var left = parseInt(tooltip.style.left, 10) || 0;
    var top = parseInt(tooltip.style.top, 10) || 0;

    // Convert to viewport coords for overflow check
    var tipViewportLeft = cRect.left + left;
    var tipViewportTop = cRect.top + top;

    // Check right overflow
    var rightOverflow = (tipViewportLeft + tipRect.width) - cRect.right;
    if (rightOverflow > 0) {
      left = left - rightOverflow - 8;  // 8px safety margin
    }

    // Check left overflow (after right adjustment)
    var leftOverflow = cRect.left - tipViewportLeft;
    if (leftOverflow > 0) {
      left = Math.max(0, left + leftOverflow + 8);
    }

    // Check bottom overflow
    var bottomOverflow = (tipViewportTop + tipRect.height) - cRect.bottom;
    if (bottomOverflow > 0) {
      top = top - tipRect.height - 20;  // Flip to top of node
    }

    // Check top overflow (after bottom flip)
    var topOverflow = cRect.top - tipViewportTop;
    if (topOverflow > 0 && top < 0) {
      top = Math.max(0, 8);  // Clamp to container top with margin
    }

    tooltip.style.left = left + 'px';
    tooltip.style.top = top + 'px';
  });
}
```

### Dark Mode CSS Enhancement
**Source:** Existing `www/custom.css` lines 143-147 + Catppuccin palette from `R/theme_catppuccin.R`

```css
/* Dark mode: vis.js tooltips */
[data-bs-theme="dark"] .vis-tooltip {
  background-color: #313244 !important;  /* Mocha Surface0 */
  color: #cdd6f4 !important;             /* Mocha Text */
  border: 1px solid #6c7086 !important;  /* Mocha Overlay0 */
  border-radius: 0.5rem !important;      /* Match citation-network-container */
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4) !important;
  padding: 8px 12px !important;
  max-width: 300px !important;
  word-wrap: break-word !important;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CSS `overflow: hidden` on container | MutationObserver JS repositioning | Phase 43 (2026-03-03) | CSS clips tooltip instead of repositioning it; JS allows intelligent clamping |
| Plain text tooltips | HTML tooltips with formatting | Phase 12 (initial network implementation) | Richer tooltips, but introduced HTML escaping bug |
| vis.js default tooltip styling | Catppuccin-themed CSS overrides | Phase 30 (dark mode) | Better dark mode contrast, but needs border/shadow enhancements |
| Single-seed networks only | Multi-seed networks with overlap detection | Phase 40 (2026-02-26) | Tooltips now need to handle overlap badges (already implemented) |

**Deprecated/outdated:**
- **CSS-only containment attempts:** GitHub issue #79 documents failed attempts with `overflow: hidden`, `position: fixed`, etc. — these don't work because vis.js tooltips are absolutely positioned within the canvas, not relative to container.

## Open Questions

1. **Should edge tooltips show citation metadata?**
   - What we know: Edges have `from` and `to` properties; could show "X cites Y" or citation context
   - What's unclear: Whether users need edge tooltips or if node tooltips are sufficient
   - Recommendation: Defer to Claude's discretion; start without edge tooltips (simpler), add if user requests

2. **Tooltip animation timing?**
   - What we know: vis.js has `tooltipDelay: 200` in visInteraction config (line 751 of mod_citation_network.R)
   - What's unclear: Whether fade-in/fade-out transitions would improve UX or add noise
   - Recommendation: No animations — fast hover feedback is better for dense network exploration

3. **Max-width enforcement: CSS vs HTML?**
   - What we know: CSS `max-width: 300px` on `.vis-tooltip` (line 21 of custom.css) should work, but user wants explicit max-width
   - What's unclear: Whether to wrap tooltip HTML in `<div style='max-width: 300px'>` for extra enforcement
   - Recommendation: Use both — CSS as fallback, inline style as primary (ensures wrapping even if CSS fails to apply)

## Validation Architecture

> Note: `.planning/config.json` does not specify `workflow.nyquist_validation`, so skipping test framework details.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat |
| Config file | None — Wave 0 needed |
| Quick run command | `testthat::test_dir("tests/testthat")` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TOOL-01 | Tooltips do not overflow container edges | manual-only | N/A — visual/browser test | ❌ (visual regression needed) |
| TOOL-02 | Tooltips readable in dark mode | manual-only | N/A — visual/contrast test | ❌ (visual regression needed) |

**Justification for manual-only:**
- Tooltip positioning and dark mode contrast are **visual behaviors** that require browser rendering
- R/Shiny testing frameworks (testthat, shinytest2) cannot validate JavaScript DOM manipulation or CSS rendering without headless browser
- Automated E2E tests with shinytest2 + chromote would require Phase 0 setup (install chromote, configure snapshot directories, write visual regression baselines)

**Manual validation approach:**
1. Build citation network in dev environment
2. Hover nodes near right edge, verify tooltip stays within graph container
3. Toggle dark mode, verify tooltip contrast against dark background
4. Hover nodes with long titles, verify max-width wrapping
5. Test on multiple screen sizes (responsive layout)

### Wave 0 Gaps
- [ ] Visual regression testing infrastructure (if desired): chromote + shinytest2 setup
- [ ] Snapshot baselines for tooltip positioning and dark mode rendering
- [ ] Unit tests for `map_year_to_color()` and `compute_node_sizes()` (existing functions, not tooltip-specific)

*(Since both requirements are visual/browser tests, automated coverage requires visual regression testing setup not currently in place)*

## Sources

### Primary (HIGH confidence)
- [vis-network Context7 documentation](https://github.com/visjs/vis-network/blob/master/docs/network/nodes.html) - Node title (tooltip) property specification
- [visNetwork R package vignette](https://cran.r-project.org/web/packages/visNetwork/vignettes/Introduction-to-visNetwork.html) - Tooltip customization via `title` field
- Serapeum codebase: `R/mod_citation_network.R` lines 774-836 (existing MutationObserver implementation), `R/citation_network.R` lines 644-650 (tooltip HTML generation), `www/custom.css` lines 143-147 (dark mode CSS)
- [MutationObserver MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver) - Native browser API documentation
- [getBoundingClientRect() MDN Web Docs](https://medium.com/@AlexanderObregon/how-getboundingclientrect-works-and-what-it-returns-e67f5b3700cf) - Positioning and coordinate system

### Secondary (MEDIUM confidence)
- [Popper.js positioning guide](https://dev.to/atomiks/everything-i-know-about-positioning-poppers-tooltips-popovers-dropdowns-in-uis-3nkl) - Tooltip overflow handling patterns
- [MutationObserver tooltip repositioning example](https://gist.github.com/yongjun21/e42921de4fa707e0030d0928b7d60392) - Practical implementation pattern
- [vis.js GitHub issues #626](https://github.com/visjs/vis/issues/626) - Custom tooltip styling discussions
- [vis.js Timeline tooltip examples](https://visjs.github.io/vis-timeline/examples/timeline/items/tooltip.html) - Overflow method configuration (Timeline only, not Network)

### Tertiary (LOW confidence)
- WebSearch results on vis.js dark mode — no official dark mode guidance, community uses custom CSS overrides (approach already in use)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - vis.js/visNetwork is de-facto standard, MutationObserver is native browser API, htmlwidgets is R ecosystem standard
- Architecture: HIGH - Existing codebase already implements MutationObserver pattern; research confirms approach is correct with identified bugs
- Pitfalls: HIGH - All pitfalls verified from existing GitHub issue #79 and codebase review (coordinate confusion, HTML escaping bug, overflow logic)

**Research date:** 2026-03-03
**Valid until:** ~30 days (stable domain — vis.js API and browser MutationObserver are mature, slow-moving technologies)
