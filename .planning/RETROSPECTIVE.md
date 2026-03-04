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

## Milestone: v9.0 — Network Graph Polish

**Shipped:** 2026-03-04
**Phases:** 3 | **Plans:** 3

### What Was Built
- Physics singularity collapse fix with position validation and debounced controls
- Ambient orbital drift for small/single-seed networks (≤20 nodes)
- Dynamic year filter bounds from actual network data + trim-to-influential toggle
- Custom HTML tooltip replacing vis.js default — proper rendering, containment, dark mode styling
- Legacy saved network compatibility: paper_title preservation with HTML sanitization

### What Worked
- Small focused phases (1 plan each) — fast turnaround, clear scope
- User testing during checkpoints caught fundamental approach failures early (tooltip vis.js limitation)
- Iterative fix cycles: 3 rounds of user testing on tooltips caught data pipeline bugs that static analysis would miss
- Pattern documentation in SUMMARY.md preserved key learnings (vis.js solver config, position validation)

### What Was Inefficient
- Phase 43 initial plan assumed vis.js default tooltip could render HTML — wrong assumption required full architectural pivot
- Three iterative fix rounds for tooltips (raw HTML → dual tooltips → data clobbering) — each required user screenshot diagnosis
- Executor agent's MutationObserver approach was fundamentally flawed; needed human feedback to pivot to custom tooltip

### Patterns Established
- Custom vis.js tooltip pattern: tooltip_html column + title=NA + htmlwidgets::onRender
- vis.js physics: always pass full solver config when re-enabling (prevents barnesHut revert)
- Data validation: check positions on actual data columns, not render flags
- Legacy data migration: regex-based HTML sanitization for saved network compatibility

### Key Lessons
1. vis.js default tooltip uses textContent not innerHTML — any HTML tooltip needs custom implementation
2. Saved data round-trips through DB can corrupt fields (tooltip HTML stored in title column → paper_title clobbering)
3. Small milestones (3 phases, 1 plan each) ship fast and maintain focus — v9.0 completed in 2 days
4. User screenshot testing is irreplaceable for UI work — catches issues that code review and planning miss

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v6.0 | 3 | 8 | UAT-driven gap closure loop for UI milestones |
| v9.0 | 3 | 3 | Small focused phases (1 plan each) for fast iteration |

### Top Lessons (Verified Across Milestones)

1. Validation phases catch nothing when earlier phases are thorough — Phase 32 was clean
2. Centralized CSS/theming prevents scatter and makes iteration fast
3. User screenshot testing catches UI issues that planning and code review miss (v6.0 UAT, v9.0 tooltips)
4. Small milestones (3 phases) ship faster with cleaner scope than large ones
