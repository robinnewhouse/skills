# Visual and evidence rules

## Quantities and confidence

- A quantitative axis compares the same units and population. Use a funnel only for linked stages in the same time window; otherwise show a chain with explicit population breaks or missing joins.
- Filled ratio bars require a known denominator. A selected list of successes is a count, not a success rate. State units, population, filters, and time window near the metric.
- Label bounded or dynamic results as snapshots, lower bounds, or approximations.
- Maturity is ordinal: define stages and show one position marker. A useful system scale is absent/unverified, partial/degraded, working with humans, automated, and governed with owner/monitoring/rollback. Adapt to the subject; never invent completion percentages.
- For system investigations, distinguish live automation, human operation, runnable but unverified code, retired work, missing wiring, and reported but unlocated claims. Pair color with text and solid/dashed lines. Omit irrelevant statuses for other subjects.
- Bound absence claims to what was inspected. Separate historical practice from enforced policy, live from healthy operation, and a human report from verified runtime evidence.
- Name cross-system joins and identifier namespaces. Preserve ambiguous attribution or referents rather than silently choosing an interpretation.

## Diagrams

- Every node has an explanatory role. Every edge ends on a node or labelled boundary; attach secondary context to the primary flow or explain its separate role.
- Keep labels next to their node or edge. Route connectors around text and cards, using compact orthogonal paths or a labelled bus. Distinct meanings need distinct junctions.
- Use dashed attached routes for missing or reported wiring. Keep corroborating sources subordinate to the main reading order.
- Use SVG coordinates for maps, with `fill="none"` on open connector paths. Give SVGs a title and description and provide an adjacent structured text equivalent.
- Balance the canvas and make the main flow understandable within ten seconds. Remove space that forces readers to reconstruct relationships.

## Desktop inspection

Inspect actual screenshots for every view, not only the DOM. Check text size, contrast, clipping, whitespace, edge endpoints, label attachment, and reading order. Regenerate screenshots of changed views after corrections.

Maintain one page-level h1, h2 view titles, tablist/tab/tabpanel relationships, roving tabindex, Arrow/Home/End behavior, visible focus, and reduced-motion handling. Print all views in landscape with source destinations visible. Orange works as an accent or fill; use darker colors for small text on off-white.

The bundled starter demonstrates components, not factual content or complete diagram wiring. Its sample numbers, four initial views, detached lower nodes, and placeholder source links require adaptation before delivery.
