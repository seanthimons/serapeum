# Abstract Notebook Tag Regression Note

Date: 2026-03-10

## User Question

Why did I see feature reversion on the abstract notebook tags; they use to cycle and now they don't do anything.

Can you tell me more about each keyword getting its own observer?

## Answer

It does not look like an intentional feature reversion. The tri-state cycle logic for the abstract notebook keyword tags still exists in the codebase, so the behavior was not deliberately removed.

The likely cause is a bug in how the keyword filter module wires click handlers. Each visible keyword badge gets its own `observeEvent()` listener. That is a normal pattern by itself, but in this implementation those observers are created inside a reactive `observe()` that re-runs whenever the keyword set changes. When that happens, the module creates a new batch of observers without tearing down the old ones.

As the abstract notebook refreshes its paper list more often, those duplicate observers accumulate. A single click can then trigger multiple listeners for the same keyword badge. Since each listener advances the state one step in the cycle (`neutral -> include -> exclude -> neutral`), one click can jump through multiple states and land back on `neutral`. In the UI that looks like the tag no longer does anything.

## What "Each Keyword Gets Its Own Observer" Means

In the keyword filter module, the server loops over the current keyword list and creates one click observer per badge:

1. It builds an input ID for a keyword badge.
2. It binds an `observeEvent(input[[input_id]], { ... })` handler to that badge.
3. That handler updates the keyword state from `neutral` to `include` to `exclude` and back to `neutral`.

If there are 30 visible keywords, there are 30 separate observers.

That structure is not inherently wrong. The problem is that the observer-registration block runs again when the keyword set refreshes, and the previous observers are not removed. After enough refreshes, the same badge can have multiple active observers attached to it.

Example:

1. Observer A sees a click and changes `neutral -> include`
2. Observer B sees the same click and changes `include -> exclude`
3. Observer C sees the same click and changes `exclude -> neutral`

From the user perspective, the badge appears unchanged even though multiple state transitions happened.

## Additional Risk

The badge input IDs are built by sanitizing keyword text. That means different raw keywords can collapse to the same sanitized ID if they differ only by punctuation or spacing. If that happens, two visually distinct badges can end up sharing one input channel, which is another way click behavior can become unstable.

## Management Summary

- The feature was likely not removed.
- The tri-state logic still exists.
- The probable regression is duplicate click observers accumulating over time.
- Recent search refresh and load-more work likely made the latent bug much easier to notice because keyword lists rebind more often.
- The fix is to ensure each live keyword badge has exactly one observer, with stable unique IDs and proper teardown or deduplicated binding.
