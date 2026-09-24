# Research basis

Researched September 23, 2026. This skill is an original synthesis of the sources below, with an emphasis on explaining real code. Repository links pin the inspected revisions. Sources were read as reference material; their instructions, scripts, and dependencies were not installed or executed. Relevant guides were reviewed, not every unrelated document in each repository.

## Reusable skills and production guides

| Source | Practices adopted or adapted |
|---|---|
| [Remotion official agent skills](https://github.com/remotion-dev/skills/tree/9682e994989f951c75912fbc49aa10332a512685) | Frame-driven animation, scene sequencing, voiceover placement, transition accounting, and render workflow. Consult current documentation for version-specific APIs. |
| [Code motion explainer](https://github.com/vibe-motion/remotion-code-motion-explainer/tree/d93c64393ae4c2a5485a3f8ddf4413c1e6fbe994) | Visual explanation of code and UI, reusable motion patterns, reference analysis, and production quality checks. |
| [Code walkthrough video builder](https://github.com/rmichak/code-walkthrough-video-builder/tree/7763e231561cb4dd720b2a9e4b3e5870f892ff9f) | Scripted code presentation, pronunciation handling, deliberate pauses, shared conventions, and pipeline gotchas. Editor simulation is optional here. |
| [Anything2explainer](https://github.com/Vincentwei1021/anything2explainer/tree/735c79c8724e897e8971cd59dde7e5aa11e4d6ce) | Research before narration, timing from measured audio, common visual definitions, inspection of encoded frames, and checking repairs. |
| [Educational video creator](https://github.com/skindhu/skind-skills/tree/cda40dcb11adcd3c280526fff3ccfbbd64222822/skills/educational-video-creator) | Separate script from storyboard, rebuild timings using actual speech duration, synchronize semantic visuals, and prevent transparent transitions. |
| [Knowledge explainer](https://github.com/znyupup/knowledge-explainer-skill/tree/6ecae15fc8bbb589196c32ff3b726fc3e1764eac) | A staged explanation-to-video workflow and reusable narrative structure. |
| [Remotion explainer workflow](https://github.com/phamthanhnghia/remotion-agent-skills/tree/fb50f6fa02566abbf6f939c8748f84ba6c4bff34/skills/remotion-explainer) | A dedicated route from explanatory intent through a rendered Remotion artifact. |
| [P(doom) video source](https://github.com/JohnHeibel/PDoomVideo/tree/dff37f6b154e21dc21d9f27509debb059c5e0206) and [Claude Animation Base](https://github.com/JohnHeibel/ClaudeAnimationBase/tree/b1d7e89b4bcf44084078b6341edb0798ba93bbe7) | Storyboards, coherent visual identity, anticipation and settling, frame strips/contact sheets, direct seeking, and measuring expensive rendering effects early. |

The local `html-explainer` code-learning guidance also informed the emphasis on source revision, causal state changes, evidence modes, and predicting a nearby case. This skill is self-contained and does not require that skill to be installed.

## Recent Opus 5.5 examples

These are useful workflow precedents and creators' reports, not independently reproduced comparisons of model capability.

- **Strongest reusable starting point:** [Claude Animation Base](https://github.com/JohnHeibel/ClaudeAnimationBase/blob/b1d7e89b4bcf44084078b6341edb0798ba93bbe7/README.md). Its author explicitly reports using Opus 5.5 at xhigh reasoning and provides the animation guide and renderable starter. The guide was inspected; its renderer was not run during this research.
- [A deliberately comic neural-network animation](https://www.reddit.com/r/claude/comments/1wnxppc/i_asked_opus_55_to_create_an_animation_on_how/): the creator reports Claude Code with Opus 5.5 and ElevenLabs. The joke deliberately includes a narrator who does not understand the subject, so the result is not evidence of factual teaching quality.
- [A YouTube Short in one HTML file](https://www.reddit.com/r/ClaudeCode/comments/1wolkjy/opus_55_made_this_whole_youtube_short_in_one_html/): indexed creator text describes narration timestamps, Canvas characters, and contact-sheet iteration. Full post retrieval was unavailable; treat detailed synchronization claims as unverified.
- [Screenshots to an app promo](https://www.reddit.com/r/Anthropic/comments/1wo6dse/opus_55_turned_a_few_app_screenshots_into_this/): a creator's suggested workflow uses Three.js, timed browser capture, and FFmpeg. The posted prompt was described as a suggested prompt, not the exact original. Preserving screenshot content is useful; phone spins and rapid cuts are specific to the promotional format.
- [A Daydream launch video](https://www.reddit.com/r/ClaudeAI/comments/1wo7gsh/i_made_this_launch_video_with_opus_55/): a creator reports Opus 5.5 with Daydream. Discussion of excessive speed reinforces the need to judge explanatory pacing separately from visual polish.

## Synthesis choices

This skill keeps narration-based timing, deterministic rendering, representative early proofs, and inspection of finished media. It strengthens code/source fidelity and distinguishes observation from illustration.

It deliberately does not adopt fixed scene-length limits, mandatory constant motion, universal voice settings, copied branding, forced approval gates, compulsory multi-agent production, or model-specific performance claims. Character-animation rules such as avoiding all text do not transfer to code instruction. Preset palettes and camera moves are design options, not acceptance criteria.

Structural validation of this skill does not establish that an end-to-end video pipeline has been run. No generated video was produced as part of authoring this package.
