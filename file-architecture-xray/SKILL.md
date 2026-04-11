---
name: file-architecture-xray
description: Create self-contained HTML architecture explainers for a specific source file, module, or closely related call path. Use when the user wants a visual, code-linked walkthrough of how one file works, asks for diagrams tied to real source slices, wants an explorable webpage instead of prose notes, or needs architecture-oriented file exploration in any repository.
---

# File Architecture X-Ray

Build a standalone HTML page that teaches one file through synchronized diagram, narrative, file map, curated code excerpts, and plain-English callouts anchored beside important code regions.

Keep the artifact file-specific. Do not try to explain the whole repository unless the user explicitly asks for it.

## Workflow

1. Inspect the target file and its immediate caller/callee context.
2. Identify 4-7 architectural zones inside the file.
3. Choose one primary file for the line-map. Usually this is the target file.
4. Decide where plain-English callouts should sit beside the code.
5. Write a JSON spec for the explainer page.
6. Run `scripts/build_xray_page.py` to generate the standalone HTML.
7. Sanity-check the generated page structure and verify the source excerpts and callout anchors match the intended line ranges.

## What To Inspect First

- Read the target file in numbered form.
- Read the nearest call-site that invokes it or the file it dispatches into.
- Look for contract boundaries:
  input normalization, option synthesis, dispatch, output normalization, error handling, telemetry, caching, or adaptation between incompatible abstractions.

If the file is large, do not visualize every helper. Group helpers into the zones that matter architecturally.

## Page Layout and Design

The generated page is a two-column layout:

### Left sidebar (sticky, scrollable)

- **Hero section**: page title, subtitle, and primary file path. No action buttons — the page is navigated by clicking diagram nodes, minimap segments, or scrolling.
- **Pipeline Diagram**: a vertical SVG flowchart of all zones. Each node is a rounded card with a clipped color accent bar on the left edge, a bold title, and two lines of monospace meta text. Nodes are connected by curved wires. Clicking a node scrolls to and highlights the corresponding slice on the right.
- **Detail panel**: shows the active zone's title, line range, description, and input/output contract shapes. Updates automatically as the user scrolls or clicks.
- **File Map (minimap)**: a vertical track with colored segments representing each zone's position within the primary file. Includes a line-number scale and a color legend.

### Right main pane (scrollable)

- **Intro section**: an eyebrow label, headline, explanatory paragraphs, and chip-style takeaways that frame the file's architectural role.
- **Zone slices**: one section per zone, each containing:
  - A header with badge, title, summary, and line range pill.
  - Note cards (terse, 2-3 per zone) laid out in a responsive grid.
  - A code panel with the source excerpt (dark theme, line numbers, file path header with macOS-style dots).
  - **Callout cards** (when present): positioned in a 230px rail to the left of the code, with each card pixel-aligned to its target line. A dashed connector line points from each card toward the code. On narrow viewports (< 940px), callouts stack above the code instead.

### Interaction

- Clicking a diagram node or minimap segment smooth-scrolls to the corresponding slice and highlights it.
- An IntersectionObserver auto-updates the active zone in the sidebar as the user scrolls through slices.
- No autoplay, no playback buttons, no gimmicks — the page is a reference document.

### Responsive behavior

- Below 1180px: the sidebar collapses above the main content (no longer sticky).
- Below 940px: slice layouts go single-column, callouts stack above code.

## Zone Selection Rules

Choose zones that represent transformations or decision points, not just top-level functions.

Good zones:

- request enters adapter
- messages converted
- provider options expanded
- stream output normalized
- usage/cost reconciled
- dynamic module dispatch

Weak zones:

- tiny helpers with no architectural leverage
- repeated utility functions that only support another zone
- every switch case as its own section

## Writing Style

Use the same tone as a strong architecture walkthrough:

- explain what the code is doing structurally, not line-by-line
- say what contract enters the zone and what contract leaves it
- call out why the zone exists
- highlight mismatches between abstractions when relevant
- keep each section opinionated and specific
- use callouts to explain local branches, special cases, or tricky transformations in ordinary English

Prefer claims like:

- "This block is the inbound adapter."
- "This is where one generic request fans out into provider-specific dialects."
- "This helper exists because the upstream and downstream contracts disagree."

