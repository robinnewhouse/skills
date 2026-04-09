#!/usr/bin/env node
/**
 * Debug Log Server - Collects logs from your app for Claude Code to read
 * 
 * Usage: node log-server.js [port]  (default: 3333)
 * 
 * Endpoints:
 *   POST /log     - Send log: { level, message, data, source }
 *   GET  /logs    - Get all logs (?level=error&source=api&limit=50)
 *   GET  /errors  - Get only errors
 *   DELETE /logs  - Clear all logs
 */

const http = require('http');
const PORT = parseInt(process.argv[2]) || 3333;

let logs = [];
const MAX_LOGS = 1000;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json'
};

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, cors);
    return res.end();
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);
  
  try {
    // POST /log
    if (url.pathname === '/log' && req.method === 'POST') {
      let body = '';
      for await (const chunk of req) body += chunk;
      const data = body ? JSON.parse(body) : {};
      
      const entry = {
        timestamp: new Date().toISOString(),
        level: data.level || 'info',
        message: data.message || data.raw || '',
        data: data.data || null,
        source: data.source || 'app'
      };
      
      logs.push(entry);
      if (logs.length > MAX_LOGS) logs = logs.slice(-MAX_LOGS);
      
      // Print to console
      const colors = { error: '\x1b[31m', warn: '\x1b[33m', info: '\x1b[36m', debug: '\x1b[90m' };
      console.log(`${colors[entry.level] || ''}[${entry.level.toUpperCase()}]\x1b[0m [${entry.source}] ${entry.message}`);
      if (entry.data) console.log('  ', JSON.stringify(entry.data));
      
      res.writeHead(200, cors);
      return res.end(JSON.stringify({ ok: true, count: logs.length }));
    }

    // GET /logs
    if (url.pathname === '/logs' && req.method === 'GET') {
      let filtered = logs;
      const level = url.searchParams.get('level');
      const source = url.searchParams.get('source');
      const since = url.searchParams.get('since');
      const limit = parseInt(url.searchParams.get('limit')) || 100;
      
      if (level) filtered = filtered.filter(l => l.level === level);
      if (source) filtered = filtered.filter(l => l.source.includes(source));
      if (since) filtered = filtered.filter(l => new Date(l.timestamp) > new Date(since));
      
      res.writeHead(200, cors);
      return res.end(JSON.stringify({ logs: filtered.slice(-limit), total: logs.length }));
    }

    // GET /errors
    if (url.pathname === '/errors' && req.method === 'GET') {
      res.writeHead(200, cors);
      return res.end(JSON.stringify({ errors: logs.filter(l => l.level === 'error') }));
    }

    // DELETE /logs
    if (url.pathname === '/logs' && req.method === 'DELETE') {
      const count = logs.length;
      logs = [];
      res.writeHead(200, cors);
      return res.end(JSON.stringify({ cleared: count }));
    }

    // GET /health
    if (url.pathname === '/health') {
      res.writeHead(200, cors);
      return res.end(JSON.stringify({ status: 'ok', logs: logs.length }));
    }

    res.writeHead(404, cors);
    res.end(JSON.stringify({ error: 'Not found' }));
  } catch (e) {
    res.writeHead(500, cors);
    res.end(JSON.stringify({ error: e.message }));
  }
});

server.listen(PORT, () => {
  console.log(`
┌─────────────────────────────────────────┐
│         DEBUG LOG SERVER                │
├─────────────────────────────────────────┤
│  http://localhost:${PORT}                  │
│                                         │
│  POST /log    - Send a log              │
│  GET  /logs   - Get all logs            │
│  GET  /errors - Get errors only         │
│  DELETE /logs - Clear logs              │
│                                         │
│  Ctrl+C to stop                         │
└─────────────────────────────────────────┘
`);
});
