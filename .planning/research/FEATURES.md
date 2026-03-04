# Feature Research

**Domain:** Research Assistant UI Design System & AI Synthesis Presets (v10.0)
**Researched:** 2026-03-04
**Confidence:** MEDIUM-HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Consistent button semantics** | Users expect primary (main action), secondary (alternative), danger (destructive) to have consistent colors/meanings across the app | LOW | Bootstrap provides `.btn-primary`, `.btn-secondary`, `.btn-success`, `.btn-danger`, `.btn-warning`, `.btn-info` with semantic colors. Already have bslib + Bootstrap 5. |
| **Icon-action pairing consistency** | Same icon should mean same action everywhere (e.g., download always uses same icon, delete always uses trash) | LOW | FontAwesome already integrated. Need audit of existing icons + policy documentation. |
| **Dark mode compatibility** | All UI elements (buttons, sidebars, tooltips) must be readable in both light/dark themes without manual switching | MEDIUM | Catppuccin Latte/Mocha already exists. Issue #137 (sidebar colors), #139 (abstract buttons) indicate incomplete coverage. CSS specificity conflicts are common pitfall. |
| **Sidebar theming coherence** | Sidebar background/foreground should adapt to theme automatically using Bootstrap semantic classes | MEDIUM | bslib `sidebar()` supports `bg` parameter. Issue #137 suggests current implementation doesn't follow theme variables. Need to use `bg-body-secondary` not hardcoded colors. |
| **AI output disclaimers** | Users expect warnings when content is AI-generated (research integrity concern) | LOW | Already implemented in v2.1 (SYNTH-05). Table stake for new presets. |
| **Structured output format** | Research synthesis presets should output structured, scannable formats (tables, lists, sections) not walls of text | MEDIUM | Literature Review Table preset (v4.0) validates this. Gap Analysis and Methodology Extractor need similar structure. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Design token system** | Single source of truth for colors/spacing/icons enables fast, consistent theming changes across entire app | MEDIUM | Bootstrap 5.3+ CSS variables + bslib `bs_theme()` provide foundation. Centralized policy in documentation (not just scattered CSS). |
| **Methodology Extractor preset** | Auto-extracts methods sections from papers into structured format (population, intervention, measures, analysis) — saves hours of manual reading | HIGH | Requires section-targeted RAG (already exists in v2.1 SYNTH-03) + structured prompt with PICO/IMRAD framework. NLP research shows 81% accuracy for IMRAD classification. |
| **Gap Analysis Report preset** | Identifies under-researched areas, conflicting findings, and methodological gaps across collection — surfaces novel research opportunities | HIGH | Requires cross-paper synthesis (not just per-paper summarization). Must use PICOS framework (Population, Intervention, Comparison, Outcome, Setting) from systematic review literature. |
| **Adaptive color semantics** | Button/badge colors that respond to context (e.g., retraction=danger, open access=success) without manual CSS | LOW-MEDIUM | Bootstrap semantic classes already support this. Need consistent mapping policy. |
| **Preset icon system** | Each AI preset has consistent icon (already implemented for Overview, Research Questions, Literature Review) reinforcing preset identity | LOW | Already implemented in v2.1 (UIPX-01). Extend to new presets. Differentiator because competitors use generic "AI" icons. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Custom color themes** | Users want to personalize interface with their favorite colors | Breaks accessibility (WCAG contrast), creates maintenance burden for every new component, dilutes brand identity | Offer light/dark mode only with vetted Catppuccin palette. Document rationale: accessibility + maintainability. |
| **Per-preset color customization** | "Let users color-code their presets" | Color already encodes semantic meaning (danger=red, success=green). User colors would conflict with semantic colors creating confusion. | Use preset icons for visual distinction, keep colors semantic. |
| **Global "Regenerate All"** | "Re-run all AI presets at once to update with new papers" | Expensive (LLM costs), slow (sequential API calls), unclear if user wants to update all or just one. Would require complex job queue UI. | Per-preset regenerate buttons (current pattern). Users control costs. |
| **Methodology extraction from all sections** | "Extract methods info from abstract, intro, discussion too" | Methods section is authoritative source. Other sections have informal/incomplete descriptions. Increases false positives. | Section-targeted retrieval focusing on Methods/Materials sections only (existing v2.1 pattern). |
| **Gap analysis on single paper** | "Show me gaps in this one paper" | Gaps are **comparative** — require multiple papers to identify what's missing. Single-paper analysis is just limitations section summarization. | Require minimum 3-5 papers in collection before enabling Gap Analysis preset. Show warning if too few. |
| **Live theme preview** | "Show what sidebar/buttons look like as I adjust theme" | Adds UI complexity, slows down settings page, users rarely customize beyond light/dark toggle. | Document theme in README with screenshots. Fixed Catppuccin palette means preview isn't needed. |

