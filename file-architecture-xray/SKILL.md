---
name: file-architecture-xray
description: Create self-contained HTML architecture explainers for a specific source file, module, or closely related call path. Use when the user wants a visual, code-linked walkthrough of how one file works, asks for diagrams tied to real source slices, wants an explorable webpage instead of prose notes, or needs architecture-oriented file exploration in any repository.
---

# File Architecture X-Ray

Build a standalone HTML page that teaches one file through synchronized diagram, narrative, file map, and curated code excerpts.

Keep the artifact file-specific. Do not try to explain the whole repository unless the user explicitly asks for it.

## Workflow

1. Inspect the target file and its immediate caller/callee context.
2. Identify 4-7 architectural zones inside the file.
3. Choose one primary file for the line-map. Usually this is the target file.
4. Write a JSON spec for the explainer page.
5. Run `scripts/build_xray_page.py` to generate the standalone HTML.
6. Sanity-check the generated page structure and verify the source excerpts match the intended line ranges.

## What To Inspect First

- Read the target file in numbered form.
- Read the nearest call-site that invokes it or the file it dispatches into.
- Look for contract boundaries:
  input normalization, option synthesis, dispatch, output normalization, error handling, telemetry, caching, or adaptation between incompatible abstractions.

If the file is large, do not visualize every helper. Group helpers into the zones that matter architecturally.

## Output Standard

Produce one self-contained HTML file with:

- a left-side diagram pane
- a synchronized detail panel for the active zone
- a right-side narrative with one section per zone
- a line-map for the primary file
- real source excerpts with line numbers
- lightweight client-side interaction only; no external dependencies

Default output location:

- If the repo already has architecture docs or a scratch docs folder, place the file there.
- Otherwise place it under `docs/architecture-analysis/` or a similarly obvious repo-local docs path.

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
- `source.path`
- `source.start`
- `source.end`

## Page Builder

Use:

```bash
python3 /Users/robin/.codex/skills/file-architecture-xray/scripts/build_xray_page.py \
  --spec /absolute/path/to/spec.json \
  --output /absolute/path/to/output.html
```

The builder:

- extracts the referenced source lines directly from disk
- escapes and renders code excerpts with line numbers
- generates the diagram, detail panel, line-map, narrative sections, and interaction logic
- produces a single standalone HTML file

## Validation

After generation:

1. Confirm the output HTML exists.
2. Check that every zone excerpt matches the intended file and line range.
3. Check that the primary file map uses the correct file and line count.
4. If you changed the builder script, run it on a small real example to confirm it still works.

Use:

```bash
python3 /Users/robin/.codex/skills/.system/skill-creator/scripts/quick_validate.py \
  /Users/robin/.codex/skills/file-architecture-xray
```

## References

- Read `references/page-spec.md` before creating or editing a spec.
- Use the page builder script instead of hand-writing the full HTML unless there is a strong reason not to.
