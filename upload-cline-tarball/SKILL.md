---
name: upload-cline-tarball
description: Build a fresh Cline SDK CLI tarball from /Users/robin/dev/cline/sdk, validate the cline bin entry, upload it to the Cline-owned cline-test-builds S3 bucket, and produce a presigned URL for Harbor runs.
---

# Upload Cline Tarball to S3

Use this skill when the user asks to prepare a fresh CLI build for Harbor or
Modal. Prefer VM-local Modal file injection for any Modal run launched from the
Harbor VM. Use S3 only as a fallback when the launcher cannot access the local
tarball file.
For Robin's `robin@cline.bot` AWS access, use the Cline account bucket
`cline-test-builds` in `us-west-2`. Do not use `uploading-sdk-wip`; that bucket
is not available in the Cline account and belongs to the older personal flow.

Older Harbor benchmark scripts may consume a presigned URL with
`npm install -g --ignore-scripts "$TARBALL_URL"` inside the task container. That
URL path was a workaround for getting the tarball into Modal. For new or edited
Modal launchers, pass a local tarball path and inject it with
`modal.Image.add_local_file(...)` instead.

For Modal runs launched from the Harbor VM, avoid S3 entirely:

1. Build the tarball locally or on the VM.
2. Copy it to the VM if needed:
   `scp <tarball> harbor:~/harbor/local-tarballs/`.
3. In the Modal launcher, inject it with:
   `modal.Image.debian_slim().add_local_file(<vm_tarball>, "/tmp/cline.tgz")`.
4. Inside the Modal sandbox, install with:
   `npm install -g -- /tmp/cline.tgz`.

This also works for plugin tarballs, trace fixtures, tiny smoke-test files, and
benchmark tarballs. It removes S3 upload, presigning, byte-range checks, and URL
secret handling from the normal Modal path.

## Script routing

Default SDK directory: `/Users/robin/dev/cline/sdk`.

First inspect `sdk_dir/apps/cli/package.json`. Use the OpenTUI platform-binary
build path when the CLI package has the platform-binary build system:

- `name` is `@cline/cli`
- `dependencies["@opentui/core"]` exists
- `scripts["build:platforms"]` starts with `bun script/build.ts` (current main may include `--install-native-variants`)
- `bin.cline` is `src/index.ts`

For local Docker Harbor runs on Robin's Apple Silicon machine, build Linux
`arm64`. Linux `x64` is for Modal or x64 Docker hosts and will fail with
`EBADPLATFORM` in local arm64 task containers.

The legacy helper script still builds a `bun-linux-x64` package and uploads to
`uploading-sdk-wip`; treat it as stale for Cline-account Harbor work unless you
are deliberately reproducing that old path. Prefer manually building the
correct Linux architecture and uploading to `cline-test-builds`.

Plugin smoke runs require extra care: the compiled CLI binary can run by
itself, but the plugin sandbox is a separate Node process that imports
`extensions/plugin-sandbox-bootstrap.js`. If that bootstrap is packaged without
host runtime modules, plugin loading fails with missing `@cline/shared`.
For plugin-enabled tarballs, include the sandbox bootstrap plus the built
host SDK packages it resolves (`@cline/shared`, `@cline/core`, `@cline/sdk`,
`@cline/agents`, `@cline/llms`) and `jiti` under `package/node_modules`.

Optional flags:

- `--sdk-dir <path>`
- `--harbor-dir <path>`
- `--run-bucket-setup`
- `--update-robin-cli-scripts`
- `--skip-install`
- `--skip-sdk-build`

Equivalent env vars are also supported: `SDK_DIR`, `HARBOR_DIR`, `RUN_BUCKET_SETUP`, `UPDATE_ROBIN_CLI_SCRIPTS`, `SKIP_INSTALL`, `SKIP_SDK_BUILD`. `--sdk-wip-dir` and `SDK_WIP_DIR` remain accepted as compatibility aliases.

## Inputs to collect

- `sdk_dir` (default: `/Users/robin/dev/cline/sdk`)
- `harbor_dir` (default: `/Users/robin/dev/harbor`)
- `update_robin_cli_scripts` (`yes`/`no`, default `no`)
- `run_bucket_setup` (`yes`/`no`, default `no`)

If inputs are missing, ask only for missing values.

## 1) Preflight check in the SDK (required)

Run:

```bash
cd "$sdk_dir"

node <<'NODE'
const fs = require('fs')
const p = JSON.parse(fs.readFileSync('apps/cli/package.json', 'utf8'))
const errors = []

if (p.name !== '@cline/cli') {
  errors.push('apps/cli/package.json name must be @cline/cli')
}
if (!p.dependencies?.['@opentui/core']) {
  errors.push('apps/cli/package.json must depend on @opentui/core')
}
if (typeof p.scripts?.['build:platforms'] !== 'string' || !p.scripts['build:platforms'].startsWith('bun script/build.ts')) {
  errors.push('apps/cli package should expose scripts.build:platforms starting with bun script/build.ts')
}
if (p.bin?.cline !== 'src/index.ts') {
  errors.push('OpenTUI development package is expected to keep bin.cline = src/index.ts')
}

if (errors.length) {
  console.error('Preflight failed:')
  for (const e of errors) console.error(`- ${e}`)
  process.exit(1)
}

console.log('Preflight OK: OpenTUI Cline platform-binary build system detected')
NODE
```

