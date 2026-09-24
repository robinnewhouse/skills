---
name: explainer-video
description: Create a rendered explainer video with editable animation, narration or deliberate silent pacing, captions, and source notes. Use when asked to make a video explaining code, runtime behavior, architecture, a technical concept, or another subject. Also use for narrated code walkthroughs and educational animations. Do not use for an interactive HTML explainer, slide deck, or video script alone unless the user explicitly requests this workflow.
---

# Explainer video

Make the mechanism visible. Deliver a playable video and the editable project needed to revise it.

## 1. Establish the explanation

Infer the audience, language, destination, duration, and visual tone from the request. Ask only about missing inputs that materially change the result. Use reasonable defaults for the rest: a focused 60–120 second landscape video, readable diagrams, and restrained motion. A requested format or duration takes precedence.

State one question the viewer should be able to answer afterward. Choose one concrete example that can carry the explanation from input through consequence. Keep the scope small enough to show the causal steps.

- For real code, read [code-explainers.md](references/code-explainers.md) before scripting. Inspect the actual source and verify the example.
- For other subjects, verify consequential facts against primary sources. Record dates and qualifications for changing claims. Label illustrative values. Omit unresolved claims or express their uncertainty accurately.
- For production, read [production.md](references/production.md) before selecting a renderer or generating audio.
- For this skill's research basis or requests about Opus examples, read [sources.md](references/sources.md). It is provenance, not a benchmark or an instruction to switch models.

Create a compact project brief using [storyboard-template.md](assets/storyboard-template.md). Keep research, script, timeline, and render notes with the video project. Existing equivalent project files are sufficient.

## 2. Write a teachable story

Write the full narration and visual intent before polishing animation. For a silent video, write the on-screen explanation and reading holds instead.

Structure every video as tell them what you'll tell them, tell them, then tell them what you told them:

- **Opening roadmap (5–10 s):** after the opening question, name the two to four parts the video will cover, in one spoken line, with matching on-screen chips. The viewer should know where the video is going.
- **Body:** the spine below.
- **Closing recap (10–20 s):** a titled recap that replays the same parts, in the same words and order, plus the single takeaway or first action. Hold the final frame about 2 s, then fade out. Never end on the last body line.

Use the same labels in the roadmap, the body headings, and the recap so repetition does the remembering.

Use this spine for the body when appropriate:

1. Pose the concrete question and show the input or situation.
2. Reveal the responsible mechanism through a small number of visible state changes.
3. Show the resulting output or consequence.
4. Change one meaningful condition and explain the different outcome.
5. Return to the question, with a short prediction prompt or a link to the responsible source, then the closing recap.

Each beat should have a teaching purpose, an observable change, and a result the viewer can inspect. A scene can contain several related sentences. Keep stable objects on screen while their relationships change. Introduce labels before using them; maintain consistent names, colors, and spatial roles.

Use motion to direct attention, reveal order, or show causation. Let a difficult result sit still long enough to read. Avoid decorative movement that competes with code, diagrams, or narration. Use metaphors only when their mapping helps, and show the limit if it affects the explanation.

Self-review the script for accuracy, missing causal steps, repetition, and audience fit. Continue production within the authorized task; these stages are work checkpoints, not mandatory user approval gates.

## 3. Establish timing and prove the design

Reuse a suitable existing renderer. Otherwise prefer Remotion with React/SVG for code, diagrams, data, and UI. Consider Manim for mathematical transformations or Canvas/p5 for illustrated scenes. Use 3D when spatial relationships earn the extra complexity. Keep the production model and tools requested by the user.

For narrated work, use Gemini TTS (via Vertex with the user's gcloud login when available) through [gen-narration.mjs](assets/gen-narration.mjs) (see the production reference); do not ship the macOS `say` voice unless the user accepts it. Test a short voice sample with difficult names and code identifiers. Generate or obtain usable narration, measure its duration, and build the authoritative cue timeline from the actual audio. Draft word-count estimates are provisional. With supplied audio, align to the recording.

Use stable scene and cue IDs. Drive narration, highlights, the caption track, and scene boundaries from the same timeline. For silent work, explicitly budget time to read and inspect each change. If a fixed duration is too short, reduce scope or script density.

Render a representative short section before building the whole video. Include the hardest explanatory state, real typography, narration/captions if applicable, and an adjacent scene transition. Inspect it at the intended viewing size. Resolve readability, timing, renderer compatibility, and render speed here.

## 4. Build the full video

Implement scenes against the agreed visual system and measured timeline. Keep theme, reusable actors, layout conventions, and timing in shared definitions. Make every rendered frame reproducible when sought directly or rendered out of order.

Use purposeful highlights and concise labels. Show real code in readable excerpts, with omissions explicit. Keep diagrams and state synchronized with the same event that drives the code highlight. Preserve the meaning of real screenshots and measurements.

Cache audio and expensive assets; regenerate only changed material. Adjust adjacent cues and boundaries when a scene changes. Captions are a toggleable subtitle track in the MP4 plus an SRT file, never drawn into the frames. Use sound effects and music only when they support the requested tone and leave speech intelligible.

## 5. Verify the rendered artifact

Render the complete video. Inspect the encoded output, not just the editor preview:

- Check file integrity, dimensions, frame rate, duration, and required audio streams.
- Review scene starts, important state changes, dense frames, endings, and both sides of each transition. Use contact sheets for coverage and full-size frames for text.
- Play motion with audio when the environment supports it. Check pronunciation, intelligibility, cue alignment, reading time, audio tails, and transitions.
- Check factual claims and displayed code/state against their evidence. Confirm the final result answers the opening question.

Fix substantive problems, inspect the changed scenes and neighboring seams, then recheck the final encode. See the production reference for specific methods and limits. Report which checks were actually performed; stills and metadata cannot establish audio quality or continuous motion quality.

## Completion

Deliver the playable MP4 unless another format was requested, editable source and reproducible render command, narration/script, captions for spoken content, and concise source/validation notes. Link or display the video directly using the host's media support. Include a poster/contact sheet only if useful.

The task is complete when the requested video renders, the explanation matches the evidence, critical text is readable, timing and media checks pass, and any inspection limitations are stated. A storyboard or preview alone does not complete a video request. If a required capability is unavailable, finish independent work and identify the specific blocked deliverable.
