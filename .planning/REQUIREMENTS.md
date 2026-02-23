# Requirements: Serapeum v6.0

**Defined:** 2026-02-22
**Core Value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings

## v6.0 Requirements

Requirements for dark mode redesign and UI polish. Each maps to roadmap phases.

### Dark Mode Palette

- [ ] **DARK-01**: Dark mode uses intentional dark gray backgrounds (#1e1e2e range), not pure black
- [ ] **DARK-02**: All text meets WCAG AA contrast ratios (4.5:1 normal, 3:1 large text) in dark mode
- [ ] **DARK-03**: Accent colors are desaturated ~20% vs light mode to prevent vibration on dark backgrounds
- [ ] **DARK-04**: Semantic colors (success/danger/warning/info) remain recognizable in dark mode
- [ ] **DARK-05**: Dark mode palette is centralized in a single overrides file injected via bs_add_rules()

### Component Styling

- [x] **COMP-01**: All Bootstrap components (cards, buttons, forms, modals, toasts, badges) render correctly in dark mode
- [ ] **COMP-02**: visNetwork citation graph canvas has proper dark background (fixes #89)
- [ ] **COMP-03**: Custom CSS uses Bootstrap CSS variables (var(--bs-*)) instead of hardcoded hex colors
- [x] **COMP-04**: Interactive states (hover, focus, disabled) meet WCAG contrast requirements in dark mode
- [ ] **COMP-05**: Visual separation uses borders/elevation instead of shadows in dark mode

### UI Polish

- [ ] **UIPX-01**: Spacing follows consistent rhythm across all views
- [ ] **UIPX-02**: Typography hierarchy is consistent (line-height, font sizes, weight)
- [x] **UIPX-03**: UI touch ups from #123 are resolved
- [ ] **UIPX-04**: All solutions are Shiny-compliant (no raw DOM manipulation that reactivity can undo)
- [ ] **UIPX-05**: About page layout and styling harmonized with the rest of the app

## Future Requirements

### Dark Mode Enhancements

- **DARK-06**: Per-session theme persistence via localStorage
- **DARK-07**: Smooth CSS transition between light/dark mode (200ms fade)
- **DARK-08**: Dark mode-specific imagery/logo adjustments
- **DARK-09**: Glow effects for interactive elements replacing shadows on hover/focus

## Out of Scope

| Feature | Reason |
|---------|--------|
| Theme auto-switch by time of day | Not what bslib supports; manual toggle sufficient |
| Multiple dark theme variants | Adds complexity without clear value |
| Per-component theme overrides in app code | Maintenance nightmare; global theme via bs_theme() |
| R plot theming (ggplot2/base) | No plots in current app; add if/when plots are introduced |
| Tooltip overflow fix (#79) | Separate bug, not dark-mode-specific; tackle in future milestone |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DARK-01 | Phase 30 | Pending |
| DARK-02 | Phase 30 | Pending |
| DARK-03 | Phase 30 | Pending |
| DARK-04 | Phase 30 | Pending |
| DARK-05 | Phase 30 | Pending |
| COMP-01 | Phase 31 | Complete |
| COMP-02 | Phase 30 | Pending |
| COMP-03 | Phase 31 | Pending |
| COMP-04 | Phase 31 | Complete |
| COMP-05 | Phase 31 | Pending |
| UIPX-01 | Phase 31 | Pending |
| UIPX-02 | Phase 31 | Pending |
| UIPX-03 | Phase 31 | Complete |
| UIPX-04 | Phase 31 | Pending |
| UIPX-05 | Phase 31 | Pending |

**Coverage:**
- v6.0 requirements: 15 total
- Mapped to phases: 15 (100%)
- Unmapped: 0

**Phase breakdown:**
- Phase 30 (Core Dark Mode Palette): 6 requirements (DARK-01 through DARK-05, COMP-02)
- Phase 31 (Component Styling & Visual Consistency): 9 requirements (COMP-01, COMP-03 through COMP-05, UIPX-01 through UIPX-05)
- Phase 32 (Testing & Polish): 0 requirements (validation phase)

---
*Requirements defined: 2026-02-22*
*Last updated: 2026-02-22 — roadmap created, traceability complete*
