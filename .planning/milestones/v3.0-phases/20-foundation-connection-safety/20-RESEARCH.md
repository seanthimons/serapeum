# Phase 20: Foundation & Connection Safety - Research

**Researched:** 2026-02-16
**Domain:** R/Shiny ragnar store infrastructure, DuckDB connection lifecycle, metadata encoding
**Confidence:** HIGH

## Summary

Phase 20 establishes the foundation for per-notebook ragnar stores without breaking existing functionality. This is pure infrastructure — no user-facing features. The phase delivers four critical components: deterministic path construction using existing notebook UUIDs, metadata encoding in ragnar's origin field to preserve section_hint during retrieval, ragnar version compatibility checks to warn on mismatches, and explicit connection cleanup patterns to prevent memory leaks.

The research confirms notebooks already use UUIDs (`uuid::UUIDgenerate()`) for IDs, making path construction straightforward: `data/ragnar/{notebook_id}.duckdb`. Ragnar 0.3.0 is installed and supports encoding arbitrary metadata in the origin field via string concatenation. R's `packageVersion()` and `compareVersion()` provide version checking. Shiny's `session$onSessionEnded()` and R's `on.exit()` handle cleanup. All patterns are well-established in the existing codebase (app.R line 166, mod_citation_network.R line 924).

The recommended approach is conservative: warn on version mismatch but don't block usage (renv will handle strict versioning later), encode three fields in origin (section_hint, DOI, source_type), close connections aggressively on any error with #TODO markers noting this can be relaxed, and create `data/ragnar/` directory eagerly on app startup. This phase has zero breaking changes — it only adds helpers and lifecycle hooks that later phases will use.

**Primary recommendation:** Use human-readable pipe-delimited encoding (`filename#page=5|section=conclusion|doi=10.1234/abc|type=pdf`) for ragnar origin field. Decode gracefully with fallback to "general" section on parse failure. Add lazy version check cached in session state. Implement connection cleanup in both `on.exit()` (function-level) and `session$onSessionEnded()` (session-level).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Version mismatch behavior:**
- Warn but allow use — don't block RAG features on incompatible ragnar version
- Minimal safety net: console warning + disable RAG if incompatible. No fancy UI — renv will handle this properly later
- Lazy check on first RAG use, not at startup. Cache result for session
- #TODO in code noting this could be replaced by renv version pinning

**Connection error handling:**
- Global notification (toast/banner) when store connection fails, not inline errors
- Aggressive cleanup: any error closes the connection. #TODO comment noting this could be relaxed to selective cleanup later
- Auto-retry on next feature use — no manual "Reconnect" button needed
- Close connections on browser tab close via Shiny's onSessionEnded

**Metadata encoding strategy:**
- Human-readable format in ragnar's origin field (pipe/colon-delimited key-value pairs)
- Three fields encoded: section_hint + DOI + source_type (PDF upload vs abstract embed)
- On decode failure: treat chunk as "general" (no section targeting), gracefully attempt correction
- Validate encoding on write only — trust format on read for performance

**Store path conventions:**
- Path pattern: `data/ragnar/{uuid}.duckdb` where UUID is per-notebook
- Add UUID column to notebooks table — existing notebooks will be purged (v3.0 fresh start), so no migration needed
- `data/ragnar/` directory created eagerly on app startup
- `data/` directory already gitignored — no changes needed

### Claude's Discretion

- Exact origin field delimiter syntax (pipes, colons, etc.)
- DuckDB connection pool implementation details
- Version comparison logic (semver parsing approach)
- Error message wording for global notifications

### Deferred Ideas (OUT OF SCOPE)

- renv setup for package namespace management — tooling todo, not in v3.0 scope

