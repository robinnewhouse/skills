# Debug Client Snippets

Copy-paste code to send logs to the debug server.

## JavaScript (Browser/Node)

```javascript
// One-liner
const dlog = (msg, data) => fetch('http://localhost:3333/log', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({level: 'debug', message: msg, data, source: location?.pathname || 'node'})
});

// With levels
const debugLog = {
  debug: (msg, data) => dlog('debug', msg, data),
  info: (msg, data) => dlog('info', msg, data),
  warn: (msg, data) => dlog('warn', msg, data),
  error: (msg, data) => dlog('error', msg, data)
};

async function dlog(level, msg, data) {
  try {
    await fetch('http://localhost:3333/log', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({level, message: msg, data, source: 'app'})
    });
  } catch { console[level](msg, data); }
}
```

## Python

```python
import requests

def dlog(msg, data=None, level='debug', source='python'):
    try:
        requests.post('http://localhost:3333/log', 
            json={'level': level, 'message': msg, 'data': data, 'source': source}, 
            timeout=1)
    except:
        print(f'[{level}] {msg}', data)

# Usage
dlog('Processing started', {'count': 100})
dlog('Error occurred', {'error': str(e)}, level='error')
```

## React Hook

```typescript
import { useCallback } from 'react';

export function useDebugLog(source: string) {
  const log = useCallback(async (level: string, message: string, data?: any) => {
    try {
      await fetch('http://localhost:3333/log', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ level, message, data, source })
      });
    } catch {
      console[level as 'log'](message, data);
    }
  }, [source]);

  return {
    debug: (msg: string, data?: any) => log('debug', msg, data),
    info: (msg: string, data?: any) => log('info', msg, data),
    error: (msg: string, data?: any) => log('error', msg, data),
  };
}

// Usage: const log = useDebugLog('MyComponent');
```

## Bash

```bash
dlog() {
  curl -s -X POST "http://localhost:3333/log" \
    -H "Content-Type: application/json" \
    -d "{\"level\": \"$1\", \"message\": \"$2\", \"source\": \"shell\"}" \
    > /dev/null 2>&1
}

# Usage: dlog "info" "Script started"
```
