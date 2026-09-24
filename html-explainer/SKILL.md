---
name: html-explainer
description: Create standalone HTML explainers for understanding code, runtime behavior, concepts, or system architecture. Use for guided learning and visual exploration, rather than slide decks or production applications.
---

# HTML Explainer

Create a durable reference that teaches through diagrams and evidence. Design for a wide desktop viewport; mobile work applies only when requested.

1. Identify the reader's question, relevant prior knowledge, and available evidence. For code understanding, read [references/code-learning.md](references/code-learning.md) and select a template by the learning task. Start with one concrete case, expose the causal steps, and offer a changed-case check. Keep prerequisite help and exercises optional. For broad system reference, use an atlas of distinct questions; view count follows the subject.
2. Adapt [assets/atlas-starter.html](assets/atlas-starter.html), reusing its visual tokens and useful components. Reshape the layout around the selected lesson; its four sample views are not a required curriculum. Replace sample claims, numbers, links, and bracketed prompts. Use inline CSS, SVG, and minimal JavaScript in one standalone HTML file.
3. Give every view a question, reading guide, supported conclusion, remaining uncertainty or scope limit, and relevant sources. Put the synthesis headline only in the synthesis view. Keep the shared title, date, tabs, and applicable legend compact and non-sticky.
4. Read [references/visual-rules.md](references/visual-rules.md) when constructing diagrams or encoding quantities, status, or maturity. Preserve keyboard tabs, visible focus, SVG descriptions, and print support. Add adjacent text explanations for complex diagrams.
5. Audit claims against sources separately from layout. For code, link the revision and symbols; distinguish recorded traces, live execution, and illustrative models. Verify relevant outputs and transitions against the source. For research-heavy current-state atlases, use a fresh reviewer subagent when available, asking for exact unsupported snippets and replacement wording. Otherwise perform a separate source audit and disclose the lack of independent review.
6. Open the HTML using available browser tools. Capture and inspect every view at roughly 1440px width; fix clipping, unreadable labels, detached edges, and misleading encodings. Exercise tabs by click and Arrow/Home/End keys, direct hash links, and print visibility; check browser errors. If browser inspection is unavailable, state that visual QA remains unverified.
7. Save the final HTML, per-view screenshots, and representative preview in the task's durable output directory. Link the HTML and show the preview when supported. External hosting or asset-stash uploads apply only when requested and available.

Use off-white, dark text, neutral panels, and restrained orange accents by default, adapting to requested branding. Prefer compact reference typography, meaningful whitespace, and structural color. Use system fonts unless licensed fonts are already available; avoid gradients and oversized pitch-deck framing.

For exemplar selection or questions about pedagogical evidence, consult [references/research.md](references/research.md). It distinguishes empirical findings from design precedents and our template synthesis. Visual polish and interaction counts do not demonstrate comprehension.
