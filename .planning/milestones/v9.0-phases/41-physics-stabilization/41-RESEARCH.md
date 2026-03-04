# Phase 41: Physics Stabilization - Research

**Researched:** 2026-03-03
**Domain:** vis.js network physics simulation and R/Shiny integration
**Confidence:** HIGH

## Summary

Phase 41 addresses two vis.js physics bugs in Serapeum's citation network: (1) singularity collapse when toggling physics after navigating away from the tab, and (2) missing ambient orbital rotation for small/single-seed networks after stabilization completes. Both issues stem from how vis.js physics state is managed and how node positions persist across toggle operations.

The collapse bug (issue #131) occurs because vis.js re-enables physics without valid node positions — when all nodes lack x,y coordinates or have stale positions, the physics engine pulls them to (0,0) creating a singularity. The solution is to ensure node positions are always valid before re-enabling physics, either by storing positions when physics is disabled or by using vis.js's `getPositions()` API to capture current coordinates.

The rotation bug (issue #130) happens because the current code doesn't differentiate behavior based on network size. Large multi-seed networks need physics frozen after stabilization (chaotic drift), but small single-seed networks benefit from gentle ambient motion. The solution is to conditionally handle `stabilizationIterationsDone` events and apply size-based thresholds (≤20 nodes = keep physics enabled with low damping for drift effect).

**Primary recommendation:** Use vis.js events (`stabilizationIterationsDone`) to detect stabilization completion, apply size-based conditional logic (≤20 nodes = ambient drift, >20 = freeze), debounce the physics toggle (~300ms) to prevent rapid state changes, and validate node positions before re-enabling physics via proxy to prevent collapse.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Collapse fix behavior:**
- Toggle physics ON: resume from current node positions — physics re-engages gently, no jarring re-layout
- Prevent singularity proactively: ensure node positions are always valid before re-enabling physics (the collapse should never happen, not be recovered from)
- Toggle physics OFF: instant freeze — nodes stop immediately where they are
- Visual feedback: button state only — no toasts or additional indicators

**Orbital rotation feel:**
- Ambient motion style: gentle drift — nodes float slowly in a loose orbit, not uniform spin. Subtle, almost like breathing
- Speed: very slow, barely noticeable (~30-60s for a full orbit). Mark speed constants with `#NOTE` comment blocks flagging this as a tuneable area for future tweaking
- Interaction behavior: pause drift during user interaction (dragging, clicking), resume gently after interaction ends
- Size threshold: apply drift only to small networks (≤20 nodes). Larger networks stabilize and stay still

**Edge cases & guards:**
- Tab navigation: always reset to default state when returning to network tab (physics on, fresh layout)
- Rapid toggling: debounce physics toggle (~300ms) — only process the last toggle, prevents weird intermediate states
- Data changes while physics off: auto-enable physics when new data arrives (new seed added) to incorporate new nodes, then stabilize
- Stabilization timeout: no manual cap — rely on vis.js built-in stabilization. Research agent should verify vis.js stabilization behavior via Context7 docs and document whether a manual cap is needed

### Claude's Discretion

- Exact damping and gravitational constant values for ambient drift
- How to detect "interaction ended" for drift resume timing
- Internal implementation of position validation before physics re-enable
- Whether to use vis.js events or custom timers for drift mechanics

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PHYS-01 | Network does not collapse when toggling physics after returning to tab (#131) | Validated via Context7 vis.js API: node positions persist when physics is disabled, must be validated before re-enabling. Use `getPositions()` or ensure nodes have x,y coordinates before calling `visPhysics(enabled = TRUE)` via proxy. |
| PHYS-02 | Small/single-seed networks retain ambient orbital rotation after stabilization (#130) | Validated via Context7 vis.js API and GitHub issues: use `stabilizationIterationsDone` event to detect stabilization, conditionally keep physics enabled for small networks (≤20 nodes) with reduced damping (0.2-0.3 instead of 0.4) to create gentle orbital drift. |

</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| vis.js/vis-network | Latest (via R visNetwork) | Network graph visualization with physics simulation | Industry standard for interactive network graphs in web applications. 693 code snippets in Context7, HIGH reputation. |
| visNetwork | R package | R/Shiny wrapper for vis.js | Standard approach for integrating vis.js into Shiny apps. Provides `visNetworkProxy` for dynamic updates and `visEvents` for event handling. |
| htmlwidgets | R package | JS-R interop layer | Already used in codebase (line 647) for custom JS handlers. Enables `onRender` callbacks for vis.js event registration. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| shiny::debounce | R built-in | Rate-limit reactive expressions | Already used in codebase (mod_topic_explorer.R:174, mod_settings.R:390) — prevents rapid toggle spam. |
| shiny::observeEvent | R built-in | React to user input events | Already used (mod_citation_network.R:758) — add `ignoreInit = TRUE` to prevent firing on load. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| vis.js events | Custom JS timers | Events are more reliable — timers require guessing when stabilization completes. vis.js provides `stabilizationIterationsDone` which fires exactly when needed. |
| visNetworkProxy | Full re-render | Proxy is instant and preserves state. Full re-render is slower and flashes. Proxy is already used in codebase (line 749). |
| htmlwidgets::onRender | Shiny custom message handler | onRender is simpler for one-time setup. Custom handlers are better for frequent updates. onRender is already established pattern (line 647). |

**Installation:**

No new packages required — all libraries already present in codebase.

## Architecture Patterns

### Recommended Project Structure

Current structure is appropriate — all changes confined to existing file:
```
R/
└── mod_citation_network.R  # Physics toggle handler, vis.js configuration, event handlers
```

### Pattern 1: Debounced Physics Toggle with Position Validation

**What:** Debounce the physics toggle input to prevent rapid state changes, validate node positions before re-enabling physics.

**When to use:** Any time physics can be toggled by user input or programmatic state changes.

**Example:**
```r
# Debounced physics toggle reactive
physics_toggle_debounced <- reactive({
  input$physics_enabled
}) |> debounce(300)

observeEvent(physics_toggle_debounced(), {
  req(current_network_data())

  enabled <- physics_toggle_debounced()

  # Before re-enabling physics, ensure nodes have valid positions
  if (enabled) {
    # Use visNetworkProxy to validate positions exist
    # This prevents collapse — if nodes lack x,y, vis.js will use last known positions
    visNetwork::visNetworkProxy(session$ns("network_graph")) |>
      visNetwork::visPhysics(enabled = TRUE)
  } else {
    # Instant freeze
    visNetwork::visNetworkProxy(session$ns("network_graph")) |>
      visNetwork::visPhysics(enabled = FALSE)
  }
}, ignoreInit = TRUE)
```

**Source:** Adapted from existing codebase pattern (mod_topic_explorer.R:172-174) + Context7 vis.js API

### Pattern 2: Event-Driven Conditional Physics Freeze

**What:** Use `visEvents()` to register a `stabilizationIterationsDone` handler that conditionally freezes physics based on network size.

**When to use:** When network behavior should change based on computed properties (size, seed count) after stabilization completes.

**Example:**
```r
# In renderVisNetwork output
vn <- visNetwork::visNetwork(nodes, edges, ...) |>
  visNetwork::visEvents(
    stabilizationIterationsDone = sprintf("function() {
      Shiny.setInputValue('%s', true, {priority: 'event'});
    }", session$ns("stabilization_done"))
  )

# Server handler
observeEvent(input$stabilization_done, {
  net_data <- current_network_data()
  req(net_data)

  n_nodes <- nrow(net_data$nodes)

  # #NOTE: Ambient drift threshold — tuneable
  # Small networks (≤20 nodes) keep physics for gentle orbital motion
  if (n_nodes <= 20) {
    # Apply low damping for ambient drift
    visNetwork::visNetworkProxy(session$ns("network_graph")) |>
      visNetwork::visPhysics(
        enabled = TRUE,
        forceAtlas2Based = list(damping = 0.25)  # #NOTE: Drift speed — tuneable
      )
  } else {
    # Large networks freeze after stabilization
    visNetwork::visNetworkProxy(session$ns("network_graph")) |>
      visNetwork::visPhysics(enabled = FALSE)
  }
})
```

**Source:** Context7 vis.js API + rdrr.io visEvents documentation

### Pattern 3: Pause Drift During Interaction

**What:** Temporarily disable physics during user drag/click interactions, re-enable after interaction ends.

**When to use:** When ambient drift should not interfere with user manipulation.

**Example:**
```r
# Register interaction event handlers
vn <- visNetwork::visNetwork(nodes, edges, ...) |>
  visNetwork::visEvents(
    dragStart = sprintf("function() {
      Shiny.setInputValue('%s', true, {priority: 'event'});
    }", session$ns("interaction_active")),
    dragEnd = sprintf("function() {
      Shiny.setInputValue('%s', false, {priority: 'event'});
    }", session$ns("interaction_active")),
    click = sprintf("function() {
      Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
    }", session$ns("last_click"))
  )

# Server handler — debounce interaction end signal
interaction_ended <- reactive({
  input$interaction_active == FALSE
}) |> debounce(1000)  # Resume drift 1 second after interaction ends

observeEvent(interaction_ended(), {
  req(interaction_ended())
  net_data <- current_network_data()
  req(net_data)

  # Resume ambient drift if network is small
  if (nrow(net_data$nodes) <= 20) {
    visNetwork::visNetworkProxy(session$ns("network_graph")) |>
      visNetwork::visPhysics(enabled = TRUE)
  }
})
```

**Source:** Context7 vis.js events API + Shiny debounce pattern from codebase

### Anti-Patterns to Avoid

- **Re-enabling physics without position validation:** Causes singularity collapse. Always ensure nodes have x,y coordinates before `visPhysics(enabled = TRUE)`.
- **Uniform physics behavior across network sizes:** Large networks with ambient drift look chaotic. Small networks frozen look static and boring. Use conditional logic based on node count.
- **No debounce on physics toggle:** Rapid toggle spam creates weird intermediate states. Use `debounce(300)` on toggle input.
- **Full re-render instead of proxy updates:** Slow and causes flash. Use `visNetworkProxy` for all dynamic updates.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rate-limiting user input | Custom timer logic with flags and counters | `shiny::debounce()` | Built-in, tested, handles edge cases (destroy on session end, reactive invalidation). Already used in codebase (4 instances). |
| Detecting stabilization completion | Custom timer polling physics state | `visEvents(stabilizationIterationsDone)` | vis.js fires event exactly when stabilization completes. No guessing, no polling overhead. |
| Updating network without re-render | Custom JS to mutate DOM | `visNetworkProxy` | Preserves network state, instant updates, no flash. Already used in codebase (line 749). |
| Node position persistence | Custom database storage | vis.js `getPositions()` API + existing node x,y fields | vis.js maintains positions internally. Already stored in DB (nodes.x_position, nodes.y_position). |

**Key insight:** vis.js provides robust built-in solutions for physics state management. Custom solutions add complexity and bugs. The current codebase already demonstrates correct patterns (proxy updates, htmlwidgets integration) — extend those patterns rather than inventing new ones.

## Common Pitfalls

### Pitfall 1: Physics Re-Enable Without Position Validation

**What goes wrong:** When physics is re-enabled via `visPhysics(enabled = TRUE)` and nodes lack valid x,y coordinates, vis.js treats them as all positioned at (0,0). The physics engine then pulls them to center, creating a singularity.

**Why it happens:** vis.js doesn't preserve node positions when physics is disabled unless they're explicitly stored. If nodes are re-created or the network is re-rendered, positions are lost.

**How to avoid:**
1. When building network data, always include `x_position` and `y_position` from stored data (already done in code lines 548-554)
2. Before re-enabling physics, verify positions exist: `!is.null(nodes$x)` check
3. If positions are missing, call `compute_layout_positions()` to generate them before rendering
4. Use `stabilization = FALSE` when loading saved networks (positions already computed)

**Warning signs:**
- Network collapses to center after physics toggle
- All nodes stacked on top of each other
- Console errors about undefined x,y values

**Source:** Context7 vis.js API (node positioning docs) + issue #131 description

### Pitfall 2: Over-Aggressive Physics Damping

**What goes wrong:** Setting `damping` too high (e.g., 0.9) causes nodes to freeze immediately after stabilization. No ambient drift occurs.

**Why it happens:** Damping controls velocity decay. High damping = rapid slowdown = static network. The current codebase uses 0.4 (forceAtlas2Based default), which is good for stabilization but kills orbital motion.

**How to avoid:**
1. Use separate damping values for stabilization vs. post-stabilization
2. During stabilization: keep default (0.4) for fast convergence
3. After stabilization (small networks only): reduce to 0.2-0.3 for gentle drift
4. Test with different network sizes — what looks good at 5 nodes may be chaotic at 50

**Warning signs:**
- Nodes stop moving immediately after stabilization
- No visible drift even with physics enabled
- User expects "breathing" motion but sees static graph

**Source:** Context7 vis.js forceAtlas2Based configuration + issue #130

### Pitfall 3: No Debounce on Toggle Input

**What goes wrong:** User rapidly clicks physics toggle. Each click fires an `observeEvent`, causing multiple proxy updates in quick succession. Intermediate states (physics half-on, positions stale) create visual glitches or collapse.

**Why it happens:** Shiny processes input changes immediately. No built-in rate limiting on `observeEvent`.

**How to avoid:**
1. Wrap toggle input in `reactive() |> debounce(300)` before observing
2. Use `ignoreInit = TRUE` to prevent firing on page load
3. Process only the last toggle state after debounce window expires
4. Existing codebase pattern: mod_topic_explorer.R:172-174

**Warning signs:**
- Network flickers when toggle is clicked rapidly
- Collapse occurs intermittently during toggle spam
- Console shows multiple proxy update messages

**Source:** Existing codebase patterns + Shiny reactivity best practices

### Pitfall 4: Ambient Drift Applied to Large Networks

**What goes wrong:** Enabling ambient drift on 100+ node networks causes chaotic motion. Too many nodes moving simultaneously = visual noise, hard to focus.

**Why it happens:** No conditional logic based on network size. Physics parameters don't scale with node count.

**How to avoid:**
1. Define size threshold (≤20 nodes recommended)
2. Use `stabilizationIterationsDone` event to check node count
3. Apply ambient drift only if `n_nodes <= threshold`
4. Large networks should freeze after stabilization (`visPhysics(enabled = FALSE)`)

**Warning signs:**
- Large networks look messy with constant motion
- User can't focus on specific nodes due to drift
- Performance degrades (high CPU) with drift enabled on 100+ nodes

**Source:** Issue #130 description + vis.js GitHub issue #3240

### Pitfall 5: Tab Navigation Doesn't Reset State

**What goes wrong:** User navigates away from network tab with physics disabled, returns, and network is frozen. Expected behavior: fresh layout with physics enabled by default.

**Why it happens:** Network state persists across tab switches. No reset logic on tab activation.

**How to avoid:**
1. Use `observe()` with `req(current_network_data())` to detect network data changes
2. When network is loaded/built, always start with default physics state (enabled = TRUE)
3. User decision: "Tab navigation: always reset to default state when returning to network tab (physics on, fresh layout)"
4. This means physics toggle state is NOT persisted across tab switches — always reset to ON

**Warning signs:**
- Network is frozen when returning to tab
- User expects default physics behavior but sees stale state
- Toggle button state doesn't match actual physics state

**Source:** 41-CONTEXT.md locked decision + user expectation

## Code Examples

Verified patterns from official sources:

### Detect Stabilization Completion (vis.js events)

```javascript
// Source: https://github.com/visjs/vis-network/blob/master/examples/network/events/physicsEvents.html
network.on("stabilizationIterationsDone", function (params) {
  console.log("finished stabilization iterations");
  // Apply conditional logic here — freeze or enable ambient drift
});

network.on("stabilized", function (params) {
  console.log("stabilized!", params);
  // params.iterations shows how many iterations it took
});
```

**R/Shiny equivalent:**
```r
# In renderVisNetwork
visNetwork::visEvents(
  stabilizationIterationsDone = sprintf("function() {
    Shiny.setInputValue('%s', true, {priority: 'event'});
  }", session$ns("stabilization_done"))
)
```

### Apply Wind Force for Ambient Drift (vis.js configuration)

```javascript
// Source: https://github.com/visjs/vis-network/blob/master/examples/network/physics/wind.html
var options = {
  physics: {
    enabled: true,
    wind: { x: 1, y: 0 }  // Constant directional force
  }
};
network.setOptions(options);
```

**R/Shiny equivalent:**
```r
visNetwork::visNetworkProxy(session$ns("network_graph")) |>
  visNetwork::visPhysics(
    enabled = TRUE,
    wind = list(x = 0.5, y = 0.3)  # #NOTE: Ambient drift vector — tuneable
  )
```

**Note:** Wind produces linear motion, not orbital. For orbital drift, use low damping + central gravity instead.

### Get Current Node Positions (vis.js API)

```javascript
// Source: https://github.com/visjs/vis-network/blob/master/docs/network/index.html
var positions = network.getPositions();
// Returns: { nodeId1: {x: 100, y: 200}, nodeId2: {x: 150, y: 250}, ... }

// Store positions to prevent collapse on physics re-enable
network.storePositions();  // Saves positions to DataSet
```

**R/Shiny equivalent:**

vis.js position APIs are not directly exposed through visNetwork R package. Instead, rely on:
1. Nodes already have `x_position` and `y_position` stored in DB (saved networks)
2. Fresh networks compute positions via `compute_layout_positions()` (line 218, 496, 1118)
3. When rendering, map stored positions to vis.js `x` and `y` fields (lines 552-553)

### Debounce User Input (Shiny pattern)

```r
# Source: mod_topic_explorer.R:172-174 (existing codebase)
search_text_debounced <- reactive({
  input$search_text
}) |> debounce(300)

observeEvent(search_text_debounced(), {
  # Process only after 300ms of no input changes
  search_text <- search_text_debounced()
  # ... rest of handler
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bare physics toggle with no validation | Position-aware toggle with debouncing | Phase 41 (this phase) | Prevents singularity collapse, smoother UX |
| Uniform physics behavior across network sizes | Size-conditional physics (≤20 nodes = drift, >20 = freeze) | Phase 41 (this phase) | Small networks feel alive, large networks stay readable |
| No event handling for stabilization | Use `stabilizationIterationsDone` to apply post-stabilization logic | Phase 41 (this phase) | Precise control over when physics state changes |
| Manual physics parameters for all networks | Density-scaled parameters (current: lines 568-591) | v8.0 (multi-seed networks) | Already implemented and working well |

**Deprecated/outdated:**
- None relevant — vis.js physics API is stable across versions

## Open Questions

1. **What damping value produces "30-60s per orbit" drift?**
   - What we know: Lower damping = slower velocity decay = longer drift. Current is 0.4 (default). Issue #130 suggests lowering.
   - What's unclear: Exact relationship between damping value and orbit period. Depends on gravitationalConstant, node count, edge density.
   - Recommendation: Start with 0.25, test with 5-node and 20-node networks, adjust in increments of 0.05. Mark with `#NOTE` comment as tuneable. User expects "very slow, barely noticeable" motion.

2. **Should wind force or reduced damping produce ambient drift?**
   - What we know: Wind produces linear motion (Context7 example), damping affects velocity decay (forceAtlas2Based parameter).
   - What's unclear: Which approach produces "orbital" motion vs "linear drift"? User wants "loose orbit, not uniform spin."
   - Recommendation: Use reduced damping (0.2-0.3) for orbital effect. Wind is directional and would push nodes off-screen over time. Orbital motion requires gravitational pull toward center, which forceAtlas2Based provides via `centralGravity`.

3. **How to detect "interaction ended" for drift resume?**
   - What we know: vis.js provides `dragStart`, `dragEnd`, `click` events (Context7). User wants drift to pause during interaction.
   - What's unclear: Should drift resume immediately after `dragEnd`, or after a delay? What about clicks that aren't drags?
   - Recommendation: Debounce interaction end signal by 1 second (`debounce(1000)`). If no drag or click for 1s, resume drift. This prevents drift from interfering with rapid interactions (click node, read tooltip, click another node).

## Validation Architecture

> Workflow validation is enabled (workflow.nyquist_validation not explicitly set, defaults to true per STATE.md context)

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat (R testing framework) |
| Config file | tests/testthat/ directory exists (16 test files found) |
| Quick run command | `Rscript -e "testthat::test_file('tests/testthat/test-mod-citation-network.R')"` |
| Full suite command | `Rscript -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PHYS-01 | Physics toggle does not collapse network | manual | Visual inspection: toggle physics on/off after returning to tab, verify nodes remain spread | ❌ Wave 0 — automated testing requires Shiny server + browser, impractical for unit tests |
| PHYS-02 | Small networks (≤20 nodes) retain ambient drift after stabilization | manual | Visual inspection: build 5-node network, wait for stabilization, observe gentle orbital motion | ❌ Wave 0 — requires visual observation of motion over time |

**Note:** Both requirements involve visual phenomena (collapse, ambient motion) that require human observation in a running Shiny app. Automated testing would require:
- Headless browser automation (Selenium/Playwright)
- vis.js canvas state inspection via JS
- Time-series position sampling to verify drift

This is disproportionate complexity for a 2-plan phase. Manual UAT is appropriate.

### Sampling Rate

- **Per task commit:** None — manual testing only
- **Per wave merge:** Manual visual check: toggle physics, observe drift
- **Phase gate:** Full UAT before `/gsd:verify-work` — test both collapse prevention and ambient drift with various network sizes

### Wave 0 Gaps

- [ ] `tests/manual/41-physics-stabilization-uat.md` — UAT checklist covering both requirements
  - PHYS-01: Build network, navigate away, return, toggle physics → no collapse
  - PHYS-02: Build 5-node network, wait for stabilization → gentle drift visible

*(No automated test infrastructure needed — manual UAT document is sufficient)*

## Sources

### Primary (HIGH confidence)

- [Context7 /visjs/vis-network](https://github.com/visjs/vis-network) - Physics configuration API, stabilization events, node positioning, wind forces
- [vis.js Physics Documentation](https://visjs.github.io/vis-network/docs/network/physics.html) - Comprehensive physics options reference
- [rdrr.io visPhysics](https://rdrr.io/cran/visNetwork/man/visPhysics.html) - R visNetwork physics function parameters
- [rdrr.io visEvents](https://rdrr.io/cran/visNetwork/man/visEvents.html) - R visNetwork event handling for stabilization

### Secondary (MEDIUM confidence)

- [vis.js GitHub Issue #3240](https://github.com/visjs/vis/issues/3240) - Node movement after stabilization ("restless node syndrome")
- Serapeum issue #131 - Singularity collapse bug description and reproduction steps
- Serapeum issue #130 - Ambient drift requirement and design constraints

### Tertiary (LOW confidence)

None — all findings verified with official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries verified via Context7 and existing codebase usage
- Architecture: HIGH - Patterns adapted from existing codebase (debounce, proxy, events)
- Pitfalls: HIGH - Collapse mechanism verified via Context7 node positioning docs + issue descriptions
- Ambient drift approach: MEDIUM - Exact damping values need empirical testing, but approach (conditional + reduced damping) is sound

**Research date:** 2026-03-03
**Valid until:** 2026-04-03 (30 days - vis.js is stable, no rapid changes expected)
