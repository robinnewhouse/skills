---
name: harbor-docker-manual
description: Manually reproduce Harbor task containers in local Docker. Use when the user wants to inspect or run a Harbor benchmark image by hand, trace a Harbor job or script such as instance/robinCliScripts/v2.sh to find the task Docker image, install a Cline/clite tarball inside the container, debug Harbor agent setup commands, or run Cline manually from inside a Docker shell.
---

# Harbor Docker Manual

Use this skill to help the user recreate Harbor's container setup manually, usually so they can inspect the task environment and run `cline`/`clite` by hand.

## Workflow

1. Start from the launcher script or job path the user names.
2. Read the launcher script enough to identify:
   - `ROOT_DIR`
   - `DATASET`
   - `AGENT`
   - `ENV_TYPE`
   - `TARBALL_URL`
   - agent kwargs passed with `--ak`
3. Locate the task config:
   - Existing job: read `jobs/<job>/<trial>/config.json`.
   - Cached Harbor task: search `~/.cache/harbor/tasks` for the task name.
   - New run script: infer the selected task from `INCLUDE_TASK_NAME`, or tell the user to pick one task first.
4. Find the Docker image:
   - Prefer `task.toml` field `[environment].docker_image`.
   - For existing jobs, read `.task.path` from trial `config.json`, then find the matching cached task.
   - If no `docker_image` exists, use the task's `environment/Dockerfile` and explain that Harbor would build an image rather than pull one.
5. Start a manual Docker shell matching Harbor's runtime architecture.
6. Have the user run install/setup mostly from inside the shell.
7. Run Cline non-interactively with explicit provider/key/model flags.

## Useful Discovery Commands

Find the selected settings in a run script:

```sh
sed -n '1,180p' /path/to/instance/robinCliScripts/v2.sh
```

Inspect an existing job and trial:

```sh
jq '.environment, .task, .agent' /path/to/jobs/<job>/<trial>/config.json
```

Find a cached task by name:

```sh
find ~/.cache/harbor/tasks -maxdepth 3 -type d -name '<task-name>'
```

Read the task image:

```sh
sed -n '1,120p' ~/.cache/harbor/tasks/<cache-id>/<task-name>/task.toml
```

List local Harbor-ish Docker images:

```sh
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}' | rg 'hb__|alexgshaw|terminal|swebench'
```

## Start Container

Use `linux/amd64` for Linux x64 tarballs, especially on Apple Silicon Macs. Do not rely on host architecture.

```sh
IMAGE="<task-image>"
NAME="harbor-manual"

docker rm -f "$NAME" 2>/dev/null || true

docker run -it \
  --name "$NAME" \
  --platform linux/amd64 \
  -w /app \
  -e API_KEY="$OPENROUTER_API_KEY" \
  -e MODELID="anthropic/claude-sonnet-4.6" \
  "$IMAGE" \
  bash
```

If the task workdir is not `/app`, inspect the task Dockerfile or run `pwd`, `ls`, and `find / -maxdepth 2 -name test.sh 2>/dev/null` inside the container.

## Install Cline Tarball Inside Container

Run this inside the container. This mirrors Harbor's `cline-v2` install path closely enough for manual debugging.

```sh
TARBALL_URL="<tarball-url>"

apt-get update
apt-get install -y curl ca-certificates git

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash

export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"

nvm install 22
nvm use 22
nvm alias default 22

npm install -g --ignore-scripts -- "$TARBALL_URL"

which cline
which clite
cline --version
clite --version
```

If `API_KEY` or `MODELID` is empty inside the shell, set them manually:

```sh
export API_KEY="sk-or-v1-..."
export MODELID="anthropic/claude-sonnet-4.6"
```

## Run Cline Manually

Avoid plain `cline` in Docker. It may trigger browser auth or interactive TUI behavior where `127.0.0.1` points at the container, not the host.

Use explicit provider/key/model flags and a prompt:

```sh
cline -P openrouter \
  -k "$API_KEY" \
  -m "$MODELID" \
  --yolo \
  --reasoning-effort medium \
  --json \
  "Hello"
```

For closest Harbor behavior, close stdin and capture all output:

```sh
set -o pipefail
cline -P openrouter \
  -k "$API_KEY" \
  -m "$MODELID" \
  --yolo \
  --reasoning-effort medium \
  -- "Task prompt here" \
  < /dev/null 2>&1 | tee /tmp/cline.txt

echo "exit=${PIPESTATUS[0]}"
```

## Common Debug Checks

Environment variables:

```sh
echo "API_KEY set? ${API_KEY:+yes}"
echo "MODELID=$MODELID"
```

Node/Cline path:

```sh
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
which node
which npm
which cline
cline --version
```

Cline state/log files:

```sh
find ~/.cline -maxdepth 5 -type f | sort | tail -100
```

Terminal escape junk such as `997;1n10;rgb...` after running bare `cline` is usually leaked TTY response text. Run `reset`, then use non-interactive commands with a prompt instead of the bare TUI.

## Cleanup

From the host:

```sh
docker rm -f harbor-manual
```

Use the actual `NAME` value if different.
