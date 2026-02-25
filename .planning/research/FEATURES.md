# Feature Research

**Domain:** Academic Research Assistant — Citation Audit, Bulk Import, and Slide Generation Workflows
**Researched:** 2026-02-25
**Confidence:** MEDIUM

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Bulk DOI import with validation | Standard in all modern reference managers (Zotero, Mendeley, Paperpile) — users expect paste-list-and-import | MEDIUM | Requires DOI validation (10.xxxx/yyyy format), OpenAlex API batch lookup, duplicate detection, error handling for invalid DOIs |
| BibTeX file upload | Universal interchange format for academic tools — expected for library migration and external tool integration | LOW | Parse .bib files, extract DOIs, handle missing fields gracefully, validate structure |
| Select-all with batch operations | Standard interface pattern across research tools — users expect efficient multi-paper workflows | LOW | Checkbox pattern with "Select All" toggle, batch actions (import to notebook, export, remove), clear visual feedback |
| Citation frequency analysis | Core citation audit methodology — identifying papers cited >5 times is standard practice for finding seminal works | MEDIUM | Count references across papers in collection, rank by frequency, filter by threshold (common: 3-5 citations minimum) |
| Backward citation tracking | Fundamental research discovery method used in systematic reviews ("snowballing", "citation chasing") | MEDIUM | Already have citation network BFS — extend to identify papers cited by multiple sources but not in collection |
| Output format validation | Users expect generated content (slides, exports) to render correctly without manual fixing | MEDIUM | Validate LaTeX/Markdown syntax, handle escaping, catch malformed output before presentation |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Citation gap detection with recommendations | Most tools show what you have — showing what you're MISSING (frequently-cited papers not in collection) is unique insight | MEDIUM | Analyze reference lists across papers, identify papers cited ≥N times that aren't in collection, provide one-click "Add to search" action |
| BibTeX for network seeding | Most tools import for citation management — using .bib as seed for citation network exploration is novel workflow | LOW | Parse .bib → extract DOIs → seed existing citation network builder, leverages existing infrastructure |
| Prompt healing for slides | Most tools require manual fixing of malformed LLM output — auto-detection and correction is quality-of-life win | HIGH | Detect LaTeX syntax errors, unmatched delimiters, broken Markdown, trigger self-correction with feedback, validate before display |
| Local-first citation audit | Cloud tools (Litmaps, Connected Papers, Scite) require upload/sync — local analysis on user's collection is privacy win | LOW | Leverage existing DuckDB infrastructure, no external API calls for audit analysis |
| Multi-level backward citation mining | First-level ("what cited these papers?") is common — second-level ("what did THOSE cite?") is advanced discovery | MEDIUM | Extend BFS to track citation depth, identify papers at depth=2+ not in collection, prevent exponential explosion |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Automatic slide healing on every generation | "Why not fix it automatically every time?" | Self-correction without external feedback has low success rates (2024 research: works only with reliable external tools), adds latency to every generation, can fail silently and corrupt valid output | Manual trigger ("Regenerate Slides" button) when user detects issue — keeps generation fast, user controls when to apply expensive correction |
| Recursive citation import (auto-import everything cited) | "Just grab all references automatically" | Exponential explosion (100 papers × 30 refs each = 3000 papers), loses intentionality in research process, contradicts local-first philosophy (massive API load) | Citation gap detection with manual selection — user sees what's missing, decides what to add |
| Cross-collection citation analysis | "Find gaps across all my notebooks" | Contradicts per-notebook isolation architecture, expensive computation on large collections, unclear UX for results spanning multiple contexts | Per-notebook citation audit — maintains architectural boundaries, keeps scope manageable |
| Real-time citation gap updates | "Update gap list as I add papers" | Reactive storm on large collections (recalculate on every paper add), premature optimization (users don't need instant updates during bulk import) | Explicit "Run Citation Audit" button — user controls when to recompute, batches analysis after bulk operations |

## Feature Dependencies

```
[BibTeX file upload]
    └──requires──> [DOI extraction logic]
                       └──requires──> [OpenAlex DOI lookup]

[Citation gap detection]
    └──requires──> [Citation frequency analysis]
                       └──requires──> [Reference list parsing from abstracts]

[Bulk DOI import] ──enhances──> [Citation gap detection] (import missing papers directly)

[BibTeX for network seeding] ──reuses──> [Citation network builder] (existing infrastructure)

[Select-all batch operations] ──enables──> [Bulk DOI import] (UI pattern for triggering import)

[Prompt healing] ──standalone──> [No dependencies on other v7.0 features]

[Multi-level backward citation mining] ──conflicts──> [Local-first philosophy] (requires exponential API calls)
```

### Dependency Notes

- **Citation gap detection requires Citation frequency analysis:** Must count references before identifying gaps — frequency analysis is the foundation.
- **Bulk DOI import requires DOI extraction logic:** BibTeX files don't always have DOI fields — need fallback to title+author matching or skip gracefully.
- **BibTeX for network seeding reuses Citation network builder:** Existing BFS traversal and graph visualization infrastructure — just need new entry point from .bib file.
- **Prompt healing standalone:** Operates on generated output independent of other features — can ship separately.
- **Multi-level backward citation conflicts with Local-first philosophy:** Depth-2 citation mining requires API calls for papers not in collection — violates privacy and can exhaust API quotas. Keep to depth-1 (analyze only what's already collected).

## MVP Definition

### Launch With (v7.0)

Minimum viable product — what's needed to validate the concepts.

- [x] **Citation frequency analysis** — Core functionality for identifying seminal works, foundation for gap detection
- [x] **Citation gap detection** — The key differentiator, shows what's missing vs what exists
- [x] **Bulk DOI import** — Table stakes for efficient workflows, unlocks import of identified gaps
- [x] **Select-all batch operations** — Required UI pattern for bulk actions (import, export, remove)
- [x] **BibTeX file upload** — Table stakes for tool interoperability, enables migration from other tools

### Add After Validation (v7.x)

Features to add once core citation audit workflow is validated.

- [ ] **Prompt healing for slides** — Quality-of-life improvement, ships after validating user actually experiences format issues (may be rare in practice)
- [ ] **BibTeX for network seeding** — Novel workflow, validate citation audit first before adding network integration
- [ ] **Export citation gaps as BibTeX** — Convenience feature, add if users request exporting gap lists for import elsewhere
- [ ] **Citation gap thresholds** — Allow users to configure minimum citation frequency (default: 3) for gap detection

### Future Consideration (v8+)

Features to defer until citation audit is proven valuable.

- [ ] **Multi-level backward citation mining (depth=2)** — Advanced discovery, requires API quota management and careful UX to prevent runaway exploration
- [ ] **Citation context analysis** — Identify HOW papers cite each other (supporting, contrasting, mentioning) like Scite — requires full-text PDF analysis, not just abstracts
- [ ] **Temporal citation trends** — Show when papers were cited (recent vs historical) to distinguish current relevance from historical importance
- [ ] **Journal impact weighting** — Weight citation frequency by source journal quality (papers cited by Nature > predatory journals)

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Citation frequency analysis | HIGH | MEDIUM | P1 |
| Citation gap detection | HIGH | MEDIUM | P1 |
| Bulk DOI import | HIGH | MEDIUM | P1 |
| Select-all batch operations | HIGH | LOW | P1 |
| BibTeX file upload | HIGH | LOW | P1 |
| Prompt healing for slides | MEDIUM | HIGH | P2 |
| BibTeX for network seeding | MEDIUM | LOW | P2 |
| Export citation gaps as BibTeX | LOW | LOW | P2 |
| Citation gap thresholds | LOW | LOW | P3 |
| Multi-level backward citation mining | HIGH | HIGH | P3 |
| Citation context analysis | HIGH | HIGH | P3 |
| Temporal citation trends | MEDIUM | MEDIUM | P3 |
| Journal impact weighting | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for v7.0 launch (core citation audit + bulk import workflows)
- P2: Should have, add in v7.x if validated (prompt healing, network integration)
- P3: Nice to have, defer to v8+ (advanced analysis requiring significant infrastructure)

## Competitor Feature Analysis

| Feature | Litmaps | Connected Papers | Scite | Serapeum v7.0 |
|---------|---------|------------------|-------|---------------|
| Citation network visualization | ✓ Force-directed graph | ✓ Similarity-based layout | ✓ Network view | ✓ BFS-based graph (shipped v2.0) |
| Citation gap detection | ✓ "Find research gaps" | ✗ No gap detection | ✗ No gap detection | ✓ Frequency-based gap analysis |
| Bulk DOI import | ✓ Paste DOI list | ✓ Import seed list | ✓ Import references | ✓ Paste DOI list with validation |
| BibTeX import | ✓ Upload .bib | ✓ Upload .bib | ✓ Upload .bib | ✓ Upload .bib for import/seeding |
| Citation context (supporting/contrasting) | ✗ No context | ✗ No context | ✓ Smart Citations (supports/contrasts/mentions) | ✗ Defer to v8+ (requires full-text) |
| Local-first (no upload) | ✗ Cloud-based | ✗ Cloud-based | ✗ Cloud-based | ✓ All analysis runs locally |
| Select-all batch operations | ✓ Multi-select | ✓ Multi-select | ✓ Multi-select | ✓ Select-all checkbox pattern |
| Slide generation from research | ✗ No slide gen | ✗ No slide gen | ✗ No slide gen | ✓ Quarto slides (shipped v1.0), healing in v7.x |

**Key Insights:**

- **Citation gap detection is a differentiator:** Litmaps has it, but Connected Papers and Scite don't — this is a valuable feature that sets tools apart.
- **Local-first is unique:** All major competitors are cloud-based — Serapeum's local analysis is a privacy/control advantage.
- **Citation context requires full-text:** Scite's Smart Citations are powerful but require analyzing full paper text, not just abstracts — defer to future when PDF pipeline is ready (#44).
- **Slide generation is unique:** No competitor offers presentation generation — Serapeum already has this differentiator (v1.0), prompt healing extends it.

## Implementation Complexity Notes

### Citation Frequency Analysis (MEDIUM)
- Parse `referenced_works` field from OpenAlex abstracts (already stored in DuckDB)
- Extract DOI from each reference URL (`https://openalex.org/W12345` → need to resolve to DOI)
- Count occurrences across all papers in search notebook
- Rank by frequency, filter by threshold (e.g., ≥3 citations)
- **Challenge:** OpenAlex work IDs are not DOIs — need to either (a) make API call to resolve W12345 → DOI, or (b) match by title heuristics
- **Recommendation:** Use OpenAlex API batch endpoint to resolve work IDs in bulk, cache results

### Citation Gap Detection (MEDIUM)
- Run citation frequency analysis on collection
- Cross-reference high-frequency citations with existing papers in collection (match by DOI)
- Generate list of "papers cited N+ times that you don't have"
- Provide OpenAlex metadata (title, authors, year, DOI) for each gap
- Add "Add to Search" button to fetch full abstract from OpenAlex
- **Challenge:** Matching citations to existing collection reliably (DOI is best, title is fuzzy)
- **Recommendation:** Store DOIs in normalized format (`10.xxxx/yyyy`), match on DOI first, fallback to fuzzy title match

### Bulk DOI Import (MEDIUM)
- UI: Textarea for pasting DOI list (one per line or comma-separated)
- Parse input, validate DOI format (`10.` prefix, check-digit if strict)
- Batch lookup via OpenAlex API (`https://api.openalex.org/works/doi:10.xxxx/yyyy`)
- Handle errors: invalid DOIs, API rate limits, not found
- Add valid papers to search notebook, show error report for failures
- **Challenge:** Rate limiting on bulk API calls (OpenAlex: 10 req/sec, polite pool 100K/day)
- **Recommendation:** Batch 50 DOIs per API call using OR filters, add progress modal with cancellation

### Select-All Batch Operations (LOW)
- Add checkbox column to search results table
- "Select All" checkbox in header toggles all visible rows
- Show action bar when ≥1 paper selected: "Import to Document Notebook", "Export", "Remove"
- Track selection state in reactive values
- **Challenge:** Maintain selection state across filters/sorting
- **Recommendation:** Use paper DOI as selection key (stable across operations), clear selection after batch action completes

### BibTeX File Upload (LOW)
- File input accepting `.bib` files
- Parse BibTeX using existing R packages (`bib2df` or `bibtex::read.bib`)
- Extract DOI from `doi` field or URL fields, handle missing DOIs gracefully
- Lookup papers via OpenAlex using DOI
- Import to search notebook or seed citation network (user choice)
- **Challenge:** BibTeX formats vary wildly, many entries lack DOIs
- **Recommendation:** Require DOI field, skip entries without DOI, show report of skipped entries

### Prompt Healing for Slides (HIGH)
- After slide generation, validate output for common issues:
  - Unmatched LaTeX delimiters (`$`, `$$`, `\(`, `\)`)
  - Broken Markdown syntax (unmatched `**`, `_`, `[]()`)
  - Invalid Quarto YAML structure
- If errors detected, show "Regenerate Slides" button
- Trigger self-correction prompt with feedback: "The following errors were detected: [list]. Please fix them."
- Re-generate and validate again (max 2 correction attempts)
- **Challenge:** Self-correction without external validation has low success rates — may produce worse output
- **Recommendation:** Make healing opt-in (manual trigger), provide diff view of changes, let user revert if correction fails

## Sources

### Citation Audit & Gap Detection
- [Litmaps: Find Research Gaps](https://www.litmaps.com) — Dynamic citation mapping tool with gap detection
- [Scite AI: Smart Citations](https://effortlessacademic.com/scite-ai-review-2026-literature-review-tool-for-researchers/) — Citation context analysis (supporting/contrasting/mentioning)
- [Connected Papers](https://www.cypris.ai/insights/11-best-ai-tools-for-scientific-literature-review-in-2026) — Similarity-based citation networks
- [Finding Seminal Works - National University Library](https://resources.nu.edu/researchprocess/seminalworks) — Citation analysis methodology
- [In-text Citation Frequencies for Relevancy](https://pmc.ncbi.nlm.nih.gov/articles/PMC8189020/) — Papers cited >5 times in text = high relevance

### Bulk Import & Reference Management
- [Best Reference Management Software 2026](https://research.com/software/best-reference-management-software) — Industry standards for bulk import
- [Zotero Bulk Import Guide](https://libguides.ucalgary.ca/guides/endnote/EN20references) — BibTeX/RIS batch workflows
- [Paperguide AI Reference Manager](https://paperguide.ai/blog/ai-reference-manager-tools/) — BibTeX, RIS, DOI import patterns
- [Paperpile Batch Import](https://paperguide.ai/blog/ai-reference-manager-tools/) — Drag-and-drop PDF, .ris batch import, direct DOI import

### Backward Citation Tracking
- [Citation Chaser Tool](https://onlinelibrary.wiley.com/doi/full/10.1002/jrsm.1563) — Forward and backward citation chasing for systematic reviews
- [Reference Mining Guide - UW Whitewater](https://libguides.uww.edu/c.php?g=548441&p=3764383) — Multi-level citation tracking methodology
- [Backward Citation Searching - Brown University](https://libguides.brown.edu/searching/citation) — Finding seminal works through reference lists

### Prompt Healing & LLM Self-Correction
- [Self-Correction in LLM Calls: A Review](https://theelderscripts.com/self-correction-in-llm-calls-a-review/) — Feedback-based correction strategies
- [When Can LLMs Actually Correct Their Own Mistakes?](https://direct.mit.edu/tacl/article/doi/10.1162/tacl_a_00713/125177/) — 2024 research: self-correction works only with reliable external feedback
- [Automatically Correcting Large Language Models](https://direct.mit.edu/tacl/article/doi/10.1162/tacl_a_00660/120911/) — Survey of automated correction strategies
- [Prompt Debugging for Reliable AI Performance](https://promptwritersai.com/prompt-debugging-diagnosing-and-fixing-broken-llm-outputs/) — Structured output schema validation

### LLM Markdown/LaTeX Output
- [LLM Markdown Rendering Demo](https://github.com/skovy/llm-markdown) — Rich-text LLM responses with Markdown, Mermaid, LaTeX
- [Dynamic LaTeX Display in Streamlit](https://discuss.streamlit.io/t/dynamic-displaying-for-llm-output-latex-inline-full-line-and-non-latex-sign/82483) — Handling mixed LaTeX and Markdown in LLM output
- [Documentation Tools 2026: Markdown & LaTeX](https://www.glukhov.org/documentation-tools/) — LaTeX to Markdown conversion workflows

---
*Feature research for: Serapeum v7.0 Citation Audit + Bulk Import Workflows*
*Researched: 2026-02-25*
