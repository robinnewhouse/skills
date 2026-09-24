# Production mechanics

## Tool and project setup

Inspect the existing project, installed tools, and runtime before choosing dependencies. Reuse a working setup and lockfile. Check the selected renderer's current official documentation or installed help for exact APIs and commands. Do not install every candidate renderer or require a paid service when an available tool meets the request.

Keep source, assets, audio, cue data, and render instructions in the video project. Keep disposable frames and intermediate media separate from final deliverables. Package the editable files and lockfile without dependency directories, credentials, or unnecessary render caches. Document required external asset locations or include usable assets when permitted.

For ordinary MP4 delivery, a solid composition background prevents accidental transparency during fades. Choose resolution and aspect ratio for the viewing destination. Landscape 1920×1080 at 30 fps is a reasonable default, not a requirement. Test text at actual playback size; a nominal pixel threshold does not guarantee legibility.

## Narration and captions

Maintain canonical narration text, optional TTS pronunciation text, and caption text separately. Pronunciation substitutions should not leak into subtitles or source excerpts. Preview difficult acronyms, variable names, punctuation, and language switches in a short sample before generating everything.

Generate speech in coherent semantic units, often a paragraph or scene, rather than isolated words. Use stable IDs and cache by text, voice, model, and settings. Store no API secrets in the project. Use a configured voice service or local engine consistent with the user's request. If required narration cannot be produced, report the missing capability and finish the script/visual work that does not depend on it.

### Default voice: Gemini TTS, one clip per line

Use `assets/gen-narration.mjs`. It needs Node 18+, `ffmpeg` and `ffprobe`, and checks for them before spending any TTS quota. Prefer `vertex` or `gcloud` login over creating personal API keys. Copy it to the project's `scripts/`, write `src/script.json` as `[{id, lines: [...]}]`, and run it. It makes one clip per narration line, trims silence at both ends, measures each clip, and writes `src/timeline.json` with frame-exact cue start/end per line. In Remotion, place each clip in a `<Sequence from={cue.start}>` with `<Audio>`, drive highlights from the same cues, and write the SRT from them (captions are a track, not rendered). Splicing is exact because each line is its own measured file. No forced alignment needed.

Providers, picked by which credentials are present, in this order (override with `TTS=`):

| `TTS=` | Needs | Model (default) |
|---|---|---|
| `vertex` | `VERTEX_PROJECT` plus `gcloud` login | `gemini-3.1-flash-tts-preview` (newest on Vertex as of 2026-09) |
| `gcloud` | `GCP_PROJECT` with the Cloud Text-to-Speech API enabled, plus `gcloud` login | `gemini-3.1-flash-tts-preview` |
| `gemini` | `GEMINI_API_KEY` (Google AI Studio) | `gemini-3.8-flash-tts`, Interactions API |
| `say` | macOS only | built-in voice. Robotic: use only for timing drafts |

- Pick one voice (`VOICE`, default `Kore`; `Charon` and `Puck` also work well) and one `STYLE` delivery prompt for the whole video, so clips sound like one take.
- Put pronunciation fixes in `src/pronounce.json`. They apply to the speech text only, never to captions.
- For non-English narration set `TTS_LANGUAGE` (BCP-47, e.g. `fr-FR`); the `gcloud` provider sends it as the voice language.
- Clips are cached by a hash of provider, model, voice, style, language, `say` rate and text, so changing one line regenerates one clip.
- Gemini TTS models are preview. If a model ID is rejected, check the current list at ai.google.dev/gemini-api/docs/speech-generation and pass it as `GEMINI_TTS_MODEL`.
- In zsh, write `${MODEL}:generateContent`, not `$MODEL:generateContent`: zsh reads `:g` as a modifier and the URL 404s with an HTML page.
- Gemini narrates at about 145 words per minute, slower than `say`. Tie reveals to phrases inside a cue (character position × cue length), not fixed frame offsets, so a voice change doesn't break sync.
- Never write the key into the project. If no provider is available, the script generates a `say` draft on macOS; elsewhere it exits with an error. Either way, finish the work that doesn't depend on narration and report that the final voice is blocked on credentials.

Measure the generated files. Use timestamps or forced alignment when available, then inspect the alignment against the audio. Correct transcription errors without replacing words actually spoken with an outdated draft. Use phrase-level cues when word-level alignment is unavailable and report any timing uncertainty.

