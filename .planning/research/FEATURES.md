# Feature Research

**Domain:** Research Discovery Tools (Academic Paper Search & Curation)
**Researched:** 2026-02-10
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Seed paper discovery | All modern research tools (Connected Papers, ResearchRabbit, Litmaps) start with seed papers. Users expect to input one paper and find related work. | MEDIUM | Requires citation network traversal (references + cited-by). OpenAlex provides this via `referenced_works` and `cited_by_count` endpoints. |
| Citation-based sorting | Users expect to sort by citation count to identify influential papers. Google Scholar, Semantic Scholar, all tools offer this. | LOW | Already have citation data from OpenAlex. Just needs UI sorting controls. |
| Relevance sorting | Default sort should be "relevant to query" not just recency or citations. Users trained by Google Scholar, Semantic Scholar. | MEDIUM | OpenAlex provides relevance scores. Need to balance with citation count (old highly-cited papers dominate pure relevance). |
| Publication year filtering | Every academic search tool offers year range filtering. Table stakes since Google Scholar. | LOW | Already supported in current search notebooks. |
| Visual quality indicators | Users expect to see badges/icons for paper type, open access status, citations at a glance without clicking. | LOW | Already implemented in Serapeum (type badges, OA badges, citation metrics). |
| Export to citation managers | Users expect BibTeX, RIS, or direct Zotero/Mendeley export. Research tools without this feel broken. | MEDIUM | Need to generate standard citation formats from OpenAlex metadata. |
| Multi-paper selection | Users expect checkboxes to select multiple papers for batch actions (export, tag, delete). | LOW | UI pattern widely expected from Gmail, file managers, etc. |
| Author filtering | Ability to filter by specific authors or exclude certain authors. | MEDIUM | OpenAlex supports author filtering via `filter=authorships.author.id` |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Local-first citation network visualization | Connected Papers charges for saved graphs. Litmaps has limits. Offering unlimited local visualization aligns with Serapeum's privacy-first mission. | HIGH | Need graph layout algorithm (force-directed), interactive canvas (D3.js or similar in Shiny). Citation data from OpenAlex. |
| LLM query builder with natural language | Elicit's natural language queries are a key differentiator. Users ask "How does sleep affect memory in teenagers?" not keyword searches. | MEDIUM | Prompt LLM to extract: concepts, date ranges, document types from natural language. Convert to OpenAlex filter syntax. |
| Topic exploration via shared citations | Litmaps/Connected Papers find papers through co-citation and bibliographic coupling. Differentiates from keyword search. | HIGH | Requires: (1) fetch seed paper citations, (2) find papers citing same works (co-citation), (3) score by overlap strength. Computationally intensive. |
| Smart startup wizard | First-time users struggle with empty notebooks. A wizard that asks "What are you researching?" and seeds initial papers reduces abandonment. | MEDIUM | Multi-step UI flow: (1) ask research topic, (2) LLM generates initial query, (3) auto-creates notebook with results, (4) prompts to select seed papers. |
| Persistent research feeds | Semantic Scholar's Research Feeds notify users of new papers matching interests. Local version saves queries and highlights new results. | MEDIUM | Store query fingerprints, poll OpenAlex periodically, diff results, flag new papers. Requires background job or manual refresh. |
| Interactive citation timeline | Visualize paper evolution over time on timeline. See how ideas developed chronologically. | MEDIUM | D3.js timeline with papers as nodes, positioned by publication year, sized by citations. |
| Automatic related paper suggestions | After embedding papers, suggest "Papers that cite these" or "Earlier work by same authors" without user input. | LOW | Use OpenAlex relationships (`referenced_works`, `related_works`, `authorships.author.works`). Surface in sidebar. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-time collaborative notebooks | Users want to share notebooks like Google Docs. | Breaks local-first architecture. Requires auth, sync conflicts, server infrastructure. Adds massive complexity for single-user tool. | Export notebook as shareable file (JSON, HTML report). Recipient imports to their local instance. |
| Comprehensive full-text search across all papers | "Why can't I search inside every paper like Ctrl+F?" | OpenAlex abstracts only, no full text. Scraping PDFs at scale = legal risk + storage cost. | Focus on abstract search (already semantic via embeddings). For specific papers, import to document notebook for full-text RAG. |
| Automatic paper quality scoring | "Tell me which papers are good." | Quality is subjective, domain-dependent. Citation count favors old papers. Journal impact factor is controversial. ML scoring = black box users don't trust. | Provide transparent filters (citation threshold, exclude predatory journals, exclude retractions). Let users decide quality criteria. |
| Built-in PDF reader | "Why do I need to download PDFs to read them?" | Scope creep. Good PDF readers exist (browser, Zotero, Adobe). Building a competitive reader = months of work for marginal value. | One-click download + open in default PDF viewer. Focus on discovery and curation, not reading experience. |
| Social features (like/comment/rate papers) | "Let me rate papers and see what others think." | Local-first = no central database. Social features require server, moderation, spam prevention. Privacy concerns sharing reading habits. | Keep local notes/tags per paper. Export curated lists as static HTML for sharing insights. |
| Automatic topic clustering without seed papers | "Just show me the research landscape on topic X." | Unsupervised clustering on broad topics = noisy results. Users don't trust "magic" without seed papers. Computationally expensive. | Require 1-3 seed papers for focused exploration. LLM query builder helps users articulate starting point. |

