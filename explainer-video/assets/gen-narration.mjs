#!/usr/bin/env node
// Narration generator for explainer videos.
//
// Reads  src/script.json  : [{id, lines: [string, ...]}, ...]   (one clip per line)
// Writes public/audio/*.wav, out/captions.srt (SRT env), and src/timeline.json with measured, frame-exact cues:
//   {fps, total, scenes: [{id, start, end, cues: [{id, text, file, start, end}]}]}
//
// Providers (TTS env var, default: first one whose credentials are present):
//   gemini  GEMINI_API_KEY          Gemini API, model GEMINI_TTS_MODEL (default gemini-3.8-flash-tts)
//   vertex  VERTEX_PROJECT + gcloud Vertex AI generateContent with your gcloud login, model VERTEX_TTS_MODEL
//                                   (default gemini-3.1-flash-tts-preview), location VERTEX_LOCATION (global)
//   gcloud  GCP_PROJECT + gcloud    Cloud Text-to-Speech Gemini-TTS, model GCLOUD_TTS_MODEL
//                                   (default gemini-3.1-flash-tts-preview); needs texttospeech API enabled
//   say     macOS                   built-in voice; last-resort fallback, sounds robotic
//
// Other env: VOICE (Kore), STYLE (delivery prompt), FPS (30), GAP (0.3s between lines),
// LEAD (0.4s scene lead-in), TAIL (0.9s scene tail), END_HOLD (2s still hold after the last line). Clips are cached by a hash of
// provider+model+voice+style+text, so editing one line regenerates only that clip.
// Leading/trailing silence is trimmed so cue timings reflect the actual speech.
import {execFileSync} from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const env = process.env;
const FPS = Number(env.FPS ?? 30), GAP = Number(env.GAP ?? 0.3), LEAD = Number(env.LEAD ?? 0.4), TAIL = Number(env.TAIL ?? 0.9), END_HOLD = Number(env.END_HOLD ?? 2);
const PROVIDER = env.TTS ?? (env.GEMINI_API_KEY ? 'gemini' : env.VERTEX_PROJECT ? 'vertex' : env.GCP_PROJECT ? 'gcloud' : 'say');
const VOICE = env.VOICE ?? (PROVIDER === 'say' ? 'Samantha' : 'Kore');
const STYLE = env.STYLE ?? 'warm, clear, calm explainer narrator, natural conversational pace, confident and not salesy';
const MODEL = PROVIDER === 'gemini' ? (env.GEMINI_TTS_MODEL ?? 'gemini-3.8-flash-tts')
  : PROVIDER === 'vertex' ? (env.VERTEX_TTS_MODEL ?? 'gemini-3.1-flash-tts-preview')
  : PROVIDER === 'gcloud' ? (env.GCLOUD_TTS_MODEL ?? 'gemini-3.1-flash-tts-preview') : 'say';
// Optional pronunciation map: src/pronounce.json {"GPT": "G P T"} — applied to TTS text only, never captions.
const PRON = fs.existsSync('src/pronounce.json') ? JSON.parse(fs.readFileSync('src/pronounce.json', 'utf8')) : {};
const ttsText = (t) => Object.entries(PRON).reduce((s, [k, v]) => s.replace(new RegExp(`\\b${k}\\b`, 'g'), v), t);

