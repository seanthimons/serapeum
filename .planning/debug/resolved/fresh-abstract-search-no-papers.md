---
status: investigating
trigger: "Investigate issue: fresh-abstract-search-no-papers"
created: 2026-03-11T13:56:22.2438645-04:00
updated: 2026-03-11T14:02:53.9247558-04:00
---

## Current Focus

hypothesis: OpenAlex zero-results are driven by over-constrained long phrase matching; fallback should progressively relax query tokens when count=0.
test: Evaluate token-relaxation variants of the query (remove punctuation tokens and generic terms) to find a deterministic sequence that reaches nonzero counts.
expecting: Relaxed query form should eventually yield nonzero count, enabling guarded retry strategy.
next_action: run OpenAlex count probes on token-relaxed variants and codify fallback sequence

## Symptoms

expected: Initializing a fresh search notebook with query `PFOA method detection reporting limit LC/MC` should create notebook and populate matching papers.
actual: Fresh search produces abstract notebook with no papers.
errors: No explicit error reported; user only sees no papers.
reproduction: Start fresh search/abstract notebook initialization, use query `PFOA method detection reporting limit LC/MC`, observe zero papers.
started: Present as of 2026-03-11; unknown when it started.

## Eliminated

## Evidence

- timestamp: 2026-03-11T13:56:56.4854897-04:00
  checked: repository-wide string search for search notebook initialization terms
  found: fresh search notebook creation handlers exist in `app.R` (discovery/query/topic consumers) and core module logic in `R/mod_search_notebook.R`
  implication: investigation should focus on create-notebook entry handlers plus OpenAlex fetch/filter pipeline

- timestamp: 2026-03-11T13:57:23.2320410-04:00
  checked: `app.R` search notebook event handlers and `R/mod_search_notebook.R` filter pipeline
  found: query-builder and fresh search flows create notebooks and fetch OpenAlex results; notebook display path applies `filter_has_abstract` and defaults it to TRUE when absent
  implication: zero visible papers can be caused by empty API results or all results lacking abstract text

- timestamp: 2026-03-11T13:58:00.1540494-04:00
  checked: `app.R` create-search handler + `R/mod_search_notebook.R` auto-search + `R/api_openalex.R::search_papers`
  found: fresh notebook creation only stores query; module auto-search then calls `search_papers()`, which always adds `has_abstract:true` and (by default) `is_retracted:false`
  implication: creation path can return zero before any local filtering if OpenAlex result set is sparse under those hard filters

- timestamp: 2026-03-11T13:59:53.6168577-04:00
  checked: local runtime execution capability for `search_papers()`
  found: local R execution blocked for this path (`httr2` missing in environment), preventing direct function invocation
  implication: must validate behavior through equivalent direct OpenAlex HTTP requests

- timestamp: 2026-03-11T14:00:37.7917866-04:00
  checked: OpenAlex HTTP counts for exact query with and without default filters
  found: `search=PFOA method detection reporting limit LC/MC` returns count 0 with no filters; adding `has_abstract:true` and `is_retracted:false` remains 0
  implication: root issue is query text interpretation at OpenAlex layer, not local post-fetch filtering

- timestamp: 2026-03-11T14:01:26.5952625-04:00
  checked: OpenAlex count matrix for nearby query variants
  found: exact query and most punctuation variants remain 0, but variant `PFOA LCMS method detection limit` returns count 111
  implication: query tokenization/acronym normalization strongly affects retrieval; fallback broadening is warranted when initial count is zero

- timestamp: 2026-03-11T14:02:15.0922899-04:00
  checked: candidate query broadening transforms (slash spacing, punctuation stripping, dropping generic terms, acronym collapse)
  found: all generic transforms still returned 0 for this query family; no broad transform recovered results
  implication: a specific typo/acronym correction fallback is more plausible than broad generic rewriting

- timestamp: 2026-03-11T14:02:53.9247558-04:00
  checked: `LC/MC` vs `LC/MS` replacements within near-original phrase structures
  found: both remained zero when phrase remained long (`PFOA method detection reporting limit ...`)
  implication: correction of slash acronym alone is insufficient; query must be relaxed/recomposed when zero results occur

## Resolution

root_cause:
fix:
verification:
files_changed: []
