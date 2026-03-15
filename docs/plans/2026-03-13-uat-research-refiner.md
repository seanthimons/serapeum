---
title: "UAT: Research Refiner Module"
date: 2026-03-13
uat_date: 2026-03-15
feature: Research Refiner (Phases 1-5)
commit: 351743a
branch: v13-search-discovery
---

# UAT: Research Refiner Module

## UAT Results Summary (2026-03-15)

| Test | Result | Notes |
|------|--------|-------|
| UAT-1 | PASS | |
| UAT-2 | PASS | Fixed: email lookup missed DB setting |
| UAT-3 | PASS | 52 candidates scored |
| UAT-4 | PASS | Minimal shift with 1 seed — expected |
| UAT-5 | PASS | |
| UAT-6 | PASS | |
| UAT-7 | PASS | |
| UAT-8 | PASS | Intent text has no scoring impact (follow-up) |
| UAT-9 | PASS | Fixed: observer stacking, NULL/NA guard, button classes, rank badges |
| UAT-10 | PASS | Fixed: batch accept now respects prior rejections |
| UAT-11 | PASS | |
| UAT-12 | PASS | |
| UAT-13 | PASS | |
| UAT-14 | SKIPPED | No preprint-heavy notebook available |
| UAT-15 | PASS | |
| UAT-16 | PASS | |
| UAT-17 | SKIPPED | |

**Bugs fixed:** 7 (email lookup, observer stacking, NULL/NA guard, button classes, rank badges, batch curation state, weight normalization)

## Context

The Research Refiner is a new standalone Shiny module that scores, ranks, and triages candidate papers against a user-defined anchor. It uses a Tier 1 metadata-only scoring engine with five components: seed connectivity, bridge score, citation velocity, FWCI, and ubiquity penalty. When any component is unavailable (e.g., no FWCI for preprints, no graph data for bridge scores), its weight is excluded and remaining weights are re-normalized — no fake data is injected.

### Files Under Test

- `R/utils_scoring.R` — Pure scoring functions
- `R/research_refiner.R` — Business logic (candidate fetching, connectivity computation)
- `R/mod_research_refiner.R` — Shiny module UI + server
- `app.R` — Sidebar button, view routing, module wiring
- `R/db.R` — `refiner_runs` and `refiner_results` tables + helpers

### Prerequisites

- At least one search notebook with 20+ papers
- OpenAlex email configured in Settings
- (Optional) A known paper DOI for seed testing, e.g. `10.1038/s41586-021-03819-2`

---

## Tier 1: Core Scoring

### UAT-1: Module loads from sidebar

**Steps:**
1. Start the app
2. Click "Research Refiner" button in the sidebar

**Expected:**
- Refiner view loads with three cards: Define Anchor, Select Candidates, Scoring Mode
- No console errors
- "Score Papers" button visible at bottom

---

### UAT-2: Add seed paper by DOI

**Steps:**
1. In Step 1, ensure anchor type is "Seed Papers"
2. Enter a DOI (e.g., `10.1038/s41586-021-03819-2`) in the seed input
3. Click "Add Seed"

**Expected:**
- Paper resolves from OpenAlex — title, year, and citation count displayed
- Input field clears after successful add
- Notification confirms the add

---

### UAT-3: Score papers from notebook

**Steps:**
1. Add a seed paper (UAT-2)
2. In Step 2, select "From Notebook" and pick a search notebook with 20+ papers
3. Leave mode as "Discovery"
4. Click "Score Papers"

**Expected:**
- Progress indicator appears during scoring
- Results card appears with ranked list
- Each result shows: rank badge, title, authors, year, venue
- Metadata badges visible: citation count, cit/yr, FWCI (where available), seed links (where >0)
- Score badge (e.g., "Score: 0.xxx") on each result
- Results are sorted descending by score
- Notification shows "Scored N candidates"

---

### UAT-4: Mode switching changes rankings

**Steps:**
1. Complete UAT-3 (scored with Discovery mode)
2. Note the top 5 papers and their scores
3. Switch mode to "Emerging"
4. Click "Score Papers" again
5. Note the top 5 papers and their scores

**Expected:**
- Ranking order differs between Discovery and Emerging
- Emerging mode should favor recent papers with high citation velocity
- Discovery mode should favor bridge papers and novel connections

---

## Tier 2: Anchor & Source Variations

### UAT-5: Multiple seed management

**Steps:**
1. Add seed paper A by DOI
2. Add seed paper B by DOI
3. Try adding seed paper A again

**Expected:**
- Both seeds shown in list with remove buttons
- Duplicate add shows warning "This paper is already added as a seed"
- Click remove on seed A — only seed B remains
- Click "Clear All" — list empties

---

### UAT-6: Intent-only anchor

**Steps:**
1. Switch anchor type to "Research Intent"
2. Enter intent text: "How do large language models improve clinical decision support?"
3. Select a notebook source
4. Click "Score Papers"

**Expected:**
- Scoring completes without errors
- Warning notification about seed connectivity being unavailable
- Results ranked by available signals (citation velocity, FWCI, ubiquity)

---

### UAT-7: Fetch from seeds (Path B)

**Steps:**
1. Add 1 seed paper
2. Switch source to "Fetch from Seeds"
3. Click "Score Papers"

**Expected:**
- Progress indicator shows "Fetching papers for seed 1/1"
- Candidates fetched from OpenAlex (citing + cited + related)
- Results displayed and scored
- Candidate count should be >0 (depends on seed paper)

---

### UAT-8: Combined anchor (seeds + intent)

