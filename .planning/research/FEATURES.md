# Feature Landscape: Discovery & Export Enhancement (v1.2)

**Domain:** Research assistant tools / Academic literature management
**Researched:** 2026-02-12
**Milestone:** v1.2 — Discovery workflow enhancement and output/export capabilities
**Confidence:** HIGH

## Context

This research focuses on **NEW features for v1.2 milestone only:**
- DOI on abstract preview (#66)
- Export abstract to seeded paper search (#67)
- Seeded search same view as abstract preview (#71)
- Citation network graph (#53)
- Citation export - .bib/.csv/BibTeX (#64)
- Export synthesis outputs (#49)

**Already built in v1.1:**
- Search notebooks with paper list, abstract detail view
- Keyword/journal filtering
- Seed paper discovery (enter DOI → find related papers → create notebook)
- Query builder (LLM-assisted search term generation)
- Topic explorer (OpenAlex topic hierarchy)
- Slide generation from RAG chat
- Cost tracking per LLM request

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **DOI display on abstract preview (#66)** | Standard metadata display in all academic tools (Google Scholar, Semantic Scholar, Web of Science). Users need to copy DOI for citations. | **Low** | Already have abstract preview UI in search notebook, DOI from OpenAlex. Just add DOI field display with copy button. |
| **BibTeX export (.bib) (#64)** | Universal standard for LaTeX users, supported by Zotero, Mendeley, Web of Science, Scopus. Researchers expect this for reference management. | **Low** | Standard format with 14 entry types, well-documented spec. Map OpenAlex fields to BibTeX fields. |
| **CSV export (#64)** | Expected for data analysis, spreadsheet import, custom workflows. Common in all academic databases. | **Low** | Flat format, need to define column schema (title, authors, year, DOI, citations, etc). |
| **Basic citation metadata (#64)** | Title, authors, year, DOI, journal required for any export. Table stakes for citation tools. | **Low** | Already have from OpenAlex API response. |
| **Export selected items (#64)** | Users expect to filter before export, not export everything. Gmail/file manager pattern. | **Medium** | Requires selection UI state management (checkboxes), export button with format picker. |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Citation network graph (#53)** | Visual discovery > list-based search. Connected Papers built entire business on this. Local = privacy + offline. | **High** | Force-directed layout, node sizing by citations, color by year, interactive zoom/pan/filter. Connected Papers charges for saved graphs, we offer unlimited local. |
| **Export abstract → seeded search (#67)** | Seamless workflow: discover in search → seed new search from abstract. Most tools require copy/paste DOI manually. | **Low** | UI flow integration between existing modules (search notebook → seed discovery). One-click action. |
| **Same view for seeded results (#71)** | Consistency: seeded search uses familiar search notebook UI instead of separate interface. Reduces learning curve. | **Medium** | Architectural: seed discovery returns structured search results, reuses search notebook component. Need adapter layer. |
| **Export synthesis outputs (#49)** | RAG chat + slide generation are differentiators; exporting them completes the workflow. Most tools don't export AI-generated content. | **Low-Medium** | Markdown/PDF export for chat summaries, HTML/PPTX for slides. Chat history → formatted document. |
| **Local-first citation network (#53)** | Most tools (Connected Papers, ResearchRabbit) are cloud-only. Local = privacy + offline + unlimited graphs. | **High** | Graph data stored in DuckDB, computed locally, no API dependencies after initial fetch. Privacy win. |
| **Multi-format export from single source (#64)** | Export to .bib, .csv, .ris, .json from same dataset without re-querying. Convenience over switching tools. | **Medium** | Abstract export layer over data model. Format-specific serializers. |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Cloud sync for citation graphs** | Scope creep, infrastructure cost, breaks local-first principle. | Keep graphs local, export as static files (JSON, PNG) if sharing needed. |
| **Custom citation styles (APA, MLA, Chicago)** | Complexity explosion (9000+ styles in Zotero). Not core value prop. Citation formatting is commodity feature. | Export BibTeX/RIS, let LaTeX/Zotero/Mendeley handle formatting. Focus on discovery, not citation formatting. |
| **PDF annotation** | Major feature, separate product category (Zotero, Mendeley specialize in this). Months of work for marginal value. | Focus on discovery/synthesis, not document markup. Users have preferred PDF readers. |
| **Reference deduplication** | Edge case complexity (fuzzy matching, merge conflicts, user decisions on which duplicate to keep). | Assume OpenAlex data is canonical, export as-is. Users can dedupe in Zotero if needed. |
| **Collaborative features** | Architecture shift (multiplayer state, conflict resolution, auth, server). Local-first means single-user. | Individual researcher workflow only. Export/share results as static files. |
| **Citation network auto-update** | Background jobs, staleness detection, API quota management. When to refresh? How to notify? | Generate on-demand only. User clicks "Generate Graph" when needed. Simple and predictable. |
| **Real-time graph physics** | Connected Papers uses smooth animations. Complex for Shiny. Performance issues with 100+ nodes. | Static layout computed once, pan/zoom only. Simpler implementation, faster. |

## Feature Dependencies

```
DOI display (#66)
  → None (standalone enhancement to existing abstract preview)

Export abstract → seeded search (#67)
  → Requires: Seed discovery module (EXISTS in v1.1)
  → Requires: Abstract detail view (EXISTS in v1.1)
  → New: UI action button "Find Related Papers"
  → New: Data flow to populate seed discovery with selected paper DOI

Seeded search same view (#71)
  → Requires: Search notebook component (EXISTS in v1.1)
  → Requires: Seed discovery module (EXISTS in v1.1)
  → New: Adapter layer to populate search notebook from seed results
  → New: Navigation flow (seed discovery → search notebook view)

Citation network graph (#53)
  → Requires: OpenAlex citations API (available, free)
  → Requires: Graph layout library (need to add: vis.js, cytoscape.js, or visNetwork)
  → Requires: Interactive visualization in Shiny (htmlwidgets)
  → Requires: DuckDB schema for graph storage (cache results)
  → Optional: Export graph as PNG/SVG/JSON

Citation export (.bib/.csv/BibTeX) (#64)
  → Requires: Selected papers list (EXISTS in search notebook)
  → Requires: Export format generators (BibTeX, CSV serializers)
  → Optional: RIS format (similar complexity to BibTeX)
  → Optional: JSON format (trivial, just serialize data frame)

Export synthesis outputs (#49)
  → Requires: RAG chat module (EXISTS in v1.1, document notebook)
  → Requires: Slides module (EXISTS in v1.1, generated from chat)
  → New: Markdown export for chat (chat history → .md file)
  → New: PDF export for chat (via pandoc or pagedown R package)
  → New: HTML export for slides (via revealjs)
  → Optional: PPTX export for slides (via officer R package, more complex)
```

## Feature Groupings by Implementation Order

### Phase 1: Quick Wins (Low complexity, high value, 1-2 days)

**Goal:** Ship improvements fast, validate export features.

1. **DOI display (#66)** — 1-2 hours
   - Add DOI to abstract preview card (already have from OpenAlex)
   - Add copy button (clipboard.js or Shiny action)
   - Format as clickable link: `https://doi.org/{doi}`

2. **Export abstract → seeded search (#67)** — 2-4 hours
   - Add "Find Related Papers" button on abstract detail view
   - Pass DOI to seed discovery module (module communication)
   - Navigate to seed discovery tab
   - Pre-fill DOI input and trigger lookup

### Phase 2: Workflow Integration (Medium complexity, 3-5 days)

**Goal:** Seamless workflows between discovery and export.

3. **Seeded search same view (#71)** — 4-8 hours
   - Modify seed discovery to emit search results (data structure)
   - Populate search notebook from seed results (adapter layer)
   - Handle "back to seed" navigation (breadcrumb or back button)
   - Consistent UI: same filters, sorting, selection as keyword search

4. **Citation export (.bib/.csv) (#64)** — 4-8 hours
   - Build BibTeX formatter (map OpenAlex → BibTeX fields)
   - Build CSV formatter (flatten data frame)
   - Add export UI (dropdown: "Export as BibTeX / CSV / RIS")
   - File download handler in Shiny
   - Handle edge cases (missing authors, no DOI, special characters)

### Phase 3: Advanced Features (High complexity, 1-2 weeks)

**Goal:** Citation network graph as marquee feature.

5. **Citation network graph (#53)** — 16-24 hours
   - Research graph library (vis.js lightweight, cytoscape.js feature-rich, visNetwork R wrapper)
   - Fetch citation data from OpenAlex (cited-by, references endpoints)
   - Build graph layout algorithm (force-directed, hierarchical, or radial)
   - Interactive features: zoom, pan, click node → abstract detail, filter by year/citations
   - Store graph snapshots in DuckDB (cache by seed DOI, avoid re-fetch)
   - UI: graph view in new tab or modal, filters sidebar
   - Performance: limit to 100 nodes initially, warn if exceeds

6. **Export synthesis outputs (#49)** — 8-12 hours
   - Chat export: Markdown (trivial, concatenate messages), PDF (via pandoc or pagedown)
   - Slides export: HTML (revealjs already used for generation?), PPTX (officer package, more work)
   - Add export buttons to document notebook (chat section, slides section)
   - File download handlers
   - Format chat history (user/assistant labels, timestamps, code blocks)

## Complexity Drivers

### Citation Network Graph (High Complexity) — Why?

**Technical challenges:**
1. **Graph layout algorithms:** Force-directed physics simulation (compute node positions), hierarchical (layered), radial (concentric circles). Need balance between aesthetics and performance.
2. **Interactive performance:** 100+ nodes = lag without optimization. Need canvas rendering (not SVG), virtualization, level-of-detail.
3. **Visual design:** Node sizing (citations), edge thickness (relationship strength), color scales (year), labels (readability), legend.
4. **Filter controls:** Year range, citation count threshold, depth limit (1-hop, 2-hop), node type (references vs cited-by).
5. **API rate limits:** Fetching citations for 100 papers = 100+ requests to OpenAlex. Need batching, caching, progress indicators.
6. **Caching strategy:** When to refresh graph? Store in DuckDB by seed DOI + depth + filters? Invalidation?

**Reference implementations:**
- **Connected Papers:** Semantic similarity + citations, 50-node cap, multi-origin, prior/derivative works split. Charges for saved graphs.
- **ResearchRabbit:** Citation-based, collections, timeline view. Free tier limited.
- **Litmaps:** Seed maps, color-coded by topic similarity. Freemium model.
- **VOSviewer:** Large-scale (1000+ nodes), desktop software, advanced layout algorithms. Academic use.
- **Local Citation Network:** R-based, Shiny UI, moderate scale (50-200 nodes). Open source.

**Recommended approach for v1.2:**
- **Library:** visNetwork (R wrapper for vis.js) — Shiny integration, good docs, moderate learning curve.
- **Scope:** Single-origin, depth=1 (seed + direct citations + direct references). Defer multi-origin to v1.3.
- **Node limit:** 100 nodes initially (performance), warn if exceeds, let user filter.
- **Layout:** Force-directed (hierarchicalRepulsion physics), auto-stabilize.
- **Visual:** Node size = citations, node color = year gradient, edges = uniform thickness.
- **Filters:** Year range slider, citation threshold slider, toggle references/citations.
- **Cache:** Store graph JSON in DuckDB by seed DOI, TTL = 30 days.

### Export Synthesis Outputs (Medium Complexity) — Why?

**Technical challenges:**
1. **Chat history formatting:** Messages are reactive list, need to serialize to Markdown/PDF. User/assistant labels, timestamps, code blocks.
2. **Slides export:** If slides generated with revealjs, export as HTML is trivial (save rendered HTML). PPTX requires officer package, template design, layout.
3. **PDF generation:** Options: pandoc (external dependency, may not be installed), pagedown (R package, CSS Paged Media, slower but self-contained).
4. **File download:** Shiny downloadHandler, temp file creation, cleanup.

**Recommended approach for v1.2:**
- **Chat export:**
  - Markdown: Trivial (concatenate messages with headers, save as .md).
  - HTML: Simple (wrap in basic HTML template, add CSS).
  - PDF: Defer to v1.3 (requires pandoc or pagedown, complexity spike).
- **Slides export:**
  - HTML: Simple if slides already use revealjs (save rendered output).
  - PPTX: Defer to v1.3 (officer package, need template, layout complexity).

## Expected Behavior from Competitive Research

### DOI Display (Google Scholar, Semantic Scholar, Web of Science)
- **Google Scholar:** Shows "DOI" link below abstract, opens resolver in new tab.
- **Semantic Scholar:** Shows DOI with copy icon, click copies to clipboard.
- **Web of Science:** Shows DOI as hyperlink, styled as metadata badge.
- **Expected for Serapeum:** Clickable DOI link (https://doi.org/...), copy button, displayed with other metadata (year, citations).

### Citation Export (Zotero, Mendeley, Web of Science, Scopus)
- **Zotero:** Supports .bib, .ris, .json, .csv. File → Export → choose format.
- **Mendeley:** Supports .bib, .ris, .xml. Right-click → Export.
- **Web of Science:** Supports .bib, .txt, .ris, tab-delimited. Select records → Export.
- **Scopus:** Supports .bib, .csv (CSV has most complete metadata).
- **Expected for Serapeum:** BibTeX (.bib) is mandatory, CSV is common, RIS is nice-to-have. Dropdown picker: "Export as BibTeX / CSV / RIS / JSON".

### Citation Network Graph (Connected Papers, ResearchRabbit, Litmaps)

**Connected Papers:**
- Force-directed graph (physics simulation)
- Node size = citation count (bigger = more cited)
- Node color = publication year gradient (darker = more recent)
- Edges = similarity strength (thicker = stronger)
- Filters: year range, keyword, open access, PDF availability
- Multi-origin mode (add 2nd seed, graph shows papers related to both)
- Prior works (left side) vs Derivative works (right side) layout
- Export: reference list to Zotero/EndNote/Mendeley

**ResearchRabbit:**
- Seed papers → similar works (citation-based)
- Timeline view (year-based horizontal layout)
- Collections (save subgraphs, track over time)
- Multiple layout options (network, timeline, list)
- Free tier unlimited

**Litmaps:**
- Seed map → visual network of related papers
- Color-coded by topic similarity (semantic)
- Discover tab (auto-suggestions)
- Export: share mind maps (URL), export citations

**Expected for Serapeum:**
- Visual graph (force-directed or hierarchical)
- Interactive (zoom, pan, click node → abstract detail)
- Filters (year, citation count, depth)
- Node size = citations, node color = year
- Local storage (DuckDB), no cloud dependency
- Export graph as image (PNG/SVG) or data (JSON)

### Seeded Search Workflow (ResearchRabbit, Litmaps, Connected Papers)
- **ResearchRabbit:** Add paper → auto-generates "Similar Papers" list view, toggle to network view.
- **Litmaps:** Seed map → visual network immediately, list view available.
- **Connected Papers:** Enter DOI → generates graph, can switch to list view.
- **Expected for Serapeum:** Enter DOI → see related papers in familiar search notebook UI (list with filters), option to switch to graph view.

## User Workflow Assumptions

### Current Workflow (Serapeum v1.1)
1. **Search:** Create search notebook → enter keywords → get results list.
2. **Filter:** Apply keyword/journal filters → sort by year/citations.
3. **Review:** Click paper → view abstract detail → manually copy DOI if needed.
4. **Discovery:** Go to seed discovery → paste DOI → get related papers in separate view.
5. **Document:** Create document notebook → upload PDF → RAG chat.
6. **Synthesize:** Generate slides from chat.
7. **Export:** None (manual copy/paste).

### Enhanced Workflow (v1.2 Target)
1. **Search:** Create search notebook → enter keywords → get results list.
2. **Filter:** Apply keyword/journal filters → sort by year/citations.
3. **Review:** Click paper → view abstract detail → **see DOI displayed** → **copy button**.
4. **Discovery:** Click "Find Related Papers" → **seeded search in same UI** (familiar filters/sorting).
5. **Select:** Multi-select papers → **export as .bib/.csv** for Zotero/spreadsheet.
6. **Visualize:** Click "Citation Network" → **interactive graph** → explore relationships.
7. **Document:** Upload PDF → RAG chat → **export chat as Markdown/PDF**.
8. **Synthesize:** Generate slides → **export as HTML/PPTX**.

### Key Improvements
- **Faster DOI access:** Displayed on abstract, no manual copy/paste needed.
- **Seamless seeded search:** One click from abstract → related papers in familiar UI.
- **Consistent UI:** Seeded results use same view as keyword search (same filters, sorting, selection).
- **Export integration:** Export citations (.bib/.csv) and synthesis outputs (chat/slides).
- **Visual discovery:** Citation network graph complements list-based search.
- **Local-first:** All data local, privacy-preserving, offline-capable.

## Open Questions

### Citation Network Graph
- **Q:** What graph library? vis.js (lightweight, good Shiny wrapper) vs cytoscape.js (feature-rich, steeper learning curve)?
  - **Recommendation:** visNetwork (R wrapper for vis.js) — balance of features and Shiny integration.
- **Q:** How many nodes before performance degrades in Shiny?
  - **Research:** Connected Papers caps at 50, Local Citation Network handles 200. **Recommend 100-node cap initially.**
- **Q:** Should graph persist in DB or regenerate each time?
  - **Recommendation:** Cache in DuckDB by seed DOI + depth + filters. TTL = 30 days. Regenerate button available.
- **Q:** Support multi-origin graphs (like Connected Papers) in v1.2 or defer?
  - **Recommendation:** Defer to v1.3. Single-origin is complex enough for first iteration.

### Citation Export
- **Q:** Support RIS format? (Common in reference managers, similar to BibTeX)
  - **Recommendation:** Yes if time permits, prioritize BibTeX > CSV > RIS.
- **Q:** Include abstracts in exports? (Large file size, but useful for review)
  - **Recommendation:** Make optional (checkbox: "Include abstracts"). Default = no.
- **Q:** Export limit? (100 papers reasonable, 1000+ may be slow)
  - **Recommendation:** Warn if >500 selected, no hard limit. User decides.

### Synthesis Export
- **Q:** Chat export: Include only assistant messages, or full conversation?
  - **Recommendation:** Full conversation (user + assistant) — provides context for review.
- **Q:** Slides export: PPTX (complex, officer package) or HTML (simple, revealjs)?
  - **Recommendation:** HTML for v1.2 (revealjs), PPTX for v1.3 if requested.
- **Q:** PDF generation: Require pandoc installation, or use R pagedown package?
  - **Recommendation:** Defer PDF to v1.3. Start with Markdown/HTML (no external dependencies).

## Sources

**Research Management Tools:**
- [Paperguide: Best Reference Management Software 2026](https://paperguide.ai/blog/best-reference-management-software-top-tools-for-researchers/)
- [Research.com: Best Reference Management Software](https://research.com/software/best-reference-management-software)
- [Zotero Documentation](https://www.zotero.org/)
- [Zotero: Add Items by Identifier (DOI)](https://researchguides.uoregon.edu/zotero/additems)

**Citation Network Visualization:**
- [Connected Papers](https://www.connectedpapers.com/)
- [Connected Papers Forum: Citation Mapping](https://forums.zotero.org/discussion/78671/citation-mapping-network-map-of-zotero-library)
- [ResearchRabbit](https://www.researchrabbit.ai)
- [Litmaps](https://www.litmaps.com/)
- [Citation Network Visualization Guide](https://ponder.ing/blog/citation-network-visualization)
- [VOSviewer](https://www.vosviewer.com/)
- [CitNetExplorer](https://www.citnetexplorer.nl/)
- [Local Citation Network](https://localcitationnetwork.github.io/)

**Citation Export Standards:**
- [BibTeX Format Explained](https://www.bibtex.com/g/bibtex-format/)
- [Bibliometrix: Data Importing and Converting](https://www.bibliometrix.org/vignettes/Data-Importing-and-Converting.html)
- [Web of Science Export Documentation](https://support.clarivate.com/ScientificandAcademicResearch/s/article/Web-of-Science-Exporting-Records-to-BibTeX?language=en_US)
- [Exporting BibTeX Files - UMD Libraries](https://lib.guides.umd.edu/facultysuccess/bibtex)

**Seeded Search Workflows:**
- [AI Research Assistant Tools 2026](https://paperguide.ai/blog/ai-research-assistant-tools-for-scientific-research/)
- [Best AI Tools for Research 2026](https://paperguide.ai/blog/ai-tools-for-research/)

**DOI and Abstract Best Practices:**
- [Abstract Research Paper Best Practices 2026](https://research.com/research/abstract-research-paper)
- [How to Write a Research Paper Abstract 2026](https://research.com/research/how-to-write-a-research-paper-abstract)

**Export and Synthesis:**
- [How to Export All Notes: 2026 Guide](https://flavor365.com/a-step-by-step-guide-to-exporting-all-your-notes/)
- [Converting PDFs to Markdown](https://medium.com/@tam.tamanna18/converting-pdfs-to-markdown-with-olmocr-and-other-tools-7a0323ca8379)
- [Academic Workflow: Zotero & Obsidian](https://medium.com/@alexandraphelan/an-updated-academic-workflow-zotero-obsidian-cffef080addd)

---

## Previous Research (v1.1 — for reference)

<details>
<summary>Click to expand v1.1 feature research (already implemented)</summary>

### v1.1 Features (Already Built)
- [x] Rich Sorting Controls (relevance, citations, date)
- [x] Seed Paper Discovery (enter DOI → related papers)
- [x] LLM Query Builder (natural language → search query)
- [x] Multi-paper Selection (checkboxes, batch actions)
- [x] Topic Explorer (OpenAlex topic hierarchy)
- [x] Slide Generation (RAG chat → presentation)
- [x] Cost Tracking (LLM request costs)

### v1.1 Table Stakes
- Seed paper discovery (citation network traversal)
- Citation-based sorting
- Relevance sorting
- Publication year filtering
- Visual quality indicators (badges)
- Multi-paper selection

### v1.1 Differentiators
- Local-first architecture (privacy, offline)
- LLM query builder (natural language queries)
- Persistent research feeds (saved queries)
- Smart startup wizard (onboarding)

### v1.1 Anti-Features
- Real-time collaborative notebooks
- Comprehensive full-text search
- Automatic paper quality scoring
- Built-in PDF reader
- Social features (like/comment/rate)

See `.planning/research/FEATURES-v1.1.md` for full v1.1 research.

</details>

---

*Feature research for v1.2 milestone: Discovery workflow enhancement and output/export capabilities*
*Researched: 2026-02-12*
