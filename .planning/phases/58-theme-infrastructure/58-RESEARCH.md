# Phase 58: Theme Infrastructure - Research

**Researched:** 2026-03-19
**Domain:** Quarto RevealJS YAML frontmatter, R file I/O, pipeline threading
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**YAML array syntax**
- When `custom_scss` is NULL (default): emit `theme: default` — single-value, unchanged from current behavior
- When `custom_scss` is provided: emit `theme: [base, custom.scss]` — array form with base theme first, custom .scss second (custom overrides base, per Quarto convention)
- The .scss file listed second takes precedence — this is the documented Quarto behavior
- Custom .scss must use `/*-- scss:defaults --*/` and `/*-- scss:rules --*/` section markers (Quarto requirement)

**Custom .scss path contract**
- New parameter: `build_qmd_frontmatter(title, theme = "default", custom_scss = NULL)`
- The .scss file is copied to `tempdir()` next to the QMD file before rendering — YAML uses a relative filename, not an absolute path
- This avoids machine-specific paths in YAML and keeps the QMD portable

**Pipeline threading**
- Thread `custom_scss` through the full pipeline: `generate_slides()` options -> `build_qmd_frontmatter()` -> file copy to tempdir
- Healing flow (`build_healing_prompt()` / healing render path) also threads `custom_scss` through so healed slides preserve the custom theme
- `mod_slides.R` caller sites updated to pass `custom_scss` (NULL for now — Phase 59 wires in the UI)

### Claude's Discretion
- Exact file copy implementation (file.copy vs fs::file_copy)
- Error handling when .scss file doesn't exist at the provided path
- Whether to validate .scss section markers before copying

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| THME-12 | Custom themes applied via `theme: [base, custom.scss]` in QMD frontmatter | `build_qmd_frontmatter()` modification + file copy to tempdir + pipeline threading documented below |
</phase_requirements>

---

## Summary

Phase 58 is a targeted plumbing change to the slide generation pipeline. The single function that emits YAML frontmatter (`build_qmd_frontmatter` in `R/slides.R`, line 129) needs a new optional `custom_scss` parameter. When provided, it emits `theme: [base, custom.scss]` instead of `theme: default`; when absent, behavior is identical to today. The .scss file must be copied to `tempdir()` alongside the QMD so Quarto can resolve the relative path at render time.

The pipeline has two code paths that call `build_qmd_frontmatter`: the primary generation path (`generate_slides()` line 315) and the healing path in `mod_slides_server` (line 622). Both must thread `custom_scss`. The `mod_slides.R` module assembles `last_options` (line 393–401) and passes that to `generate_slides()` — `custom_scss = NULL` is simply added to that options list now, with real values wired in Phase 59.

The v17 branch (`v17-pdf-image-pipeline`) adds PDF figure extraction and base64 image injection into slide QMD files. That branch's `slides.R` is *more complex* than the current v16 branch. The v16 branch has already stripped figure-related code from both `slides.R` and `mod_slides.R`, so the current baseline is the correct, clean version to modify.

**Primary recommendation:** Modify `build_qmd_frontmatter` to accept `custom_scss`, add a file copy step before QMD write, thread the parameter through `generate_slides()` and the healing re-build in `mod_slides_server`. No UI changes in this phase.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| base R `file.copy()` | built-in | Copy .scss to tempdir | No dependency; already used for QMD file writes in this pipeline |
| `yaml` package | already a dep | Validate YAML after frontmatter build | Already imported via `validate_qmd_yaml()` |

No new package dependencies are required for this phase.

**Installation:** None — all necessary tools already present.

---

## Architecture Patterns

### Existing Project Structure (relevant files)

```
R/
├── slides.R           # build_qmd_frontmatter(), generate_slides(), heal_slides()
├── mod_slides.R       # mod_slides_server() — assembles options list, calls generate_slides()
tests/testthat/
└── test-slides.R      # Unit tests for build_qmd_frontmatter, validate_qmd_yaml, etc.
```

### Pattern 1: build_qmd_frontmatter — current shape

`build_qmd_frontmatter(title, theme = "default")` builds YAML via `paste0()` string concatenation (v7.0 decision — no LLM-generated YAML). The current theme line at line 160 is:

```r
"    theme: ", theme_val, "\n",
```

When `custom_scss` is provided, this line becomes:

```r
"    theme: [", theme_val, ", ", basename(custom_scss), "]\n",
```

`basename()` extracts just the filename (e.g., `my-theme.scss`), because the file is copied to `tempdir()` alongside the QMD so Quarto resolves it by relative name.

### Pattern 2: File copy before QMD write

In `generate_slides()`, after building `frontmatter` and before writing `qmd_path`:

