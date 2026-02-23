# Project Research Summary

**Project:** Dark Mode Palette Redesign & UI Polish
**Domain:** R/Shiny/bslib dark mode theming and visual consistency
**Researched:** 2026-02-22
**Confidence:** HIGH

## Executive Summary

Serapeum needs a comprehensive dark mode redesign, moving from a basic toggle with poor contrast to an intentional, accessible dark palette with proper UI consistency. The research reveals that bslib and Bootstrap 5.3+ provide excellent dark mode foundations through CSS custom properties and the `data-bs-theme` attribute system, but successful implementation requires careful attention to contrast ratios (WCAG AA 4.5:1 minimum), desaturated accent colors, dark gray backgrounds (#1e1e2e, not pure black), and component-specific overrides for canvas-based widgets like visNetwork.

The recommended approach is a three-phase implementation: (1) establish a core dark mode palette using Bootstrap CSS variables, handling canvas widgets explicitly; (2) audit and fix visual consistency issues including spacing, typography, interactive states, and the known citation network background problem (#89) and tooltip overflow (#79); (3) comprehensive testing and polish across all modules. The biggest risks are CSS specificity wars where custom rules override Bootstrap's dark mode variables, canvas elements (visNetwork) that don't respond to CSS and need programmatic background colors, and interactive state contrast failures on hover/focus/disabled states that break accessibility.

The existing JavaScript toggle mechanism is sound and requires no changes. The core work involves creating a centralized dark mode palette file (`www/dark-mode-overrides.scss`), refactoring existing custom CSS to use Bootstrap CSS variables instead of hardcoded colors, and explicitly configuring visNetwork graph backgrounds. This is a low-to-medium complexity project with well-established patterns and high-quality official documentation from Posit/RStudio and Bootstrap.

## Key Findings

### Recommended Stack

Bootstrap 5.3.1+ with bslib 0.10.0 provides the foundation for dark mode theming through native CSS custom properties (`--bs-body-bg`, `--bs-body-color`, etc.) and the `data-bs-theme` attribute system. The colorspace package enables WCAG 2.1 contrast validation with the `contrast_ratio()` function. No additional libraries are required—bslib handles all Bootstrap theming needs, and third-party widgets like visNetwork and commonmark will inherit dark mode colors through CSS variables automatically (with exceptions for canvas elements).

**Core technologies:**
- **bslib 0.10.0**: Bootstrap theming framework for Shiny — provides `bs_theme()` for Sass variable customization, supports Bootstrap 5.3+ with native dark mode, allows dynamic theme updates via `bs_add_rules()`
- **Bootstrap 5.3.1+**: UI framework with native color modes — introduced `data-bs-theme` attribute for global mode switching, extensive CSS custom properties for dark mode, semantic color system that adapts automatically
- **colorspace (latest)**: WCAG contrast validation — provides `contrast_ratio()` implementing WCAG 2.1 algorithms, essential for verifying 4.5:1 normal text and 3:1 large text requirements
- **sass (latest)**: Sass compilation for custom theming — dependency of bslib, required for `bs_add_rules()` and Bootstrap Sass mixins

**Critical pattern:** Use Bootstrap CSS variables (`var(--bs-body-bg)`) instead of hardcoded hex values to ensure components automatically adapt to theme changes. Canvas-based widgets (visNetwork) require explicit background color configuration via JavaScript options, not CSS.

### Expected Features

Dark mode for R/Shiny/bslib applications has well-established expectations driven by accessibility standards and platform conventions. Users expect comfortable contrast (not harsh pure black/white), consistent semantic colors, and visual separation through borders (since shadows don't work in dark mode).

**Must have (table stakes):**
- **WCAG AA contrast ratios** (4.5:1 normal text, 3:1 large text) — accessibility baseline, dark mode cannot be inaccessible
- **Dark gray backgrounds** (#1a1a1a to #1e1e2e, not pure black) — prevents eye strain and halation effects
- **Desaturated accent colors** (reduce saturation ~20 points vs light mode) — saturated colors vibrate against dark backgrounds
- **Semantic color consistency** (success/danger/warning/info recognizable) — Bootstrap handles automatically via CSS variables
- **Borders for visual separation** (shadows disappear in dark mode) — use semi-transparent borders like rgba(255,255,255,0.1)
- **Component coverage** (cards, buttons, forms, modals, toasts, badges) — all components must render correctly in dark mode

**Should have (differentiators):**
- **Intentional color palette** (not just inverted) — purpose-built dark palette shows design attention
- **Comfortable contrast** (aim for 7:1 for body copy, not just minimum 4.5:1) — exceeds baseline for better readability
- **Component-specific overrides** (visNetwork canvas, code blocks) — shows polish beyond Bootstrap defaults
- **Smooth theme transitions** (fade between light/dark, 200ms) — professional feel vs instant flip

**Defer (v2+):**
- **Per-session theme persistence** — low friction to toggle each session, can add later
- **Dark mode-specific imagery** — only if logo/branding looks bad, test first
- **Glow effects for interactive elements** — nice-to-have polish, standard focus rings work fine

### Architecture Approach

Serapeum's dark mode architecture leverages existing patterns well. The current JavaScript toggle (manual `data-bs-theme` attribute manipulation with localStorage persistence) is the standard Bootstrap 5.3 approach and requires no changes. The core work involves enhancing the `bs_theme()` definition in `app.R` with a centralized dark mode overrides file, refactoring existing custom CSS to use Bootstrap CSS variables instead of hardcoded colors, and handling canvas widgets (visNetwork) through explicit programmatic configuration rather than CSS.

**Major components:**
1. **Global dark mode palette** (`www/dark-mode-overrides.scss`) — centralized Bootstrap CSS variable redefinitions under `[data-bs-theme='dark']` selectors, injected via `bs_add_rules()`, single source of truth for all dark mode colors
2. **Component-level overrides** (`www/custom.css`, inline styles) — extend existing files to use Bootstrap CSS variables (`var(--bs-body-bg)`) instead of hardcoded hex values, ensures automatic theme adaptation
3. **Canvas widget configuration** (visNetwork in `R/citation_network.R`) — programmatic background color setting via widget options, container background theming via CSS, accepts that canvas content has limited CSS integration
4. **Client-side theme toggle** (existing JavaScript) — no changes needed, already correctly using `data-bs-theme` attribute and localStorage persistence

**Key pattern:** Bootstrap CSS custom properties provide automatic theme consistency. When `data-bs-theme="dark"` is applied to `<html>`, all CSS variables update automatically, cascading through all components that reference them. Components that use hardcoded colors break this cascade and create specificity wars.

### Critical Pitfalls

1. **Canvas elements ignore CSS dark mode styling** — visNetwork canvas elements don't respect `[data-bs-theme="dark"]` CSS selectors because canvas renders via JavaScript drawing APIs, not DOM. Already documented in Serapeum as issue #89 where dark navy background blends with viridis palette. Prevention: Set `background` parameter directly in `visNetwork()` function call, use `htmlwidgets::onRender()` to read current theme, avoid relying on CSS alone for canvas widgets.

2. **CSS specificity wars between custom rules and Bootstrap variables** — custom CSS with hardcoded colors overrides Bootstrap's CSS variables, causing light mode styles to "stick" in dark mode. Warning signs: components remain light when `data-bs-theme="dark"` is applied, DevTools shows Bootstrap variables crossed out. Prevention: Use Bootstrap CSS variables (`var(--bs-body-bg)`) instead of hex values, scope custom overrides with explicit `[data-bs-theme="light"]` and `[data-bs-theme="dark"]` selectors.

3. **Pure black backgrounds cause eye strain and halation** — pure black (#000) with white text creates harsh 21:1 contrast that causes eye fatigue and optical "glow" effects, especially for users with astigmatism. Prevention: Use dark gray backgrounds (#121212, #1a1a1a, #1e1e2e) and slightly off-white text (#e8e8e8, #f0f0f0), aim for 15:1 to 17:1 contrast ratio instead of maximum 21:1.

4. **Contrast ratio failures on interactive states** (hover, focus, disabled) — developers test default state but forget hover/focus, which fail WCAG when Bootstrap's default darkening is applied to already-dark colors. Focus rings disappear, disabled states blend into background. Prevention: Test all interactive states in both themes, use contrasting accent color for focus indicators (3:1 minimum per WCAG 2.1), avoid just darkening already-dark colors on hover.

5. **Scoped theme inheritance breaks nested components** — setting `data-bs-theme` on individual components creates CSS specificity conflicts and inheritance failures. Tooltips/modals/popovers render outside parent in DOM so don't inherit component-level themes. Prevention: Apply `data-bs-theme` only at `<html>` level, avoid component-level theme attributes, let CSS cascade handle inheritance.

## Implications for Roadmap

Based on research, suggested phase structure follows architectural dependencies and risk mitigation:

### Phase 1: Core Dark Mode Palette
**Rationale:** Establishes foundation that all subsequent work depends on. Must define global color system before touching component-specific styles. Addresses highest-risk pitfalls first (CSS specificity, canvas widgets, pure black backgrounds).

**Delivers:**
- Centralized dark mode palette in `www/dark-mode-overrides.scss` with Bootstrap CSS variable overrides
- Integration via `bs_add_rules()` in `app.R`
- WCAG AA validated contrast ratios (4.5:1 minimum)
- Dark gray backgrounds (#1e1e2e range, not pure black)
- Desaturated accent colors (~20% less saturation than light mode)
- visNetwork canvas background fix (addresses issue #89)

**Addresses:**
- Must-have: WCAG AA contrast, dark gray backgrounds, desaturated accents, semantic color consistency
- Differentiator: Intentional color palette (not just inverted)

**Avoids:**
- Pitfall #2: CSS specificity wars (establishes Bootstrap CSS variable pattern from start)
- Pitfall #3: Pure black eye strain (uses dark gray palette)
- Pitfall #1: Canvas elements ignore CSS (fixes visNetwork background explicitly)

**Research flag:** Standard patterns — well-documented bslib/Bootstrap theming, official documentation high quality, skip deep research.

### Phase 2: Visual Consistency Audit
**Rationale:** Once global palette is stable, can systematically refactor component-level styles. Spacing, typography, and interactive state issues are independent of each other and can be tackled methodically. Addresses known issues (#79 tooltip overflow, #89 citation network background).

**Delivers:**
- Refactored `www/custom.css` using Bootstrap CSS variables instead of hardcoded colors
- Refactored inline styles in `app.R` for theme responsiveness
- Fixed spacing adherence to 8pt grid
- Typography consistency (line-height 140-180%, proper hierarchy)
- Interactive state contrast testing (hover, focus, disabled)
- Resolution of known issues: tooltip overflow (#79), citation network background (#89)
- Elevation system using borders and lighter surface colors (no shadows)

**Uses:**
- Bootstrap CSS variables defined in Phase 1
- `bs_add_rules()` for component-specific dark mode overrides
- colorspace `contrast_ratio()` for interactive state validation

**Implements:**
- Component-level override pattern (use CSS vars, scope with `[data-bs-theme]`)
- Progressive enhancement for canvas widgets (style containers, not canvas content)

**Avoids:**
- Pitfall #4: Interactive state contrast failures (explicit testing and validation)
- Pitfall #5: Scoped theme inheritance (maintains `data-bs-theme` at `<html>` only)
- Pitfall #7: Z-index conflicts (fixes tooltip overflow, tests positioning)

**Research flag:** Standard patterns — Bootstrap typography and spacing best practices well-documented, WCAG testing tools available, skip research.

### Phase 3: Comprehensive Testing & Polish
**Rationale:** Final validation after architecture and components are complete. Ensures nothing was missed, catches edge cases, verifies cross-module consistency.

**Delivers:**
- All modules tested in both light and dark modes
- Empty states, error states, loading states verified
- Long text wrapping, overlapping elements edge cases resolved
- Cross-mode consistency checklist completed
- Theme toggle UX verified (localStorage persistence, smooth transitions)
- Documentation of dark mode patterns for future development

**Testing coverage:**
- Navigation (sidebar, navbar, active states)
- Cards (search results, abstract previews, settings sections)
- Forms (inputs, selects, checkboxes, sliders)
- Buttons (primary, secondary, danger, disabled)
- Modals (progress modal, confirmation dialogs)
- Toasts (success, error, info notifications)
- Badges (OA badges, document type, predatory journal warnings)
- visNetwork graphs (citation network, all color palettes)
- Year range slider histogram

**Avoids:**
- "Looks done but isn't" — systematic checklist prevents missing critical pieces
- UX pitfalls — theme persistence, discoverable toggle, proper transitions
- Integration gotchas — visNetwork, third-party widgets tested comprehensively

**Research flag:** No research needed — pure testing and validation phase.

### Phase Ordering Rationale

- **Phase 1 before Phase 2:** Global palette must be defined and stable before refactoring component CSS. Otherwise component changes may need rework when palette changes. Establishes CSS variable pattern that Phase 2 systematically applies.

- **Phase 2 before Phase 3:** Can't test comprehensively until all components are dark mode aware. Testing incomplete components wastes time re-testing after changes.

- **Canvas widget fix in Phase 1:** visNetwork background issue (#89) is architectural (CSS can't style canvas), not polish. Must be addressed when establishing dark mode approach, not deferred to Phase 2.

- **Interactive state testing in Phase 2:** Requires stable palette from Phase 1 to test hover/focus colors. Part of visual consistency, not initial palette definition.

- **Known issues (#79, #89) in Phase 2:** These are component-specific refinements that depend on Phase 1 palette. Tooltip overflow is z-index/positioning issue, citation network background is already being fixed in Phase 1 (canvas background), remainder of #89 (palette selection) is Phase 2 polish.

### Research Flags

Phases with standard patterns (skip `research-phase`):
- **Phase 1 (Core Palette):** Well-documented bslib/Bootstrap 5.3 theming patterns, official documentation from Posit and Bootstrap core team is comprehensive and high quality. colorspace WCAG validation is straightforward.
- **Phase 2 (Visual Consistency):** Bootstrap spacing and typography best practices well-established, CSS specificity and variable usage patterns documented, interactive state testing uses standard WCAG tools.
- **Phase 3 (Testing):** Pure testing and validation, no new patterns to research.

No phases require deeper research. All patterns are well-documented with official sources.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | Official Posit/RStudio and Bootstrap documentation, bslib is mature and well-maintained, colorspace is standard R package for color calculations |
| Features | **HIGH** | WCAG standards are objective, dark mode best practices well-established across industry (Material Design, Apple HIG, Bootstrap guidelines converge), table stakes vs differentiators clear from multiple sources |
| Architecture | **HIGH** | Existing Serapeum implementation already follows correct pattern (JavaScript toggle with `data-bs-theme`), Bootstrap 5.3 architecture documented officially, bslib integration patterns from RStudio source code |
| Pitfalls | **HIGH** | Known issues already documented in Serapeum (#79, #89), Bootstrap CSS specificity and canvas widget limitations well-documented in official docs and community discussions, WCAG contrast failures common and preventable |

**Overall confidence:** HIGH

Research is based primarily on official documentation from Posit/RStudio (bslib), Bootstrap core team, W3C WCAG standards, and confirmed by Serapeum's existing codebase inspection. Dark mode theming patterns are mature and well-established as of Bootstrap 5.3 (released 2023). No experimental or cutting-edge techniques required.

### Gaps to Address

No significant gaps requiring additional research. All key areas have high-quality official documentation and established patterns. During implementation:

- **Color palette specifics** — Exact hex values for primary/secondary/accent colors will require design judgment and iteration with WCAG testing. colorspace package makes validation straightforward, but aesthetic decisions are subjective.

- **visNetwork theme detection** — If dynamic theme switching for graph colors is desired (beyond container background), will need to implement JavaScript message passing between Shiny and htmlwidget. Research shows this is possible but not essential (container theming + neutral graph colors is acceptable).

- **Plots and charts** — If Serapeum generates R plots (ggplot2, base R), will need to integrate thematic package for auto-theming. Research doesn't show existing plots in current codebase, but pattern is well-documented if needed.

These are implementation details, not research gaps. Proceed with confidence.

## Sources

### Primary (HIGH confidence)
- [bslib Theming Guide](https://rstudio.github.io/bslib/articles/theming/index.html) — bs_theme() parameters, Sass variables, best practices
- [bs_theme() Reference](https://rstudio.github.io/bslib/reference/bs_theme.html) — function parameters, Bootstrap version support
- [input_dark_mode() Reference](https://rstudio.github.io/bslib/reference/input_dark_mode.html) — dark mode toggle parameters, server values
- [Bootstrap 5.3 Color Modes](https://getbootstrap.com/docs/5.3/customize/color-modes/) — CSS custom properties, data-bs-theme attribute, semantic colors
- [Bootstrap 5.3 Colors](https://getbootstrap.com/docs/5.3/customize/color/) — color system, Sass variables, theming maps
- [Bootstrap 5.3 CSS Variables](https://getbootstrap.com/docs/5.3/customize/css-variables/) — comprehensive list of available CSS custom properties
- [colorspace contrast_ratio()](https://colorspace.r-forge.r-project.org/reference/contrast_ratio.html) — WCAG validation, parameters, algorithms
- [WCAG 2.1 Contrast Minimum](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html) — accessibility standards
- [WCAG 2.1 Non-text Contrast](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html) — UI component contrast requirements

### Secondary (MEDIUM confidence)
- [Shiny Theming Overview](https://shiny.posit.co/r/articles/build/themes/) — integration patterns
- [bslib 0.10.0 Changelog](https://rstudio.github.io/bslib/news/index.html) — latest version features
- [Bootstrap 5.3.0 Release](https://blog.getbootstrap.com/2023/05/30/bootstrap-5-3-0/) — dark mode announcement
- [Dark Mode UI Best Practices (Atmos)](https://atmos.style/blog/dark-mode-ui-best-practices) — design principles
- [12 Principles of Dark Mode Design (Uxcel)](https://uxcel.com/blog/12-principles-of-dark-mode-design-627) — desaturation, elevation, contrast guidance
- [Dark Mode Common Mistakes (Nielsen Norman Group)](https://www.nngroup.com/articles/dark-mode-users-issues/) — UX pitfalls
- [Color Contrast Accessibility Guide 2025](https://www.allaccessible.org/blog/color-contrast-accessibility-wcag-guide-2025) — WCAG testing best practices
- [visNetwork Introduction](https://cran.r-project.org/web/packages/visNetwork/vignettes/Introduction-to-visNetwork.html) — styling options
- [visNetwork GitHub Issue #151](https://github.com/datastorm-open/visNetwork/issues/151) — background color customization

### Tertiary (LOW confidence, web search)
- Various blog posts on dark mode design patterns — consistent with official sources, used for validation
- CSS custom properties guides — supplementary to official Bootstrap docs

### Project-Specific
- `.planning/todos/pending/2026-02-13-fix-citation-network-background-color-blending.md` — known visNetwork dark mode issue in Serapeum (issue #89)
- `www/custom.css` — current dark mode implementation patterns
- GitHub Issue #79 — tooltip overflow in citation network

---
*Research completed: 2026-02-22*
*Ready for roadmap: yes*