## Feature Dependencies

```
[LLM Query Builder]
    └──requires──> [OpenRouter API configured]

[Seed Paper Discovery]
    └──requires──> [Citation network data from OpenAlex]
                       └──requires──> [Related works endpoint]

[Citation Network Visualization]
    └──requires──> [Seed Paper Discovery]
    └──requires──> [Graph layout algorithm]

[Topic Exploration (co-citation)]
    └──requires──> [Seed Paper Discovery]
    └──requires──> [Multiple API calls to fetch citation overlap]

[Smart Startup Wizard]
    └──requires──> [LLM Query Builder]
    └──enhances──> [Seed Paper Discovery]

[Rich Sorting (relevance + citations + date)]
    └──requires──> [OpenAlex relevance scores + citation metadata]

[Export to Citation Managers]
    └──requires──> [BibTeX/RIS formatter]
    └──enhances──> [Multi-paper selection]

[Research Feeds (new paper notifications)]
    └──requires──> [Saved queries in database]
    └──requires──> [Background polling or manual refresh]
```

### Dependency Notes

- **LLM Query Builder requires OpenRouter API:** Natural language parsing needs LLM. Already configured for chat, can reuse for query assistance.
- **Seed Paper Discovery requires Citation Network Data:** Must fetch `referenced_works` and `cited_by_api_url` from OpenAlex for a given DOI/work ID.
- **Citation Network Visualization requires Seed Paper Discovery:** Can't visualize relationships without first fetching the network.
- **Smart Startup Wizard enhances Seed Paper Discovery:** Wizard helps users articulate research question, then seeds papers via discovery features.
- **Topic Exploration requires multiple API calls:** Co-citation analysis = fetch references for seed papers, then find papers citing same works. Expensive but valuable.
- **Export enhances Multi-paper selection:** Selecting multiple papers only valuable if you can do something with the selection (export, tag, delete).

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the discovery features.

