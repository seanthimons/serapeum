# Feature Research: Polish & Analysis (v2.1)

**Domain:** Research assistant tools / Academic literature management
**Researched:** 2026-02-13
**Milestone:** v2.1 — UI polish, interactive year filtering, and conclusion synthesis
**Confidence:** HIGH

## Context

This research focuses on **NEW features for v2.1 milestone only:**
- UI icon consistency (synthesis icons, favicon)
- UI space reclamation (sidebar cleanup)
- Citation network progress modal with stop button
- Interactive year range slider-filter (search notebooks + citation networks)
- Conclusion synthesis with future directions (RAG-targeted, both notebook types)

**Already built in v2.0:**
- Citation network visualization with BFS traversal
- Citation export (BibTeX/CSV)
- Synthesis export (Markdown/HTML)
- Export-to-seed workflow
- DOI storage and display
- Cost tracking, model selection, journal quality controls

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Year range filter with histogram (#TBD)** | Universal in academic databases (Google Scholar "Since 2020", PubMed year slider, Web of Science date range). Users expect to filter by publication year. | **Medium** | Google Scholar shows "Since YYYY" preset buttons. PubMed uses slider with histogram showing distribution. **Histogram shows where papers cluster**, prevents dead-end queries (e.g., filtering 2000-2005 when all results are 2015+). |
| **Progress indicator for long operations (#80)** | Standard UX: users need feedback that system is working. Shiny spinners exist, but citation network BFS can take 30+ seconds. | **Low** | Built-in `withProgress()` or `waiter` package. **Must show progress AND allow cancellation** for user control. Without cancel, users force-quit app. |
| **Consistent icon design across features** | Professional tools use coherent icon sets (FontAwesome, Bootstrap Icons, Academicons). Mixing icon styles looks unpolished. | **Low** | Serapeum likely uses `bsicons` (Bootstrap Icons). Synthesis features need clear icons (document-text, download, file-export). Favicon anchors brand recognition. |
| **Cancel button for long operations (#80)** | Gmail search, Excel recalculation, IDE builds all allow cancellation. Users expect to abort if query is wrong or taking too long. | **Medium** | Shiny `ExtendedTask` + `input_task_button` pattern. Task must be async (promises + mirai). Cancel button invokes `task$cancel()`. Without this, users stuck waiting or restart app. |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Histogram preview on year slider** | Shows **where papers cluster** before filtering. Prevents "0 results" dead-ends. PubMed has this, Google Scholar doesn't. **Rare in research tools**. | **Medium** | R `histoslider` package exists: Shiny binding for histogram slider. Pass numeric year vector → renders slider + histogram bars. Updates on data change. **Differentiator**: most tools show slider OR filter count, not distribution preview. |
| **Year filter applies to both lists AND graphs** | Most tools: filters on search results, but graph view separate. Serapeum: **consistent filtering across modalities**. Filter 2020-2025 → both paper list and citation network update. | **Medium** | Shared reactive filter state. Citation network uses `visNetwork` → filter nodes by `publication_year` field. Requires graph re-render on filter change (fast if layout cached). **UX win**: users don't re-apply filters per view. |
| **Conclusion synthesis with future directions (#27)** | Elicit, Semantic Scholar, Consensus aggregate findings across papers. **None offer section-targeted RAG for conclusions/limitations**. Serapeum: extract conclusion sections → synthesize positions → propose research gaps. | **High** | FutureGen paper (2025) shows: 1) Regex extract "conclusion", "limitations", "future work" sections. 2) LLM filter sentences (GPT-4o mini prompt). 3) Synthesize across papers. **Disclaimer critical**: "AI-generated, verify before use." Not authoritative. |
| **Progress modal with live status updates** | Standard modals show spinner. **Improved UX**: show current step ("Fetching citations for Paper 15/30..."). User knows progress, not just "working". | **Low-Medium** | Shiny `withProgress()` supports `incProgress(message = "...")`. Update message in loop. **bslib modal** wraps progress bar. Rarer: tools like ResearchRabbit don't show granular status. |
| **Academicons for academic context** | Standard tools use FontAwesome/Bootstrap. **Academicons** = specialist icons for academia (DOI, ORCID, arXiv, Google Scholar, PubMed logos). Adds polish for academic audience. | **Low** | Academicons CSS + font. `<i class="ai ai-doi"></i>`. Supplement FontAwesome. Example: DOI link with DOI icon, not generic link icon. **Subtle but professional**. |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Auto-refresh graphs on filter change** | Real-time graph updates = re-layout on every slider drag. **Janky UX**: nodes jump around, users lose spatial memory. ResearchRabbit/Connected Papers use static layouts. | Apply year filter **on button click or slider release**, not live drag. Show "Apply Filter" button. Layout once, filter nodes via visibility, don't recompute positions. |
| **Multi-range year sliders** | Allow "2000-2005 OR 2020-2025". **Complexity**: non-contiguous ranges confuse users, complicate UI. No major tool does this. | Single contiguous range only. Users can run separate queries if needed. |
| **Consensus meter visualization** | Consensus app shows "Yes/No/Possibly" breakdown across papers. **Requires**: structured answers per paper, semantic analysis, confidence scoring. **Scope creep**: FutureGen focuses on extraction, not consensus. | Show synthesized text summary, not quantified consensus. Simpler: "Papers highlight X, Y challenges. Proposed directions: A, B, C." User interprets, not algorithm. |
| **Per-paper conclusion extraction UI** | UI to view/edit extracted conclusions per paper. **Rabbit hole**: becomes PDF annotation tool. Zotero/Mendeley territory. | Synthesize across papers directly. If extraction wrong, user verifies in original PDF (external tool). |
| **Automated research gap identification** | "AI finds gaps you missed." **Overpromise**: requires deep domain understanding, semantic reasoning, validation. FutureGen uses human annotation for validation. | Frame as "**Proposed** future directions based on paper conclusions." Heavy disclaimers. User evaluates suggestions, not auto-accept. |
| **Year histogram with drill-down** | Click histogram bar → filter to that year bin. **Complex interaction**: users expect slider to control filter, not clicks on bars. Mixing interaction modes confuses. | Histogram is **preview only**, slider is **control**. Clear separation of concerns. |

## Feature Dependencies

```
Year range slider-filter
  → Requires: Paper data with publication_year (EXISTS in OpenAlex)
  → Requires: histoslider R package (EXTERNAL, mature)
  → Requires: Reactive filter state shared between search + graph (NEW)
  → Enhances: Search notebook (filter list)
  → Enhances: Citation network (filter graph nodes)

Progress modal with cancel
  → Requires: ExtendedTask (Shiny 1.8.1+, EXISTS)
  → Requires: input_task_button or custom modal (bslib, EXISTS)
  → Requires: Async operation with mirai or future (NEW)
  → Requires: Cancellation logic in task (NEW)
  → Applies to: Citation network BFS (long-running)

Conclusion synthesis
  → Requires: PDF text extraction (pdftools, EXISTS)
  → Requires: Section identification (regex patterns, NEW)
  → Requires: LLM filtering (OpenRouter, EXISTS)
  → Requires: Multi-document synthesis (LLM, EXISTS in chat)
  → Requires: Output formatting (markdown, EXISTS)
  → Dependencies: Document notebook (RAG), Search notebook (multi-paper selection)

Icon consistency
  → Requires: Icon inventory (audit current icons, NEW)
  → Requires: Academicons CSS/font (EXTERNAL, easy add)
  → Requires: Favicon design/generation (NEW)
  → No dependencies, pure visual polish

UI space reclamation
  → Requires: Sidebar audit (identify unused/redundant elements, NEW)
  → Requires: Layout refactor (collapsible sections, accordion, NEW)
  → No dependencies, pure layout changes
```

### Dependency Notes

- **Year filter requires histogram preview:** Slider without histogram = no visibility into data distribution. Users guess ranges. Histogram shows clusters → informed decisions.
- **Progress modal requires async + cancel:** Without async, Shiny blocks UI. Without cancel, users trapped. Both required for good UX.
- **Conclusion synthesis requires section extraction:** Can't synthesize conclusions without extracting them first. Regex + LLM filtering is staged approach (FutureGen pattern).

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority | Rationale |
|---------|------------|---------------------|----------|-----------|
| Progress modal with cancel (#80) | HIGH | MEDIUM | **P1** | Users currently stuck during 30s+ BFS. High frustration, medium effort. |
| Year slider-filter (lists) | HIGH | MEDIUM | **P1** | Table stakes. Users expect year filtering. Medium effort (histoslider library exists). |
| Icon consistency + favicon | MEDIUM | LOW | **P1** | Low-hanging fruit. Professional polish. 2-4 hours total. |
| UI sidebar cleanup | MEDIUM | LOW | **P1** | Improves usability. Collapsible cards, better spacing. Low effort. |
| Year filter (graphs) | MEDIUM | MEDIUM | **P2** | Extends year filter to graphs. Useful but not critical (can filter list first). Requires graph re-render logic. |
| Conclusion synthesis | MEDIUM | HIGH | **P2** | Differentiator but complex. Section extraction brittle. LLM filtering = cost. Heavy disclaimers needed. Defer if time-constrained. |

**Priority key:**
- **P1: Must have** — Core UX improvements, table stakes filtering, quick wins
- **P2: Should have** — Differentiators, add when P1 complete
- **P3: Nice to have** — Future consideration (none in v2.1)

## Implementation Approach

### Year Range Slider-Filter (Medium Complexity)

**Why Medium:**
- `histoslider` library handles slider + histogram (reduces complexity)
- Must wire to reactive filter state (moderate Shiny reactivity)
- Must apply to both search results (easy: filter data frame) and citation network (moderate: filter visNetwork nodes)
- Histogram bins = how to group years? (1-year bins, 5-year bins?)

**Recommended approach:**
1. **Phase 1: Search notebook slider** (4-6 hours)
   - Install `histoslider` package
   - Extract publication years from search results (numeric vector)
   - Render `input_histoslider(years, start = min, end = max)`
   - Wire to reactive filter: `filtered_papers <- reactive({ papers[year >= input$year_slider[1] & year <= input$year_slider[2], ] })`
   - Test with realistic data (e.g., 200 papers spanning 1995-2025)

2. **Phase 2: Citation network filter** (3-4 hours)
   - Citation network stored with `publication_year` field
   - Add year slider to network UI (same `histoslider` component)
   - Filter nodes: `visNetworkProxy() %>% visSelectNodes(id = nodes_in_range$id)`
   - OR: Re-render graph with filtered nodes (simpler, performance ok if <100 nodes)
   - Test: filter 2020-2025 → only nodes in range visible, edges update

**Pitfalls:**
- **Histogram bin selection:** Too many bins (1-year) = sparse, hard to read. Too few (10-year) = loses granularity. **Recommendation:** Auto-bin based on data range (e.g., `breaks = "FD"` in `hist()`).
- **No data in range:** User filters 1990-1995, but all papers are 2015+. **Mitigation:** Show "0 results" message, histogram shows actual distribution (user sees mistake).
- **Graph filter performance:** If 500+ nodes, filtering = slow. **Mitigation:** Warn if graph >200 nodes, suggest narrowing initial search.

### Progress Modal with Cancel (Medium Complexity)

**Why Medium:**
- Shiny `ExtendedTask` + `input_task_button` exist (reduces complexity)
- Must convert BFS loop to async operation (mirai package)
- Must handle cancellation (check `task$status()` in loop, abort if cancelled)
- Must update progress message in loop (`incProgress(message = "...")`)

**Recommended approach:**
1. **Use bslib `input_task_button`** (built-in progress state)
   - `input_task_button("generate_network", "Generate Citation Network")`
   - Auto-disables during task, shows spinner + "Processing..." message
   - Auto-re-enables on completion

2. **Wire to `ExtendedTask`** (async operation)
   ```r
   network_task <- ExtendedTask$new(function(seed_doi, depth) {
     # BFS loop here, wrapped in mirai::mirai() or future::future()
   })

   observeEvent(input$generate_network, {
     network_task$invoke(seed_doi = selected_doi, depth = 1)
   })
   ```

3. **Add cancel button** (separate from task button)
   - `actionButton("cancel_network", "Stop")`
   - `observeEvent(input$cancel_network, { network_task$cancel() })`
   - In BFS loop: `if (!task$running()) { break }` (abort on cancel)

4. **Progress updates** (show current step)
   - Use `withProgress()` inside async task
   - `incProgress(1/total, message = sprintf("Fetching citations for %s (%d/%d)", paper_id, i, total))`
   - Updates modal message as BFS proceeds

**Pitfalls:**
- **Async dependencies:** `mirai` or `future` package required. **Recommendation:** `mirai` (newer, simpler API, recommended by Posit).
- **Cancel doesn't abort API calls:** If API request in-flight, cancel won't stop it (network I/O). **Mitigation:** Check cancel status between API calls, not mid-call.
- **Progress without total:** BFS depth-first = don't know total nodes upfront. **Mitigation:** Show "Fetched X papers..." without denominator, or estimate based on depth (depth=1 → ~50 papers).

### Conclusion Synthesis (High Complexity)

**Why High:**
- Section extraction brittle (PDF structure varies by journal/author)
- Regex patterns fail on multi-column layouts, tables, figures
- LLM filtering = API cost (GPT-4o mini per paper)
- Synthesis quality = variable (depends on extraction accuracy)
- User expectations = manage carefully (disclaimers, verify warnings)

**Recommended approach (staged implementation):**

1. **Phase 1: Section extraction** (6-8 hours)
   - Use `pdftools::pdf_text()` to extract full text (EXISTS in Serapeum)
   - Regex patterns for section headers (case-insensitive):
     - `(?i)(conclusions?|limitations?|future work|future research|future directions)`
   - Extract text from match to next section header or end
   - FutureGen pattern: "Papers often do not have exclusive future work sections (combined with conclusions/limitations)"
   - **Store extracted sections** (don't re-extract per synthesis request)

2. **Phase 2: LLM filtering** (4-6 hours)
   - Send extracted sections to GPT-4o mini (cheap: $0.15/1M input tokens)
   - Prompt: "Extract sentences related to future research directions, study limitations, and proposed next steps. Return only relevant sentences, nothing else."
   - **Validation:** FutureGen shows LLM filtering improved ROUGE-1 from 17.50 to 24.59 (+7.09 points)
   - **Cost estimate:** 50 papers × 500 words/section × $0.15/1M tokens = $0.00375 (~0.4 cents)

3. **Phase 3: Multi-document synthesis** (6-8 hours)
   - Aggregate filtered sentences across papers
   - Send to LLM (GPT-4o or Claude) for synthesis
   - Prompt template:
     ```
     You are a research synthesis assistant. Below are conclusion/limitation/future work sections from {N} academic papers.

     Synthesize these into:
     1. Common themes across papers
     2. Key limitations identified
     3. Proposed future research directions

     Format as markdown. Be concise. Cite papers inline.

     [Extracted sections here]
     ```
   - **Output:** Markdown report (same format as chat export)

4. **Phase 4: UI integration** (4-6 hours)
   - Add "Synthesize Conclusions" button to document notebook (RAG chat area)
   - Add to search notebook (multi-paper selection)
   - Modal: "Synthesizing conclusions from {N} papers... this may take 1-2 minutes."
   - Display synthesis in expandable card or modal
   - **Heavy disclaimers:**
     - "AI-generated synthesis. Verify with original papers before citing."
     - "Extraction may miss content in tables, figures, or multi-column layouts."
     - "Proposed directions are speculative, not authoritative."
   - Export button → save as Markdown

**Pitfalls (from FutureGen paper):**
- **Extraction accuracy:** "Papers often do not have exclusive future work sections" → combined with conclusions. **Mitigation:** Extract broadly (conclusions + limitations + future work), let LLM filter.
- **Section headers vary:** "Future Work" vs "Future Directions" vs "Recommendations" vs implicit. **Mitigation:** Broad regex, accept false positives (LLM filters).
- **Multi-column PDFs:** `pdftools` extracts columns sequentially → garbled text. **Mitigation:** Document limitation, suggest users verify.
- **Cost per synthesis:** 50 papers × (extraction + filtering + synthesis) = ~$0.50-$1.00 per run. **Mitigation:** Confirm before running ("Estimated cost: $0.75. Continue?").
- **Quality variance:** Synthesis quality depends on extraction quality. **Mitigation:** Show extracted sections to user (preview before synthesis).

### Icon Consistency + Favicon (Low Complexity)

**Why Low:**
- Icon inventory = audit current UI (2 hours)
- Replace mismatched icons (1 hour)
- Add Academicons (30 minutes: CDN link in HTML head)
- Favicon generation (1 hour: design + multi-size export)

**Recommended approach:**

1. **Icon audit** (2 hours)
   - List all icons in UI (search for `bsicons::`, `icon()`, `<i class=`)
   - Current icons likely: `bsicons::bs_icon()` (Bootstrap Icons)
   - Check for mismatches (e.g., FontAwesome icon where bsicons expected)
   - Document icon usage: which features use which icons

2. **Add Academicons** (30 minutes)
   - Add CDN link to `ui.R` or main HTML:
     ```html
     <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/jpswalsh/academicons@1/css/academicons.min.css">
     ```
   - Use for academic-specific icons:
     - DOI links: `<i class="ai ai-doi"></i>`
     - OpenAlex: `<i class="ai ai-open-access"></i>` (for OA badge)
     - Export: `<i class="ai ai-zotero"></i>` (BibTeX export implies Zotero)
   - **Don't overuse:** Only where academically appropriate (DOI, citations, exports)

3. **Favicon design** (1 hour)
   - Simple, recognizable at 16×16px (browser tab size)
   - Academic theme: book, scroll, network graph, magnifying glass
   - **Recommendation:** Stylized "S" (Serapeum) + book/network motif
   - Generate multi-size: 16×16, 32×32, 48×48, 180×180 (iOS), 192×192 (Android)
   - Use [RealFaviconGenerator](https://realfavicongenerator.net/) (generates all sizes + HTML)
   - SVG favicon for future-proofing (smaller file size, scales infinitely)

4. **Consistency pass** (1 hour)
   - Standardize icon size (e.g., all buttons use 18px icons)
   - Standardize icon position (icon-left for primary actions, icon-right for external links)
   - Ensure color contrast (icons visible in light/dark mode)

**Pitfalls:**
- **Icon overload:** Too many icons = cluttered UI. **Guideline:** Icons for actions (buttons), not labels (text).
- **Academicons size mismatch:** Academicons designed to match FontAwesome 5 metrics. If using Bootstrap Icons, may need CSS adjustment. **Test:** Render side-by-side, check alignment.
- **Favicon cache:** Browsers cache favicons aggressively. **Mitigation:** Append version query (`favicon.ico?v=2`) or clear browser cache during testing.

### UI Sidebar Cleanup (Low Complexity)

**Why Low:**
- Visual/layout changes only (no logic changes)
- Identify unused elements (1 hour)
- Collapse/accordion patterns (bslib `accordion()`, EXISTS)
- Spacing adjustments (CSS tweaks)

**Recommended approach:**

1. **Audit sidebar** (1 hour)
   - List all sidebar elements (filters, controls, info cards)
   - Identify rarely-used elements (e.g., advanced filters, help text)
   - Measure vertical space usage (how much scrolling required?)

2. **Collapse infrequently-used sections** (2 hours)
   - Use `bslib::accordion()` for collapsible sections
   - Example: "Advanced Filters" collapsed by default, expand on click
   - Example: "Journal Quality Controls" collapsed (already collapsible in v1.2?)
   - Save state in `reactiveValues()` (user preference persists during session)

3. **Tighten spacing** (1 hour)
   - Reduce padding between cards (CSS: `margin-bottom: 0.5rem` instead of `1rem`)
   - Smaller font for secondary text (labels, help text)
   - Remove redundant labels (e.g., "Filter by Year" label if slider obvious)

4. **Reorganize priority** (1 hour)
   - Most-used controls at top (year filter, sort)
   - Least-used at bottom (advanced filters, help)
   - Consider tabs for distinct filter groups (basic/advanced)

**Pitfalls:**
- **Over-collapsing:** If everything collapsed, users don't discover features. **Guideline:** 1-2 primary sections expanded, rest collapsed.
- **Lost state on collapse:** If user sets filter, collapses section, expands again → does filter persist? **Mitigation:** Filters are reactive values, persist regardless of UI visibility.

## Expected Behavior from Competitive Research

### Year Range Filter with Histogram

**Google Scholar:**
- Preset buttons: "Since 2020", "Since 2015", "Custom range..."
- Custom range: two text inputs (start year, end year), no slider
- **No histogram preview** (users guess distribution)

**PubMed:**
- Year slider with histogram bars showing publication count per year
- Drag handles to adjust range
- Histogram updates on search (shows distribution of current results)
- **Best-in-class UX** (users see clusters before filtering)

**Web of Science:**
- Date range filter: two dropdowns (start year, end year)
- No histogram, no slider
- Shows result count after applying filter

**Local Citation Network:**
- Year filter as toggle checkbox ("Filter by year?")
- Text inputs for range (no slider)
- No histogram

**Consensus:**
- "Published since" filter (dropdown: last year, last 5 years, all time, custom)
- Custom = text input (single year or range)
- No histogram

**Expected for Serapeum:**
- **Slider + histogram** (PubMed pattern, best UX)
- Histogram shows distribution of current results (updates on search)
- Drag handles to adjust range (no text inputs needed, but optional)
- Live preview of filtered count ("Showing 45 of 200 papers")

### Progress Modal with Cancellation

**Gmail search:**
- Spinner with "Searching..." message
- Cancel button (stops search, returns to inbox)
- Progress percentage if known ("40% complete")

**Excel recalculation:**
- Modal: "Calculating... (ESC to cancel)"
- Shows cell reference being calculated
- ESC key aborts

**VSCode / IntelliJ builds:**
- Progress bar with status message ("Compiling 150/300 files...")
- Cancel button (aborts build)
- Output log visible (what's being processed)

**ResearchRabbit / Connected Papers:**
- Spinner with generic "Loading..." message
- **No cancel button** (users can't abort)
- **No progress updates** (no "Fetching paper 15/50...")

**Expected for Serapeum:**
- Modal with progress bar ("Fetching citations: 23/50 papers...")
- Cancel button ("Stop")
- Status message updates per step (not static "Loading...")
- **Differentiator:** granular progress (most tools don't show per-paper status)

### Conclusion Synthesis

**Elicit:**
- "Summary of findings" across papers
- TL;DR per paper, then aggregated themes
- Cites papers inline (clickable)
- **Does not target conclusion sections** (full paper summaries)

**Semantic Scholar:**
- "TL;DR" per paper (single sentence summary)
- **No multi-paper synthesis** (aggregation left to user)

**Consensus:**
- "Consensus Meter" (Yes/No/Possibly breakdown)
- "Synthesis" tab (aggregates findings across papers)
- Cites papers inline
- **Does not extract conclusion sections** (analyzes abstracts/full text)

**FutureGen (research paper, 2025):**
- Extracts conclusion/limitations/future work sections
- LLM filters sentences (GPT-4o mini)
- Generates future research directions
- **Validates extraction with human annotators**
- ROUGE-1 score: 24.59 (LLM-filtered) vs 17.50 (raw extraction)

**Expected for Serapeum:**
- **Section-targeted synthesis** (conclusions/limitations/future work only)
- Aggregates across papers (not per-paper)
- Output: markdown report (themes, limitations, proposed directions)
- **Heavy disclaimers** (AI-generated, verify before use)
- **Differentiator:** No major tool offers section-targeted conclusion synthesis

### Icon Design

**Zotero:**
- Custom icon set (book, document, folder, tag)
- Consistent style (flat, monochrome, 16×16px)
- Favicon: red "Z" on white background

**Mendeley:**
- Custom icon set (paper, folder, group, web)
- Consistent style (outlined, teal accent color)
- Favicon: green "M" in circle

**Semantic Scholar:**
- Mix of FontAwesome + custom icons
- Academic-specific: citation count (quote-left), open access (unlock)
- Favicon: purple "S" + book motif

**Connected Papers:**
- Custom icon set (graph, node, edge, filter)
- Consistent style (rounded, purple theme)
- Favicon: purple network graph (3 connected nodes)

**Expected for Serapeum:**
- **Bootstrap Icons** (already used in bslib apps, consistent)
- **Academicons** for academic-specific (DOI, OA, citations)
- Favicon: book/network/search motif (recognizable at 16×16px)
- **Consistent sizing/spacing** across all icons

## Competitor Feature Comparison

| Feature | Google Scholar | PubMed | Consensus | Connected Papers | Serapeum v2.1 |
|---------|---------------|---------|-----------|------------------|---------------|
| **Year filter with histogram** | Preset buttons, no histogram | **Slider + histogram** | Dropdown, no histogram | No year filter | **Slider + histogram** |
| **Progress modal with cancel** | N/A (instant search) | N/A | Spinner, no cancel | Spinner, no cancel | **Progress + cancel** |
| **Conclusion synthesis** | No | No | Full-paper synthesis | No | **Section-targeted synthesis** |
| **Icon consistency** | Basic, Google style | Standard, minimal | Mix of FA + custom | Custom set | **bsicons + Academicons** |
| **Year filter on graphs** | No graph view | No graph view | No graph view | No year filter | **Unified filter (list + graph)** |

**Key takeaways:**
- **PubMed year slider + histogram = gold standard** (copy this UX)
- **Progress with cancel = rare** in research tools (UX win for Serapeum)
- **Section-targeted conclusion synthesis = novel** (no major tool does this)
- **Unified year filter across views = differentiator** (most tools silo filters per view)

## Open Questions

### Year Range Slider-Filter
- **Q:** Histogram bin size? 1-year bins (precise but sparse) vs 5-year bins (readable but coarse)?
  - **Recommendation:** Auto-bin based on data range. <20 years span → 1-year bins. 20-50 years → 2-year bins. >50 years → 5-year bins.
- **Q:** Apply filter on slider drag (live) or on release/button click?
  - **Recommendation:** On release (avoids jank during drag). Optional: "Apply Filter" button for explicit control.
- **Q:** Show filtered count before applying? ("This filter will show 45 of 200 papers")
  - **Recommendation:** Yes, live preview. Use `observeEvent(input$year_slider, ignoreNULL = FALSE)` to update count reactively.

### Progress Modal with Cancel
- **Q:** Show progress as percentage or count? ("40%" vs "23/50 papers")
  - **Recommendation:** Count (more informative). "Fetched 23 of ~50 papers..." (BFS = estimate total).
- **Q:** Cancel button position? Inside modal (next to progress) or separate button (sidebar)?
  - **Recommendation:** Inside modal, bottom-right. "Cancel" button (not "X" close button).
- **Q:** What happens to partial results if cancelled? Discard or show?
  - **Recommendation:** Show partial results (user may find useful). Warning: "Incomplete network (cancelled)."

### Conclusion Synthesis
- **Q:** Run synthesis automatically or user-triggered?
  - **Recommendation:** User-triggered (button: "Synthesize Conclusions"). Avoid surprise API costs.
- **Q:** Synthesis from all papers or selected papers?
  - **Recommendation:** Both. Search notebook → multi-select. Document notebook → all uploaded PDFs. Default = all, allow select.
- **Q:** Show extracted sections before synthesis? (User can verify extraction quality)
  - **Recommendation:** Optional preview. Modal: "Review Extracted Sections" (expandable per paper). "Continue to Synthesis" button.
- **Q:** How to handle extraction failures? (PDF garbled, no conclusion section found)
  - **Recommendation:** Log warnings, show to user. "3 of 10 papers had no extractable conclusions." Synthesize from successful extractions only.

### Icon Consistency
- **Q:** Replace all icons with Academicons, or mix bsicons + Academicons?
  - **Recommendation:** Mix. bsicons for general UI (buttons, menus), Academicons for academic-specific (DOI, citations, exports).
- **Q:** Favicon: simple logo or detailed graphic?
  - **Recommendation:** Simple (recognizable at 16×16px). Test at small size before finalizing.

## Sources

**Year Range Filtering:**
- [PubMed Interact: JavaScript slider bars for search filters](https://pmc.ncbi.nlm.nih.gov/articles/PMC1636030/)
- [Google Scholar: Advanced Search](https://libguides.utdallas.edu/h-index-using-web-of-science-scopus-google-scholar/introduction/google-scholar)
- [Filter UX Design Patterns & Best Practices](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-filtering)
- [Numeric Filters: Issues and Best Practices](https://www.uxmatters.com/mt/archives/2010/02/numeric-filters-issues-and-best-practices.php)
- [histoslider: Histogram Slider for Shiny](https://github.com/cpsievert/histoslider)
- [histoslider CRAN documentation](https://cran.r-project.org/web/packages/histoslider/histoslider.pdf)
- [Designing The Perfect Slider UX](https://www.smashingmagazine.com/2017/07/designing-perfect-slider/)

**Progress Modal & Cancellation:**
- [Shiny: User feedback (Mastering Shiny Chapter 8)](https://mastering-shiny.org/action-feedback.html)
- [Shiny ExtendedTask documentation](https://shiny.posit.co/r/reference/shiny/latest/extendedtask.html)
- [bslib input_task_button documentation](https://rstudio.github.io/bslib/reference/input_task_button.html)
- [bslib bind_task_button documentation](https://rstudio.github.io/bslib/reference/bind_task_button.html)
- [Shiny: Concurrent, forked, cancellable tasks](https://gist.github.com/jcheng5/9504798d93e5c50109f8bbaec5abe372)
- [Shiny: Non-blocking operations](https://shiny.posit.co/r/articles/improve/nonblocking/)

**Conclusion Synthesis & Section Extraction:**
- [FutureGen: LLM-RAG Approach to Generate Future Work of Scientific Articles](https://arxiv.org/html/2503.16561v1)
- [A Systematic Review of RAG: Progress, Gaps, and Future Directions](https://arxiv.org/html/2507.18910v1)
- [Retrieval-Augmented Generation for Educational Applications](https://www.sciencedirect.com/science/article/pii/S2666920X25000578)
- [RAG in 2026: Bridging Knowledge and Generative AI](https://squirro.com/squirro-blog/state-of-rag-genai)

**Research Tool Features & UI:**
- [Elicit: AI for Scientific Research](https://elicit.com/)
- [Evaluating Elicit as Semi-Automated Second Reviewer](https://journals.sagepub.com/doi/10.1177/08944393251404052)
- [Elicit vs Consensus: Detailed Comparison 2026](https://paperguide.ai/blog/elicit-vs-consensus/)
- [Semantic Scholar: AI-Powered Research Tool](https://www.semanticscholar.org/)
- [Consensus: AI for Research](https://consensus.app/)
- [Consensus Advanced Search Filters](https://help.consensus.app/en/articles/9922799-advanced-search-filters)
- [Consensus Product & Feature Updates](https://consensus.app/home/blog/consensus-product-feature-updates/)
- [Top 10 AI Models for Scientific Research 2026](https://pinggy.io/blog/top_ai_models_for_scientific_research_and_writing_2026/)

**Citation Network Visualization:**
- [Local Citation Network](https://localcitationnetwork.github.io/)
- [CitNetExplorer: Analyzing Citation Patterns](https://www.citnetexplorer.nl/)
- [VOSviewer: Visualizing Scientific Landscapes](https://www.vosviewer.com/)
- [Citation Network Visualization Guide](https://ponder.ing/blog/citation-network-visualization)

**Icon Design:**
- [Academicons: Specialist Icon Font for Academics](https://jpswalsh.github.io/academicons/)
- [How to Favicon in 2026: SVG & Multi-size Best Practices](https://evilmartians.com/chronicles/how-to-favicon-in-2021-six-files-that-fit-most-needs)
- [RealFaviconGenerator: Favicon Generator for All Browsers](https://realfavicongenerator.net/)
- [Free Research Icons (Flaticon)](https://www.flaticon.com/free-icons/research)

**UX Research & Design Trends:**
- [State of UX 2026: Design Deeper to Differentiate](https://www.nngroup.com/articles/state-of-ux-2026/)
- [UI Design Trends 2026](https://landdding.com/blog/ui-design-trends-2026)
- [40 Slider UI Examples That Work](https://www.eleken.co/blog-posts/slider-ui)

---

*Feature research for v2.1 milestone: UI polish, interactive year filtering, and conclusion synthesis*
*Researched: 2026-02-13*