const run = (cmd, args) => execFileSync(cmd, args, {stdio: ['ignore', 'pipe', 'pipe']});
const duration = (f) => parseFloat(run('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f]).toString());

// Find the first long base64 payload anywhere in a JSON response (response shapes vary by API version).
function findAudio(o) {
  if (!o || typeof o !== 'object') return null;
  for (const [k, v] of Object.entries(o)) {
    if ((k === 'data' || k === 'audioContent') && typeof v === 'string' && v.length > 1000) return v;
    const r = findAudio(v);
    if (r) return r;
  }
  return null;
}

async function post(url, headers, body) {
  for (let attempt = 1; ; attempt++) {
    const res = await fetch(url, {method: 'POST', headers: {'Content-Type': 'application/json', ...headers}, body: JSON.stringify(body)});
    const json = await res.json().catch(() => ({}));
    if (res.ok) return json;
    if (attempt < 4 && (res.status === 429 || res.status >= 500)) { await new Promise((r) => setTimeout(r, 2000 * attempt)); continue; }
    throw new Error(`${PROVIDER} TTS ${res.status}: ${JSON.stringify(json).slice(0, 400)}`);
  }
}

// Returns a Buffer that is either a WAV (RIFF) or raw 24 kHz s16le PCM.
async function synth(text) {
  if (PROVIDER === 'gemini') {
    const json = await post('https://generativelanguage.googleapis.com/v1beta/interactions', {'x-goog-api-key': env.GEMINI_API_KEY}, {
      model: MODEL,
      input: [{type: 'user_input', content: [{type: 'text', text, annotations: [{type: 'speech_metadata', style: STYLE}]}]}],
      response_format: {type: 'audio'},
      generation_config: {speech_config: [{voice: VOICE}]},
    });
    const b64 = findAudio(json);
    if (!b64) throw new Error('no audio in Gemini response: ' + JSON.stringify(json).slice(0, 400));
    return Buffer.from(b64, 'base64');
  }
  if (PROVIDER === 'vertex') {
    // Style goes in as a spoken-direction prefix; the model follows it without reading it aloud.
    const token = run('gcloud', ['auth', 'print-access-token']).toString().trim();
    const loc = env.VERTEX_LOCATION ?? 'global';
    const host = loc === 'global' ? 'aiplatform.googleapis.com' : `${loc}-aiplatform.googleapis.com`;
    const json = await post(`https://${host}/v1/projects/${env.VERTEX_PROJECT}/locations/${loc}/publishers/google/models/${MODEL}:generateContent`,
      {Authorization: `Bearer ${token}`}, {
        contents: [{role: 'user', parts: [{text: `Read this as a ${STYLE.replace(/\.$/, '')}: ${text}`}]}],
        generationConfig: {responseModalities: ['AUDIO'], speechConfig: {voiceConfig: {prebuiltVoiceConfig: {voiceName: VOICE}}}},
      });
    const b64 = findAudio(json);
    if (!b64) throw new Error('no audio in Vertex response: ' + JSON.stringify(json).slice(0, 400));
    return Buffer.from(b64, 'base64'); // raw 24 kHz s16le PCM
  }
  if (PROVIDER === 'gcloud') {
    const token = run('gcloud', ['auth', 'print-access-token']).toString().trim();
    const json = await post('https://texttospeech.googleapis.com/v1/text:synthesize',
      {Authorization: `Bearer ${token}`, 'x-goog-user-project': env.GCP_PROJECT}, {
        input: {prompt: STYLE, text},
        voice: {languageCode: 'en-us', name: VOICE, model_name: MODEL},
        audioConfig: {audioEncoding: 'LINEAR16', sampleRateHertz: 24000},
      });
    return Buffer.from(json.audioContent, 'base64');
  }
  const tmp = '/tmp/_narration.aiff';
  run('say', ['-v', VOICE, '-r', env.RATE ?? '188', '-o', tmp, text]);
  return fs.readFileSync(tmp);
}

async function clip(text, out) {
  const raw = await synth(ttsText(text));
  const tmp = out + '.src';
  fs.writeFileSync(tmp, raw);
  const isRaw = PROVIDER !== 'say' && raw.subarray(0, 4).toString() !== 'RIFF';
  const input = isRaw ? ['-f', 's16le', '-ar', '24000', '-ac', '1', '-i', tmp] : ['-i', tmp];
  // Trim silence at both ends (reverse trick), normalise to 48 kHz mono.
  const trim = 'silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,areverse,' +
    'silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,areverse';
  run('ffmpeg', ['-y', '-v', 'error', ...input, '-af', trim, '-ar', '48000', '-ac', '1', out]);
  fs.unlinkSync(tmp);
}

const script = JSON.parse(fs.readFileSync('src/script.json', 'utf8'));
fs.mkdirSync('public/audio', {recursive: true});
console.log(`provider=${PROVIDER} model=${MODEL} voice=${VOICE}`);
let t = 0;
const scenes = [];
for (const s of script) {
  const start = t, cues = [];
  t += LEAD;
  for (const [i, line] of s.lines.entries()) {
    const h = crypto.createHash('sha1').update([PROVIDER, MODEL, VOICE, STYLE, ttsText(line)].join('|')).digest('hex').slice(0, 10);
    const file = `audio/${s.id}_${i}_${h}.wav`, out = 'public/' + file;
    if (!fs.existsSync(out)) { process.stdout.write(`  ${s.id}.${i} … `); await clip(line, out); console.log('ok'); }
    const d = duration(out);
    const words = line.split(/\s+/).length;
    if (d > words / 1.3 + 1.5) console.warn(`  ! ${s.id}.${i}: ${d.toFixed(1)}s for ${words} words — listen for spoken style text or long pauses`);
    // Accumulate absolute seconds; round only when converting to frames (no drift).
    cues.push({id: `${s.id}.${i}`, text: line, file, start: Math.round(t * FPS), end: Math.round((t + d) * FPS)});
    t += d + GAP;
  }
  t += TAIL - GAP;
  scenes.push({id: s.id, start: Math.round(start * FPS), end: Math.round(t * FPS), cues});
}
t += END_HOLD;
scenes[scenes.length - 1].end = Math.round(t * FPS);
fs.writeFileSync('src/timeline.json', JSON.stringify({fps: FPS, total: Math.round(t * FPS), provider: PROVIDER, model: MODEL, voice: VOICE, scenes}, null, 1));
// Captions as an SRT file (muxed later as a toggleable subtitle track, never burned into frames).
const SRT = env.SRT ?? 'out/captions.srt';
const stamp = (fr) => { const ms = Math.round((fr / FPS) * 1000), p = (n, w = 2) => String(n).padStart(w, '0');
  return `${p(Math.floor(ms / 3600000))}:${p(Math.floor(ms / 60000) % 60)}:${p(Math.floor(ms / 1000) % 60)},${p(ms % 1000, 3)}`; };
fs.mkdirSync(SRT.split('/').slice(0, -1).join('/') || '.', {recursive: true});
fs.writeFileSync(SRT, scenes.flatMap((s) => s.cues).map((c, i) => `${i + 1}\n${stamp(c.start)} --> ${stamp(c.end + 8)}\n${c.text}\n`).join('\n'));
console.log(`total ${t.toFixed(1)}s  captions → ${SRT}`);
for (const s of scenes) console.log(`${s.id} @${(s.start / FPS).toFixed(1)}s  ${((s.end - s.start) / FPS).toFixed(1)}s`);
