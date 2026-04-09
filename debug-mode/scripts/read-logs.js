#!/usr/bin/env node
/**
 * Debug Log Reader - Fetch logs from the debug server
 * 
 * Usage:
 *   node read-logs.js              # Get recent logs
 *   node read-logs.js --errors     # Errors only
 *   node read-logs.js --json       # Output as JSON
 *   node read-logs.js --watch      # Watch for new logs
 *   node read-logs.js --clear      # Clear all logs
 *   node read-logs.js --level=warn # Filter by level
 */

const http = require('http');
const PORT = process.env.DEBUG_PORT || 3333;
const BASE = `http://localhost:${PORT}`;

const args = process.argv.slice(2);
const flags = {};
args.forEach(a => {
  if (a.startsWith('--')) {
    const [k, v] = a.slice(2).split('=');
    flags[k] = v || true;
  }
});

async function fetch(url) {
  return new Promise((resolve, reject) => {
    http.get(url, res => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => resolve(JSON.parse(data)));
    }).on('error', reject);
  });
}

async function del(url) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = http.request({ hostname: u.hostname, port: u.port, path: u.pathname, method: 'DELETE' }, res => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => resolve(JSON.parse(data)));
    });
    req.on('error', reject);
    req.end();
  });
}

function format(log) {
  const colors = { error: '\x1b[31m', warn: '\x1b[33m', info: '\x1b[36m', debug: '\x1b[90m' };
  const time = new Date(log.timestamp).toLocaleTimeString();
  let out = `${colors[log.level] || ''}[${log.level.toUpperCase().padEnd(5)}]\x1b[0m ${time} [${log.source}] ${log.message}`;
  if (log.data) out += '\n  ' + JSON.stringify(log.data, null, 2).split('\n').join('\n  ');
  return out;
}

async function main() {
  try {
    await fetch(`${BASE}/health`);
  } catch {
    console.error('\x1b[31mLog server not running. Start with: node log-server.js\x1b[0m');
    process.exit(1);
  }

  if (flags.clear) {
    const r = await del(`${BASE}/logs`);
    console.log(`Cleared ${r.cleared} logs`);
    return;
  }

  const endpoint = flags.errors ? '/errors' : '/logs';
  const params = new URLSearchParams();
  if (flags.level) params.set('level', flags.level);
  if (flags.source) params.set('source', flags.source);
  if (flags.limit) params.set('limit', flags.limit);

  if (flags.watch) {
    let lastTime = new Date().toISOString();
    console.log('Watching for logs... (Ctrl+C to stop)\n');
    setInterval(async () => {
      try {
        const p = new URLSearchParams(params);
        p.set('since', lastTime);
        const data = await fetch(`${BASE}/logs?${p}`);
        data.logs?.forEach(log => {
          console.log(flags.json ? JSON.stringify(log) : format(log));
          lastTime = log.timestamp;
        });
      } catch {}
    }, 500);
    return;
  }

  const data = await fetch(`${BASE}${endpoint}?${params}`);
  const logs = flags.errors ? data.errors : data.logs;

  if (!logs?.length) {
    console.log('No logs found');
    return;
  }

  if (flags.json) {
    console.log(JSON.stringify(logs, null, 2));
  } else {
    console.log(`\n${logs.length} logs:\n`);
    logs.forEach(l => console.log(format(l)));
  }
}

main().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
