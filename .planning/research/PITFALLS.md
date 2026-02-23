# Pitfalls Research

**Domain:** Dark Mode Redesign in R/Shiny/bslib Applications
**Researched:** 2026-02-22
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Canvas Elements Ignore CSS Dark Mode Styling

**What goes wrong:**
visNetwork (vis.js) canvas elements don't respect `[data-bs-theme="dark"]` CSS selectors. Background colors set via CSS on the container are ignored by the canvas, resulting in white/light backgrounds in dark mode or dark backgrounds bleeding through in light mode. This is already documented in Serapeum as issue #89 where dark navy background (`#1a1a2e`) blends with viridis palette dark nodes.

**Why it happens:**
HTML5 canvas elements render via JavaScript drawing APIs, not the DOM. CSS background-color on the wrapper div has no effect on the canvas itself. vis.js creates its own canvas element and sets background programmatically. Bootstrap's `data-bs-theme` attribute changes CSS variables, but canvas rendering doesn't read CSS variables automatically.

**How to avoid:**
- Set `background` parameter directly in `visNetwork()` function call (e.g., `visNetwork(..., background = "#1e1e2e")`)
- Use `htmlwidgets::onRender()` to inject JavaScript that reads the current theme and sets canvas background post-render
- Avoid relying on CSS alone for canvas-based widgets (visNetwork, plotly canvas mode, custom canvas charts)
- Consider using `shiny::getCurrentOutputInfo()` to detect theme and pass appropriate colors to widget parameters

**Warning signs:**
- White flash when switching to dark mode on graph/chart components
- Canvas background doesn't match container background in either theme
- Color palettes (viridis, magma) with dark ends blend into background making nodes invisible
- Dark mode CSS rules have no visible effect on visualization widgets

**Phase to address:**
Phase 1 (Core Dark Mode Palette) — establish pattern for all canvas-based widgets. Fix citation network background as proof of concept.

---

### Pitfall 2: CSS Specificity Wars Between Custom Rules and Bootstrap Variables

**What goes wrong:**
Custom CSS rules with high specificity override Bootstrap's dark mode CSS variables, causing light mode styles to "stick" in dark mode. Components remain light-colored even with `[data-bs-theme="dark"]` applied. This manifests as white cards, light buttons, or bright backgrounds persisting in dark mode.

**Why it happens:**
Bootstrap 5.3 uses CSS custom properties (variables) that cascade and inherit. When you write custom CSS like `.my-card { background-color: white; }`, this has higher specificity than Bootstrap's variable-based approach `background-color: var(--bs-body-bg)`. CSS specificity rules mean your custom rule wins, blocking the dark mode variable from taking effect.

**How to avoid:**
- Use Bootstrap CSS variables instead of hardcoded colors: `background-color: var(--bs-body-bg)` not `background-color: white`
- Scope custom color overrides with `[data-bs-theme="light"]` selector explicitly
- When you must override, use both light and dark mode selectors:
  ```css
  [data-bs-theme="light"] .my-card { background-color: white; }
  [data-bs-theme="dark"] .my-card { background-color: #1e1e2e; }
  ```
- Test with browser DevTools: if a CSS variable is being overridden, you'll see it crossed out in the inspector

**Warning signs:**
- Components remain light when `data-bs-theme="dark"` is applied to `<html>`
- Browser DevTools shows Bootstrap variables crossed out by custom rules
- Dark mode works in vanilla Bootstrap example but not in your app
- Must use `!important` flags to make dark mode work (symptom of specificity conflict)

**Phase to address:**
Phase 1 (Core Dark Mode Palette) — audit `www/custom.css` for all hardcoded color values. Phase 2 (Visual Consistency) — verify no specificity conflicts remain.

---

### Pitfall 3: Pure Black Backgrounds Cause Eye Strain and Halation