- [x] **Rich Sorting Controls** — Users expect to sort by relevance, citations, or date. Table stakes for academic search. Without this, tool feels primitive compared to Google Scholar.
- [x] **Seed Paper Discovery** — Core value proposition. Enter DOI/title, get related papers via citations. This is what differentiates discovery tools from basic search.
- [x] **LLM Query Builder** — Helps users translate "I want to research X" into effective search queries. Reduces friction for non-expert users. Aligns with Serapeum's AI-assisted approach.
- [x] **Multi-paper Selection** — Needed for batch export, batch import to document notebooks. Expected UX from every modern app.
- [x] **Export to BibTeX** — Most common citation format. Researchers need this for LaTeX, reference managers. Low effort, high value.

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] **Citation Network Visualization** — High complexity, high value. Validate that users want discovery features before investing in graph visualization.
- [ ] **Topic Exploration (co-citation)** — Computationally expensive. Add once seed paper discovery proves useful and users want deeper exploration.
- [ ] **Smart Startup Wizard** — Reduces abandonment for new users. Add after seeing onboarding drop-off in analytics.
- [ ] **Research Feeds** — Persistent queries for ongoing research. Add when users express desire to "track this topic over time."
- [ ] **Export to RIS/Zotero** — Additional citation formats. Add based on user requests (BibTeX covers LaTeX users, RIS covers others).

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Interactive Citation Timeline** — Nice visualization but not core to discovery workflow. Defer until citation network viz is working well.
- [ ] **Author Network Visualization** — Interesting for some disciplines, not universally valuable. Wait for specific user requests.
- [ ] **Automatic Related Paper Suggestions** — Low complexity but adds UI noise. Wait until users are comfortable with manual discovery first.
- [ ] **Advanced Filtering (author, venue, funder)** — Power user features. Core users will ask for these specifically when needed.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Rich Sorting (relevance/citations/date) | HIGH | LOW | P1 |
| Seed Paper Discovery (citations) | HIGH | MEDIUM | P1 |
| LLM Query Builder | HIGH | MEDIUM | P1 |
| Multi-paper Selection | HIGH | LOW | P1 |
| Export to BibTeX | HIGH | LOW | P1 |
| Citation Network Visualization | HIGH | HIGH | P2 |
| Topic Exploration (co-citation) | MEDIUM | HIGH | P2 |
| Smart Startup Wizard | MEDIUM | MEDIUM | P2 |
| Research Feeds | MEDIUM | MEDIUM | P2 |
| Export to RIS/Zotero | MEDIUM | LOW | P2 |
| Interactive Citation Timeline | LOW | MEDIUM | P3 |
| Author Network Visualization | LOW | HIGH | P3 |
| Automatic Related Paper Suggestions | LOW | LOW | P3 |
| Advanced Filtering (author/venue/funder) | MEDIUM | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch (table stakes + core differentiators)
- P2: Should have, add when possible (stronger differentiators, quality of life)
- P3: Nice to have, future consideration (power user features, exploratory visualizations)

## Competitor Feature Analysis

| Feature | Connected Papers | Semantic Scholar | Elicit | Research Rabbit | Litmaps | Serapeum Approach |
|---------|------------------|------------------|--------|-----------------|---------|-------------------|
| Seed Paper Discovery | Visual graph from 1+ seed papers, 50K papers scanned | Citation graphs, related works | Semantic search, concept-based | Citation trails, co-citation networks | Similarity, authorship, abstract/title | OpenAlex citation network (references + cited-by), lower visual polish but local-first |
| Natural Language Queries | No | Limited | **Strong differentiator** - full research questions | No | Keyword-based | LLM-assisted query builder via OpenRouter |
| Sorting Options | Year, keyword, PDF availability, open access | Relevance, recency, citation count | Relevance, date, citations | Customizable axes (X/Y sorting) | Similarity, recency, citations | Relevance + citations + date (all three toggleable) |
| Visualization | **Strong** - interactive graph with Prior/Derivative works | Citation graphs, research feeds | Table-based | **Strong** - customizable network views, moveable nodes | **Strong** - color-coded mind maps | Defer to v1.x (focus on discovery first, viz later) |
| Export/Integration | Limited (free tier) | Zotero, Mendeley integration | CSV, research tables | Collection sharing | Share mind maps | BibTeX first (P1), RIS/Zotero later (P2) |
| Topic Exploration | Multi-origin graphs, co-citation | Research Feeds (adaptive AI recommendations) | Concept extraction | Similar papers, refs, cited-by | Shared citations, authorship patterns | Co-citation analysis (P2), start with simpler citation traversal (P1) |
| Onboarding | Minimal - assumes user has seed paper | Tutorial, search guidance | Query builder helps | Collection-based workflow | Minimal | Smart startup wizard (P2) to reduce abandonment |
| Privacy Model | Cloud-based, freemium | Cloud-based, free | Cloud-based, freemium | Cloud-based, free | Cloud-based, free/paid | **Local-first differentiator** - all data local, unlimited graphs |

## Sources