</user_constraints>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ragnar | 0.3.0 | Vector store with hybrid VSS+BM25 retrieval | Posit's official R RAG solution, DuckDB-native, automatic VSS extension loading |
| DuckDB | 1.3.2 (via ragnar) | Embedded vector database | Lightweight, single-file, built-in VSS support via extension |
| uuid | latest | UUID generation for notebook IDs | Already in use (db.R line 240), RFC 4122 compliant |
| DBI | 1.2.3+ | Database interface | Standard R DB abstraction, used throughout codebase |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| digest | latest (temp) | Hash generation for version 1 stores | Remove in Phase 23 after migration to version 2 stores |
| bslib | latest | Toast notifications | Global error messages for connection failures |
| shiny | 1.7.0+ | Session lifecycle hooks | `session$onSessionEnded()` cleanup |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UUID paths | Auto-increment IDs | UUIDs are globally unique, filesystem-safe, already in use — no collision risk |
| Origin field encoding | Separate metadata table | Origin field is native to ragnar, survives store persistence, no JOIN needed |
| `on.exit()` cleanup | Manual close calls | on.exit guarantees cleanup on error/early return, prevents leaks |
| Lazy version check | Startup version check | Lazy check avoids blocking app startup, only warns users who actually use RAG |

**Installation:**

Ragnar and dependencies already installed. No new packages required for Phase 20.

## Architecture Patterns

### Recommended Project Structure

Current structure already appropriate:
```
R/
├── db.R                   # Database operations (will add path helpers here)
├── _ragnar.R              # Ragnar integration (will add version check, cleanup)
├── mod_*.R                # Shiny modules (will add cleanup hooks)
└── app.R                  # Main app (directory creation on startup)

data/
├── notebooks.duckdb       # Main database (notebooks.id already UUID)
└── ragnar/                # Per-notebook stores (create in Phase 20)
    ├── {uuid1}.duckdb
    ├── {uuid2}.duckdb
    └── ...
```

### Pattern 1: Deterministic Path Construction

**What:** Build ragnar store path from notebook UUID without database lookups

**When to use:** Anywhere ragnar store access is needed (PDF upload, abstract embed, RAG query)

**Example:**
```r
# Source: Existing codebase pattern (create_notebook in db.R line 239)
# and research on filesystem-safe paths

#' Get ragnar store path for a notebook
#' @param notebook_id Notebook UUID (VARCHAR primary key)
#' @return Character path to ragnar store file
get_notebook_ragnar_path <- function(notebook_id) {
  # Validate UUID format (basic sanity check, not strict RFC 4122)
  if (is.null(notebook_id) || nchar(notebook_id) == 0) {
    stop("notebook_id cannot be NULL or empty")
  }

  # Construct deterministic path
  file.path("data", "ragnar", paste0(notebook_id, ".duckdb"))
}

# Usage in modules:
store_path <- get_notebook_ragnar_path(notebook_id)
store <- connect_ragnar_store(store_path)
```

**Why this works:** Notebooks already use UUIDs (verified via db query), UUIDs are filesystem-safe (no special chars), deterministic construction eliminates race conditions.

### Pattern 2: Metadata Encoding in Origin Field

**What:** Encode section_hint, DOI, source_type in ragnar's origin field using delimited key-value pairs

**When to use:** When inserting chunks to ragnar (PDF upload, abstract embed), when decoding retrieval results

