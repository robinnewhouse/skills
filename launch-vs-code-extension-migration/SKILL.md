---
name: launch-vs-code-extension-migration
description: Launch the SDK-backed Cline VS Code extension from any cline branch or worktree for visual/manual testing. Use when the user needs to run or see the apps/vscode extension migration branch, cannot use the VS Code launch config, or asks Codex to open an Extension Development Host for a Cline VS Code extension branch.
---

# Launch VS Code Extension Migration

Use this skill to run the SDK-backed `apps/vscode` extension in a real VS Code Extension Development Host.

## Inputs

Determine these from context when possible:

- `repo`: cline checkout/worktree to launch from.
- `branch`: branch to launch, if the user names one.
- `environment`: `production`, `staging`, or `local`; default `production`.

Do not assume `/Users/robin/dev/cline` is the right worktree. Verify the branch first.

## 1) Find or create the right worktree

Check the current directory and all known worktrees:

```bash
pwd
git status --short --branch
git -C /Users/robin/dev/cline worktree list --porcelain
```

If the requested branch is already checked out in a clean worktree, use that path.

If no worktree has the requested branch, create a dedicated run worktree:

```bash
run_root="/Users/robin/.codex/worktrees/run-vscode-extension-$(date +%s)"
mkdir -p "$run_root"
git -C /Users/robin/dev/cline worktree add "$run_root/cline" "<branch>"
repo="$run_root/cline"
```

If the branch exists only on `origin`, use `origin/<branch>` or first create a local branch from it.

## 2) Inspect launch config and scripts

Use the repo's own launch settings as the source of truth:

```bash
sed -n '1,220p' "$repo/.vscode/launch.json"
node -e "const p=require('$repo/apps/vscode/package.json'); console.log(JSON.stringify(p.scripts,null,2))"
```

The normal extension path is:

```bash
extension_dir="$repo/apps/vscode"
```

## 3) Install dependencies as needed

Install only if the relevant `node_modules` directory is missing or stale enough to block the build.

```bash
cd "$extension_dir"
npm ci
```

The user's global npm config may contain `ignore-scripts=true`, which prevents `grpc-tools` from downloading `protoc`. Always repair this before proto generation:

```bash
npm rebuild grpc-tools --ignore-scripts=false
```

Install webview dependencies if needed:

```bash
cd "$extension_dir/webview-ui"
npm ci
```

## 4) Build enough to launch

From `apps/vscode`:

```bash
cd "$extension_dir"
npm run protos
npm run build:webview
node esbuild.mjs
```

Do not require full `npm run compile` if the user only needs to see the extension and `compile` is blocked by unrelated type/lint failures. For this branch family, full `check-types` may fail on existing Node 22 `fetch.preconnect` typing issues while the launchable bundle still builds.

## 5) Launch VS Code Extension Development Host

Prefer a fresh temp profile so installed Cline extensions and old user state do not confuse the result:

```bash
user_data_dir="$extension_dir/dist/tmp/user"

IS_DEV=true \
TEMP_PROFILE=true \
DEV_WORKSPACE_FOLDER="$extension_dir" \
CLINE_ENVIRONMENT="${environment:-production}" \
code --new-window \
  --user-data-dir="$user_data_dir" \
  --profile-temp \
  --sync=off \
  --disable-workspace-trust \
  --disable-extension saoudrizwan.claude-dev \
  --disable-extension saoudrizwan.cline-nightly \
  --extensionDevelopmentPath="$extension_dir" \
  "$extension_dir"
```

If `code` is missing, check:

```bash
command -v code
ls -d /Applications/Visual\ Studio\ Code*.app 2>/dev/null
```

Use the regular VS Code app unless the user asks for Insiders.

## 6) Verify the host is running

Check for a process launched with the expected extension development path:

```bash
ps aux | rg -i "extensionDevelopmentPath=$extension_dir|$extension_dir" | rg -v rg
```

Find and tail the Cline output log:

```bash
find "$user_data_dir" -path '*logs*' -type f -maxdepth 6 | rg '1-Cline\.log$|Cline\.log$'
tail -n 120 "$(find "$user_data_dir" -path '*logs*' -type f -maxdepth 6 | rg '1-Cline\.log$|Cline\.log$' | tail -n 1)"
```

Expected healthy signals include:

- `[Cline] extension activated`
- `[SdkController] Initialized with SDK adapter layer`
- `[VscodeSessionHost] Initialized`

Existing MCP server errors or OAuth prompts can be normal user-state noise; do not treat them as launch failure unless they block the UI.

## 7) Bring the UI forward

Bring VS Code to the foreground:

```bash
osascript -e 'tell application "Visual Studio Code" to activate'
```

The `code` CLI may not support `--command` in this environment. To focus Cline or open MCP, use command URIs:

```bash
open 'vscode://command/workbench.view.extension.claude-dev-ActivityBar'
open 'vscode://command/cline.mcpButtonClicked'
```

If command URIs target another VS Code window, tell the user the Extension Development Host is running and ask them to click the Cline activity-bar icon in the temp-profile window.

## 8) Do not clean up prematurely

Leave the VS Code process and temporary worktree running while the user is inspecting it. Only remove the run worktree after the user is done:

```bash
git -C /Users/robin/dev/cline worktree remove "$repo"
```