**Steps:**
1. Switch anchor type to "Both"
2. Add a seed paper AND enter intent text
3. Score from notebook

**Expected:**
- No errors — both anchor components accepted
- Scoring proceeds normally

---

## Tier 3: Curation & Export

### UAT-9: Accept/reject individual papers

**Steps:**
1. Score a notebook (UAT-3)
2. Click the check button on paper #1 — should turn green (accepted)
3. Click the check button on paper #1 again — should revert to default (pending)
4. Click the X button on paper #3 — should turn red (rejected)
5. Click the X button on paper #3 again — should revert to pending

**Expected:**
- Toggle behavior: accept/reject toggles between active state and pending
- Visual feedback: accepted = green background, rejected = red background, pending = no color

---

### UAT-10: Batch accept top N

**Steps:**
1. Score a notebook with 30+ papers
2. Click "Accept Top 25"

**Expected:**
- First 25 results show green/accepted state
- Notification: "Accepted top 25 papers"
- Remaining papers unchanged

---

### UAT-11: Reject bottom half

**Steps:**
1. Score a notebook with 20+ papers
2. Click "Reject Bottom Half"

**Expected:**
- Bottom 50% of results show red/rejected state
- Top 50% unchanged
- Notification shows count of rejected papers

---

### UAT-12: Import accepted into existing notebook

**Steps:**
1. Score and accept some papers (UAT-10)
2. In the curation section, select an existing notebook from the dropdown
3. Click "Import Papers"

**Expected:**
- Progress indicator during import
- Notification: "Imported N papers into notebook"
- App navigates to the target notebook
- Imported papers visible in the notebook
- Run import again — no duplicates created

---

### UAT-13: Import into new notebook

**Steps:**
1. Score and accept some papers
2. Select "Create New Notebook" in dropdown
3. Enter name "Refined Results"
4. Click "Import Papers"

**Expected:**
- New notebook created and appears in sidebar
- App navigates to new notebook
- Accepted papers present in the notebook

---

## Tier 4: Edge Cases

### UAT-14: All papers lack FWCI

**Steps:**
1. Score a notebook where most/all papers have NULL FWCI (common for preprint-heavy collections)

**Expected:**
- Warning: "FWCI data unavailable for all papers — excluded from scoring"
- Rankings still differentiated (not all tied)
- Scores based on remaining signals (velocity, connectivity, ubiquity)

---

### UAT-15: No seeds with "seeds" anchor type

**Steps:**
1. Leave anchor type as "Seed Papers"
2. Do NOT add any seeds
3. Click "Score Papers"

**Expected:**
- Validation message: "Please add at least one seed paper"
- No scoring attempted

---

### UAT-16: Empty notebook

**Steps:**
1. Create an empty search notebook
2. Select it as source in the refiner
3. Click "Score Papers"

**Expected:**
- Message: "No candidates found to score"
- No results rendered

---

## Advanced Weights (Optional)

### UAT-17: Advanced slider sync

**Steps:**
1. Check "Show Advanced Weights"
2. Observe slider values match Discovery defaults (w1=0.25, w2=0.30, w3=0.20, w4=0.15, w5=0.30)
3. Switch mode to "Emerging"
4. Observe sliders update to Emerging values (w1=0.10, w2=0.15, w3=0.40, w4=0.25, w5=0.20)

**Expected:**
- Sliders update when mode changes
- Slider labels match component names (Seed Connectivity, Bridge Score, etc.)

---

## Follow-up Items

1. **Advanced weights need tooltips.** Each weight slider should have a tooltip explaining what the component measures and how it affects ranking (e.g., "Seed Connectivity: proportion of seed papers that cite or are cited by this candidate").

2. **Intent text does not affect scoring.** In "Both" and "Research Intent" modes, the intent is saved as metadata but never used in `score_candidate_pool()`. For intent to influence rankings, a semantic similarity component is needed (e.g., embed intent + compare to abstracts). Currently intent-only mode just drops seed connectivity and scores on citation metrics alone — the intent text is ignored. Consider either adding a Tier 2 semantic signal or making the UI clearer that intent is metadata-only for now.

---

## Review Concerns

_Flagged during plan review — to be validated against implementation before UAT execution._

1. **Weight values in UAT-17 don't sum to 1.0.** Discovery defaults sum to 1.20, Emerging to 1.10. Either the listed values are wrong, or the plan should note that raw weights are re-normalized (consistent with the Context section). Verify against `utils_scoring.R`.

2. **UAT-12 conflates import and idempotency.** "Run import again — no duplicates created" tests different logic (dedup check) than the initial import flow. Consider splitting into a separate case if dedup logic is non-trivial.

3. **UAT-7 acceptance criterion is weak.** "Candidate count should be >0 (depends on seed paper)" is untestable if the seed has no connections. Specify a known seed DOI that guarantees results, or define a fallback assertion.

4. **No UAT covers score persistence (DB round-trip).** `refiner_runs` and `refiner_results` tables are listed as files under test, but no case verifies that scores persist across sessions or that re-opening a previous run restores results.

5. **No UAT covers network failure handling.** What happens when OpenAlex is unreachable during DOI resolution (UAT-2) or candidate fetching (UAT-7)? Graceful error vs. crash.

6. **UAT-6 anchor type label should be verified.** "Research Intent" must match the actual UI label in `mod_research_refiner.R`.

7. **UAT-3 "cit/yr" badge** — confirm this metric is computed and rendered by the module (not mentioned in the scoring engine description).

8. **UAT-10 "Accept Top 25"** — if the button label is dynamic based on result count, the test should note the expected label format.
