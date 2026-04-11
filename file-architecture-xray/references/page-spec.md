# Page Spec

Use this skill by writing a JSON spec, then generating the final page from that spec.

## Authoring Heuristic

Think in this order:

1. What is the file's architectural job?
2. What are the 4-7 biggest transformations or control points?
3. What line ranges best demonstrate each one?
4. What is the contract entering and leaving each zone?

The best pages are selective. Use enough code to anchor the explanation, not enough to recreate the whole file.

## Required Top-Level Fields

```json
{
  "title": "Provider Gateway X-Ray",
  "subtitle": "How one file reshapes requests and streams provider output back into the SDK contract.",
  "source_path": "/abs/path/to/target-file.ts",
  "source_total_lines": 781,
  "intro": {
    "eyebrow": "Mental Model",
    "headline": "This file is a protocol adapter.",
    "paragraphs": [
      "Paragraph one.",
      "Paragraph two."
    ],
    "chips": [
      "input shape becomes output shape",
      "dispatch happens here"
    ]
  },
  "zones": []
}
```

## Zone Shape

```json
{
  "id": "messages",
  "title": "Message normalization",
  "badge": "Inbound normalization",
  "summary": "Internal messages are converted into the shape expected by the downstream runtime.",
  "range_label": "target-file.ts 120-210",
  "detail_body": "This is the inbound adapter for the file.",
  "input": "InternalMessage[]",
  "output": "RuntimeMessage[]",
  "color": "#157a6e",
  "meta": [
    "toRuntimeMessages()",
    "target-file.ts 120-210"
  ],
  "notes": [
    {
      "label": "Why it matters",
      "body": "This is where the file preserves metadata that would otherwise be lost."
    },
    {
      "label": "Input -> output",
      "body": "InternalMessage[] -> RuntimeMessage[]"
    }
  ],
  "callouts": [
    {
      "line": 155,
      "lines_label": "Lines 152-160",
      "title": "Special-case branch",
      "body": "Explain what this branch is doing in plain English and why it exists."
    }
  ],
  "source": {
    "path": "/abs/path/to/target-file.ts",
    "start": 120,
    "end": 210
  }
}
```

## Field Guidance

Top-level:

- `title`: Page title, not the file path.
- `subtitle`: One sentence on what the page explains.
- `source_path`: Primary file for the line-map and overall framing.
- `source_total_lines`: Optional. Total lines in the primary file. If omitted, the builder reads the file to count.
- `intro.eyebrow`: Short framing label.
- `intro.headline`: The main mental-model sentence.
- `intro.paragraphs`: Two or three concise paragraphs.
- `intro.chips`: Fast-reading takeaways shown as pill-shaped chips.

For zones:

- `id`: Stable lowercase identifier, letters/digits/hyphens only.
- `title`: The name shown in the diagram node, detail panel, and slice header.
- `badge`: Small category label like `Dispatch`, `Inbound normalization`, `Cross-cutting lens`.
- `summary`: One paragraph describing the zone's architectural role.
- `range_label`: Human-readable label shown in the slice header and detail panel.
- `detail_body`: Summary shown in the sidebar detail panel when this zone is active.
- `input`: The contract entering the zone. Shown in the sidebar "Input shape" box.
- `output`: The contract leaving the zone. Shown in the sidebar "Output shape" box.
- `color`: Hex color used for the slice accent bar, diagram node accent, minimap segment, and legend swatch.
- `meta`: One or two short lines shown in the diagram node (monospace). If omitted, falls back to `range_label`.
- `notes`: Usually 2-3 note blocks. Each has a `label` and `body`. Keep them terse. Rendered in a responsive grid above the code.
- `callouts`: Optional line-anchored explanation cards shown in a rail beside the code. Use these for local logic that deserves ordinary-English explanation right next to the relevant excerpt.
- `source.path`: Absolute path to the file for the code excerpt.
- `source.start`: First line number to include.
- `source.end`: Last line number to include.

## Callout Guidance

Use callouts when:

- a branch is subtle
- a local transformation is easy to miss
- a helper call hides important meaning
- a provider- or framework-specific quirk needs translation into plain English

Suggested callout shape:

```json
{
  "line": 210,
  "lines_label": "Lines 208-214",
  "title": "Why this branch exists",
  "body": "This branch only runs when the upstream contract does not carry the metadata in the expected place."
}
```

Guidelines:

- Prefer 1-3 callouts per zone.
- Anchor each callout to a representative line inside the excerpt.
- The `line` field must be a line number **within the zone's `source.start`..`source.end` range**. The builder computes the card's vertical position as a pixel offset from the zone's start line.
- Keep each callout to 1-3 short sentences.
- Prefer 220 characters or less when possible.
- Do not restate the section summary; use callouts for more local explanation.
- Callout cards are positioned absolutely in a 230px rail to the left of the code panel. Cards anchored to lines that are close together may overlap. Avoid stacking more than 3 long cards in a small line range.
- After generating, always verify that cards visually align with their target lines in the browser. See SKILL.md "Critical: Line Anchoring Geometry" for the verification procedure.

## Selection Rules

- Use one primary file for most zones when possible.
- **Include a caller context zone** when the target file receives a pre-shaped input from an upstream call site. Show the caller's code so the reader understands what contract the file actually receives and why certain assumptions hold. Place this zone first.
- Allow one or two context zones from adjacent files (caller, delegated module) if they clarify the call path or a separated concern.
- Do not include more than seven zones unless the user explicitly asks for depth.
- Keep each excerpt tight. Prefer 20-90 lines.

## Output Naming

Use obvious names:

- `docs/architecture-analysis/target-file-xray.html`
- `docs/architecture-analysis/provider-adapter-xray.html`
- `scratch/foo-xray.html`

## Example Workflow

1. Read the target file with line numbers.
2. Read one caller or one downstream dispatch file.
3. Draft the spec JSON.
4. Generate the page.
5. Verify callout alignment in the browser (offset must be 0).
6. Sanity-check the excerpts and narrative.
