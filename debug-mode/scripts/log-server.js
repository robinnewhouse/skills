#!/usr/bin/env node
/**
 * Debug Ingest Server — Cursor-style NDJSON log collector.
 *
 * Usage: node log-server.js [--port 7695] [--out .cursor]
 *
 * Accepts POSTs at /ingest/<sessionId> and appends each event as one NDJSON
 * line to <out>/debug-<sessionId-prefix>.log. Mirrors Cursor debug mode so
 * the same instrumentation pattern works both inside Cursor and with this
 * standalone server.
 *
 * Event shape (all optional except timestamp — filled in if missing):
 *   { sessionId, timestamp, hypothesisId, location, message, data }
 *
 * Read the logs via scripts/read-logs.js or tail the NDJSON file directly.
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};

const PORT = parseInt(flag('port', process.env.DEBUG_PORT || '7695'), 10);
const OUT_DIR = path.resolve(flag('out', '.cursor'));
const SESSION_ID = flag('session', crypto.randomUUID());
const SHORT = SESSION_ID.slice(0, 6);
const LOG_FILE = path.join(OUT_DIR, `debug-${SHORT}.log`);

fs.mkdirSync(OUT_DIR, { recursive: true });
fs.writeFileSync(LOG_FILE, '');

const stream = fs.createWriteStream(LOG_FILE, { flags: 'a' });
let eventCount = 0;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Debug-Session-Id',
  'Content-Type': 'application/json',
};

function write(entry) {
  stream.write(JSON.stringify(entry) + '\n');
  eventCount += 1;

  const hyp = entry.hypothesisId ? `[${entry.hypothesisId}] ` : '';
  const loc = entry.location ? `${entry.location} — ` : '';
  const msg = entry.message || '';
  process.stdout.write(`${hyp}${loc}${msg}\n`);
  if (entry.data) process.stdout.write(`  ${JSON.stringify(entry.data)}\n`);
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, cors);
    return res.end();
  }

  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);

  if (req.method === 'POST' && url.pathname.startsWith('/ingest/')) {
    let body = '';
    for await (const chunk of req) body += chunk;
    const sid = url.pathname.slice('/ingest/'.length) ||
      req.headers['x-debug-session-id'] || SESSION_ID;

    try {
      const parsed = body ? JSON.parse(body) : {};
      const events = Array.isArray(parsed) ? parsed : [parsed];
      for (const ev of events) {
        write({
          sessionId: sid,
          timestamp: ev.timestamp || Date.now(),
          hypothesisId: ev.hypothesisId,
          location: ev.location,
          message: ev.message,
          data: ev.data,
        });
      }
      res.writeHead(204, cors);
      return res.end();
    } catch (e) {
      res.writeHead(400, cors);
      return res.end(JSON.stringify({ error: e.message }));
    }
  }

  if (req.method === 'GET' && url.pathname === '/health') {
    res.writeHead(200, cors);
    return res.end(JSON.stringify({ ok: true, sessionId: SESSION_ID, logFile: LOG_FILE, events: eventCount }));
  }

  res.writeHead(404, cors);
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, '127.0.0.1', () => {
  process.stdout.write(
    `NDJSON ingest server started\n` +
    `  POST http://127.0.0.1:${PORT}/ingest/${SESSION_ID}\n` +
    `  header: X-Debug-Session-Id: ${SHORT}\n` +
    `  writing: ${LOG_FILE}\n`
  );
});

process.on('SIGINT', () => {
  stream.end(() => process.exit(0));
});