**What goes wrong:**
Using pure black (`#000000`) backgrounds with white or light text creates harsh contrast that causes eye fatigue and "halation" — an optical effect where bright text appears to bleed or glow against dark backgrounds. Users with astigmatism experience this more severely. The harsh contrast defeats the purpose of dark mode (reducing eye strain).

**Why it happens:**
Developers assume maximum contrast (21:1) is always better for accessibility. Pure black seems like the "correct" dark mode choice. However, 100% contrast is actually harder to read and causes more eye strain than slightly reduced contrast. This is especially problematic in low-light conditions when users are most likely to use dark mode.

**How to avoid:**
- Use dark gray backgrounds instead of pure black: `#121212`, `#1a1a1a`, or `#1e1e2e` (Bootstrap default)
- Use slightly off-white text instead of pure white: `#e8e8e8`, `#f0f0f0` or `var(--bs-body-color)` in dark mode
- Aim for 15:1 to 17:1 contrast ratio, not 21:1 maximum
- Test with actual users or simulate astigmatism effects
- Follow Material Design dark theme guidance: surface colors should be dark grays, not true black

**Warning signs:**
- User reports of eye strain specifically in dark mode
- Text appears to "glow" or blur around edges on dark backgrounds
- Design uses `#000000` or `#ffffff` directly
- Contrast checker shows 21:1 ratio (too high, ironically)

**Phase to address:**
Phase 1 (Core Dark Mode Palette) — establish dark gray palette (`#1e1e2e` range), never use pure black. Document in style guide.

---

### Pitfall 4: Hardcoded Colors in R Plot Code Break Dark Mode

**What goes wrong:**
ggplot2 and other R plotting libraries generate plots with hardcoded colors (white backgrounds, black text, light gray grid lines) that look terrible in dark mode. The plots become unreadable white rectangles in an otherwise dark interface. This is particularly bad for plots embedded in Shiny outputs.

**Why it happens:**
R plotting functions default to light backgrounds. When you call `ggplot()` without specifying theme, it uses `theme_gray()` with white background and black text. These are baked into the plot image, not styled with CSS. Unlike HTML widgets, static plot images can't respond to CSS dark mode selectors.

**How to avoid:**
- Use the `thematic` package: `thematic::thematic_shiny()` auto-detects bslib theme and styles plots to match
- For ggplot2 specifically: use `ggdark` package or implement dark theme with `theme_minimal() + theme(panel.background = element_rect(fill = "transparent"))`
- Set plot background to transparent and let container background show through
- Use `shiny::getCurrentOutputInfo()` to detect current theme and conditionally apply dark/light ggplot themes
- For static exports, offer theme toggle that regenerates plots

**Warning signs:**
- White ggplot2 plots in dark mode UI
- Plot backgrounds don't match surrounding card backgrounds
- Grid lines disappear against dark plot backgrounds
- Text labels are black on dark backgrounds (unreadable)

**Phase to address:**
Phase 1 (Core Dark Mode Palette) — integrate `thematic` if plots exist. Phase 2 (Visual Consistency) — audit all plot outputs for theme compatibility.

---

### Pitfall 5: Scoped Theme Inheritance Breaks Nested Components

**What goes wrong:**
Setting `data-bs-theme="dark"` on a component creates theme boundaries that prevent proper inheritance. Child components may revert to global theme instead of respecting parent component theme. Or, setting theme on parent causes unintended cascade to children that should remain light.

**Why it happens:**
CSS custom properties inherit from parent but can be overridden by higher specificity selectors. Bootstrap's color mode system uses `data-bs-theme` attribute selectors. When you apply this to nested components, CSS specificity rules become complex. A selector like `.my-component [data-bs-theme="dark"]` has different specificity than `[data-bs-theme="dark"] .my-component`, causing inheritance proximity to fail.

**How to avoid:**
- Apply `data-bs-theme` at the highest level possible (usually `<html>`)
- Avoid setting `data-bs-theme` on individual components unless absolutely necessary
- If you must scope theme to component, explicitly set theme on all children that need it
- Test theme changes with nested layouts: card → card-body → button → tooltip
- Use browser DevTools to trace which theme selector is winning for each element

