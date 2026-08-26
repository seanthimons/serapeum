---
# serapeum-wjsd
title: Bootstrap R 4.6 with P3M and pak
status: in-progress
type: task
priority: high
created_at: 2026-08-26T16:08:34Z
updated_at: 2026-08-26T16:39:16Z
---

Set renv R version to 4.6, initialize boosterpak P3M/pak startup policy, re-snapshot, validate a fresh-device restore path, then fast-forward live branches.

Programmatic verification: setup.R exits 0 through the pak/P3M restore path; the lockfile records R 4.6, P3M, renv, pak, and boosterpak; boosterpak status reports valid configuration; beans check and git diff check pass.
