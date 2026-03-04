# Pitfalls Research

**Domain:** Adding global design system + AI synthesis presets to existing R/Shiny research assistant
**Researched:** 2026-03-04
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: CSS Specificity Wars — !important Cascade Hell

**What goes wrong:**
Custom CSS rules intended to enforce the global design system fail to override existing Bootstrap/bslib styles, leading developers to use `!important` repeatedly. This creates a cascade of specificity conflicts where each fix requires higher specificity, eventually making the CSS unmaintainable. Dark mode overrides break, component theming becomes unpredictable, and seemingly unrelated changes cause visual regressions across modules.

**Why it happens:**
Bootstrap compiles Sass variables at build time with high specificity. When adding design system rules post-compilation via `bs_add_rules()`, the new rules have lower specificity unless carefully crafted. Developers reach for `!important` as the quickest fix without understanding the cascade implications. With 18 production modules touching UI elements, each adding their own overrides, specificity conflicts compound exponentially.

**How to avoid:**
1. Use `bs_add_variables()` to set Bootstrap Sass variables BEFORE compilation, not `bs_add_rules()` for runtime CSS injection
2. Leverage Bootstrap semantic classes (`bg-body-secondary`, `bg-body-tertiary`) that adapt to themes automatically
3. When runtime CSS is unavoidable, use selector specificity (`.custom-class .btn-primary`) rather than `!important`
4. Document specificity hierarchy: Bootstrap defaults < theme variables < component overrides < state overrides
5. Audit existing `!important` usage (v6.0 added `!important` for value box text) — replace with proper specificity before adding more

**Warning signs:**
- CSS rules work in isolation but break when other modules load
- Same style defined multiple times with increasing specificity
- Dark mode toggle causes styles to "snap back" to defaults
- Developer tools show 3+ overridden declarations per property
- "It works in light mode but not dark mode" bug reports

**Phase to address:**
Phase 1 (Design System Foundation) — Establish CSS specificity hierarchy and audit existing overrides before touching any module code. Create migration guide: "Bootstrap variable overrides → semantic classes → scoped selectors → never !important"

---

### Pitfall 2: Icon Library Fragmentation — Mixed Visual Languages

**What goes wrong:**
The codebase uses a mix of fontawesome icons and bsicons inconsistently across modules, with some buttons using semantic naming (e.g., `fa("floppy-disk")` for save) while others use visual naming (e.g., `bs_icon("circle-fill")` for status). Adding a global icon policy reveals dozens of inconsistencies: save buttons with different icons, download actions using both `fa("download")` and `bs_icon("cloud-arrow-down")`, or icons chosen based on what library the original developer preferred. Users perceive the app as unpolished; accessibility suffers because semantic meaning is lost.