## Feature Dependencies

```
Design Token System
    └──requires──> Bootstrap 5 CSS Variables (already exists)
    └──requires──> Centralized Theme Documentation (NEW)

Methodology Extractor Preset
    └──requires──> Section-Targeted RAG (exists: v2.1 SYNTH-03)
    └──requires──> Structured Output Prompt Engineering (NEW)
    └──enhances──> Literature Review Table Preset (cross-paper comparison)

Gap Analysis Report Preset
    └──requires──> Section-Targeted RAG (exists: v2.1 SYNTH-03)
    └──requires──> Cross-Paper Synthesis Logic (NEW)
    └──requires──> PICOS Framework Implementation (NEW)
    └──requires──> Minimum Paper Count Check (NEW: ≥3 papers)

Sidebar Dark Mode Fix (#137)
    └──requires──> Bootstrap Semantic Color Classes (exists)
    └──conflicts──> Hardcoded Hex Colors (current issue)

Button Theme Harmonization (#139)
    └──requires──> Design Token System (policy for when to use which variant)
    └──requires──> Dark Mode Compatibility (existing Catppuccin palette)

Citation Audit Bug Fixes (#134, #133)
    └──blocks──> All other features (critical bugs)
    └──requires──> No dependencies (just bug fixes)
```

### Dependency Notes

- **Design Token System requires Centralized Documentation:** Bootstrap variables exist, but without documented policy (when to use `btn-primary` vs `btn-secondary`), devs make inconsistent choices. Policy document enables consistent implementation.
- **Methodology Extractor enhances Literature Review Table:** Once methods are extracted as structured data, can feed into comparison matrix showing which studies used which methods (enables methodological gap analysis).
- **Gap Analysis requires minimum paper count:** Gaps are comparative. With <3 papers, can only show limitations (not gaps). UI should disable preset or show warning.
- **Sidebar theme fix conflicts with hardcoded colors:** Current sidebar likely uses `bg="#xxxxxx"` hex values. Must replace with `bg="body-secondary"` Bootstrap semantic classes for automatic dark mode adaptation.
- **Button harmonization requires policy before implementation:** Without deciding "destructive actions = danger, primary actions = primary, secondary actions = secondary", will just move colors around without fixing root problem (inconsistent semantics).

## MVP Definition

### Launch With (v10.0)

Minimum viable product — what's needed to validate theme harmonization + AI synthesis additions.

