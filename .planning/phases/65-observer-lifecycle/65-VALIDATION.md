---
phase: 65
slug: observer-lifecycle
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 65 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 65-01-01 | 01 | 1 | LIFE-01 | manual | Code audit + smoke test | N/A | ⬜ pending |
| 65-01-02 | 01 | 1 | LIFE-02 | manual | Code audit + smoke test | N/A | ⬜ pending |
| 65-01-03 | 01 | 1 | LIFE-03 | manual | Smoke test (verify single DB call) | N/A | ⬜ pending |
| 65-01-04 | 01 | 1 | LIFE-04 | manual | Smoke test + console inspection | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Observer lifecycle changes are Shiny reactive patterns that cannot be unit-tested without a running Shiny session.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Chip handler single-fire | LIFE-01 | Observer accumulation requires live Shiny session with modal interaction | Open slide heal modal N times, click chip, verify updateTextAreaInput fires once |
| Figure action no-duplicate | LIFE-02 | Requires PDF upload + figure extraction + re-extraction cycle | Upload PDF, extract figures, re-extract, click keep/ban — verify single action fires |
| list_documents single call | LIFE-03 | Requires monitoring DB query count during async processing | Add temporary message() logging, trigger doc_refresh, count list_documents calls in console |
| No orphaned observers | LIFE-04 | Requires console inspection after module close | Exercise slides + notebook modules, close/switch, check R console for errors |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