**Why it happens:**
bslib recommends bsicons as Bootstrap-native, but fontawesome has broader icon coverage (16,000+ vs 2,000+). Developers pick whichever library has the icon they need without checking if an equivalent exists. No icon naming convention exists, so some developers name icons by visual appearance ("circle with X") while others name by semantic meaning ("error indicator"). With 18 modules developed incrementally, no one audited for consistency. Known issue: bsicons requires `tags$i()` wrapper for `nav_panel()` integration (GitHub issue #639).

**How to avoid:**
1. Choose ONE primary icon library for the design system (recommend bsicons for Bootstrap consistency)
2. Document fontawesome as fallback ONLY when bsicons lacks required icon
3. Create `R/icons.R` with semantic wrapper functions: `icon_save()`, `icon_download()`, `icon_error()` that return correct library call
4. Enforce naming convention: icons named by semantic meaning, not visual appearance
5. Audit all existing icon calls: `grep -r "fa(" R/ | wc -l` and `grep -r "bs_icon(" R/ | wc -l` — map each to semantic name
6. Document nav_panel icon integration issue (bsicons requires `tags$i()` wrapper)
7. Always add accessibility: `bslib::tooltip()` for icon-only buttons, `aria-label` attributes

**Warning signs:**
- Same action (e.g., "Export") has different icons across modules
- Icon sizing inconsistent (some 1em, some 1.2em, some raw pixel values)
- Accessibility warnings about missing titles on icon-only buttons
- Git history shows icon swaps: "changed fa() to bs_icon() to match other buttons"
- User feedback: "The UI feels inconsistent"

**Phase to address:**
Phase 1 (Design System Foundation) — Complete icon audit and create semantic wrappers BEFORE touching buttons or sidebar theming. Phase 2+ inherits consistent icons.

---

### Pitfall 3: Module Theme State Desynchronization

**What goes wrong:**
With 18 Shiny modules rendering UI independently, applying the global design system causes theme state mismatches. Module A redraws with new button styling, but Module B still shows old styles because its reactive UI regeneration logic doesn't trigger. When users toggle dark mode, some panels update immediately while others lag or never update. Saved networks load with old tooltip HTML, citation graphs use outdated color schemes, and settings page shows mixed button variants. Users see a "half-migrated" UI, eroding trust.

**Why it happens:**
Shiny modules have independent reactive contexts. If modules cache UI elements or use conditional rendering (`if (initialized) ...`), they won't detect external theme changes. The app sets `bs_theme()` globally, but modules that build UI strings (e.g., visNetwork tooltip_html) don't automatically regenerate when theme changes. With multiple modules calling `renderUI()`, `renderPlot()`, and `htmlwidgets::onRender()`, each needs explicit theme reactivity wiring.

**How to avoid:**
1. Audit all modules for cached UI elements — search for `renderUI()` with conditional logic
2. Make theme reactive using `session$getCurrentTheme()` if supporting dynamic switching
3. For htmlwidgets (visNetwork tooltips), store theme variables in reactive values and regenerate widget on change
4. Test theme consistency by: apply design system → reload saved network → toggle dark mode → check all modules
5. Document modules that CAN'T react to runtime theme changes (e.g., saved tooltip HTML) — plan migration strategy
6. Consider theme version field in database (e.g., `theme_version: 2`) to flag outdated saved content

**Warning signs:**
- "Old tooltips show after network reload" (known: v9.0 fixed old HTML with `strip_llm_yaml()` pattern)
- Dark mode toggle updates navbar but not modal dialogs
- Settings page shows new button style, but search notebook shows old style
- Saved content (networks, chats) renders differently than freshly generated content
- Git blame shows theme changes in `R/app.R` but not in individual `mod_*.R` files

**Phase to address:**
Phase 2 (Button/Sidebar Theming) — After design system foundation is set, audit modules for theme reactivity BEFORE applying new button styles. Phase 3+ can assume consistent propagation.

---

### Pitfall 4: Section-Targeted RAG Brittleness — Keyword Heuristic Failures

**What goes wrong:**
New AI synthesis presets (Methodology Extractor, Gap Analysis Report) rely on section-targeted RAG retrieval to pull relevant chunks. The existing heuristic matches keywords like "method" or "approach" in chunk text to identify methodology sections. This works for standard academic papers but fails on preprints, review articles, or papers with non-standard structure ("Experimental Design", "Study Protocol", "Materials and Procedures"). Presets return generic abstracts instead of methodology details. Gap Analysis retrieves conclusions instead of future work sections. Users get incorrect synthesis outputs, blame the LLM, and lose trust in AI features.

**Why it happens:**
Academic papers lack standardized section headers. IMRAD structure (Intro, Methods, Results, Discussion) is common but not universal. The current heuristic uses content-based matching (check chunk text for keywords), which is more robust than heading-based matching but still brittle. With two new presets targeting different sections (methodology, future work/limitations), the keyword lists grow complex and risk false positives. Known tech debt: section_hint not encoded in PDF ragnar origins (#118), limiting fallback options.

Research shows keyword-based retrieval is brittle for natural language questions and has poor recall for descriptive queries. Static retrievers fail on complex tasks needing iterative lookups. As paper count grows, RAG systems make progressively more mistakes due to distracting information, with error rates increasing ~1% per 5 additional documents.

**How to avoid:**
1. Expand section keyword dictionaries for new preset types: methodology ("method", "approach", "design", "procedure", "protocol", "experimental"), future work ("future work", "future research", "limitations", "gap", "open question", "further research", "remaining challenges")
2. Implement multi-tier retrieval fallback: section-filtered → keyword-boosted unfiltered → direct vector search
3. Test on diverse paper types: journal articles, preprints, reviews, conference papers, non-IMRAD structures
4. Add retrieval diagnostics: log which tier succeeded, how many chunks matched section filter, keyword match confidence
5. Consider ML-based section classifier as future enhancement (out of scope for v10.0, but document limitation)
6. Address #118 (section_hint in PDF origins) during Phase 3 or defer as known limitation with workaround
7. Document retrieval quality in preset disclaimers: "Works best on papers with standard structure"

**Warning signs:**
- Methodology Extractor returns abstract/intro instead of methods
- Gap Analysis Report repeats paper conclusions without identifying gaps
- Retrieval diagnostics show high fallback rates (>30% falling to unfiltered tier)
- Preset quality varies dramatically by paper source (works on Nature, fails on arXiv)
- User feedback: "The methodology summary is just the paper summary again"

**Phase to address:**
Phase 4 (Methodology Extractor Preset) — Develop and test section targeting for methodology BEFORE writing preset prompt. Phase 5 (Gap Analysis Report Preset) reuses and extends the pattern.

---

### Pitfall 5: Prompt Template Coupling — Static Context Bloat

**What goes wrong:**
New AI presets (Methodology Extractor, Gap Analysis Report) duplicate prompt components already present in existing presets (Overview, Research Question Generator, Literature Review Table). Each preset hardcodes instruction-data separation, RAG citation format, paper metadata structure, and output formatting guidelines. When OpenRouter changes API behavior or citation format needs adjustment, developers must update 7 preset prompts identically. Inconsistencies creep in: Gap Analysis uses "Source: [Author, Year]" while Methodology uses "[Author Year]". Maintenance cost scales O(n) with preset count.

**Why it happens:**
Existing preset architecture treats each preset as a monolithic prompt string. No shared prompt component library exists. Developers copy-paste from similar presets and modify the task-specific portion, unintentionally duplicating the boilerplate. Decision log shows standalone `generate_research_questions()` was kept separate from `generate_preset()` due to different prompt structure, suggesting no unified template system. As preset count grows from 5 to 7 (and epic suggests more to come), technical debt compounds.

Research shows this is a common LLM app mistake: ambiguous prompts cause drift and hallucinations, and trying to make one prompt perform multiple tasks degrades all performance. Best practice is structured prompts separating static context from dynamic context with placeholders filled at runtime.

**How to avoid:**
1. Extract shared prompt components into reusable functions: `prompt_header()`, `prompt_rag_context()`, `prompt_citation_format()`, `prompt_safety_constraints()`
2. Presets compose task-specific instructions + shared components: `glue(prompt_header(), task_instructions, prompt_rag_context(), format_spec)`
3. Centralize OWASP instruction-data separation template (v2.1 decision) for all presets
4. Document differences: why Research Question Generator needs paper metadata enrichment but Methodology doesn't
5. Version prompt components: if citation format changes, bump `prompt_citation_format()` version and update all presets
6. Test matrix: each preset × citation format change = automated test verifying format compliance
7. Use prompt template variables with runtime substitution: `{RAG_CONTEXT}`, `{TASK_INSTRUCTIONS}`, `{FORMAT_SPEC}`

**Warning signs:**
- New preset PRs show large prompt string diffs that mostly duplicate existing presets
- Bug fix to citation format requires changes across 5+ files
- Preset outputs show inconsistent citation styles
- Developers write "TODO: make this consistent with other presets" comments
- Prompt length grows unbounded as safety constraints accumulate

**Phase to address:**
Phase 3 (AI Preset Foundation Refactor) — Extract shared components BEFORE adding Methodology and Gap Analysis presets. Phases 4-5 compose presets from components, not monolithic strings.

---

### Pitfall 6: Citation Audit Race Conditions — Multiple Paper Concurrent Writes

**What goes wrong:**
When adding multiple papers to citation audit simultaneously (batch import, multi-select), concurrent database writes cause foreign key constraint violations, duplicate cache entries, or lost audit results. User imports 5 papers, citation audit modal shows "4/5 completed", but database contains partial results for all 5 with corrupt references. Refreshing the page shows missing papers (#133) or duplicate entries. The bug manifests intermittently, frustrating users and making debugging difficult. This is the root cause of #134 (citation audit error when adding multiple papers).

**Why it happens:**
mirai workers run in isolated processes with independent DuckDB connections. v7.0 established pattern: create import_run in main session, pass `db_path` to worker for independent connection. However, citation audit flow likely follows different pattern: create paper entry → launch mirai audit task → write audit results. If multiple papers launch concurrent mirai tasks, workers race to write to `citation_audit_cache` table. DuckDB's file-based locking may not prevent write conflicts across processes. Known tech debt: connection leak in `search_chunks_hybrid()` (#117) and secondary ragnar leak in `ensure_ragnar_store()` suggest connection management discipline issues.

Citation research shows ~20% of citations contain errors, with consistency issues common when managing large bibliographies. Automated tools are prone to matching errors without human review.

**How to avoid:**
1. Batch citation audits: queue papers → single mirai task processes all → write results atomically
2. If per-paper parallelism required, use DuckDB transactions with SERIALIZABLE isolation level
3. Implement retry logic with exponential backoff for constraint violations
4. Add import_run_id to citation_audit_cache to track audit batch provenance
5. Test concurrent writes explicitly: `for i in 1..10; add_paper_$i & done` and verify database integrity
6. Fix connection leaks (#117, #119) BEFORE adding citation audit fixes to prevent compounding issues
7. Consider connection pooling if not already implemented (DuckDB supports single-writer, multiple readers)

**Warning signs:**
- Citation audit completion percentage inconsistent across UI refreshes
- Foreign key constraint errors in logs during batch operations
- Database query shows more rows than expected (duplicates)
- Database query shows fewer rows than expected (lost writes)
- "Paper added but not showing in abstract notebook" (#133) — suggests write lost or FK broken
- Intermittent bugs that pass in isolation but fail under concurrent load

**Phase to address:**
Phase 2 (Citation Audit Bug Fixes) — Audit and fix concurrent write patterns BEFORE touching any citation audit code. Add integration test for multi-paper concurrent audits.

---

### Pitfall 7: Dark Mode Collision — Browser Preference vs. App Toggle

**What goes wrong:**
Users with OS-level dark mode preference enabled visit the app. The app detects `prefers-color-scheme: dark` and applies Catppuccin Mocha theme. User clicks `bslib::input_dark_mode()` toggle to switch to light mode, but some components (custom CSS panels, vis.js canvas) ignore the toggle because they're bound to CSS media query, not app state. The toggle shows "Light" but components remain dark. Browser refresh resets toggle to dark, losing user preference. Users with OS light + app dark preference have no persistence across sessions.

**Why it happens:**
CSS `prefers-color-scheme` media query and JavaScript-driven theme toggles operate independently. User agent preference takes precedence over OS-level preference in the browser's evaluation order. bslib `input_dark_mode()` sets theme via JavaScript, but custom CSS using `@media (prefers-color-scheme: dark)` responds to browser preference, not app state. v6.0 switched from custom JS toggle to `bslib::input_dark_mode()` for thematic integration, but didn't audit all custom CSS. vis.js dark canvas (v6.0: COMP-02) uses rgba borders to work in both modes, which is workaround not true theme reactivity. No localStorage persistence for user preference.

**How to avoid:**
1. Audit ALL CSS for `@media (prefers-color-scheme: dark)` — replace with class-based targeting (`.dark-mode .component`)
2. Use `input_dark_mode(..., mode = "light")` to set default independent of OS preference
3. Add server-side observer for dark mode toggle: `observeEvent(input$dark_mode, { session$setCurrentTheme(...) })`
4. Consider three-mode toggle: "System" (follow OS), "Light", "Dark" — current binary toggle lacks "System" option
5. Test matrix: OS light + app dark, OS dark + app light, toggle during active session, refresh browser
6. Document components that can't reactively switch: saved network tooltips, exported HTML, slide decks
7. Add localStorage persistence: `session$userData$dark_mode_preference <- input$dark_mode` + restore on session start
8. Use priority-based CSS: define custom properties for both themes, wrap dark styles in media query, add `.light-theme` class override inside

**Warning signs:**
- Toggle changes navbar but not modal dialogs or custom panels
- Browser refresh resets toggle state
- "Dark mode toggle doesn't work" but only for users with OS dark mode enabled
- Components using `prefers-color-scheme` media queries in custom CSS
- Git history shows theme detection code removed/replaced without auditing CSS dependencies

**Phase to address:**
Phase 2 (Sidebar/Button Theming) — Audit and fix dark mode reactivity BEFORE applying new theming. Phase 1 should document which components are media-query-bound vs app-state-bound.

---

### Pitfall 8: Connection Leak Amplification — Design System Rendering Load

**What goes wrong:**
Applying the global design system increases UI rendering frequency as modules redraw with new button styles, icon wrappers, and theme variables. Known connection leaks (#117: `search_chunks_hybrid()`, secondary ragnar leak in `ensure_ragnar_store()`) amplify under increased load. Database connections exhaust, app slows to crawl, users see "unable to connect to database" errors. Memory usage climbs steadily across session. The leaks existed before but were manageable at low render frequency; design system refactor triggers them constantly.

**Why it happens:**
Connection leaks occur when database handles aren't closed after use. `search_chunks_hybrid()` leak suggests missing `on.exit(dbDisconnect(con))` pattern. v3.0 established lifecycle management: "Connection lifecycle with on.exit cleanup (TEST-02)", but audit found leaks remain. Design system refactor increases module redraw frequency, calling leaked functions more often. DuckDB is single-writer, so leaked connections block new writes. With async tasks (mirai) creating additional connections (`db_path` pattern), leak impact compounds. DuckDB documentation warns about garbage collection warnings when connections aren't explicitly closed.

**How to avoid:**
1. FIX connection leaks (#117, #119) in Phase 0 or Phase 1 BEFORE any design system work begins
2. Audit all database connection patterns: `grep -r "dbConnect" R/` → verify every call has `on.exit(dbDisconnect(...), add = TRUE)`
3. Audit ragnar store connections: `ragnar::connect_ragnar()` → verify `store@con` always closed
4. Use `DBI::dbDisconnect(store@con)` for S7 ragnar stores (v3.0 decision: "DBI::dbDisconnect(store@con) for S7 objects")
5. Add connection leak detection test: count open connections before/after module render, assert delta = 0
6. Monitor memory usage during development: `pryr::mem_used()` before/after design system rendering
7. Document connection ownership: who opens, who closes, when to use connection pooling
8. Use `dbDisconnect(con, shutdown = TRUE)` for DuckDB to avoid garbage collection warnings

**Warning signs:**
- App performance degrades over session lifetime (slow initially fast operations)
- Database locks preventing writes: "database is locked" errors
- Memory usage climbs without corresponding data growth
- DuckDB warnings about unclosed connections in logs
- Tests fail intermittently with "too many open files" or connection errors
- Git history shows fixes to connection leaks, but new leaks introduced in other modules

**Phase to address:**
Phase 0 (Tech Debt Cleanup) — Fix connection leaks BEFORE Phase 1 design system work. Add leak detection tests to CI.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `!important` in custom CSS | Overrides Bootstrap quickly without understanding specificity | CSS becomes unmaintainable; dark mode breaks; refactoring requires full rewrite | Never — always use proper selector specificity or Bootstrap variables |
| Hardcoding icon calls (`fa("icon")`) in modules | Fast development, no abstraction needed | Icon inconsistency across app; changing icon library requires 100+ line changes | Acceptable for MVP only; refactor to semantic wrappers by v10.0 |
| Copy-paste preset prompts | New preset ships in 1 hour instead of 4 | Maintenance cost scales O(n) with preset count; inconsistencies accumulate | Acceptable until 3rd preset; refactor to component architecture by 4th |
| Module-local theme overrides | Module renders correctly in isolation | Theme desync across modules; dark mode toggle only works in some panels | Never in production — use global theme only |
| Skipping connection leak fixes | Ship design system features faster | App stability degrades; leaks amplify under increased render load; emergency hotfix required | Never — fix leaks before increasing load |
| Deferring section_hint encoding (#118) | PDF ingestion works "well enough" | Section-targeted RAG fallback unavailable; new presets have lower quality | Acceptable if fallback tiers compensate; revisit when RAG quality SLA needed |
| Using `prefers-color-scheme` media queries in custom CSS | Works for users who don't toggle | Toggle ignored by media-query-bound components; user preference lost on refresh | Never after adding `input_dark_mode()` — use class-based targeting |
| Single-tier section keyword matching | Simple heuristic, easy to understand | Brittle across paper structure variations; preset quality inconsistent | Acceptable for MVP if disclaimer warns "works best on standard papers"; add fallback tiers for production |

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| OpenRouter LLM API | Assuming all models accept same prompt structure (instructions vs messages API) | Test each new model with preset prompts; document model-specific quirks (v7.0: Gemini Flash vs Claude Sonnet syntax differences) |
| ragnar vector stores | Treating ragnar store connection as disposable (no cleanup) | Always close store connection: `on.exit(DBI::dbDisconnect(store@con), add = TRUE)` for S7 objects |
| DuckDB async tasks | Sharing connection across main session and mirai workers | Pass `db_path` to worker, create independent connection (v7.0 pattern) |
| bslib theme system | Injecting CSS via `bs_add_rules()` for theme variables | Use `bs_add_variables()` to set Sass variables before compilation; reserve `bs_add_rules()` for truly runtime-specific CSS |
| visNetwork htmlwidget | Expecting widget to reactively update when Shiny theme changes | Store theme variables in reactive values, regenerate entire widget on theme change |
| bsicons in nav_panel | Passing `bs_icon()` directly to `icon` argument | Wrap with `tags$i()`: `icon = tags$i(bs_icon("star"))` (GitHub issue #639) |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Regenerating all module UI on theme change | App lags when toggling dark mode | Only regenerate theme-reactive components; cache static UI elements | >10 modules with complex UI |
| N+1 RAG retrieval calls for multi-section presets | Preset generation takes 5-10 seconds | Batch retrieve all sections in single call; filter/group in-memory | >3 section targets per preset |
| Per-icon render calls without wrapper cache | Button-heavy modules (settings, sidebar) render slowly | Cache icon HTML in module initialization: `icon_cache$save <- bs_icon("save")` | >20 icons per module |
| Individual citation audit API calls | Batch import of 50 papers takes 10+ minutes | Batch audit requests where API supports it; parallelize with rate limiting | >10 papers per import |
| Module-level CSS specificity overrides | CSS file grows unbounded; selectors nest 5+ levels deep | Flatten specificity hierarchy; use Bootstrap utilities and semantic classes | >5000 LOC CSS |
| Section keyword matching on full paper text | RAG retrieval latency increases with paper length | Pre-chunk papers with section boundaries; search within chunk metadata first | Papers >50 pages |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Including RAG retrieved text directly in prompts without delimiter | Prompt injection via malicious paper content | Use OWASP instruction-data separation (v2.1): `<instructions>...</instructions> <data>...</data>` |
| Displaying LLM raw output as HTML without sanitization | XSS via malicious LLM output (code blocks with script tags) | Sanitize LLM output with `commonmark::markdown_html(... extensions = FALSE)` or HTML escaper |
| Storing API keys in app state without encryption | Keys leaked via error messages, logs, or debug dumps | Use `keyring` package; never store in reactiveValues; redact from logs |
| Allowing user-supplied SQL in filters (even indirectly via LLM) | SQL injection via crafted paper metadata | Parameterize all queries; validate LLM filter outputs against allowlist (v1.0 decision) |
| Trusting paper DOIs without validation | Cache poisoning via fake DOI entries | Validate DOI format (`10.xxxx/yyyy`); check OpenAlex response status; handle missing papers gracefully |
| Embedding user content without attribution | Copyright violation, license non-compliance | Store paper license metadata; display attribution in exports; block embedding of retracted papers |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Inconsistent button variants (primary vs secondary) across modules | Cognitive load increases; users unsure which actions are primary | Document button hierarchy in design system: primary (1 per context), secondary (multiple ok), tertiary (destructive); audit all modules |
| Icon-only buttons without tooltips or aria-labels | Screen reader users can't identify button purpose; visual users guess | Always pair icon buttons with tooltip: `bslib::tooltip(actionButton(..., icon = icon_save()), "Save notebook")` |
| Dark mode toggle without persistence | Users must re-toggle every session | Store preference in localStorage or user settings database table |
| AI preset outputs without disclaimers | Users trust incorrect LLM summaries; cite app in papers inappropriately | Add disclaimer header (v2.1): "AI-generated content. Verify accuracy before use." |
| Citation audit errors silently ignored | Users assume audit succeeded, miss critical references | Show error modal with details; log failed DOIs; offer "Retry Failed" button |
| Design system applied gradually (module-by-module) | Users see "half-migrated" UI; perceive app as broken | Apply design system atomically: all modules in single release; feature flag if phased rollout required |
| Methodology Extractor returns abstract when section not found | Users trust wrong content; "Methodology" label misleads | Show retrieval diagnostics: "Could not locate methodology section. Showing abstract." |
| No visual feedback during long-running preset generation | Users think app froze; click button multiple times | Show progress indicator; disable button during generation; display estimated time |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Design System CSS:** Often missing dark mode compatibility — verify all custom CSS works in both Catppuccin Latte and Mocha
- [ ] **Icon Library Migration:** Often missing semantic wrapper functions — verify all icon calls use `icon_*()` wrappers, not raw `fa()` or `bs_icon()`
- [ ] **Button Theming:** Often missing state variants (hover, active, disabled) — verify design system defines all states and all modules implement them
- [ ] **Module Theme Reactivity:** Often missing `session$getCurrentTheme()` wiring — verify modules redraw when dark mode toggles
- [ ] **AI Preset Prompts:** Often missing OWASP instruction-data separation — verify all new presets use delimiter pattern from v2.1
- [ ] **Section-Targeted RAG:** Often missing fallback tiers — verify preset doesn't fail silently when section not found
- [ ] **Citation Audit Concurrency:** Often missing transaction handling or retry logic — verify batch imports don't corrupt database
- [ ] **Connection Lifecycle:** Often missing `on.exit()` cleanup — verify every `dbConnect()` or `connect_ragnar()` has paired cleanup
- [ ] **Accessibility:** Often missing aria-labels or keyboard navigation — verify design system components meet WCAG AA (Catppuccin palette does, but interactive elements need testing)
- [ ] **Export Consistency:** Often missing theme compatibility — verify exported HTML/slides use theme variables, not hardcoded colors

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| CSS specificity wars | HIGH | 1. Audit all `!important` usage; 2. Rebuild CSS using Bootstrap variable overrides; 3. Regression test all modules light+dark; 4. Document specificity hierarchy |
| Icon library fragmentation | MEDIUM | 1. Create icon mapping table (existing → semantic name); 2. Build wrapper functions; 3. Search-replace all calls; 4. Visual regression test |
| Module theme desync | LOW | 1. Add `observeEvent(session$getCurrentTheme(), ...)` to affected modules; 2. Invalidate cached UI elements; 3. Test dark mode toggle |
| Section RAG brittleness | MEDIUM | 1. Add fallback tier retrieval; 2. Expand keyword dictionaries; 3. Test on diverse paper corpus; 4. Add retrieval diagnostics UI |
| Prompt template coupling | HIGH | 1. Extract shared components to functions; 2. Refactor all presets to use components; 3. Test matrix (presets × format changes); 4. Version components |
| Citation audit race conditions | HIGH | 1. Add database transactions with SERIALIZABLE isolation; 2. Implement retry logic; 3. Add integration test for concurrent writes; 4. Check foreign key integrity |
| Dark mode collision | MEDIUM | 1. Replace media queries with class-based selectors; 2. Add localStorage persistence; 3. Set explicit default mode; 4. Test OS preference matrix |
| Connection leak amplification | HIGH | 1. Fix all connection leaks immediately; 2. Add leak detection tests; 3. Monitor memory during CI; 4. Document connection ownership |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| CSS specificity wars | Phase 1: Design System Foundation | All custom CSS uses Bootstrap variables or semantic classes; no `!important` added |
| Icon library fragmentation | Phase 1: Design System Foundation | All icon calls use `icon_*()` wrappers; audit script shows 0 raw `fa()` or `bs_icon()` calls |
| Module theme desync | Phase 2: Button/Sidebar Theming | Dark mode toggle updates all modules; saved content flagged if outdated; no visual regressions |
| Section RAG brittleness | Phase 4: Methodology Extractor | Retrieval diagnostics show <30% fallback rate on test corpus; works on journal + preprint papers |
| Prompt template coupling | Phase 3: AI Preset Foundation Refactor | New presets compose from shared components; citation format change requires 1-file edit |
| Citation audit race conditions | Phase 2: Citation Audit Bugs | Integration test passes: 10 concurrent paper additions result in correct database state |
| Dark mode collision | Phase 2: Sidebar/Button Theming | No components use `prefers-color-scheme` media queries; toggle works regardless of OS preference |
| Connection leak amplification | Phase 0: Tech Debt Cleanup | Leak detection test passes; memory usage stable across 100-module-render session |

## Sources

### R/Shiny and bslib Documentation
- [bslib Theming Documentation](https://rstudio.github.io/bslib/articles/theming/index.html)
- [bslib Dark Mode Input Control](https://rstudio.github.io/bslib/reference/input_dark_mode.html)
- [Shiny Modules Tutorial (datanovia)](https://www.datanovia.com/learn/tools/shiny-apps/advanced-concepts/modules.html)
- [Mastering Shiny: Modules Chapter](https://mastering-shiny.org/scaling-modules.html)
- [Engineering Production-Grade Shiny Apps: Project Structure](https://engineering-shiny.org/structuring-project.html)
- [Shiny - bslib v0.9.0 brings branded theming to Shiny for R](https://shiny.posit.co/blog/posts/bslib-0.9.0/)

### CSS and Design Systems
- [MDN: CSS Specificity](https://developer.mozilla.org/en-US/docs/Web/CSS/Specificity)
- [How To Override Bootstrap 5 CSS Styles (ThemeSelection)](https://themeselection.com/override-bootstrap-css-styles/)
- [Troubleshooting Bootstrap CSS Overrides (Mindful Chase)](https://www.mindfulchase.com/explore/troubleshooting-tips/troubleshooting-bootstrap-css-overrides-fixing-unintended-style-conflicts.html)
- [Design System Naming Conventions (DesignRush)](https://www.designrush.com/best-designs/apps/trends/design-system-naming-conventions)
- [Iconography Guide (designsystems.com)](https://www.designsystems.com/iconography-guide/)
- [Iconography In Design Systems: Troubleshooting And Maintenance (Smashing Magazine)](https://www.smashingmagazine.com/2024/04/iconography-design-systems-troubleshooting-maintenance/)

### Dark Mode Implementation
- [Dark Mode Toggle and prefers-color-scheme (DEV Community)](https://dev.to/abbeyperini/dark-mode-toggle-and-prefers-color-scheme-4f3m)
- [MDN: prefers-color-scheme](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme)
- [The prefers-color-scheme media query (Kau-Boys)](https://kau-boys.com/3958/web-development/the-prefers-color-scheme-media-query)
- [The CSS prefers-color-scheme user query and order of preference (Sara Soueidan)](https://www.sarasoueidan.com/blog/prefers-color-scheme-browser-vs-os/)

### RAG and LLM Prompt Engineering
- [Prompt Engineering for RAG Pipelines (StackAI)](https://www.stackai.com/blog/prompt-engineering-for-rag-pipelines-the-complete-guide-to-prompt-engineering-for-retrieval-augmented-generation)
- [Seven Failure Points When Engineering a RAG System (arXiv)](https://arxiv.org/pdf/2401.05856)
- [Advanced RAG Techniques (Meilisearch)](https://www.meilisearch.com/blog/rag-techniques)
- [Ultimate Prompt Engineering Guide 2026 (Sariful Islam)](https://sarifulislam.com/blog/prompt-engineering-2026/)
- [10 Common LLM Prompt Mistakes (GoInsight.ai)](https://www.goinsight.ai/blog/llm-prompt-mistake/)
- [Towards Understanding Retrieval Accuracy and Prompt Quality in RAG Systems (arXiv)](https://arxiv.org/html/2411.19463v1)

### Testing and Code Quality
- [Testing Legacy Shiny Apps (Jakub Sobolewski)](https://jakubsobolewski.com/blog/testing-legacy-shiny/)
- [How to Write Tests with shiny::testServer (Appsilon)](https://www.appsilon.com/post/how-to-write-tests-with-shiny-testserver)
- [Mastering Shiny: Testing Chapter](https://mastering-shiny.org/scaling-testing.html)

### Database and Async Operations
- [mirai Documentation (CRAN)](https://cran.r-project.org/web/packages/mirai/readme/README.html)
- [A simple workflow for async Shiny with mirai (R-bloggers)](https://www.r-bloggers.com/2024/01/a-simple-workflow-for-async-shiny-with-mirai/)
- [DuckDB Memory Behavior Issue #464](https://github.com/duckdb/duckdb/issues/464)
- [Option to silence warning "Database is garbage-collected" (GitHub Issue #34)](https://github.com/duckdb/duckdb-r/issues/34)

### Citation and Bibliography
- [Citation Errors in Scientific Research (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10307651/)
- [5 Common Citation Mistakes (Sourcely)](https://www.sourcely.net/resources/5-common-citation-mistakes-and-how-to-fix-them-instantly)
- [10 Common Citation Mistakes (Bibliography.com)](https://www.bibliography.com/citations/10-common-citation-mistakes-and-how-to-ensure-you-avoid-them/)

### Icon Libraries
- [Bootstrap 5 icons vs Font Awesome (Themesberg)](https://themesberg.com/blog/bootstrap/bootstrap-icons-vs-fontawesome)
- [bsicons GitHub Issue #639 (nav_panel integration)](https://github.com/rstudio/bslib/issues/639)
- [Font Awesome Accessibility Docs](https://fontawesome.com/v5/docs/web/other-topics/accessibility)

### Project-Specific Context
- Serapeum PROJECT.md (v1.0–v9.0 decision log, known tech debt)
- GitHub issues #117 (connection leak), #118 (section_hint encoding), #119 (dead code), #133 (citation audit papers not appearing), #134 (citation audit error multiple papers), #137 (sidebar colors), #138 (global design system), #139 (abstract buttons)

---
*Pitfalls research for: Adding global design system + AI synthesis presets to existing R/Shiny research assistant*
*Researched: 2026-03-04*
