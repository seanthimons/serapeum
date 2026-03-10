---
phase: 53
slug: toolbar-restructuring
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-10
---

# Phase 53 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat (latest CRAN) |
| **Config file** | tests/testthat.R (existing) |
| **Quick run command** | `Rscript -e "testthat::test_dir('tests/testthat', filter = 'toolbar')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Rscript -e "testthat::test_dir('tests/testthat', filter = 'toolbar')"`
- **After every plan wave:** Run `Rscript -e "testthat::test_dir('tests/testthat')"`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 53-01-01 | 01 | 1 | TOOL-06 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-toolbar-restructuring.R')"` | ❌ W0 | ⬜ pending |
| 53-01-02 | 01 | 1 | TOOL-01 | manual-only | Smoke test: verify all 6 buttons show icon+text | N/A | ⬜ pending |
| 53-01-03 | 01 | 1 | TOOL-02 | manual-only | Smoke test: verify button order in rendered UI | N/A | ⬜ pending |
| 53-01-04 | 01 | 1 | TOOL-03 | manual-only | Smoke test: inspect button classes in DevTools | N/A | ⬜ pending |
| 53-01-05 | 01 | 1 | TOOL-04 | manual-only | Smoke test: verify 3x2 grid with row separation | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-toolbar-restructuring.R` — stubs for TOOL-06 (verify "Papers" span removed from UI code)
- [ ] Smoke test procedure documented — covers TOOL-01 through TOOL-04 (UI rendering verification)
- [x] Framework install: Already exists (testthat in tests/ directory)

*Most requirements are UI/visual and require manual verification; unit test for "Papers" label removal is the only automatable check.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| All buttons show icon+text | TOOL-01 | Visual rendering check | Start app, verify all 6 toolbar buttons display both icon and text label |
| Button workflow order | TOOL-02 | DOM order check | Verify order: Import, Edit Search, Citation Network, Export, Refresh, Load More |
| Lavender/gray color harmony | TOOL-03 | CSS theming visual | Inspect button classes: primary=lavender actions, secondary=gray support |
| 3x2 grid with row separation | TOOL-04 | Layout visual | Verify two rows of 3 buttons with tight vertical gap |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