Stop if preflight fails.

## 2) AWS bucket/account check

Use the configured Cline account credentials. A good account check is:

```bash
aws sts get-caller-identity
aws s3 ls s3://cline-test-builds --region us-west-2
```

Expected account/user for Robin's Cline credentials:
`arn:aws:iam::886436933832:user/robin@cline.bot`. The known usable buckets are
`cline-test-builds` and `cline-tasks`.

## 3) Build tarball

```bash
cd "$sdk_dir"

bun install
bun run build:sdk
bun -F @cline/cli build

# The OpenTUI build compiles apps/cli/src/index.ts to a platform package under
# apps/cli/dist/cli-linux-<arch>/bin/cline. Pick linux-arm64 for local Docker
# on Apple Silicon, linux-x64 for x64 Docker/Modal.

TARBALL_PATH="$(ls -1t apps/cli/dist/*.tgz | head -n 1)"
echo "$TARBALL_PATH"
```

## 4) Validate tarball shape

```bash
tar -xOf "$TARBALL_PATH" package/package.json | jq -r '.name, .version, .bin.cline'
tar -tzf "$TARBALL_PATH" | head -n 20
```

Confirm:
- `.bin.cline` exists
- `package/bin/cline` exists
- entries are under `package/...`

## 5) Inject local tarball into Modal

Use this by default for Modal launches from Harbor. If an existing launcher
expects `TARBALL_URL`, prefer changing it to accept `TARBALL_PATH` and install
the injected file.

Minimal shape:

```python
import modal

app = modal.App.lookup("cline-smoke", create_if_missing=True)
image = (
    modal.Image.debian_slim()
    .add_local_file("/home/robin_cline_bot/harbor/local-tarballs/cline.tgz", "/tmp/cline.tgz")
)

sb = modal.Sandbox.create(
    "bash",
    "-lc",
    "npm install -g -- /tmp/cline.tgz && cline --version",
    app=app,
    image=image,
    timeout=120,
)
```

## 6) Fallback: upload + verify presigned readability

Use S3 only when the target runner cannot access the tarball file locally and
cannot be adjusted to use `add_local_file`:

```bash
cd "$sdk_dir"

SHA="$(git rev-parse --short HEAD)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BASE="$(basename "$TARBALL_PATH" .tgz)"
KEY="cline-builds/${BASE}-${STAMP}-${SHA}.tgz"
S3_URI="s3://cline-test-builds/${KEY}"

aws s3 cp "$TARBALL_PATH" "$S3_URI" --region us-west-2

TARBALL_URL="$(aws s3 presign "$S3_URI" --region us-west-2 --expires-in 604800)"
curl -fsS -r 0-0 "$TARBALL_URL" -o /tmp/tarball-byte-test.bin
wc -c /tmp/tarball-byte-test.bin

echo "$S3_URI"
echo "$TARBALL_URL"
```

## 6) Optional: update `instance/robinCliScripts` defaults

Only run if `update_robin_cli_scripts=yes`.

```bash
cd "$harbor_dir"

NEW_S3_URI="$S3_URI"
NEW_PUBLIC_URL="$TARBALL_URL"

NEW_S3_URI="$NEW_S3_URI" NEW_PUBLIC_URL="$NEW_PUBLIC_URL" \
perl -0pi -e '
  s|TARBALL_S3_URI="\$\{TARBALL_S3_URI:-[^}]*\}"|TARBALL_S3_URI="${TARBALL_S3_URI:-$ENV{NEW_S3_URI}}"|g;
  s|TARBALL_URL="\$\{TARBALL_URL:-[^}]*\}"|TARBALL_URL="${TARBALL_URL:-$ENV{NEW_PUBLIC_URL}}"|g;
' instance/robinCliScripts/*.sh

rg -n 'TARBALL_S3_URI="\$\{TARBALL_S3_URI:-|TARBALL_URL="\$\{TARBALL_URL:-' \
  instance/robinCliScripts/*.sh
```

This rewrites only `${VAR:-...}` defaults, not runtime overrides.

## 7) Report back

Return:
- tarball path
- S3 URI
- presigned URL, if appropriate for the user context
- whether script defaults were updated
- any failed checks/errors

## Safety rules

- Use region `us-west-2` and bucket `cline-test-builds` for Robin/Cline Harbor work.
- Do not print presigned URLs or credentials in final user-facing summaries unless
  the user explicitly needs the URL.
- Do not skip preflight.
- Do not claim success unless the 1-byte `curl` check succeeds.
