# Cost Tracker Interactivity Plan

## Goal

Upgrade the cost tracker so the daily history is interactive and the operation table carries richer context, without introducing Plotly.

## Decisions

- Use a stacked `ggplot2` chart rendered in Shiny.
- Use native Shiny hover input plus a custom HTML tooltip instead of a heavy chart dependency.
- Represent each stacked section as an operation within a day.
- Show model breakdown inside the hover tooltip for the hovered operation/day segment.
- Replace raw emoji labels with the app's existing tiny icon language where practical.
- Keep data changes query-level only; no schema migration is required because `cost_log` already stores `operation`, `model`, token counts, cost, and timestamp.

## Scope

- Add normalized label/icon helpers for operations and models.
- Add cost-history segment aggregation and enriched operation summary aggregation.
- Replace the cost history `barplot()` with an interactive chart container and tooltip.
- Replace the cost-by-operation `tableOutput()` with HTML-capable rendering.
- Add focused tests for data formatting and aggregation.

## Risks

- Hovering stacked bars is more manual than using a JS chart library, so tooltip hit-testing must be derived from the plotted data.
- Some operation/day buckets may contain many models; tooltips should summarize cleanly instead of dumping raw rows.
- The current shell cannot run the project's R test suite directly without the full local R environment, so verification may need to stay at source-level unless the app environment is available.