**Research Discovery Tools:**
- [Connected Papers - Loyola Marymount University LibGuides](https://libguides.lmu.edu/AIresearchtools/CP)
- [Connected Papers Official Site](https://www.connectedpapers.com/)
- [Connected Papers: 2025 Review - Skywork.ai](https://skywork.ai/skypage/ko/Connected-Papers:-My-Deep-Dive-into-the-Visual-Research-Tool-(2025-Review)/1972566882891395072)
- [Semantic Scholar - TCS Education System Libraries](https://tcsedsystem.libguides.com/ai_tools_for_lit_discovery/semantic_scholar)
- [Semantic Scholar Review: Free AI Academic Search (2026)](https://agentaya.com/ai-review/semantic-scholar/)
- [Semantic Scholar Official Site](https://www.semanticscholar.org/)
- [Elicit: How to Use for 10x Faster Research (2026)](https://www.fahimai.com/how-to-use-elicit)
- [Elicit AI Review (2026) - Social Think](https://socialthink.io/blog/elicit-ai/)
- [Research Rabbit: 2026 Review - The Effortless Academic](https://effortlessacademic.com/research-rabbit-2026-review-for-researchers/)
- [Research Rabbit Official Site](https://www.researchrabbit.ai)
- [Litmaps Official Site - Features](https://www.litmaps.com/features)
- [11 Best AI Tools for Scientific Literature Review in 2026 | Cypris](https://www.cypris.ai/insights/11-best-ai-tools-for-scientific-literature-review-in-2026)

**User Expectations & Pain Points:**
- [What Research Software Needs to Deliver in 2026 - Checker](https://www.checker-soft.com/what-research-software-needs-to-deliver-in-2026/)
- [Your 2026 UX Stack: What to Keep, What to Drop - UX University](https://uxuniversity.io/p/your-2026-ux-stack-what-to-keep-what)
- [What is an Onboarding Wizard (with Examples) - UserGuiding](https://userguiding.com/blog/what-is-an-onboarding-wizard-with-examples)
- [17 Best Onboarding Flow Examples (2026) - Whatfix](https://whatfix.com/blog/user-onboarding-examples/)

**Academic Search Features:**
- [The Ultimate Guide to Academic Search Engines (2026) - PaperGuide](https://paperguide.ai/blog/academic-search-engines/)
- [How to Customize Search Filters for Academic Research - Sourcely](https://www.sourcely.net/resources/how-to-customize-search-filters-for-academic-research)
- [28 Best Academic Search Engines 2026 - SciJournal](https://www.scijournal.org/articles/academic-search-engines)

**LLM Query Building:**
- [LLM SQL Generator: Natural Language to SQL - AI2SQL](https://ai2sql.io/llm-sql-query-generator)
- [How LLM Search Works: Step-by-Step Guide (2026)](https://two99.org/blog/how-llm-search-works-a-step-by-step-guide/)
- [9 Best LLMs for Web Search Tasks in 2026 - VisionVix](https://visionvix.com/best-llm-for-web-search/)
- [Search Query Understanding with LLMs - Yelp Engineering](https://engineeringblog.yelp.com/2025/02/search-query-understanding-with-LLMs.html)

**Citation Management & Export:**
- [The 12 Best Citation Management Software (2026) - LLMRefs](https://llmrefs.com/blog/best-citation-management-software)
- [Best Reference Management Software for 2026 - Research.com](https://research.com/software/best-reference-management-software)
- [9 Best AI Tools for Research in 2026 - PaperGuide](https://paperguide.ai/blog/ai-tools-for-research/)

**Visualization & Network Analysis:**
- [Tools for Literature Mapping - The Digital Orientalist](https://digitalorientalist.com/2025/03/18/tools-for-literature-mapping/)
- [3 New Tools for Literature Mapping - Aaron Tay (Medium)](https://aarontay.medium.com/3-new-tools-to-try-for-literature-mapping-connected-papers-inciteful-and-litmaps-a399f27622a)
- [VOSviewer - Visualizing Scientific Landscapes](https://www.vosviewer.com/)
- [CitNetExplorer - Analyzing Citation Patterns](https://www.citnetexplorer.nl/)
- [Litmaps vs ResearchRabbit vs Connected Papers (2025) - The Effortless Academic](https://effortlessacademic.com/litmaps-vs-researchrabbit-vs-connected-papers-the-best-literature-review-tool-in-2025/)

**Privacy & Local-First Trends:**
- [Data Privacy Trends 2026: Essential Guide - SecurePrivacy](https://secureprivacy.ai/blog/data-privacy-trends-2026)
- [5 Emerging Data Privacy Trends in 2026 - Osano](https://www.osano.com/articles/data-privacy-trends)
- [Data Privacy Week 2026: Navigating the New Era of Data Control - SecureWorld](https://www.secureworld.io/industry-news/data-privacy-week-2026)

---
*Feature research for: Research Discovery Tools (Academic Paper Search & Curation)*
*Researched: 2026-02-10*
