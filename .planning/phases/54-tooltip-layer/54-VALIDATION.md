---
phase: 54
slug: tooltip-layer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 54 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.2.3 |
| **Config file** | tests/testthat/ (standard testthat structure) |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Shiny smoke test (app starts without error)
- **After every plan wave:** Manual UAT checklist
- **Before `/gsd:verify-work`:** Full UAT pass — all 12 tooltips visible, keyboard accessible, dark mode tested
- **Max feedback latency:** 30 seconds (smoke test)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 54-01-01 | 01 | 1 | TOOL-05 | smoke | Shiny smoke test (app starts) | N/A | ⬜ pending |
| 54-01-02 | 01 | 1 | TOOL-05 | manual | UAT: Tab through buttons, verify tooltip appears on focus | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Tooltip behavior requires full Shiny runtime + browser environment — testthat cannot simulate hover/focus events or Bootstrap tooltip JavaScript.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tooltips appear on hover/focus for all 12 buttons | TOOL-05 | Requires browser JS runtime | Hover + Tab through each button, verify tooltip text |
| Tooltips keyboard accessible | TOOL-05 | Requires browser focus events | Tab to each button, verify tooltip appears on focus |
| Tooltips dismissible via Escape | TOOL-05 | Requires browser keyboard events | Focus button, press Escape, verify tooltip closes |
| Tooltips readable in dark mode | TOOL-05 | Requires CSS theme rendering | Toggle dark mode, hover buttons, verify contrast |
| 300ms delay prevents flicker | TOOL-05 | Requires browser hover timing | Quickly drag cursor across toolbar grid |
| Export dropdown tooltip not clipped | TOOL-05 | Requires browser layout rendering | Hover Export button, verify tooltip fully visible |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
