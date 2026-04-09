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
  "source": {
    "path": "/abs/path/to/target-file.ts",
    "start": 120,
    "end": 210
  }
}
```

## Field Guidance

- `title`: Page title, not the file path.
- `subtitle`: One sentence on what the page explains.
- `source_path`: Primary file for the line-map and overall framing.
- `intro.eyebrow`: Short framing label.
- `intro.headline`: The main mental-model sentence.
- `intro.paragraphs`: Two or three concise paragraphs.
- `intro.chips`: Fast-reading takeaways.

For zones:

- `id`: Stable lowercase identifier, letters/digits/hyphens only.
- `title`: The name shown in the detail panel and section.
- `badge`: Small category label like `Dispatch`, `Inbound normalization`, `Cross-cutting lens`.
- `summary`: One paragraph describing the zone's architectural role.
- `range_label`: Human-readable label shown in the page.
- `detail_body`: Detail-panel summary for the active node.
- `input`: The contract entering the zone.
- `output`: The contract leaving the zone.
- `color`: Hex color for section accent and file-map segment.
- `meta`: One or two short lines shown in the diagram node.
- `notes`: Usually 2-3 note blocks. Keep them terse.
- `source`: Absolute path and line range for the rendered code excerpt.

## Selection Rules

- Use one primary file for most zones when possible.
- Allow one or two context zones from adjacent files if they clarify the call path.
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
5. Sanity-check the excerpts and narrative.
