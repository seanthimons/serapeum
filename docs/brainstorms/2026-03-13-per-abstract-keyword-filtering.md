---
date: 2026-03-13
topic: per-abstract-keyword-filtering
issue: https://github.com/seanthimons/serapeum/issues/151
milestone: v13.0 Search & Discovery
---

# Per-Abstract Keyword Ban/Keep Filtering

## What We're Building

Extend the existing keyword ban/keep system so that keywords displayed on individual abstract cards have the same toggle behavior (neutral → keep → ban) as the global top-30 keyword chip bin. When a user acts on a per-abstract keyword, it promotes into the global chip bin as the single source of truth — immediately filtering existing papers and affecting future searches.

## Why This Approach

Users encounter irrelevant keywords on individual abstracts that never appear in the top-30 global panel. Today there's no way to act on these. Rather than building a separate filtering mechanism, we reuse the existing chip toggle pattern and global state — keeping one mental model for keyword filtering everywhere.

## Key Decisions

- **Same chip UI everywhere**: Per-abstract keywords get the identical ban/keep/neutral toggle interaction as global keywords. No new interaction patterns to learn.
- **Global chip bin is the single source of truth**: Banning/keeping from an abstract card writes to the same global state the top-30 panel uses.
- **Chip bin grows beyond 30**: The global bin always shows the top-30 *plus* any user-acted keywords, so users can see and reverse every filtering decision they've made.
- **Immediate effect on existing papers**: Banning a keyword hides matching papers already in the notebook (not just future searches). Keeping pins them.
- **Reversible from either location**: A user can undo a ban/keep from the abstract card or the global bin — same state, same result.

## Resolved Questions

- **Visual distinction in global bin?** No — user-promoted keywords blend in with the top-30, no special styling.
- **Hidden paper count indicator?** No — keep the existing "N included | N excluded" summary in the keyword panel. No new unified counter.

## Next Steps

→ Plan implementation details for the reusable chip component and global state wiring.
