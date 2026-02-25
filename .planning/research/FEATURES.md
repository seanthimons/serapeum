# Feature Landscape: Dark Mode Palette Redesign & UI Polish

**Domain:** Dark mode theming and UI consistency for Bootstrap 5 / bslib R/Shiny apps
**Researched:** 2026-02-22

## Table Stakes

Features users expect. Missing = dark mode feels broken or unprofessional.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| WCAG AA contrast ratios (4.5:1 normal, 3:1 large text) | Accessibility baseline — dark mode cannot be inaccessible | Low | bslib handles most of this automatically; verify custom overrides |
| Dark gray (not pure black) backgrounds | Pure black (#000) causes eye strain and halation; industry standard is #121212 or similar | Low | bslib's `bg` parameter in `bs_theme()` |
| Desaturated accent colors | Saturated colors vibrate against dark backgrounds | Low | Reduce saturation ~20 points vs light mode |
| Semantic color consistency | success/danger/warning/info must remain recognizable | Low | Bootstrap semantic variables already adapt; verify custom styles |
| Elevated surfaces use lighter shades | Light mode uses shadows for depth; dark mode uses lighter surface colors | Medium | Bootstrap CSS variables for card/modal backgrounds need testing |
| Readable text contrast | Body text, links, disabled states must all be readable | Low | Test with WCAG contrast checker |
| Borders for visual separation | Shadows disappear in dark mode; subtle borders replace them | Low | Use semi-transparent borders (e.g., rgba(255,255,255,0.1)) |
| Component coverage | All components (cards, buttons, forms, modals, toasts, badges) render correctly | Medium | Bootstrap handles most; test custom components like visNetwork graphs |
| Consistent spacing and typography | Same spatial rhythm and typographic scale as light mode | Low | No changes needed; verify no regressions |
| Icons remain visible | Icon colors must adapt to dark backgrounds | Low | Fontawesome/bsicons should inherit text color; verify custom SVGs |

## Differentiators

Features that set dark mode apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Per-session theme persistence | User's choice remembered within session | Low | Bootstrap `data-bs-theme` + sessionStorage (not bslib built-in) |
| Smooth theme transitions | Fade between light/dark instead of instant flip | Low | CSS transitions on root color variables |
| Component-specific overrides | Specialized dark styles for visNetwork canvas, code blocks, etc. | Medium | visNetwork background can be set via options; syntax highlighting needs care |
| Comfortable contrast (not just compliant) | Go beyond 4.5:1 minimum for primary text (aim for 7:1 for body copy) | Low | bslib defaults likely already good; verify with testing |
| Intentional color palette | Not just inverted colors — purpose-built dark palette | Medium | Requires design decisions for primary/secondary/accent colors |
| Dark mode-specific imagery | Adjust logo contrast or icon brightness for dark backgrounds | Low-Medium | May need alternative assets for branding |
| Glow effects for interactive elements | Subtle glows replace shadows on hover/focus states | Low | CSS box-shadow with light semi-transparent color |
| Reduced motion support | Respect `prefers-reduced-motion` for theme transitions | Low | Good accessibility practice |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Pure color inversion | Results in illegible images, broken icons, harsh contrast | Design purpose-built dark palette with desaturated colors |
| Auto-switching based on time of day | Annoying when user has preference; not what bslib/Bootstrap support | Use system preference (`prefers-color-scheme`) or manual toggle |
| Multiple dark theme variants | Adds complexity without clear value for this app | One well-designed dark theme |
| Dark mode-only features | Creates inconsistency between modes | All features available in both modes |
| Overly bright accent colors | Cause eye strain and vibration on dark backgrounds | Desaturate and slightly darken accent colors |
| Ignoring existing `input_dark_mode()` | bslib provides built-in toggle — reinventing it adds maintenance burden | Use `input_dark_mode()` from bslib if toggle needed |
| Per-component theme overrides in app code | Data attributes scattered everywhere become maintenance nightmare | Global theme via `bs_theme()`, component overrides only for edge cases |
| Aggressive shadows in dark mode | Don't work visually; blend into background or look out of place | Use elevation via lighter surface colors and subtle borders |

## Feature Dependencies

```
WCAG contrast ratios → Readable text contrast
Dark gray backgrounds → Elevated surfaces use lighter shades
Borders for visual separation → Component coverage (borders must work on all components)
Semantic color consistency → Desaturated accent colors (semantic colors need desaturation too)
Intentional color palette → All table stakes features (palette drives everything else)
```

## MVP Recommendation

**Prioritize:**

1. **Intentional color palette** — Define bg, fg, primary, secondary, success, danger, warning, info with proper desaturation and contrast
   - Use bslib's `bs_theme()` with custom colors
   - Test with WCAG contrast checker
   - Document hex values and rationale

2. **Component coverage validation** — Test all existing components in new dark mode
   - Cards, buttons, forms, modals, toasts, badges
   - visNetwork citation graphs (set canvas background)
   - Syntax highlighting in code blocks (if applicable)
   - Year range slider histogram
   - Toast notifications
   - Settings page two-column layout

3. **Borders for visual separation** — Replace shadow-based depth with borders
   - Semi-transparent borders on cards
   - Subtle dividers between sections
   - Elevated modal/dropdown borders

4. **UI consistency audit** — Fix spacing, typography, and visual hierarchy issues in both modes
   - Verify 8pt spatial grid adherence
   - Check line-height consistency (140-180%)
   - Ensure interactive states (hover, focus, disabled) are clear
   - Test tooltip overflow (#79 already in backlog)
   - Validate citation network background color (#89 already in backlog)

**Defer:**

- **Per-session persistence** — User can toggle each session; low friction to defer
- **Smooth transitions** — Polish, not essential; can add after core palette works
- **Dark mode-specific imagery** — Only if logo/branding looks bad; test first
- **Glow effects** — Nice-to-have; standard focus rings work fine

## Implementation Approach

### Phase 1: Define Dark Palette (Low complexity, 2-4 hours)

**Inputs needed:**
- Current light mode theme inspection (read from app.R or theme file)
- Brand color requirements (if any)
- WCAG contrast validation tool

**Outputs:**
```r
dark_theme <- bs_theme(
  version = 5,
  bg = "#1a1a1a",           # Dark gray, not pure black
  fg = "#e0e0e0",           # Light gray text
  primary = "#[desaturated primary]",
  secondary = "#[desaturated secondary]",
  success = "#[desaturated green]",
  danger = "#[desaturated red]",
  warning = "#[desaturated yellow]",
  info = "#[desaturated cyan]",
  base_font = font_google("Inter"),  # or current font
  code_font = font_google("JetBrains Mono")
)
```

**Dependencies:**
- Access to bslib package (already in project)
- WCAG contrast checker (WebAIM, browser DevTools)

**Validation:**
- Test all semantic colors against dark bg (4.5:1 minimum for normal text)
- Verify fg against bg (aim for 7:1+ for body copy)
- Check desaturation (~20 points lower than light mode)

---

### Phase 2: Component Testing & Fixes (Medium complexity, 4-8 hours)

**Components to validate:**
1. **Navigation** — Sidebar, navbar, active states
2. **Cards** — Search results, abstract previews, settings sections
3. **Forms** — Input fields, selects, checkboxes, sliders
4. **Buttons** — Primary, secondary, danger, disabled states
5. **Modals** — Progress modal, confirmation dialogs
6. **Toasts** — Success, error, info notifications
7. **Badges** — OA badges, document type badges, predatory journal warnings
8. **Tables** — Cost history table (if visible in dark mode)
9. **visNetwork graphs** — Citation network canvas background
10. **Year range slider** — Histogram bars, slider track

**Fixes needed:**
- Add `background` parameter to visNetwork options for dark canvas
- Test Bootstrap card borders (may need `border-color` override)
- Verify form input borders visible (Bootstrap should handle this)
- Check disabled button contrast (common dark mode pitfall)

**Edge cases:**
- visNetwork requires explicit background color option (not automatic from bslib)
- Tooltip overflow (#79) may be more visible in dark mode
- Citation network year filter histogram bars need color testing

---

### Phase 3: Borders & Elevation (Low-Medium complexity, 2-4 hours)

**Problem:** Shadows don't work in dark mode (blend into background or look like glows).

**Solution:** Use combination of:
1. Lighter surface colors for elevated components (cards, modals)
2. Subtle borders for visual separation

**Implementation via `bs_add_rules()`:**
```scss
[data-bs-theme="dark"] {
  .card {
    background-color: lighten($bg, 5%);  // Slightly lighter than page bg
    border: 1px solid rgba(255, 255, 255, 0.1);
  }

  .modal-content {
    background-color: lighten($bg, 8%);
    border: 1px solid rgba(255, 255, 255, 0.15);
  }

  hr {
    border-color: rgba(255, 255, 255, 0.1);
  }
}
```

**Test:**
- Cards visually separated from page background
- Modal clearly elevated above page
- Section dividers visible but subtle

---

### Phase 4: UI Consistency Polish (Medium complexity, 4-6 hours)

**Audit areas:**
1. **Spacing** — Verify 8pt grid (or 4pt half-step) adherence
   - Card padding consistent
   - Button spacing uniform
   - Section margins follow system

2. **Typography** — Verify scale and rhythm
   - Line-height 140-180% (test readability)
   - Paragraph spacing 2x font size
   - Heading hierarchy clear
   - Font weights consistent

3. **Interactive states** — All components show clear feedback
   - Hover states visible
   - Focus rings WCAG compliant (3:1 contrast)
   - Disabled states distinguishable but not distracting
   - Active/selected states obvious

4. **Visual hierarchy** — Information architecture clear
   - Primary actions stand out (via color, size, position)
   - Secondary actions recede
   - Tertiary actions available but not distracting

**Known issues to fix:**
- Tooltip overflow (#79) — clip or reposition
- Citation network background (#89) — visNetwork canvas color
- Settings page two-column layout — balance visual weight

**Tools:**
- Browser DevTools inspector for spacing measurements
- WCAG contrast checker for focus states
- Visual comparison screenshots (before/after)

---

## Testing Checklist

**Contrast validation:**
- [ ] Body text vs background (aim for 7:1+)
- [ ] Link text vs background (4.5:1 minimum)
- [ ] Button text vs button background (4.5:1 minimum)
- [ ] Disabled text vs background (no minimum, but should be clearly disabled)
- [ ] Focus indicators vs background (3:1 minimum per WCAG 2.1)
- [ ] Badge text vs badge background (4.5:1 for normal size)
- [ ] Semantic colors (success/danger/warning/info) vs backgrounds

**Component coverage:**
- [ ] Sidebar navigation
- [ ] Search result cards
- [ ] Abstract preview modal
- [ ] Settings page sections
- [ ] Input fields (text, select, checkbox, slider)
- [ ] Primary/secondary/danger buttons
- [ ] Toast notifications (all types)
- [ ] Badges (OA, document type, blocked journal)
- [ ] Cost history table
- [ ] Citation network graph (canvas background)
- [ ] Year range slider + histogram
- [ ] Progress modal with spinner
- [ ] Synthesis output panels

**Cross-mode consistency:**
- [ ] Same spacing in light and dark
- [ ] Same typography scale in light and dark
- [ ] Same interactive behavior in light and dark
- [ ] Same feature availability in light and dark
- [ ] Smooth toggle between modes (no layout shift)

**Edge cases:**
- [ ] Long text wrapping in cards
- [ ] Empty states (no search results, no documents)
- [ ] Error states (API failures, validation errors)
- [ ] Loading states (spinners, progress bars)
- [ ] Overlapping elements (modals over graphs, tooltips over cards)

---

## Complexity Assessment

| Feature Category | Complexity | Rationale |
|------------------|------------|-----------|
| Color palette definition | **Low** | bslib's `bs_theme()` makes this straightforward; main effort is design decisions and contrast testing |
| Bootstrap component adaptation | **Low-Medium** | Bootstrap 5.3 handles most automatically via CSS variables; need to test and verify, not rebuild |
| Custom component overrides | **Medium** | visNetwork, syntax highlighting, and app-specific styles need manual attention |
| Border/elevation system | **Low-Medium** | CSS rules via `bs_add_rules()`; requires design eye for subtlety |
| UI consistency audit | **Medium** | Time-consuming inspection and testing, but no complex code changes |
| Interactive state polish | **Low** | Mostly verification; Bootstrap defaults likely good, minor tweaks possible |
| Testing and validation | **Medium** | Comprehensive but straightforward; WCAG tools exist; manual visual testing required |

**Overall:** Low-Medium complexity. bslib and Bootstrap 5.3 provide excellent dark mode foundations. Main effort is design decisions, testing, and edge case handling (visNetwork, custom components).

---

## Dependencies on Existing Infrastructure

| Dependency | Impact | Notes |
|------------|--------|-------|
| bslib package | **Critical** | All theming goes through `bs_theme()`; version must support Bootstrap 5.3 color modes |
| Bootstrap 5.3+ | **Critical** | Requires `data-bs-theme` attribute support and dark mode CSS variables |
| visNetwork | **Medium** | Citation graphs need explicit background color option; not automatic from bslib |
| Existing custom CSS | **Medium** | Any `style.css` or inline styles may override theme; need audit |
| Shiny modules | **Low** | Modules should inherit theme automatically; verify no hardcoded colors |
| Fontawesome/bsicons | **Low** | Icons should inherit text color; verify no hardcoded fills |
| Toast notification system | **Low** | Should use Bootstrap toast classes; verify color inheritance |
| Year range slider (likely custom) | **Medium** | Histogram bars may need color adjustment for dark background |

**Migration risks:**
- Existing light mode custom styles may break dark mode (need `[data-bs-theme="dark"]` scoping)
- visNetwork graphs will have white canvas by default (needs explicit background setting)
- Any hardcoded hex colors in R code or inline styles will not adapt

---

## Sources

### Official Documentation
- [Bootstrap 5.3 Color Modes](https://getbootstrap.com/docs/5.3/customize/color-modes/)
- [bslib Theming Guide](https://rstudio.github.io/bslib/articles/theming/index.html)
- [bslib Dark Mode Input](https://rstudio.github.io/bslib/reference/input_dark_mode.html)
- [WCAG Contrast Requirements](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)

### Best Practices & Design Principles
- [Dark Mode UI Design Best Practices (Atmos)](https://atmos.style/blog/dark-mode-ui-best-practices)
- [12 Principles of Dark Mode Design (Uxcel)](https://uxcel.com/blog/12-principles-of-dark-mode-design-627)
- [Dark Mode: Common Mistakes and Issues (Nielsen Norman Group)](https://www.nngroup.com/articles/dark-mode-users-issues/)
- [Dark UI Design Principles (Toptal)](https://www.toptal.com/designers/ui/dark-ui-design)

### Implementation Guides
- [Shiny R 1.8.0 Dark Mode Updates](https://shiny.posit.co/blog/posts/shiny-r-1.8.0/)
- [R Shiny bslib Theming (Appsilon)](https://www.appsilon.com/post/r-shiny-bslib)
- [Bootstrap Dark Mode Extended (MDBootstrap)](https://mdbootstrap.com/docs/standard/extended/dark-mode/)

### Accessibility & Testing
- [Dark Mode Accessibility (DubBot)](https://dubbot.com/dubblog/2023/dark-mode-a11y.html)
- [Dark Mode Contrast Checker Tools 2026](https://accesstive.com/blog/best-color-contrast-checker-tools/)
- [WCAG Color Contrast Guide 2025 (AllAccessible)](https://www.allaccessible.org/blog/color-contrast-accessibility-wcag-guide-2025)

### UI Polish & Consistency
- [Design System Checklist (UXPin)](https://www.uxpin.com/studio/blog/launching-design-system-checklist/)
- [Typography Spacing Principles (BuninUX)](https://buninux.com/learn/typography-spacing)
- [UI Consistency Best Practices (UXPin)](https://www.uxpin.com/studio/blog/guide-design-consistency-best-practices-ui-ux-designers/)

### Component-Specific
- [visNetwork Introduction (CRAN)](https://cran.r-project.org/web/packages/visNetwork/vignettes/Introduction-to-visNetwork.html)
- [Bootstrap Semantic Colors](https://getbootstrap.com/docs/5.3/customize/color/)