**Warning signs:**
- Theme changes work on some components but not others in same container
- Nested components flicker between light/dark when parent theme changes
- Must apply `data-bs-theme` to every component individually (symptom of broken inheritance)
- Tooltips, popovers, modals appear in wrong theme (they render outside parent in DOM)

**Phase to address:**
Phase 1 (Core Dark Mode Palette) — establish theme application at `<html>` level only. Phase 2 (Visual Consistency) — audit all nested components for correct inheritance.

---

### Pitfall 6: Contrast Ratio Failures on Interactive States (Hover, Focus, Disabled)

**What goes wrong:**
Default light mode hover/focus states fail WCAG contrast requirements in dark mode. A button that has sufficient contrast in default state becomes unreadable on hover. Focus indicators are invisible. Disabled states blend into background. This breaks accessibility and keyboard navigation.

**Why it happens:**
Developers test default state contrast but forget to test interactive states. Bootstrap's default hover/focus states darken colors, which works in light mode but fails in dark mode (darkening an already dark color reduces contrast). Focus rings that are dark blue on light backgrounds become invisible on dark backgrounds.

**How to avoid:**
- Test all interactive states (default, hover, focus, active, disabled) in both themes
- Use color-contrast() Sass function to ensure hover states maintain 4.5:1 ratio minimum
- For focus indicators, use contrasting accent color or glow effect, not just border darkening
- Aim for 3:1 minimum contrast for focus indicators (WCAG 2.1 Success Criterion 1.4.11)
- Use browser DevTools to force hover/focus states and check contrast
- Consider outline instead of border for focus (outline doesn't affect layout)

**Warning signs:**
- Focus ring disappears in dark mode
- Hovered buttons are barely distinguishable from default state
- Disabled inputs/buttons invisible against background
- Color contrast checker passes for default state but fails on :hover/:focus pseudo-classes
- Keyboard navigation difficult in dark mode (invisible focus)

**Phase to address:**
Phase 2 (Visual Consistency) — audit all interactive elements for contrast in all states. Create component testing checklist.

---

### Pitfall 7: Tooltip and Modal Z-Index Conflicts in Dark Mode

**What goes wrong:**
Tooltips appear behind modals. Popovers are cut off by parent containers. Dark mode overlays blend with dark backgrounds making modal backdrops invisible. Z-index stacking contexts break when custom positioned elements are introduced for dark mode styling.

**Why it happens:**
Bootstrap's z-index scale (modal-backdrop: 1050, modal: 1055, tooltip: 1080) assumes simple stacking. When you add custom positioned elements (absolute/fixed/relative) for dark mode styling, you create new stacking contexts. Elements with `position: relative` and `z-index: 1` can break tooltip rendering if they're parents of the trigger element.

Additionally, Bootstrap renders tooltips/popovers in `<body>`, not inside their trigger's parent, so `data-bs-theme` applied to parent doesn't affect them.

**How to avoid:**
- Avoid `position: relative` with `z-index` on containers that have tooltips/popovers
- If you must position elements, ensure z-index doesn't exceed Bootstrap's overlay range (< 1000)
- Test tooltips/popovers inside: modals, positioned cards, fixed headers, scrollable containers
- For modal backdrops in dark mode, use semi-transparent dark overlay: `rgba(0, 0, 0, 0.7)` not `rgba(0, 0, 0, 0.5)`
- Ensure tooltips have proper theme by setting `data-bs-theme` on `<html>` not component level

**Warning signs:**
- Tooltips appear behind parent elements or modals
- Popovers are clipped by `overflow: hidden` containers
- Modal backdrop is nearly invisible in dark mode
- Citation network tooltips overflow container boundary (documented in #79)
- Tooltip theme doesn't match application theme

**Phase to address:**
Phase 2 (Visual Consistency) — fix known tooltip overflow issue (#79). Audit all positioned elements and z-index values.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `!important` to override Bootstrap dark mode styles | Quick fix for specificity issues | Creates maintenance nightmare, harder to override later, indicates underlying specificity problem | Never — always fix specificity root cause |
| Hardcoding colors instead of Bootstrap CSS variables | Faster than looking up variable names | Breaks dark mode, requires duplicate rules for light/dark, harder to rebrand | Never in production — only in prototyping if removed before merge |
| Setting inline styles in Shiny UI functions | Easy to apply conditional colors in R code | Can't be overridden by CSS, breaks theme switching, creates inconsistency | Only for truly dynamic colors (e.g., data-driven node colors in graphs) |
| Duplicating light/dark color values instead of using Sass variables | Works without understanding Sass | Difficult to maintain, colors drift out of sync, no single source of truth | MVP only — refactor before adding more themes |
| Inverting all colors with CSS filter | Single line of CSS for instant dark mode | Breaks images, inverts logos, poor contrast, unprofessional appearance | Never for production — demo/prototype only |
| Skipping contrast testing on interactive states | Default state passes, assume hover/focus are fine | Accessibility failures, keyboard nav breaks, WCAG violation | Never — interactive states are critical for a11y |

## Integration Gotchas

Common mistakes when integrating dark mode with external libraries and widgets.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| visNetwork / vis.js | Relying on CSS background-color for canvas | Set `background` parameter in `visNetwork()` call + `htmlwidgets::onRender()` for theme detection |
| ggplot2 plots | Using default `theme_gray()` with white background | Use `thematic::thematic_shiny()` for auto-theming or manual theme switching with `getCurrentOutputInfo()` |
| DT DataTables | Assuming bslib theming extends to DataTables | DT uses separate theming system — must set `style = "bootstrap5"` and customize via `formatStyle()` |
| Quarto slides | Expecting dark mode to carry over to exported slides | Slides are standalone HTML — must set reveal.js theme to dark explicitly in YAML header |
| Plotly | Canvas rendering ignores CSS theme variables | Use `layout(paper_bgcolor, plot_bgcolor)` with conditional theme detection, not CSS |
| Custom JavaScript widgets | Assuming they read CSS variables automatically | Pass theme colors as widget config parameters from R, use JS to read `data-bs-theme` attribute if needed |
| Modal/popover content | Setting `data-bs-theme` on trigger element only | Bootstrap renders modals/popovers in `<body>` — set theme globally or on modal element itself |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Regenerating all plots on theme change | UI freezes when toggling dark mode | Use `thematic::thematic_shiny()` for reactive theming or cache plot objects and only regenerate on data change | > 5 plots on page |
| Re-rendering entire visNetwork on theme change | 1-2 second freeze, layout recalculation | Use `htmlwidgets::onRender()` to update only canvas background, preserve node positions | > 50 nodes |
| Inline style injection for every themed element | Slow initial render, large HTML payload | Use CSS rules with `[data-bs-theme]` selectors, not inline styles | > 100 themed elements |
| CSS filter inversion for dark mode | Entire page must repaint on theme toggle | Proper CSS variable approach with minimal repaints | Any page with animations |
| Loading separate CSS bundles for light/dark | Flash of unstyled content (FOUC), double HTTP requests | Single CSS bundle with `[data-bs-theme]` selectors | Always a problem |

## UX Pitfalls

Common user experience mistakes in dark mode design.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No persistent theme preference | User must re-select dark mode every session | Use `input_dark_mode()` with localStorage persistence (built into bslib) |
| Abrupt theme switching without transition | Jarring visual change, disorienting | Add CSS transition on root variables: `transition: background-color 0.2s, color 0.2s` |
| No theme toggle discoverable in UI | Users don't realize dark mode exists | Place theme toggle in prominent location (navbar, settings, or use bslib's built-in toggle) |
| Images/logos designed only for light backgrounds | Logo invisible in dark mode | Provide separate logo for dark mode or use transparent PNGs with proper contrast |
| Pure white or pure black extremes | Eye strain, halation, harsh contrast | Use near-black (`#1e1e2e`) and off-white (`#e8e8e8`) for comfortable reading |
| Insufficient testing of content in both themes | Screenshots, badges, embedded content break | Test all user-generated and external content in both themes |
| Syntax highlighting breaks in dark mode | Code blocks unreadable with light theme colors | Use theme-aware syntax highlighting (e.g., Prism.js with dark theme) |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Dark mode toggle exists:** Often missing localStorage persistence — verify theme survives page reload
- [ ] **Components are dark:** Often missing proper color variables — verify Bootstrap variables used, not hardcoded colors
- [ ] **Interactive states work:** Often missing hover/focus contrast — verify all states meet WCAG 2.1 standards in both themes
- [ ] **Canvas widgets are themed:** Often missing programmatic background setting — verify visNetwork, plotly have explicit background colors
- [ ] **Custom CSS respects theme:** Often missing `[data-bs-theme]` selectors — verify no light mode colors "stick" in dark mode
- [ ] **Focus indicators visible:** Often missing contrast testing — verify focus rings meet 3:1 ratio in dark mode
- [ ] **Modals and tooltips themed:** Often missing because rendered outside component tree — verify global theme applies correctly
- [ ] **Plot outputs match theme:** Often missing thematic integration — verify ggplot2/base R plots adapt to dark mode
- [ ] **Disabled states visible:** Often missing sufficient contrast — verify disabled inputs don't disappear in dark mode
- [ ] **Logos and images adapt:** Often missing dark mode variants — verify brand assets work on dark backgrounds

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| CSS specificity war with Bootstrap | LOW | Use DevTools to identify conflicting rule → add `[data-bs-theme]` selector → replace hardcoded color with CSS variable |
| Canvas widget ignores dark mode | LOW | Add `background` parameter to widget function → test in both themes → consider `htmlwidgets::onRender()` if dynamic needed |
| Pure black/white causing eye strain | LOW | Replace `#000000` → `#1e1e2e`, `#ffffff` → `#e8e8e8` in CSS variables → propagates through entire theme |
| Hardcoded plot colors | MEDIUM | Install `thematic` package → add `thematic::thematic_shiny()` to app initialization → test all plot outputs |
| Interactive state contrast failures | MEDIUM | Audit all buttons/inputs/links with DevTools → add dark mode hover/focus rules → test with keyboard navigation |
| Scoped theme inheritance broken | MEDIUM | Move `data-bs-theme` to `<html>` → remove component-level theme attributes → test nested layouts |
| Z-index conflicts | MEDIUM | Audit all `position` and `z-index` rules → remove unnecessary positioning → test tooltips in modals |
| No theme persistence | LOW | Ensure `input_dark_mode()` is used (includes localStorage by default) → verify browser localStorage not disabled |
| Entire UI needs dark mode retrofit | HIGH | Phase 1: Core palette + canvas widgets → Phase 2: Interactive states + nested components → Phase 3: Content testing |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Canvas elements ignore CSS | Phase 1: Core Dark Mode Palette | Test visNetwork citation network background in both themes, no white flash |
| CSS specificity wars | Phase 1: Core Dark Mode Palette | DevTools audit shows no hardcoded colors overriding Bootstrap variables |
| Pure black eye strain | Phase 1: Core Dark Mode Palette | All backgrounds use `#1e1e2e` range, no `#000000` in CSS or Bootstrap config |
| Hardcoded R plot colors | Phase 1: Core Dark Mode Palette | If plots exist: `thematic` integrated, plots match theme automatically |
| Scoped theme inheritance | Phase 1: Core Dark Mode Palette | `data-bs-theme` only on `<html>`, no component-level theme attributes |
| Interactive state contrast | Phase 2: Visual Consistency | All buttons/inputs tested with keyboard nav, focus visible in dark mode, WCAG 2.1 compliant |
| Z-index conflicts | Phase 2: Visual Consistency | Tooltip overflow (#79) fixed, modals tested with tooltips, no stacking issues |
| Theme toggle UX | Phase 2: Visual Consistency | `input_dark_mode()` visible in navbar, theme persists across sessions |
| Images/logos don't adapt | Phase 2: Visual Consistency | Favicon and brand assets work on both backgrounds |
| Missing content testing | Phase 3: Polish & Testing | All synthesis outputs, exported slides, BibTeX, HTML tested in both themes |

## Sources

**Official Documentation:**
- [bslib Theming Guide](https://rstudio.github.io/bslib/articles/theming/index.html) — HIGH confidence
- [Bootstrap 5.3 Color Modes](https://getbootstrap.com/docs/5.3/customize/color-modes/) — HIGH confidence
- [Bootstrap 5.3 CSS Variables](https://getbootstrap.com/docs/5.3/customize/css-variables/) — HIGH confidence
- [Bootstrap 5.3 Z-Index](https://getbootstrap.com/docs/5.3/utilities/z-index/) — HIGH confidence
- [Shiny for R 1.8.0: Dark Mode](https://shiny.posit.co/blog/posts/shiny-r-1.8.0/) — HIGH confidence
- [thematic Auto-Theming](https://rstudio.github.io/thematic/articles/auto.html) — HIGH confidence
- [visNetwork Documentation](https://cran.r-project.org/web/packages/visNetwork/visNetwork.pdf) — HIGH confidence

**Accessibility Standards:**
- [WebAIM Contrast Guide](https://webaim.org/articles/contrast/) — HIGH confidence
- [WCAG 2.1 Contrast Minimum](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html) — HIGH confidence
- [WCAG 2.1 Non-text Contrast](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html) — HIGH confidence

**Dark Mode Best Practices:**
- [Color Contrast Accessibility Guide 2025](https://www.allaccessible.org/blog/color-contrast-accessibility-wcag-guide-2025) — MEDIUM confidence
- [Dark Mode Accessibility Guide](https://www.accessibilitychecker.org/blog/dark-mode-accessibility/) — MEDIUM confidence
- [Dark Mode Charts Best Practices 2026](https://www.cleanchart.app/blog/dark-mode-charts) — MEDIUM confidence
- [BrowserStack Dark Mode Testing](https://www.browserstack.com/guide/how-to-test-apps-in-dark-mode) — MEDIUM confidence

**CSS Variables and Cascade:**
- [Dark Mode and CSS Variables](https://betterprogramming.pub/dark-mode-and-css-variables-ed6dc250232c) — MEDIUM confidence
- [CSS Custom Properties Complete Guide](https://devtoolbox.dedyn.io/blog/css-variables-complete-guide) — MEDIUM confidence
- [MDN CSS Custom Properties](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_cascading_variables/Using_CSS_custom_properties) — HIGH confidence

**Project-Specific Issues:**
- `.planning/todos/pending/2026-02-13-fix-citation-network-background-color-blending.md` — Known visNetwork dark mode issue in Serapeum
- `www/custom.css` lines 10-12 — Current dark mode implementation for citation network
- GitHub Issue #79 — Tooltip overflow in citation network
- GitHub Issue #89 — Citation network background color blending

**Community Resources:**
- [Passing CSS Theme to Canvas (Aaron Gustafson)](https://www.aaron-gustafson.com/notebook/passing-your-css-theme-to-canvas/) — LOW confidence (general canvas theming)
- [ggdark Package](https://github.com/nsgrantham/ggdark) — MEDIUM confidence (specific to ggplot2)
- [Bootstrap GitHub Issue #38973](https://github.com/twbs/bootstrap/issues/38973) — MEDIUM confidence (data-bs-theme behavior differences)

---
*Pitfalls research for: Dark Mode Redesign in R/Shiny/bslib Applications*
*Researched: 2026-02-22*
