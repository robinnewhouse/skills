---
name: setup-clickhouse-mcp
description: Configure, verify, install, or repair the official ClickHouse MCP server for local Cline data analysis. Use before querying ClickHouse or when ClickHouse MCP authentication, Cline MCP settings, uv availability, credentials, or database connectivity is uncertain, especially for ~/.cline/data/settings/cline_mcp_settings.json.
---

# Setup ClickHouse MCP

Do this before analysis if ClickHouse access has not already been verified in the current session. First check whether setup works; if it does not, help the user set it up or repair it.

## Health-check flow

1. Check whether a ClickHouse MCP server/tool is available in the session.
2. If available, run the cheapest safe connectivity check available, such as listing databases/tables or `SELECT 1`.
3. If the health check succeeds, proceed with analysis.
4. If unavailable or auth/connectivity fails, stop. Do not keep trying analytic queries.
5. Help the user install, configure, or repair the official ClickHouse MCP server in Cline settings.
6. Retry the health check only after setup/configuration changes are complete.

## Cline MCP settings setup

Goal: add or update the official ClickHouse MCP server in Cline's user config with minimal changes and no credential thrashing.

### 1. Locate settings

Use:

```text
~/.cline/data/settings/cline_mcp_settings.json
```

Preserve any existing `mcpServers` entries.

### 2. Determine `uv` path

Run:

```bash
command -v uv
```

Prefer the absolute path in config, for example `/opt/homebrew/bin/uv`, because the ClickHouse MCP README recommends using the absolute executable path.

If `uv` is missing, ask whether to install it or use a Python fallback. Do not invent a path.

### 3. Choose connection environment

Use the user's real ClickHouse connection credentials. The MCP server does not do browser/login OAuth; it connects with ClickHouse host/user/password environment variables.

Rules:

- Prefer a dedicated least-privileged/read-only ClickHouse user.
- Credentials in this JSON are plaintext. In `sdk/` today, MCP `env` values are stored and passed literally; `${env:VAR}` expansion is not supported unless that support is added.
- If credentials are absent, ask for them. Do not silently configure the public demo account.
- If the user does not want plaintext credentials in JSON, use a wrapper script that loads/sets environment variables and then `exec`s the official `uv ... mcp-clickhouse` command.
- Do not use admin/default credentials unless the user explicitly accepts that risk.
- Keep write access disabled by default. Do not set `CLICKHOUSE_ALLOW_WRITE_ACCESS=true` unless explicitly requested.
- Only use the official SQL Playground (`sql-clickhouse.clickhouse.com`, user `demo`) if the user explicitly asks for demo/public playground setup.

For ClickHouse Cloud, usually use:

```text
CLICKHOUSE_HOST=<instance>.<region>.<cloud>.clickhouse.cloud
CLICKHOUSE_PORT=8443
CLICKHOUSE_SECURE=true
CLICKHOUSE_VERIFY=true
```

The host should not include `https://`.

### 4. Back up before editing

Copy the config to a timestamped backup in the same directory:

```text
cline_mcp_settings.json.bak.<timestamp>
```

### 5. Add/update server entry

Add or update this entry under `mcpServers`, replacing placeholders with the user's real values:

```json
"mcp-clickhouse": {
  "command": "/absolute/path/to/uv",
  "args": [
    "run",
    "--with",
    "mcp-clickhouse",
    "--python",
    "3.10",
    "mcp-clickhouse"
  ],
  "env": {
    "CLICKHOUSE_HOST": "YOUR_CLICKHOUSE_HOST",
    "CLICKHOUSE_PORT": "8443",
    "CLICKHOUSE_USER": "YOUR_CLICKHOUSE_USER",
    "CLICKHOUSE_PASSWORD": "YOUR_CLICKHOUSE_PASSWORD",
    "CLICKHOUSE_SECURE": "true",
    "CLICKHOUSE_VERIFY": "true",
    "CLICKHOUSE_CONNECT_TIMEOUT": "30",
    "CLICKHOUSE_SEND_RECEIVE_TIMEOUT": "30",
    "CLICKHOUSE_MCP_SERVER_TRANSPORT": "stdio"
  },
  "disabled": false
}
```

Official package/command:

```bash
uv run --with mcp-clickhouse --python 3.10 mcp-clickhouse
```

Stdio transport does not require MCP auth tokens; HTTP/SSE transports do.

Do not use values like `${env:CLICKHOUSE_PASSWORD}` in the `env` object; they will be passed literally in the current SDK implementation. Use plaintext JSON values or point `command` at a wrapper script that sets env vars and then execs `uv run --with mcp-clickhouse --python 3.10 mcp-clickhouse`.

### 6. Validate JSON

Run:

```bash
node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')); console.log('json valid')" ~/.cline/data/settings/cline_mcp_settings.json
```

### 7. Smoke-test startup

Launch the configured command with the configured environment and a short timeout, without sending MCP requests.

Success indicators:

- It installs/starts without import or config errors.
- Logs include `ClickHouse tools registered` and `transport 'stdio'`.
- It may exit cleanly if stdin closes; that is okay for this smoke test.

Failure indicators:

- Non-zero exit from import/config errors.
- Missing `uv` path.
- Bad credentials or network/TLS errors when it tries to connect.

### 8. Restart Cline

Restart or reload Cline after editing the MCP settings file.

## Demo/public playground setup

Use demo only when explicitly requested:

```text
CLICKHOUSE_HOST=sql-clickhouse.clickhouse.com
CLICKHOUSE_USER=demo
CLICKHOUSE_PASSWORD=
```

## Do not

- Do not run broad data queries as a setup check.
- Do not infer, print, or expose credentials unnecessarily.
- Do not use `${env:VAR}` placeholders unless SDK support for env expansion has been added.
- Do not loop through repeated failed queries.
- Do not silently configure the demo account.
- Do not enable write access unless explicitly requested.
- Do not mix future cloud, Slack, or Tailscale deployment concerns into local setup unless the user asks.