```r
# Copy custom .scss to tempdir so relative path resolves
if (!is.null(custom_scss)) {
  scss_dest <- file.path(tempdir(), basename(custom_scss))
  if (!file.copy(custom_scss, scss_dest, overwrite = TRUE)) {
    warning("Failed to copy custom .scss file: ", custom_scss)
  }
}
```

This keeps the QMD portable — the YAML references only `my-theme.scss`, not an absolute path.

### Pattern 3: Threading through options list

The `generate_slides()` function already receives `options` as a named list. `options$theme` is extracted at line 314. Adding `options$custom_scss %||% NULL` follows the established pattern exactly.

`mod_slides.R` builds `generation_state$last_options` at lines 393–401:

```r
generation_state$last_options <- list(
  model = input$model,
  length = input$length,
  audience = input$audience,
  citation_style = input$citation_style,
  include_notes = input$include_notes,
  theme = input$theme,
  custom_scss = NULL,           # Phase 59 wires in real value from UI
  custom_instructions = input$custom_instructions
)
```

The healing path in `mod_slides_server` (lines 621–622) also calls `build_qmd_frontmatter` directly:

```r
theme <- generation_state$last_options$theme %||% "default"
frontmatter <- build_qmd_frontmatter(title, theme)
```

This must be updated to:

```r
theme <- generation_state$last_options$theme %||% "default"
custom_scss <- generation_state$last_options$custom_scss
# Re-copy .scss to tempdir for healed render
if (!is.null(custom_scss)) {
  file.copy(custom_scss, file.path(tempdir(), basename(custom_scss)), overwrite = TRUE)
}
frontmatter <- build_qmd_frontmatter(title, theme, custom_scss)
```

### Pattern 4: render_qmd_to_html — working directory

The current v16 branch does NOT set `wd = dirname(qmd_path)` when calling `processx::run()` for Quarto (that line was removed vs. v17). The tempdir approach means both the QMD and the .scss file are in the same directory (`tempdir()`), so Quarto will resolve the relative path correctly as long as QMD and .scss are co-located — no `wd` change is needed.

### Anti-Patterns to Avoid

- **Absolute .scss path in YAML:** Do not put the full file system path in the `theme:` field. Machine-specific paths break portability and Quarto will emit a confusing error if the path contains spaces or Windows backslashes.
- **Skipping the file copy in the healing path:** The healing path in `mod_slides_server` re-calls `build_qmd_frontmatter` independently. If the .scss file is only copied in `generate_slides()`, it will be missing when Quarto re-renders after healing.
- **Quoting the array in YAML:** The correct Quarto syntax is `theme: [default, custom.scss]` — no quotes around the array. Quotes around the whole value (`theme: "[default, custom.scss]"`) would make Quarto treat it as a string, not an array.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML array serialization | Custom string formatter | `paste0("theme: [", base, ", ", scss_name, "]")` | Simple two-element array — no library needed, consistent with rest of frontmatter builder |
| File existence validation | Complex pre-flight check | `tryCatch(file.copy(...))` with `warning()` | Phase 58 is plumbing; strict validation belongs in Phase 59 when UI supplies the path |
| .scss section marker validation | Regex scan of file contents | Deferred per CONTEXT.md discretion | Phase 59 can add validation when themes are user-uploaded |

---

## Common Pitfalls

### Pitfall 1: YAML array vs. scalar — breaking the default path

**What goes wrong:** After adding the `custom_scss` branch, the `theme_val` scalar path (`"    theme: ", theme_val, "\n"`) must remain untouched when `custom_scss` is NULL. A simple `if/else` on the theme line handles this, but it is easy to accidentally always emit the array form.

**How to avoid:** The condition is `!is.null(custom_scss)`, not `!is.null(custom_scss) && nchar(custom_scss) > 0`. Use the null check. Existing test `build_qmd_frontmatter produces valid YAML with theme and CSS` already verifies `theme: moon` for the scalar case — run it to confirm no regression.

### Pitfall 2: .scss filename collisions in tempdir

**What goes wrong:** If two notebooks both use a file called `custom.scss`, the second copy would overwrite the first in `tempdir()`. This is fine for sequential renders but would be a problem for concurrent sessions.

**How to avoid:** `file.copy(..., overwrite = TRUE)` is correct for single-user local-first app. No change needed for Phase 58. Future phases can namespace by session if needed.

### Pitfall 3: Forgetting the healing code path

**What goes wrong:** `generate_slides()` copies the .scss and passes it to `build_qmd_frontmatter`, but the healing re-build in `mod_slides_server` at line 622 calls `build_qmd_frontmatter` independently. If the healing path is not updated, healed slides lose the custom theme.

**How to avoid:** The healing path is in `mod_slides_server` at lines 618–623 — explicitly update this block as part of the same task that updates `generate_slides()`.

### Pitfall 4: v17 branch confusion

