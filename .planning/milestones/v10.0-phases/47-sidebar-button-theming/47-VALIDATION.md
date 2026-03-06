---
phase: 47
slug: sidebar-button-theming
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-05
---

# Phase 47 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x (R test framework) |
| **Config file** | tests/testthat.R (existing) |
| **Quick run command** | `Rscript -e "testthat::test_file('tests/testthat/test_icon_wrappers.R')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Visual inspection in running app (light + dark mode)
- **After every plan wave:** Manual WCAG contrast check on changed buttons + `Rscript -e "testthat::test_dir('tests/testthat')"`
- **Before `/gsd:verify-work`:** Full visual regression testing of all modules
- **Max feedback latency:** 15 seconds (automated), 60 seconds (manual visual)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 47-01-01 | 01 | 1 | DSGN-04 | unit | `Rscript -e "testthat::test_file('tests/testthat/test_icon_wrappers.R')"` | ❌ W0 | ⬜ pending |
| 47-01-02 | 01 | 1 | THEM-01 | manual-only | Visual inspection light/dark mode | N/A | ⬜ pending |
| 47-01-03 | 01 | 1 | THEM-02 | manual-only | WCAG contrast checker on citation audit button | N/A | ⬜ pending |
| 47-01-04 | 01 | 1 | THEM-03 | manual-only | Visual inspection of Import Papers button | N/A | ⬜ pending |
| 47-01-05 | 01 | 1 | DSGN-03 | manual-only | Code review of btn-* classes across all modules | N/A | ⬜ pending |
| 47-01-06 | 01 | 1 | THEM-04 | manual-only | Visual inspection of notebook button uniformity | N/A | ⬜ pending |
| 47-01-07 | 01 | 1 | THEM-05 | manual-only | Responsive test at multiple screen widths | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tests/testthat/test_icon_wrappers.R` — created by Plan 01 Task 2 during execution (no separate Wave 0 needed)

*Existing infrastructure covers remaining phase requirements. Most validation is manual (visual theming phase).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sidebar colors adapt to light/dark mode | THEM-01 | Visual theming — requires rendered UI | Toggle dark mode switch, verify all sidebar buttons are readable and match Catppuccin palette |
| Citation audit button readable in light mode | THEM-02 | Color contrast requires visual inspection | View sidebar in light mode, verify citation audit button text/border is clearly visible |
| Import papers button has distinct color | THEM-03 | Visual distinctiveness is subjective | Compare Import Papers button color to all other sidebar buttons in both themes |
| All buttons follow semantic color scheme | DSGN-03 | Requires visual comparison to design system | Cross-reference each button's btn-* class against Phase 45 semantic policy |
| Notebook buttons uniform styling | THEM-04 | UI uniformity requires visual check | Open document notebook, verify all preset buttons have consistent style |
| Button bar uses available space | THEM-05 | Responsive layout requires browser testing | Resize browser window, verify buttons reflow without overflow or hiding |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
