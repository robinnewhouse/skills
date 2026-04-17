#!/usr/bin/env node
/**
 * Debug Log Reader — tails / filters an NDJSON debug log.
 *
 * Usage:
 *   node read-logs.js                         # most recent .cursor/debug-*.log
 *   node read-logs.js --file .cursor/debug-abc.log
 *   node read-logs.js --hyp B                 # filter by hypothesisId
 *   node read-logs.js --grep "pty exit"       # substring match on message
 *   node read-logs.js --tail 50               # last N events
 *   node read-logs.js --watch                 # stream new events
 *   node read-logs.js --summary               # counts per hypothesis/location
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  if (i < 0) return fallback;
  const next = args[i + 1];
  return !next || next.startsWith('--') ? true : next;
};

function latestLog() {
  const dir = '.cursor';
  if (!fs.existsSync(dir)) return null;
  const matches = fs.readdirSync(dir)
    .filter(f => /^debug-.*\.log$/.test(f))
    .map(f => ({ f, mtime: fs.statSync(path.join(dir, f)).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime);
  return matches[0] ? path.join(dir, matches[0].f) : null;
}

const file = flag('file') || latestLog();
if (!file || !fs.existsSync(file)) {
  process.stderr.write('No debug log found. Start scripts/log-server.js first.\n');
  process.exit(1);
}

const hyp = flag('hyp');
const grep = flag('grep');
const tailN = parseInt(flag('tail', '0'), 10);
const watch = flag('watch');
const summary = flag('summary');

function parse(line) {
  try { return JSON.parse(line); } catch { return null; }
}

function matches(ev) {
  if (hyp && ev.hypothesisId !== hyp) return false;
  if (grep && !(ev.message || '').includes(grep)) return false;
  return true;
}

function format(ev) {
  const t = new Date(ev.timestamp).toISOString().slice(11, 23);
  const h = ev.hypothesisId ? `[${ev.hypothesisId}] ` : '';
  const loc = ev.location ? `${ev.location} — ` : '';
  let out = `${t} ${h}${loc}${ev.message || ''}`;
  if (ev.data) out += '\n  ' + JSON.stringify(ev.data);
  return out;
}

function readAll() {
  return fs.readFileSync(file, 'utf8')
    .split('\n')
    .map(parse)
    .filter(Boolean);
}

if (summary) {
  const events = readAll();
  const byHyp = {};
  const byLoc = {};
  for (const ev of events) {
    byHyp[ev.hypothesisId || '(none)'] = (byHyp[ev.hypothesisId || '(none)'] || 0) + 1;
    if (ev.location) byLoc[ev.location] = (byLoc[ev.location] || 0) + 1;
  }
  process.stdout.write(`File: ${file}\nEvents: ${events.length}\n\nBy hypothesis:\n`);
  for (const [k, v] of Object.entries(byHyp)) process.stdout.write(`  ${k}: ${v}\n`);
  process.stdout.write(`\nTop locations:\n`);
  for (const [k, v] of Object.entries(byLoc).sort((a, b) => b[1] - a[1]).slice(0, 10)) {
    process.stdout.write(`  ${v.toString().padStart(5)}  ${k}\n`);
  }
  process.exit(0);
}

if (watch) {
  process.stdout.write(`Watching ${file}\n`);
  let pos = fs.statSync(file).size;
  fs.watch(file, () => {
    const size = fs.statSync(file).size;
    if (size <= pos) { pos = size; return; }
    const fd = fs.openSync(file, 'r');
    const buf = Buffer.alloc(size - pos);
    fs.readSync(fd, buf, 0, buf.length, pos);
    fs.closeSync(fd);
    pos = size;
    for (const line of buf.toString('utf8').split('\n')) {
      const ev = parse(line);
      if (ev && matches(ev)) process.stdout.write(format(ev) + '\n');
    }
  });
  return;
}

let events = readAll().filter(matches);
if (tailN > 0) events = events.slice(-tailN);

if (!events.length) {
  process.stdout.write('No matching events.\n');
  process.exit(0);
}

for (const ev of events) process.stdout.write(format(ev) + '\n');
