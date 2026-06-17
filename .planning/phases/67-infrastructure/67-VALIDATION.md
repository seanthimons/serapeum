---
phase: 67
slug: infrastructure
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-27
---

# Phase 67 - Validation Strategy

> Per-phase validation contract for fresh-install migration idempotency.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `"C:\\Program Files\\R\\R-4.5.1\\bin\\Rscript.exe" -e "testthat::test_file('tests/testthat/test-db-migrations.R')"` |
| **Focused startup command** | `"C:\\Program Files\\R\\R-4.5.1\\bin\\Rscript.exe" -e "testthat::test_file('tests/testthat/test-db.R')"` |
| **Full suite command** | `"C:\\Program Files\\R\\R-4.5.1\\bin\\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

---

## Sampling Rate

- After every migration SQL task: run `test-db-migrations.R`
- After startup-path regression work: run `test-db.R`
- After the final wave: run both targeted files, then the full suite if shared startup code changed
- Max feedback latency target: under 30 seconds for targeted DB tests

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 67-01-01 | 01 | 1 | INFR-01 | structural | `Select-String -Pattern "CREATE TABLE IF NOT EXISTS|CREATE INDEX IF NOT EXISTS|ADD COLUMN IF NOT EXISTS" migrations\\005_* , migrations\\006_* , migrations\\008_* , migrations\\012_* , migrations\\018_*` | ✅ | ✅ green |
| 67-01-02 | 01 | 1 | INFR-01 | integration | `"C:\\Program Files\\R\\R-4.5.1\\bin\\Rscript.exe" -e "testthat::test_file('tests/testthat/test-db-migrations.R')"` | ✅ | ✅ green |
| 67-02-01 | 02 | 2 | INFR-01 | integration | `"C:\\Program Files\\R\\R-4.5.1\\bin\\Rscript.exe" -e "testthat::test_file('tests/testthat/test-db.R')"` | ✅ | ✅ green |
| 67-02-02 | 02 | 2 | INFR-01 | integration | `"C:\\Program Files\\R\\R-4.5.1\\bin\\Rscript.exe" -e "testthat::test_file('tests/testthat/test-db-migrations.R'); testthat::test_file('tests/testthat/test-db.R')"` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- Existing DB test infrastructure is sufficient.
- The missing proof is a real startup-path regression that executes `get_db_connection()` twice against the same clean database.
- Structural grep checks are allowed as fast feedback, but they do not replace the startup-path tests.

---

## Manual-Only Verifications

None required for this phase. Phase completion should be provable through automated startup and migration tests.

---

## Validation Sign-Off

- [x] All tasks have automated verification
- [x] Sampling continuity is maintained across both waves
- [x] Wave 0 artifacts exist before execution begins
- [x] No manual-only gate is needed
- [x] `nyquist_compliant: true` set after execution evidence is collected

**Approval:** complete