- [x] **Citation audit bug fixes (#134, #133)** — Critical blockers. Can't ship with broken citation audit feature.
- [ ] **Design token policy document** — Written guidelines for button variants, icon usage, color semantics. Prevents future inconsistency. ~2 hours to write, reference Bootstrap docs + Catppuccin palette.
- [ ] **Sidebar dark mode fix (#137)** — Replace hardcoded colors with Bootstrap semantic classes. ~30 min implementation once policy exists.
- [ ] **Button theming audit + fix (#139)** — Apply design token policy to existing buttons. ~1-2 hours to audit, 1-2 hours to fix.
- [ ] **Methodology Extractor preset (#100)** — First new AI synthesis preset. Validates section-targeted RAG reuse pattern. PICO/IMRAD structured output.
- [ ] **Gap Analysis Report preset (#101)** — Second new AI synthesis preset. More complex (cross-paper synthesis). Validates multi-paper analysis pattern.

### Add After Validation (v10.x)

Features to add once core is working.

- [ ] **Preset icon for Methodology Extractor** — After validating preset works, add icon for visual consistency with other presets. Low priority, doesn't affect functionality.
- [ ] **Preset icon for Gap Analysis Report** — Same as above.
- [ ] **Minimum paper count validation for Gap Analysis** — If users try to run on <3 papers, show helpful error. Can defer until users report confusion.
- [ ] **Methodology comparison matrix** — After Methodology Extractor proven useful, add "Compare Methods Across Papers" feature to Literature Review Table preset. Requires both presets working first.

### Future Consideration (v11+)

Features to defer until product-market fit is established.

- [ ] **Advanced PICOS filtering for Gap Analysis** — Allow users to specify which PICOS dimensions to analyze (e.g., "only show gaps in study populations, not interventions"). Complex UI, unclear if users need granularity.
- [ ] **Methodology extraction confidence scores** — Add "High/Medium/Low confidence" tags to extracted methods based on section text clarity. Requires NLP tuning, unclear value vs noise.
- [ ] **Export Gap Analysis as structured JSON** — For programmatic analysis. Niche use case, Markdown export likely sufficient.
- [ ] **Cross-notebook theme preferences** — Allow users to save theme choices per notebook. Adds complexity, light/dark toggle is sufficient for MVP.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Citation audit bug fixes (#134, #133) | HIGH (blocks existing feature) | LOW (just debugging) | P1 |
| Design token policy document (#138) | HIGH (prevents future bugs) | LOW (~2 hours writing) | P1 |
| Sidebar dark mode fix (#137) | HIGH (visible in every session) | LOW (30 min, policy-dependent) | P1 |
| Button theming audit (#139) | MEDIUM (improves consistency) | MEDIUM (2-4 hours audit + fix) | P1 |
| Methodology Extractor preset (#100) | HIGH (new valuable feature) | HIGH (prompt engineering + structured output) | P1 |
| Gap Analysis Report preset (#101) | HIGH (unique differentiator) | HIGH (complex cross-paper logic) | P1 |
| Preset icons for new presets | LOW (cosmetic only) | LOW (~15 min each) | P2 |
| Min paper count validation | MEDIUM (prevents confusion) | LOW (1 hour) | P2 |
| Methodology comparison matrix | MEDIUM (enhances existing) | MEDIUM (2-3 hours) | P2 |
| Advanced PICOS filtering | LOW (niche power user feature) | HIGH (complex UI + logic) | P3 |
| Methodology confidence scores | LOW (adds noise for unclear gain) | HIGH (NLP tuning) | P3 |
| Gap Analysis JSON export | LOW (niche use case) | MEDIUM (1-2 hours) | P3 |

**Priority key:**
- P1: Must have for v10.0 launch (design system foundation + new presets)
- P2: Should have, add in v10.1 once core validated (enhancements)
- P3: Nice to have, future consideration (power user features)

## Competitor Feature Analysis

Research assistant tools with similar features (based on 2026 web search):

| Feature | Elicit | Paperguide | Our Approach (Serapeum) |
|---------|--------|------------|-------------------------|
| **Methodology Extraction** | Automated data extraction for systematic reviews, focuses on screening + extraction | "Deep Research AI" with methodology field in literature tables | Section-targeted RAG with PICO/IMRAD framework prompts. Differentiator: reuses existing RAG infrastructure (v2.1), doesn't require new embedding strategy. |
| **Gap Analysis** | Not explicitly mentioned | Not explicitly mentioned | **Unique differentiator.** Uses PICOS framework from systematic review methodology. Cross-paper synthesis not just per-paper summarization. |
| **Structured Output** | Organizes into structured formats | Structured literature tables with TLDR, methodology, findings, limitations fields | Literature Review Table (v4.0) already implements comparison matrix. New presets follow same pattern (tables/lists not prose). |
| **AI Disclaimers** | Not mentioned in sources | Not mentioned in sources | **Differentiator.** Explicit AI-generated content warnings (v2.1 SYNTH-05). Research integrity focus. |
| **Dark Mode** | Not mentioned | Not mentioned | Catppuccin Latte/Mocha with WCAG AA contrast (v6.0). Issue #137 shows incomplete coverage (gap to fix in v10.0). |
| **Theme Consistency** | Not applicable (web apps, different tech stack) | Not applicable | **Unique challenge:** R/Shiny + bslib + Bootstrap 5 + custom Catppuccin palette. Design token system addresses this at architecture level. |

**Key Insight:** Elicit and Paperguide focus on automation scale (125M+ papers). Serapeum focuses on **local-first**, **quality synthesis**, and **transparent AI usage**. Gap Analysis Report and explicit AI disclaimers are clear differentiators. Methodology Extractor is table stakes (competitors have it), but our implementation leveraging existing section-targeted RAG is simpler.

## Implementation Notes

### Design Token System

**What to include in policy document:**

1. **Button Variant Semantics** (from Bootstrap docs):
   - `btn-primary`: Primary action (e.g., "Search", "Generate", "Save")
   - `btn-secondary`: Secondary/alternative action (e.g., "Cancel", "Back")
   - `btn-success`: Positive confirmation (e.g., "Confirm Import", "Apply Filter")
   - `btn-danger`: Destructive action (e.g., "Delete Notebook", "Remove Paper", "Clear All")
   - `btn-warning`: Caution action (e.g., "Overwrite", "Force Sync")
   - `btn-info`: Informational action (e.g., "Learn More", "View Details")
   - `btn-outline-*`: Low-emphasis variant of above (use for tertiary actions)

2. **Icon Consistency Map** (FontAwesome):
   - Download: `fa-download`
   - Delete/Remove: `fa-trash`
   - Edit: `fa-edit` or `fa-pencil`
   - Search: `fa-search`
   - Filter: `fa-filter`
   - Settings: `fa-cog`
   - Export: `fa-file-export`
   - Import: `fa-file-import`
   - Info: `fa-info-circle`
   - Warning: `fa-exclamation-triangle`
   - Success: `fa-check-circle`
   - Preset-specific icons (already defined in v2.1): `fa-list-ul` (Overview), `fa-question-circle` (Research Questions), `fa-table` (Literature Review Table), `fa-lightbulb` (Conclusions Synthesis)

3. **Color Semantic Classes** (Bootstrap + bslib):
   - Background: `bg-body`, `bg-body-secondary`, `bg-body-tertiary` (auto-adapts to theme)
   - Text: `text-body`, `text-body-secondary`, `text-muted` (auto-adapts)
   - Borders: `border-secondary`, `border-tertiary`
   - Badges: `badge bg-success` (open access), `badge bg-danger` (retracted), `badge bg-warning` (predatory journal)
   - **Never hardcode hex colors in component code** — use Bootstrap semantic classes or bslib theme variables

4. **Sidebar Theming** (bslib):
   - Use `sidebar(bg = "body-secondary")` not `sidebar(bg = "#f5e0dc")`
   - Foreground color auto-adapts from `bs_theme(fg = ...)`
   - Border color auto-adapts from Bootstrap border utilities

**Pitfalls to document:**

- **CSS specificity conflicts:** Bootstrap CSS loaded after custom CSS will override. Solution: Use `bs_add_rules()` to inject custom CSS after Bootstrap compilation.
- **Component inconsistency:** Some Bootstrap components (e.g., `text-bg-{color}`) don't fully support dark mode. Solution: Test all components in both themes, file issues, use workarounds (e.g., explicit dark mode overrides via `bs_add_rules()`).
- **Hardcoded colors breaking theme switching:** If any component uses `style="background-color: #xxxxxx"`, it won't adapt to theme changes. Solution: Audit all components, replace with Bootstrap classes.

### Methodology Extractor Preset

**Structured output format** (based on PICO/IMRAD research):

```markdown
## Methodology Overview

**Study Design:** [Experimental, observational, survey, meta-analysis, etc.]

**Population/Sample:**
- Participants: [N, demographics, inclusion/exclusion criteria]
- Setting: [Where study was conducted]

**Intervention/Exposure:**
- [What was manipulated or observed]

**Comparison/Control:**
- [Control group, baseline, or comparison condition]

**Outcomes/Measures:**
- Primary: [Main dependent variables]
- Secondary: [Additional measures]

**Analysis Methods:**
- Statistical tests: [t-test, ANOVA, regression, etc.]
- Software: [R, SPSS, Python, etc.]
- Corrections: [Multiple comparison correction, etc.]

**Limitations Noted:**
- [Author-reported limitations from methods/discussion sections]
```

**Implementation approach:**

1. Reuse section-targeted RAG from v2.1 (SYNTH-03) with `section_hints = c("method", "material", "procedure")`
2. Prompt engineering: Include correct/wrong examples (v7.0 SLIDE-03 pattern showed 8/8 success rate with concrete examples)
3. Structured output: Use markdown headers/lists like Literature Review Table (v4.0), not prose
4. Add to preset dropdown in UI, follow existing preset pattern
5. Include AI disclaimer banner (v2.1 SYNTH-05 pattern)

**Complexity drivers:**
- Prompt engineering for consistent structure across different paper styles (experimental vs observational vs review)
- Handling papers that don't follow IMRAD structure (e.g., some computer science papers)
- Determining when to say "Not reported" vs inferring from other sections

### Gap Analysis Report Preset

**Structured output format** (based on PICOS framework for systematic reviews):

```markdown
## Research Gap Analysis

**Papers Analyzed:** [N papers]

---

### Population Gaps

**Well-Studied Populations:**
- [Demographics/groups with strong evidence base]

**Under-Studied Populations:**
- [Demographics/groups with limited research]

**Rationale:** [Why these gaps matter]

---

### Methodological Gaps

**Common Approaches:**
- [Dominant study designs: e.g., "80% observational, 20% experimental"]

**Missing Approaches:**
- [Study designs not represented: e.g., "No longitudinal studies"]

**Rationale:** [Why these gaps matter]

---

### Outcome Gaps

**Well-Measured Outcomes:**
- [Outcomes frequently studied]

**Under-Measured Outcomes:**
- [Outcomes rarely studied despite relevance]

**Rationale:** [Why these gaps matter]

---

### Conflicting Findings

**Area:** [Topic with disagreement]
**Papers:** [Citation count with conflicting results]
**Nature of Conflict:** [What contradicts what]
**Potential Explanation:** [Methodological differences, population differences, etc.]

---

### Future Research Directions

1. [Specific research question based on identified gap]
2. [Another research question]
3. [Another research question]
```

**Implementation approach:**

1. Reuse section-targeted RAG but query **all sections** (not just methods) — need intro (research questions), discussion (limitations, future work)
2. Cross-paper synthesis logic: Generate intermediate summaries per paper, then meta-summary identifying patterns/gaps
3. Minimum paper count check: Show warning if <3 papers ("Gap analysis requires multiple papers for comparison. Add more papers to this notebook.")
4. PICOS framework prompt engineering with examples
5. Follow existing preset pattern (dropdown, disclaimer banner, export)

**Complexity drivers:**
- Cross-paper synthesis (not just per-paper retrieval) — may require multiple RAG queries + LLM calls
- Distinguishing "limitations" (author-reported weaknesses) from "gaps" (missing across literature)
- Avoiding false gaps (e.g., claiming "no studies on X" when collection is just narrow)
- Cost management (multiple LLM calls for synthesis) — may need cost warning in UI

**Key decision: Sequential vs parallel synthesis?**
- **Sequential:** Query each paper → intermediate summary → final meta-analysis. More LLM calls, higher cost, more controllable.
- **Parallel:** Query all papers at once, LLM synthesizes in single call. Cheaper, but may hit token limits with large collections.
- **Recommendation:** Start with sequential (matches existing preset pattern of one LLM call per preset), optimize to parallel if users report speed issues.

## Sources

**UI Design Systems & Theming:**
- [UI Color Palette 2026: Best Practices (IxDF)](https://ixdf.org/literature/article/ui-color-palette)
- [Modern App Colors: Design Palettes That Work In 2026 (WebOsmotic)](https://webosmotic.com/blog/modern-app-colors/)
- [Bootstrap Buttons · Bootstrap v5.3](https://getbootstrap.com/docs/5.3/components/buttons/)
- [Color modes · Bootstrap v5.3](https://getbootstrap.com/docs/5.3/customize/color-modes/)
- [bslib Theming Documentation](https://rstudio.github.io/bslib/articles/theming/index.html)
- [bslib Sidebars Documentation](https://rstudio.github.io/bslib/articles/sidebars/index.html)
- [Font Awesome Icon Design Guidelines](https://docs.fontawesome.com/web/add-icons/upload-icons/icon-design/)
- [Design Tokens That Scale in 2026 (Mavik Labs)](https://www.maviklabs.com/blog/design-tokens-tailwind-v4-2026)
- [CSS Variables Guide: Design Tokens & Theming (FrontendTools)](https://www.frontendtools.tech/blog/css-variables-guide-design-tokens-theming-2025)

**Methodology Extraction & Research Synthesis:**
- [11 Best AI Tools for Scientific Literature Review in 2026 (Cypris)](https://www.cypris.ai/insights/11-best-ai-tools-for-scientific-literature-review-in-2026)
- [Elicit: AI for scientific research](https://elicit.com/)
- [Paperguide: The AI Research Assistant](https://paperguide.ai/)
- [Use of deep learning-based NLP models for full-text data elements extraction (Nature Scientific Reports)](https://www.nature.com/articles/s41598-025-03979-5)
- [Automated generation of research workflows from academic papers (ScienceDirect)](https://www.sciencedirect.com/science/article/abs/pii/S175115772500094X)
- [Structure of a Research Paper: IMRaD Format (UMN Libraries)](https://libguides.umn.edu/StructureResearchPaper)
- [Discovering IMRaD Structure with Different Classifiers (Semantic Scholar)](https://www.semanticscholar.org/paper/Discovering-IMRaD-Structure-with-Different-Ribeiro-Yao/be2ef84f950edf665924cbb7d24545eeb319dffd)

**Gap Analysis & Systematic Review Methodology:**
- [Framework for Determining Research Gaps During Systematic Review (NCBI)](https://www.ncbi.nlm.nih.gov/books/NBK126702/)
- [Methodology for mapping reviews, evidence maps, and gap maps (Research Synthesis Methods - Cambridge)](https://www.cambridge.org/core/journals/research-synthesis-methods/article/methodology-for-mapping-reviews-evidence-maps-and-gap-maps/9C0C51FF65DC0D8D52CB616B08B0F986)
- [Literature Gap and Future Research (National University LibGuides)](https://resources.nu.edu/researchprocess/literaturegap)
- [Gaps in the Literature (UNE Library Services)](https://library.une.edu/research-help/help-with/gaps-in-the-literature/)
- [Data Extraction for Systematic Reviews (UNC LibGuides)](https://guides.lib.unc.edu/systematic-reviews/extract-data)
- [Data extraction and comparison for complex systematic reviews (Springer Systematic Reviews)](https://link.springer.com/article/10.1186/s13643-023-02322-1)

**AI Interface Design Patterns:**
- [Design Patterns For AI Interfaces (Smart Interface Design Patterns)](https://smart-interface-design-patterns.com/articles/ai-design-patterns/)
- [Design Patterns For AI Interfaces — Smashing Magazine](https://www.smashingmagazine.com/2025/07/design-patterns-ai-interfaces/)

**Bootstrap & Dark Mode Pitfalls:**
- [Most components don't support theme/dark mode changes · Bootstrap Issue #37976](https://github.com/twbs/bootstrap/issues/37976)
- [How To Override Bootstrap 5 CSS Styles? (ThemeSelection)](https://themeselection.com/override-bootstrap-css-styles/)

---
*Feature research for: Research Assistant UI Design System & AI Synthesis Presets (v10.0)*
*Researched: 2026-03-04*
*Confidence: MEDIUM-HIGH (Bootstrap/bslib docs are authoritative HIGH; AI tool features from web search MEDIUM; gap analysis methodology from systematic review literature HIGH)*