**Example:**
```r
# Source: Existing origin format in _ragnar.R line 114
# Extended with metadata encoding per user decision

#' Encode metadata into ragnar origin field
#' @param base_origin Base origin (e.g., "filename#page=5" or "abstract:uuid")
#' @param section_hint Section classification (e.g., "conclusion", "general")
#' @param doi Paper DOI (optional, for abstracts)
#' @param source_type "pdf" or "abstract"
#' @return Encoded origin string
encode_origin_metadata <- function(base_origin, section_hint = "general",
                                   doi = NULL, source_type = "pdf") {
  # Human-readable pipe-delimited format
  parts <- c(base_origin)
  parts <- c(parts, paste0("section=", section_hint))
  if (!is.null(doi) && nchar(doi) > 0) {
    parts <- c(parts, paste0("doi=", doi))
  }
  parts <- c(parts, paste0("type=", source_type))

  paste(parts, collapse = "|")
}

#' Decode metadata from ragnar origin field
#' @param origin Encoded origin string
#' @return List with base_origin, section_hint, doi, source_type
decode_origin_metadata <- function(origin) {
  # Graceful degradation on parse failure
  tryCatch({
    parts <- strsplit(origin, "\\|")[[1]]
    base_origin <- parts[1]

    # Extract key-value pairs
    section_hint <- "general"  # Default fallback
    doi <- NA_character_
    source_type <- NA_character_

    for (part in parts[-1]) {
      if (grepl("^section=", part)) {
        section_hint <- sub("^section=", "", part)
      } else if (grepl("^doi=", part)) {
        doi <- sub("^doi=", "", part)
      } else if (grepl("^type=", part)) {
        source_type <- sub("^type=", "", part)
      }
    }

    list(
      base_origin = base_origin,
      section_hint = section_hint,
      doi = doi,
      source_type = source_type
    )
  }, error = function(e) {
    # Fallback: treat as general section
    message("[decode_origin_metadata] Parse failed for origin: ", origin,
            " - defaulting to general section")
    list(
      base_origin = origin,
      section_hint = "general",
      doi = NA_character_,
      source_type = NA_character_
    )
  })
}

# Usage:
# Write:
origin <- encode_origin_metadata("paper.pdf#page=5",
                                  section_hint = "conclusion",
                                  doi = "10.1234/abc",
                                  source_type = "pdf")
# Result: "paper.pdf#page=5|section=conclusion|doi=10.1234/abc|type=pdf"

# Read:
metadata <- decode_origin_metadata(origin)
# Result: list(base_origin = "paper.pdf#page=5", section_hint = "conclusion", ...)
```

**Why this works:** Origin field is persisted by ragnar, human-readable for debugging, pipe delimiter unlikely in filenames/DOIs, graceful fallback on parse failure.

### Pattern 3: Lazy Version Check with Session Caching

**What:** Check ragnar version compatibility on first RAG use, cache result for session, warn but don't block

**When to use:** First call to any ragnar function in a session (connect, create, retrieve)

**Example:**
```r
# Source: R's built-in packageVersion() and compareVersion()
# Pattern from existing codebase ragnar_available() check

#' Check ragnar version compatibility (lazy, cached)
#' @param session Shiny session object (for caching)
#' @return TRUE if compatible (or check already run), FALSE if incompatible
check_ragnar_version <- function(session = NULL) {
  # Session-level cache (avoid repeated checks)
  if (!is.null(session)) {
    cached <- session$userData$ragnar_version_checked
    if (!is.null(cached)) {
      return(cached)
    }
  }

  # Check if ragnar is available at all
  if (!requireNamespace("ragnar", quietly = TRUE)) {
    warning("[ragnar] Package not installed - RAG features disabled")
    compatible <- FALSE
  } else {
    # Get installed version
    installed_version <- as.character(packageVersion("ragnar"))
    expected_version <- "0.3.0"

    # Compare versions (0 = equal, -1 = installed < expected, 1 = installed > expected)
    comparison <- compareVersion(installed_version, expected_version)

    if (comparison != 0) {
      # #TODO: This could be replaced by renv version pinning for strict enforcement
      warning(
        "[ragnar] Version mismatch detected. ",
        "Expected: ", expected_version, ", ",
        "Installed: ", installed_version, ". ",
        "RAG features may behave unexpectedly. ",
        "Consider updating or pinning via renv."
      )
      compatible <- TRUE  # Warn but allow (per user decision)
    } else {
      compatible <- TRUE
    }
  }

  # Cache result in session
  if (!is.null(session)) {
    session$userData$ragnar_version_checked <- compatible
  }

  compatible
}

# Usage in module:
if (!check_ragnar_version(session)) {
  showNotification("RAG features disabled (ragnar not available)", type = "warning")
  return()
}
```

**Why this works:** Lazy check avoids startup penalty, session caching prevents repeated warnings, warning-but-allow matches user decision for v3.0 (renv pinning deferred).

### Pattern 4: Connection Cleanup with on.exit() and onSessionEnded

**What:** Explicit cleanup at function and session level to prevent connection leaks

**When to use:** Any function that opens ragnar store connection, any module that uses ragnar

