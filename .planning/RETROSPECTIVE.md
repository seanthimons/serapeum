# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v6.0 — Dark Mode + UI Polish

**Shipped:** 2026-02-25
**Phases:** 3 | **Plans:** 8

### What Was Built
- Catppuccin Latte/Mocha dark mode palette with 11.8:1 WCAG contrast ratios
- Centralized dark CSS in R/theme_catppuccin.R (~244 lines)
- visNetwork dark canvas with rgba borders for viridis node visibility
- Theme-aware Bootstrap classes replacing all hardcoded colors
- bslib::input_dark_mode() replacing custom JS toggle

### What Worked
- Phase 32 validation passed with 0 code changes — clean execution across all 3 phases
- Catppuccin palette provided proven contrast ratios out of the box, avoiding manual WCAG tuning
- Centralized dark CSS approach (single file) made iterative fixes fast and contained
- UAT-driven gap closure (Plans 03-05) caught issues that initial implementation missed

### What Was Inefficient
- Requirements traceability wasn't updated during execution — 12/15 showed "Pending" at completion
- Plans 31-04 and 31-05 were gap closure from UAT findings, suggesting initial plans underestimated dark mode edge cases (value boxes, Sass-compiled colors, notification specificity)
- Phase 31 grew from 2 planned to 5 plans due to iterative UAT findings

### Patterns Established
- UAT → gap closure → re-UAT loop as standard for UI milestones
- CSS specificity debugging pattern: check Sass compilation vs runtime, use !important only for build-time baked values
- bg-body-secondary/tertiary as standard panel/badge backgrounds (auto-adapts to theme)

### Key Lessons
1. Dark mode requires testing every component state (empty, loading, error) — initial plans only covered happy paths
2. Sass-compiled Bootstrap values (e.g., value box text colors) can't be overridden with CSS variables — need !important
3. bslib::input_dark_mode() is superior to custom JS toggles for Shiny dark mode
4. Requirements traceability should be updated during execution, not deferred to milestone completion

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v6.0 | 3 | 8 | UAT-driven gap closure loop for UI milestones |

### Top Lessons (Verified Across Milestones)

1. Validation phases catch nothing when earlier phases are thorough — Phase 32 was clean
2. Centralized CSS/theming prevents scatter and makes iteration fast
