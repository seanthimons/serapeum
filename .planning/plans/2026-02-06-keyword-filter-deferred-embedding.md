# Keyword Filter Panel & Deferred Embedding Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:writing-plans to create detailed implementation plan from this design.

**Goal:** Add a keyword tag cloud for filtering papers and change embedding to be user-triggered rather than automatic.

**Problem:** Currently, embeddings happen automatically on refresh, wasting money on papers the user may not want. Users need a way to curate their paper selection before committing to embedding costs.

---

## Feature Overview

### 1. Keyword Filter Panel
- Located in the whitespace at top-right (above "Abstract Details")
- Shows all unique keywords from current papers as clickable badges with counts
- Clicking a keyword deletes all papers with that keyword (with confirmation)
- Enables rapid corpus curation before embedding

### 2. Deferred Embedding
- "Refresh" no longer triggers embedding automatically
- New "🧠 Embed Papers" button lets user trigger embedding when ready
- Makes embedding cost explicit and user-controlled

### 3. Individual Paper Delete
- X button on each paper in the list
- Quick delete without confirmation
- Supports fine-grained curation

### 4. Exclusion Tracking
- Deleted papers are tracked in an exclusion list
- Excluded papers won't reappear on subsequent refreshes
- Can clear exclusions to start fresh

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  🔍 AMR                                           [Delete]      │
│  Query: anti microbial resistance                               │
├──────────────────────┬──────────────────────────────────────────┤
│                      │  Keywords (47 papers)                    │
│  Papers    [✏️][🔄]  │  [bacteria (12)] [resistance (10)]       │
│                      │  [aquaculture (8)] [AMR (6)] [urban (3)] │
│  ☑ Show only papers  │  ...                                     │
│    with abstracts    │                                          │
│                      │  [🧠 Embed 47 Papers]                    │
│  ┌────────────────┐  │                                          │
│  │ Paper Title  ✕ │  │  3 papers excluded (clear)               │
│  │ Author - 2024  │  ├──────────────────────────────────────────┤
│  │ Journal        │  │  Abstract Details                    [x] │
│  └────────────────┘  │                                          │
│  ┌────────────────┐  │  Title...                                │
│  │ Paper Title  ✕ │  │  Authors...                              │
│  │ Author - 2024  │  │  Abstract text...                        │
│  └────────────────┘  │                                          │
│                      │                                          │
└──────────────────────┴──────────────────────────────────────────┘
```

---

## Component Specifications

### Keyword Filter Panel

**Location:** Top-right whitespace, above "Abstract Details"

**Header:** "Keywords (N papers)" where N is current paper count

**Tag Cloud:**
- All unique keywords as Bootstrap badges with counts
- Format: `[keyword (count)]`
- Sorted by count descending (most frequent first)
- Style: `badge bg-secondary me-1 mb-1` with hover effect
- Cursor: pointer

**Click Behavior:**
- Shows confirmation modal: "Delete N papers tagged 'keyword'?"
- Buttons: "Delete" (danger) / "Cancel"
- On confirm: delete papers, update UI

**Empty State:** "No keywords available" (muted text)

---

### Embed Papers Button

**Location:** Below keyword tag cloud

**States:**

| Condition | Text | Style | Enabled |
|-----------|------|-------|---------|
| No papers | "No Papers to Embed" | Secondary | No |
| Papers exist, none embedded | "🧠 Embed N Papers" | Primary | Yes |
| Some embedded, some new | "🧠 Embed N New Papers" | Primary | Yes |
| All embedded | "✓ All Papers Embedded" | Success | No |

**Click Behavior:**
1. Show progress modal with spinner
2. Generate embeddings for unembedded papers
3. Update button state
4. Close modal

---

### Paper List X Button

**Location:** Top-right corner of each paper item in list

**Style:** Small, subtle X icon. Visible on hover or always visible (TBD during implementation)

**Click Behavior:**
1. No confirmation (fast delete)
2. Add paper_id to exclusion list
3. Delete paper from database
4. Fade out animation
5. Update tag cloud and counts

---

### Exclusion Tracking

**Display:** Below embed button: "N papers excluded (clear)"

**Style:** Small muted text, "clear" is a link

**Click "clear" Behavior:**
- Confirmation: "Clear all exclusions? Excluded papers may reappear on next refresh."
- On confirm: Clear exclusion list, update display

---

## Database Changes

### Notebooks Table

Add column:
```sql
ALTER TABLE notebooks ADD COLUMN excluded_paper_ids VARCHAR DEFAULT '[]'
```

- Stores JSON array of OpenAlex paper IDs
- Example: `["W12345", "W67890", "W11111"]`

---

## Data Flow

### On "Refresh" Click

1. Fetch papers from OpenAlex API (existing logic)
2. Load `excluded_paper_ids` from notebook
3. Filter out any paper where `paper_id` is in exclusion list
4. Save remaining papers to `abstracts` table
5. **Do NOT generate embeddings** (changed from current behavior)
6. Update tag cloud with keywords from current papers
7. Update paper list
8. Update embed button state

### On Keyword Click

1. User clicks keyword badge (e.g., "bacteria (8)")
2. Show confirmation: "Delete 8 papers tagged 'bacteria'?"
3. If cancelled: do nothing
4. If confirmed:
   a. Query all paper IDs with that keyword
   b. Add paper IDs to `excluded_paper_ids`
   c. Delete papers from `abstracts` table
   d. Delete associated chunks
   e. Update tag cloud (remove/update badges)
   f. Update paper list
   g. Update embed button state

### On Paper X Click

1. User clicks X on paper item
2. Add paper_id to `excluded_paper_ids`
3. Delete paper from `abstracts` table
4. Delete associated chunks
5. Brief fade-out animation
6. Update tag cloud counts
7. Update embed button state

### On "Embed Papers" Click

1. User clicks "🧠 Embed N Papers"
2. Show progress modal
3. Get all unembedded papers (papers without embeddings in chunks table)
4. For each paper:
   a. Generate embedding via OpenRouter
   b. Store in chunks table
   c. Update progress
5. If ragnar available, index abstracts
6. Close modal
7. Update button to "✓ All Papers Embedded"
8. Chat functionality now available

### On "Clear Exclusions" Click

1. User clicks "clear" link
2. Show confirmation: "Clear all exclusions? Excluded papers may reappear on next refresh."
3. If confirmed:
   a. Set `excluded_paper_ids` to `[]`
   b. Update display to hide exclusion count

---

## Edge Cases

### No Keywords on Papers
- Some OpenAlex papers don't have keywords
- Tag cloud shows "No keywords available"
- User can still delete individual papers via X button

### All Papers Deleted
- Tag cloud: empty, shows "No keywords available"
- Embed button: "No Papers to Embed" (disabled)
- Paper list: empty state message

### Deleting Embedded Paper
- Paper is deleted (embedding is lost)
- This is intentional - user chose to remove it
- No special handling needed

### Large Number of Keywords
- Limit display to top 20-30 keywords by count
- Add "Show all keywords" expand link if more exist

---

## Testing Considerations

1. **Keyword extraction** - Verify keywords are properly extracted from OpenAlex
2. **Tag cloud rendering** - Test with 0, 1, 10, 50+ keywords
3. **Deletion confirmation** - Verify modal shows correct count
4. **Exclusion persistence** - Refresh should not bring back excluded papers
5. **Embed button states** - Test all state transitions
6. **Animation** - Paper fade-out should be smooth
7. **Chat availability** - Chat should only work after embedding

---

## Files to Modify

| File | Changes |
|------|---------|
| `R/db.R` | Add `excluded_paper_ids` column migration, add helper functions |
| `R/mod_search_notebook.R` | Keyword panel UI, embed button, X buttons, event handlers |
| `R/api_openalex.R` | No changes needed (keywords already extracted) |

---

## Implementation Priority

1. **Database migration** - Add excluded_paper_ids column
2. **Remove auto-embedding** - Stop embedding on refresh
3. **Add embed button** - Basic button with state management
4. **Add keyword panel** - Tag cloud display
5. **Add keyword click-to-delete** - With confirmation
6. **Add paper X button** - Individual delete
7. **Add exclusion tracking** - Display and clear functionality
8. **Polish** - Animations, edge cases, testing