Captions should use natural phrase boundaries, readable line breaks, sufficient contrast, and a reserved safe region. Test long identifiers, Unicode, mathematical notation, and the target language's glyphs. Deliver captions as a subtitle track, never drawn into the frames: write an SRT from the cue timeline and add it to the MP4 as a toggleable track (`ffmpeg -i raw.mp4 -i captions.srt -map 0 -map 1 -c copy -c:s mov_text -metadata:s:s:0 language=eng final.mp4`, replacing `eng` with the ISO 639-2 code of the caption language, e.g. `fra`, `jpn`). Also ship the SRT beside the video. Burn captions in only when the user explicitly asks.

Music is optional. If used, keep speech clear through suitable levels and ducking, and inspect for clipping or distracting changes. Leave enough time for the last spoken word and the final visual result.

## One authoritative timeline

Store the project frame rate and global integer-frame cue positions centrally. Use half-open intervals `[startFrame, endFrame)` and stable IDs. Derive scene-local frames by subtracting the scene start. Convert measured audio timestamps consistently; accumulate from absolute times to avoid repeated rounding drift. Respect rational frame rates if the project uses them.

A cue should connect narration or silent reading time to the relevant visual event. Scenes, code highlights, captions, and audio placement consume the same cue data. Do not maintain independent copies of timing constants across components.

Audio duration, pauses, action time, and result-reading time all count. Overlapping visual transitions can shorten the composition compared with the sum of scene lengths. Account for that when placing audio, and distinguish deliberate speech overlap from an accidental collision. Recalculate downstream positions after narration changes.

Some visuals should anticipate a spoken idea; others should reveal its consequence after the words. Judge this against the meaning and actual playback, rather than imposing one universal millisecond offset.

## Deterministic rendering

The frame should be a function of frame index, project configuration, and fixed inputs. Derive animation from renderer time. Avoid wall-clock timers, accumulated mutable simulation state, and unseeded randomness during rendering. Precompute simulations, traces, and expensive assets when necessary.

Wait for fonts, images, and other assets before capture. Localize required assets so a network response cannot change a later render. Keep meaningful visual identity across scenes through shared data and components. In React, define component types at module scope rather than recreating them inside frame renders.

Test direct seeking, backward seeking, and rendering the same selected frame twice. Compare the resulting frame content, not compressed video file bytes. A scene that only works after playing from frame zero is not ready for parallel or out-of-order rendering.

Render the hardest representative section early, including a transition. Measure its rendering cost on the actual machine and estimate full-film time. Tune concurrency to available memory; do not assume maximum parallelism is faster. Simplify costly decorative effects before sacrificing the explanation's readability.

## Inspect the finished encode

Use the installed renderer's validation/build checks, then render the requested output. These example FFmpeg commands are optional when the tools are available:

```sh
ffprobe -v error -show_streams -show_format -of json final.mp4
ffmpeg -v error -i final.mp4 -f null -
```

Inspect the reported video dimensions, frame rate, stream durations, and expected audio stream. Compare video length with intended frame count divided by fps; account for frame granularity and audio codec padding. A successful process exit does not prove every requested stream exists. Decoding catches corrupted media but not teaching or layout errors.

Extract inspection frames from the encoded file. Cover every scene's start, important event, densest state, and end, plus frames immediately before and after each seam. Contact sheets reveal coverage, continuity, and pacing structure. Full-resolution frames or crops reveal clipped labels, tiny text, missing glyphs, and layering mistakes. Inspect a short frame strip around suspicious motion.

Play the complete video with audio if supported. Listen for pronunciation, clarity, unwanted overlap, abrupt edits, and cutoff. Watch whether the eye can follow state changes and whether reading holds are long enough. Look for a highlight referring to yesterday's script, a transition obscuring a result, or an audio tail extending beyond the last frame.

If playback or listening is unavailable, state that limitation. Do not claim audio synchronization or smooth motion was verified solely from file metadata or isolated frames. Keep intentional still holds; automatic motion metrics are diagnostic aids, not teaching requirements.

Record substantive defects with scene/cue IDs and timestamps. Fix them, inspect affected scenes and adjoining boundaries, then verify the newly encoded final file. Stop when the acceptance checks pass. Leave minor optional aesthetic changes out of the critical path.

## Handoff

Provide the final video, editable project, exact render command, dependencies/lockfile, script, captions, and source notes. State what was checked and any remaining limitation. Separate creator claims, measured results, and illustrative content. Store project-specific lessons with the project; changes to the installed skill require the user's request.