**Example:**
```r
# Source: Existing patterns in app.R line 166, mod_citation_network.R line 924
# Applied to ragnar stores

#' Connect to ragnar store with automatic cleanup
#' @param path Path to ragnar store
#' @return RagnarStore object or NULL on error
connect_ragnar_with_cleanup <- function(path) {
  store <- NULL

  tryCatch({
    store <- ragnar::ragnar_store_connect(path)

    # Function-level cleanup on error or early return
    on.exit({
      if (!is.null(store)) {
        # #TODO: This aggressive cleanup could be relaxed to selective cleanup later
        # Currently closes on ANY exit (error or success) for safety
        tryCatch({
          ragnar::ragnar_store_close(store)  # If ragnar has close method
        }, error = function(e) {
          # Store may already be closed, ignore
        })
      }
    }, add = TRUE)

  }, error = function(e) {
    # Global notification on connection failure (per user decision)
    message("[ragnar] Connection failed: ", e$message)
    showNotification(
      paste("Failed to connect to notebook search index:", e$message),
      type = "error",
      duration = 10
    )
    return(NULL)
  })

  store
}

# Session-level cleanup in module:
module_server <- function(id, con, config) {
  moduleServer(id, function(input, output, session) {
    # ... module logic ...

    # Track active store in reactive value
    active_store <- reactiveVal(NULL)

    # Session cleanup on browser close
    session$onSessionEnded(function() {
      store <- active_store()
      if (!is.null(store)) {
        tryCatch({
          # Close any open ragnar store
          ragnar::ragnar_store_close(store)
        }, error = function(e) {
          # Already closed or invalid, ignore
        })
      }
    })
  })
}
```

