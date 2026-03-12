# Quarto Slide Generation - Design Document

> Generate presentation slides from document notebook content using Quarto RevealJS

## Overview

A feature within document notebooks that generates presentation slide decks from selected PDFs. Users configure length, audience, citation style, and other options. The system uses an LLM to synthesize content into structured slides, then renders them via Quarto for preview and export.

**Key capabilities:**
- Select specific documents from a notebook to include
- Detailed configuration: length, audience, citations, themes, custom instructions
- Model selection for generation (allows using stronger models for this task)
- In-app preview of rendered slides
- Export to `.qmd`, HTML, or PDF

## User Interface

### Entry Point

A "Generate Slides" button in the document notebook toolbar, alongside existing preset buttons (Summarize, Key Points, etc.). Disabled if the notebook contains no documents.

### Modal Dialog

Clicking "Generate Slides" opens a modal with three sections:

**1. Document Selection**
- Checklist of all documents in the notebook
- Checkboxes to select which PDFs to include
- "Select All" toggle for convenience

**2. Configuration Options**

| Option | Type | Values |
|--------|------|--------|
| Model | Dropdown | Available OpenRouter chat models (defaults to current notebook model) |
| Length | Radio | Short (5-8 slides), Medium (10-15 slides), Long (20+ slides) |
| Audience | Dropdown | Technical, Executive, General/Educational |
| Citation style | Dropdown | Footnotes, Inline parenthetical, Speaker notes only, None |
| Speaker notes | Checkbox | Default: checked |
| Theme | Dropdown | RevealJS themes (default, moon, night, serif, simple, etc.) |
| Custom instructions | Text area | Optional free-form guidance |

**3. Actions**
- "Generate" button triggers the process
- Progress indicator during generation

### Results View

After generation:
- **Preview panel**: Rendered slides in an iframe, navigable
- **Export buttons**: Download .qmd | Download HTML | Download PDF
- **Regenerate button**: Modify options and regenerate without closing modal

## Generation Pipeline

### Step 1: Content Retrieval

Fetch all chunks from selected documents. Unlike chat (similarity search), slide generation needs comprehensive coverage:
- Retrieve all chunks for each selected document
- Order by page number and chunk index
- Retain metadata (document name, page number) for citations

### Step 2: Content Assembly

Group chunks by source document into structured context. If total content exceeds model context window:
1. Prioritize beginning and end of each document
2. Use embeddings to select diverse representative chunks from middle sections
3. Show warning to user about sampling

### Step 3: Prompt Construction

Build structured prompt containing:
- Assembled content with source markers
- User configuration (length, audience, citation style, etc.)
- Custom instructions if provided
- Output format requirements (valid Quarto RevealJS markdown)

### Step 4: LLM Generation

- Send prompt to selected model via OpenRouter
- Stream response back
- Validate output is valid Quarto markdown
- If malformed, attempt single repair pass

### Step 5: Post-Processing

- Inject selected theme into YAML frontmatter
- Validate citation markers against source documents
- Save to temporary location for preview/export

## Output Format

Generated `.qmd` files follow this structure:

```yaml
---
title: "Presentation Title"
format:
  revealjs:
    theme: {selected-theme}
    slide-number: true
    footer: "Generated from {notebook-name}"
---
```

Followed by markdown slides using:
- `#` for section titles (horizontal separator)
- `##` for individual slides
- `::: {.notes}` blocks for speaker notes

### File Naming

Exports use: `{notebook-name}-slides.{ext}`

Example: `ML-Papers-slides.qmd`, `ML-Papers-slides.html`

## Technical Implementation

### New Files

| File | Purpose |
|------|---------|
| `R/mod_slides.R` | Shiny module: modal UI, configuration form, export actions |
| `R/slides.R` | Core functions: prompt building, content assembly, Quarto rendering |

### Dependencies

**System requirement:** Quarto CLI (1.3+) must be installed. Not an R package.
- Feature disabled with helpful message if Quarto not found
- Version check on startup; warning for older versions

**No new R packages required:**
- `httr2` — existing, for OpenRouter calls
- `processx` — existing, for running Quarto CLI

### Integration Points

| Location | Change |
|----------|--------|
| `mod_document_notebook.R` | Add "Generate Slides" button launching modal |
| `db.R` | Add helper to fetch all chunks for specific documents |
| `api_openrouter.R` | Reuse existing chat completion functions |

### Temporary Files

- Generated `.qmd` and rendered outputs stored in `tempdir()`
- Cleaned up on session end
- No persistent storage of generated slides in v1

### Quarto Execution

```r
processx::run(
  "quarto",
  c("render", qmd_path, "--to", format),
  timeout = 120
)
```

Errors captured and displayed to user. Timeout prevents hung renders.

## Error Handling

| Scenario | Response |
|----------|----------|
| Quarto not installed | Feature disabled, message in UI explaining how to install |
| Quarto render fails | Show error, offer `.qmd` download anyway for local debugging |
| Model returns invalid markdown | Attempt one repair pass, then show best-effort result |
| PDF export fails | Suggest downloading HTML and printing from browser |
| Content too large | Sample chunks, show warning about incomplete coverage |
| Document has minimal text | Warn if any selected document has <3 chunks |

## Edge Cases

### Large Documents

If selected documents exceed ~80% of model context:
1. Sample chunks intelligently (intro, conclusion, diverse middle)
2. Display warning about sampling
3. Suggest selecting fewer documents for comprehensive coverage

### Concurrent Generation

- Only one generation per session at a time
- "Generate" button disabled while in progress
- Prevents resource contention

### Theme Availability

Built-in RevealJS themes only (v1):
- default, beige, blood, dark, league, moon, night, serif, simple, sky, solarized

Custom themes out of scope.

## Scope

### In Scope (v1)

- Document notebook integration
- Document selection UI
- Full configuration options (length, audience, citations, notes, theme, custom instructions)
- Model selection for generation
- In-app preview via iframe
- Export: .qmd, HTML, PDF
- Error handling and user feedback

### Out of Scope (v1)

- Search notebook support
- Generation history/persistence
- Custom RevealJS themes
- Image extraction from PDFs
- Collaborative editing of generated slides
- Direct integration with presentation software

### Future Considerations

- Save generation history to database
- Template presets (conference talk, lecture, meeting summary)
- Include figures/images from source PDFs
- Search notebook support for literature review presentations
