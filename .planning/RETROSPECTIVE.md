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

## Milestone: v10.0 — Theme Harmonization & AI Synthesis

**Shipped:** 2026-03-06
**Phases:** 6 | **Plans:** 10

### What Was Built
- Connection leak fix + dead code removal with automated regression test
- Catppuccin design system: semantic color policy, 76 icon wrappers, visual swatch sheet
- Citation audit bug fixes: multi-paper import with duplicate tracking, abstract notebook sync
- Sidebar & button theming: custom peach/sky CSS, 206 icon calls migrated, search buttons recolored
- Methodology Extractor preset: section-targeted RAG into GFM tables with DOI citations
- Gap Analysis Report preset: cross-paper synthesis with 5 gap dimensions and contradiction detection

### What Worked
- Design system foundation (Phase 45) before theming (Phase 47) — policy-first approach prevented ad-hoc color decisions
- Section-targeted RAG pattern reuse — Phase 48 established pattern, Phase 49 replicated it with different section filters and output format
- Two-row preset bar (Quick/Deep) — scalable layout for growing preset count
- Contradiction blockquote formatting — user feedback during checkpoint caught buried contradictions, fixed immediately

### What Was Inefficient
- REQUIREMENTS.md traceability not updated during Phase 49 execution — GAPS-01 and GAPS-05 showed "Pending" despite being complete
- Phase 45 missing VERIFICATION.md — phase completed but verifier never ran (caught during milestone audit)
- SUMMARY.md frontmatter missing `one_liner` and `requirements_completed` fields across all plans — extraction tools returned null
- 76 icon wrappers may be over-engineered — only ~30 are actively used, rest are preemptive

### Patterns Established
- Section-targeted RAG with 3-level fallback (section filter → distributed sampling → all chunks)
- `build_context_by_paper()` for grouped context construction
- Dynamic token budget management (starts at 7 chunks/paper, reduces to 2 if > 80k tokens)
- Preset type tagging in `is_synthesis` vector for AI disclaimer display
- Two-row preset bar: Quick (Overview, Study Guide, Outline) / Deep (Conclusions, Lit Review, Methods, Research Gaps, Slides)
- Custom CSS button classes (btn-outline-peach, btn-outline-sky) for sidebar differentiation

### Key Lessons
1. Policy-first design (document colors → validate with swatch → then code) prevents bike-shedding during implementation
2. RAG preset development follows a replicable pattern — backend function + UI button + handler + is_synthesis = ~200 lines per preset
3. Section-targeted retrieval quality varies with paper structure — fallback strategy is essential
4. Contradiction detection works best with blockquote visual separation — inline bold prefix gets lost in narrative text
5. SUMMARY frontmatter fields need consistent population — missing `requirements_completed` breaks milestone audit automation

### Cost Observations
- Model mix: 100% sonnet for executors and verifiers (balanced profile)
- Phase 49 execution: 2 waves, 3 agents (executor + continuation + verifier), ~10 min total
- Pattern reuse from Phase 48→49 reduced research time significantly

---

## Milestone: v20.0 — Shiny Reactivity Cleanup

**Shipped:** 2026-03-29
**Phases:** 4 | **Plans:** 6

### What Was Built
- req()/isolate() guards and input validation across query builder, match_aa_model, section_filter
- Observer destroy-before-create lifecycle for chip handlers, figure action observers
- Cached docs_reactive() eliminating redundant list_documents() DB calls in renderUI
- Session$onSessionEnded cleanup hooks for document notebook and slides modules
- Shared show_error_toast() with modal-then-notify pattern across all 9 preset handlers
- Idempotent SQL migration DDL (IF NOT EXISTS) for fresh installs with regression tests

### What Worked
- Phase ordering by regression risk (additive guards → lifecycle → error handling → infrastructure) — no regressions during incremental changes
- Audit-before-fix approach: GARD-02 audit confirmed no code changes needed, avoiding unnecessary modifications
- Small milestone (4 phases, 6 plans) completed in 3 days with clean scope
- TDD for Phase 64 (39 assertions) caught edge cases (nzchar(NA_character_) returns TRUE, not NA)

### What Was Inefficient
- SUMMARY.md frontmatter missing `one_liner` fields in Phases 64-66 — milestone completion automation couldn't extract accomplishments
- STATE.md progress counters showed 0/4 despite all phases being complete — stale from initial creation
- Phase 67 "Plans: TBD" never updated in ROADMAP.md after plans were created

### Patterns Established
- modal-then-notify: removeModal() → show_error_toast() → is_processing(FALSE) → NULL for all preset error handlers
- Observer lifecycle: destroy-before-create with tryCatch-wrapped destroy() in loops
- Session cleanup: onSessionEnded hook with defensive tryCatch for each observer store

### Key Lessons
1. Additive-only changes (req(), isolate()) are safe first steps — they catch NULLs before structural changes add complexity
2. R's nzchar(NA_character_) returns TRUE, not NA — explicit is.na() check required in guards
3. Fresh-install regression tests are essential — idempotent DDL issues only surface on clean databases
4. Stability milestones complete faster than feature milestones — fewer design decisions, clearer scope

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v6.0 | 3 | 8 | UAT-driven gap closure loop for UI milestones |
| v9.0 | 3 | 3 | Small focused phases (1 plan each) for fast iteration |
| v10.0 | 6 | 10 | Policy-first design system + replicable RAG preset pattern |
| v20.0 | 4 | 6 | Regression-risk-ordered stability phases + additive-first approach |

### Top Lessons (Verified Across Milestones)

1. Validation phases catch nothing when earlier phases are thorough — Phase 32 was clean
2. Centralized CSS/theming prevents scatter and makes iteration fast
3. User screenshot testing catches UI issues that planning and code review miss (v6.0 UAT, v9.0 tooltips)
4. Small milestones (3-4 phases) ship faster with cleaner scope than large ones — confirmed v9.0 (2 days), v20.0 (3 days)
5. Policy-first design (document → validate → code) prevents bike-shedding — confirmed across v6.0 (Catppuccin) and v10.0 (design system)
6. RAG preset development is now a replicable pattern (~200 LOC per preset) — backend + UI + handler + is_synthesis
7. Stability milestones benefit from regression-risk ordering — additive guards before structural changes prevents cascading failures