**What goes wrong:** The v17 branch (`v17-pdf-image-pipeline`) has a more complex `slides.R` with figure injection, base64 encoding, and a `wd =` argument to `render_qmd_to_html`. Applying v17 patterns (like `wd = dirname(qmd_path)`) to the v16 branch would be incorrect — those were reverted on this branch.

**How to avoid:** Work only against `R/slides.R` and `R/mod_slides.R` on the current `gsd/phase-57-citation-traceability` branch. Do not cherry-pick from v17.

---

## Code Examples

### Current build_qmd_frontmatter (lines 129–167 of R/slides.R)

The theme line to modify is at line 160:

```r
"    theme: ", theme_val, "\n",
```

### Target signature

```r
build_qmd_frontmatter <- function(title, theme = "default", custom_scss = NULL) {
  theme_val <- if (is.null(theme) || theme == "default") "default" else theme

  theme_line <- if (!is.null(custom_scss)) {
    paste0("    theme: [", theme_val, ", ", basename(custom_scss), "]\n")
  } else {
    paste0("    theme: ", theme_val, "\n")
  }

  paste0(
    "---\n",
    "title: \"", gsub('"', '\\\\"', title), "\"\n",
    "format:\n",
    "  revealjs:\n",
    "    embed-resources: true\n",
    theme_line,
    "    smaller: true\n",
    # ... rest unchanged
    "---\n"
  )
}
```

### Quarto RevealJS theme array syntax (confirmed from Quarto docs)

```yaml
format:
  revealjs:
    theme: [default, custom.scss]
```

The second file takes precedence. Quarto processes them in order: base theme first, custom overrides second.

### Custom .scss file structure (required markers)

```scss
/*-- scss:defaults --*/
$body-bg: #1e1e2e;
$body-color: #cdd6f4;
$link-color: #89b4fa;

/*-- scss:rules --*/
.reveal h2 {
  color: #cba6f7;
}
```

Source: Quarto RevealJS themes documentation — https://quarto.org/docs/presentations/revealjs/themes.html

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| LLM-generated YAML (risk of injection) | Programmatic `build_qmd_frontmatter()` via `paste0()` | v7.0 | Safe, controlled YAML; Phase 58 modification is safe |
| Single theme string | Array `theme: [base, custom.scss]` | This phase | Enables custom theme overrides |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat (version from project) |
| Config file | `tests/testthat.R` |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-slides.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THME-12 | `build_qmd_frontmatter(title, theme, custom_scss)` emits `theme: [base, custom.scss]` when `custom_scss` provided | unit | `Rscript -e "testthat::test_file('tests/testthat/test-slides.R')"` | ✅ (add new tests to existing file) |
| THME-12 | Default behavior unchanged — `custom_scss = NULL` emits `theme: default` | unit | same | ✅ (existing test covers scalar form; verify still passes) |
| THME-12 | .scss file copied to tempdir alongside QMD | unit | same | ❌ Wave 0 — new test needed |
| THME-12 | `validate_qmd_yaml()` parses the array-form theme YAML without error | unit | same | ❌ Wave 0 — new test needed |

### Sampling Rate

- **Per task commit:** `Rscript.exe -e "testthat::test_file('tests/testthat/test-slides.R')"`
- **Per wave merge:** `Rscript.exe -e "testthat::test_dir('tests/testthat')"`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] New test: `build_qmd_frontmatter with custom_scss emits array theme` — covers THME-12 array syntax
- [ ] New test: `build_qmd_frontmatter with custom_scss uses basename only` — verifies portability (no absolute path in YAML)
- [ ] New test: `generate_slides copies scss to tempdir` — mocks `file.copy`, verifies it's called with correct args

*(Existing `test-slides.R` covers the scalar theme case — no new file needed, append to existing.)*

---

## Sources

### Primary (HIGH confidence)

- Quarto RevealJS Themes documentation — https://quarto.org/docs/presentations/revealjs/themes.html — array syntax, .scss section markers
- `R/slides.R` source (read directly) — `build_qmd_frontmatter` current implementation, `generate_slides` options threading
- `R/mod_slides.R` source (read directly) — `generation_state$last_options` structure, healing path at lines 618–623
- `tests/testthat/test-slides.R` source (read directly) — existing test coverage for `build_qmd_frontmatter`

### Secondary (MEDIUM confidence)

- Git diff of v17 branch (`v17-pdf-image-pipeline`) vs. v16 — confirms v16 is the clean baseline without figure-injection complexity; confirms `render_qmd_to_html` does NOT set `wd` on v16

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all patterns verified from source code
- Architecture: HIGH — read actual implementation; exact line numbers cited
- Pitfalls: HIGH — identified from code inspection and v17 diff review

**Research date:** 2026-03-19
**Valid until:** 2026-04-18 (stable domain — R/Quarto patterns do not change rapidly)