Avoid generic tutorial language and avoid changelog-style narration.

## Spec Authoring

Write a spec JSON file before generating the page.

Read `references/page-spec.md` for the schema and authoring guidance.

Minimum recommended fields:

- `title`
- `subtitle`
- `source_path`
- `intro`
- `zones`

For each zone, include:

- `id`
- `title`
- `badge`
- `summary`
- `range_label`
- `detail_body`
- `input`
- `output`
- `color`
- `meta`
- `notes`
- `callouts` when the code benefits from beside-the-code explanation
- `source.path`
- `source.start`
- `source.end`

## Page Builder

Use:

```bash
python3 /Users/robin/.agents/skills/file-architecture-xray/scripts/build_xray_page.py \
  --spec /absolute/path/to/spec.json \
  --output /absolute/path/to/output.html
```

The builder:

- extracts the referenced source lines directly from disk
- escapes and renders code excerpts with line numbers
- generates the diagram, detail panel, line-map, narrative sections, and interaction logic
- produces a single standalone HTML file with no external dependencies

## Critical: Line Anchoring Geometry

Callout cards are absolutely positioned beside the code using pixel offsets computed from layout constants at the top of `build_xray_page.py`. These constants **must** match the actual rendered geometry of the code panel. If they drift, callouts will appear at the wrong lines.

The constants and what they represent:

- `CODE_ROW_HEIGHT` — the vertical step between consecutive code lines in pixels. This must equal the actual rendered height of a `.code-line` div. Currently 20px (set by `min-height: 20px` on `.code-line`).
- `CODE_HEADER_HEIGHT` — the distance from the top of the `.code` element to the top of the `<pre>` block. Includes the `.code` border-top (1px), `.code-header` padding/content/border-bottom. Currently 40px.
- `CODE_BODY_PADDING_TOP` — the `padding-top` on the `<pre>` element. Currently 18px.

The callout `top` formula is: `CODE_HEADER_HEIGHT + CODE_BODY_PADDING_TOP + (line - zone_start) * CODE_ROW_HEIGHT`.

### Rules to prevent anchoring bugs

1. **Never put whitespace inside `<pre>` tags.** Code line divs are joined with `""` (no separator), and the template must use `<pre>{code_html}</pre>` with no newlines or spaces. Inside `<pre>`, any newline character renders as a visible line break and adds ~15px of phantom spacing per line, making every callout drift further down the file.

2. **If you change any code-panel CSS** (`.code-header` padding, `.code-line` min-height, `<pre>` padding, `.code` border), you must update the corresponding constant in `build_xray_page.py` and regenerate.

3. **After regenerating, always verify alignment** by checking computed positions in the browser:
   ```js
   // In browser console or preview_eval:
   (() => {
     const slice = document.querySelector('.slice');
     const overlay = slice.querySelector('.callout-overlay');
     const card = slice.querySelector('.callout-card');
     const label = card.querySelector('.callout-line').textContent;
     const lineNum = parseInt(label.match(/(\d+)/)[1]);
     const line = slice.querySelector('#line-' + lineNum);
     const offset = card.getBoundingClientRect().top - line.getBoundingClientRect().top;
     return { label, offset }; // offset should be 0
   })()
   ```

4. **The layout uses CSS grid** (`.code-shell-true`) with two columns: a 230px callout rail and the code panel. The callout overlay is `position: relative` and cards are `position: absolute` within it. Both grid cells share the same top edge, so callout pixel offsets correspond directly to code line positions.

## Validation

After generation:

1. Confirm the output HTML exists.
2. Check that every zone excerpt matches the intended file and line range.
3. **Check that callout cards align to their target lines** — use the browser verification snippet above. The offset must be 0 for every card.
4. Check that the primary file map uses the correct file and line count.
5. If you changed the builder script, run it on a small real example to confirm it still works.

Use:

```bash
python3 /Users/robin/.codex/skills/.system/skill-creator/scripts/quick_validate.py \
  /Users/robin/.agents/skills/file-architecture-xray
```

## References

- Read `references/page-spec.md` before creating or editing a spec.
- Use the page builder script instead of hand-writing the full HTML unless there is a strong reason not to.