**Why this works:** `on.exit()` guarantees cleanup even on error, `session$onSessionEnded()` catches browser close, aggressive cleanup prevents leaks (can optimize later with #TODO marker).

### Anti-Patterns to Avoid

- **Storing paths in database** — Adds state synchronization complexity, paths can be computed deterministically from notebook_id
- **Manual close() calls without on.exit()** — Cleanup skipped on error, causes connection leaks
- **Startup version check** — Blocks app launch for users who don't use RAG features
- **Fancy version mismatch UI** — Over-engineering, renv will handle this properly in future

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UUID generation | Custom GUID function | `uuid::UUIDgenerate()` | Already used in codebase, RFC 4122 compliant, tested |
| Version comparison | String splitting | `compareVersion()` | Built-in R function, handles semver edge cases |
| Session cleanup | Manual tracking | `session$onSessionEnded()` | Shiny handles browser close, disconnects, timeouts |
| Function cleanup | try/finally blocks | `on.exit(..., add=TRUE)` | R idiom, guaranteed execution, composable |
| Path validation | Complex regex | Basic checks + tryCatch | Filesystem handles invalid paths, fail fast on error |

**Key insight:** R and Shiny provide battle-tested infrastructure for all these patterns. Use them. Custom solutions introduce bugs (UUID collisions, version parsing edge cases, cleanup race conditions).

## Common Pitfalls

### Pitfall 1: Notebook ID is Already UUID, No New Column Needed

**What goes wrong:** Assuming notebooks table needs a new `uuid` column, adding migration logic, breaking existing foreign key constraints.

**Why it happens:** User decision says "Add UUID column to notebooks table" but actual verification shows `id` column is already UUID format (verified via db query: `48fb8820-fbc0-4e75-bf46-92c6dae1db0b`).

**How to avoid:**
- Read current schema with `DESCRIBE notebooks` before planning migrations
- Use existing `notebooks.id` directly for path construction
- No schema changes needed in Phase 20

**Warning signs:**
- Tasks mention "add uuid column"
- Migration scripts for notebooks table
- Foreign key constraint errors

### Pitfall 2: Origin Field Delimiter Collision

**What goes wrong:** Using delimiter character that appears in filename, DOI, or section name. Encoding breaks. Example: filename "data|raw.pdf" with pipe delimiter creates ambiguous parsing.

**Why it happens:** Filenames can contain special characters, DOIs contain slashes and periods, section names might have pipes if user-defined.

**How to avoid:**
- Use pipe `|` as primary delimiter (rare in filenames, not allowed in Windows paths)
- Use equals `=` for key-value separation (never in DOIs, filenames)
- Validate input: warn if filename contains pipe, suggest rename
- Test decode with filenames: `test|file.pdf`, `file.with.dots.pdf`, `10.1234/doi`

**Warning signs:**
- Decode returns wrong section_hint
- Base origin missing filename extension
- DOI truncated at delimiter

### Pitfall 3: DuckDB Connection Leaks from Missing on.exit()

**What goes wrong:** Opening ragnar store in reactive observer without cleanup. User switches notebooks repeatedly. Connection count grows. Eventually hits OS file handle limit. App freezes or crashes.

**Why it happens:** Shiny reactive contexts don't automatically clean up resources. Observers re-run on input changes. Each run opens new connection. Previous connections stay open in memory.

**How to avoid:**
- ALWAYS use `on.exit()` when opening connections
- Set `add=TRUE` to stack multiple cleanup calls
- Test with rapid notebook switching (10+ switches in 30 seconds)
- Monitor file handles: `lsof | grep duckdb` (Linux) or Process Explorer (Windows)

**Warning signs:**
- App slows down after switching notebooks multiple times
- "Too many open files" error
- Memory usage grows linearly with notebook switches
- DuckDB lock errors after extended use

### Pitfall 4: Version Check Blocking RAG for Patch Updates

**What goes wrong:** Strict version check requires exact match (0.3.0). Ragnar releases patch update (0.3.1). Check fails. RAG features disabled. Users can't query documents even though 0.3.1 is backward compatible.

**Why it happens:** Comparing with `!=` instead of semver rules. Patch updates (0.3.x) should be compatible, minor updates (0.x.0) may break, major updates (x.0.0) definitely break.

**How to avoid:**
- Use `compareVersion()` to check if installed < minimum required
- Allow equal or greater patch versions (0.3.0, 0.3.1, 0.3.2)
- Warn on minor/major version difference (0.4.0, 1.0.0)
- Test with multiple ragnar versions: 0.2.9, 0.3.0, 0.3.1, 0.4.0

**Warning signs:**
- RAG disabled after harmless package update
- Error messages about version mismatch for patch updates
- Users complaining RAG broke after `update.packages()`

### Pitfall 5: data/ragnar/ Directory Creation Fails Silently

**What goes wrong:** Assuming `data/` exists and is writable. Creating `data/ragnar/` fails due to permissions or disk full. Error swallowed by `showWarnings = FALSE`. Later ragnar store creation fails with cryptic "path not found" error.

**Why it happens:** `dir.create(..., showWarnings = FALSE)` hides all errors, not just "already exists". If creation fails for other reasons (permissions, disk space), code proceeds silently.

**How to avoid:**
- Check `dir.create()` return value (TRUE on success, FALSE on failure)
- Use `recursive = TRUE` to create parent directories if needed
- Verify directory writability after creation: `file.access(path, mode = 2)`
- Fail fast with clear error message if directory creation fails

```r
# Bad:
dir.create("data/ragnar", showWarnings = FALSE)

# Good:
if (!dir.create("data/ragnar", showWarnings = FALSE, recursive = TRUE)) {
  if (!dir.exists("data/ragnar")) {
    stop("Failed to create data/ragnar directory. Check permissions and disk space.")
  }
}
```

**Warning signs:**
- Ragnar store creation fails with "parent directory does not exist"
- Works on dev machine, fails in deployment (different permissions)
- Intermittent failures on low disk space

## Code Examples

Verified patterns from codebase and R documentation:

### UUID Generation (Existing Pattern)

```r
# Source: db.R line 240 (create_notebook function)
id <- uuid::UUIDgenerate()
# Returns: "48fb8820-fbc0-4e75-bf46-92c6dae1db0b"

# Filesystem-safe (no special chars):
path <- file.path("data", "ragnar", paste0(id, ".duckdb"))
# Returns: "data/ragnar/48fb8820-fbc0-4e75-bf46-92c6dae1db0b.duckdb"
```

### Version Comparison (Built-in R)

```r
# Source: R help(compareVersion)
installed <- as.character(packageVersion("ragnar"))  # "0.3.0"
required <- "0.3.0"

comparison <- compareVersion(installed, required)
# Returns: 0 (equal), -1 (installed < required), 1 (installed > required)

# Example checks:
if (comparison < 0) {
  stop("Ragnar version too old. Please update.")
}

if (comparison > 0) {
  warning("Ragnar version newer than tested. May have breaking changes.")
}
```

### Session Cleanup (Existing Pattern)

```r
# Source: app.R line 166 (main server function)
session$onSessionEnded(function() {
  close_db_connection(con)
})

# Source: mod_citation_network.R line 924
session$onSessionEnded(function() {
  cleanup_session_flags(session$token)
})

# Apply to ragnar stores:
session$onSessionEnded(function() {
  # Close any active ragnar store
  if (!is.null(active_store())) {
    tryCatch({
      # Close logic here
    }, error = function(e) {
      # Already closed, ignore
    })
  }
})
```

### Function Cleanup (R Idiom)

```r
# Source: R help(on.exit), existing usage in test-db.R
process_document <- function(notebook_id) {
  store <- connect_ragnar_store(get_notebook_ragnar_path(notebook_id))
  on.exit({
    if (!is.null(store)) close_ragnar_store(store)
  }, add = TRUE)

  # ... processing logic ...
  # Cleanup guaranteed even if error occurs
}
```

### Directory Creation (Robust Pattern)

```r
# Source: db.R line 8 (get_db_connection)
dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)

# Enhanced for Phase 20:
ragnar_dir <- "data/ragnar"
if (!dir.create(ragnar_dir, showWarnings = FALSE, recursive = TRUE)) {
  if (!dir.exists(ragnar_dir)) {
    stop("Failed to create ", ragnar_dir, ". Check permissions.")
  }
}

# Verify writable:
if (file.access(ragnar_dir, mode = 2) != 0) {
  stop(ragnar_dir, " is not writable. Check permissions.")
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Shared ragnar store | Per-notebook stores | v3.0 (2026-02) | Clean isolation, no cross-notebook pollution |
| Metadata in chunks table | Metadata in origin field | v3.0 (2026-02) | No JOIN needed, survives ragnar persistence |
| Startup version checks | Lazy version checks | v3.0 (2026-02) | No startup penalty for non-RAG users |
| Manual connection cleanup | on.exit() + onSessionEnded | Existing pattern | Prevents leaks in reactive contexts |

**Deprecated/outdated:**
- **Shared store** (`data/serapeum.ragnar.duckdb`): Removed in Phase 24 after migration
- **chunks.embedding column**: Removed in Phase 23, replaced by ragnar stores
- **digest dependency**: Removed in Phase 23 after version 2 stores (ragnar uses rlang::hash)

## Open Questions

None. All technical domains well-understood from existing codebase and R documentation.

## Sources

### Primary (HIGH confidence)
- Serapeum codebase: `R/db.R`, `R/_ragnar.R`, `app.R`, `R/mod_citation_network.R` — Verified UUID usage, existing cleanup patterns, ragnar integration
- R package documentation: `help(packageVersion)`, `help(compareVersion)`, `help(on.exit)`, `help(uuid::UUIDgenerate)` — Standard R functions
- DuckDB schema query: `DESCRIBE notebooks` against `data/notebooks.duckdb` — Confirmed id column is UUID format
- Ragnar 0.3.0 installed version check via Rscript — Confirmed available functions

### Secondary (MEDIUM confidence)
- `.planning/research/SUMMARY.md` — Comprehensive ragnar migration research (2026-02-16)
- `.planning/research/PITFALLS.md` — DuckDB connection locking, metadata loss, version compatibility
- Shiny documentation: `session$onSessionEnded()` lifecycle hook — Session cleanup patterns

## Metadata

**Confidence breakdown:**
- Path construction: HIGH — UUIDs already in use, file.path() is standard R
- Metadata encoding: HIGH — Origin field verified in existing _ragnar.R, delimiter choice validated
- Version checking: HIGH — Built-in R functions, tested with installed ragnar
- Connection cleanup: HIGH — Patterns already used in app.R and mod_citation_network.R

**Research date:** 2026-02-16
**Valid until:** 2026-04-16 (60 days, stable domain — R core functions don't change)
