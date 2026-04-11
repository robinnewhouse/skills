---
name: upload-cline-tarball
description: Build a fresh sdk-wip CLI tarball, validate clite/cline bin entries, upload it to uploading-sdk-wip S3 with a permanent public URL, and optionally update harbor repo robinCliScripts defaults.
---

# Upload Cline/Clite Tarball to S3 (Permanent URL)

Use this skill when the user asks to upload a fresh CLI build to S3 using the permanent `uploading-sdk-wip` flow.

## Preferred execution path (single script)

Use the bundled script at [resources/upload-cline-tarball.sh](resources/upload-cline-tarball.sh).

```bash
bash <skill_dir>/resources/upload-cline-tarball.sh
```

Optional flags:

- `--sdk-wip-dir <path>`
- `--harbor-dir <path>`
- `--run-bucket-setup`
- `--update-robin-cli-scripts`
- `--auto-fix-clite-cline`

Equivalent env vars are also supported: `SDK_WIP_DIR`, `HARBOR_DIR`, `RUN_BUCKET_SETUP`, `UPDATE_ROBIN_CLI_SCRIPTS`, `AUTO_FIX_CLITE_CLINE`.

The script enforces the same safety checks defined below (required preflight + 1-byte public `curl` verification).

## Inputs to collect

- `sdk_wip_dir` (default: `/Users/robin/dev/sdk-wip`)
- `harbor_dir` (default: `/Users/robin/dev/harbor-ara`)
- `update_robin_cli_scripts` (`yes`/`no`, default `no`)
- `run_bucket_setup` (`yes`/`no`, default `no`)
- `auto_fix_clite_cline` (`yes`/`no`, default `no`)

If inputs are missing, ask only for missing values.

## 1) Preflight check in sdk-wip (required)

Run:

```bash
cd "$sdk_wip_dir"

node <<'NODE'
const fs = require('fs')
const p = JSON.parse(fs.readFileSync('apps/cli/package.json', 'utf8'))
const errors = []

if (p.bin?.clite !== 'dist/index.js') {
  errors.push('bin.clite must be dist/index.js')
}
if (p.bin?.cline !== 'dist/index.js') {
  errors.push('bin.cline must be dist/index.js')
}
if (!p.scripts?.['build:binary']?.includes('cp ./dist/cline ./dist/clite')) {
  errors.push('scripts.build:binary must copy dist/cline -> dist/clite')
}

if (errors.length) {
  console.error('Preflight failed:')
  for (const e of errors) console.error(`- ${e}`)
  process.exit(1)
}

console.log('Preflight OK: clite + cline support is present in sdk-wip/apps/cli/package.json')
NODE
```

Stop if preflight fails.

If `auto_fix_clite_cline=yes`, the bundled script will deterministically patch `apps/cli/package.json` to:
- set `bin.clite` to `dist/index.js`
- set `bin.cline` to `dist/index.js`
- ensure `scripts.build:binary` includes `cp ./dist/cline ./dist/clite`

It still fails if `scripts.build:binary` exists but is a non-string value.

## 2) One-time bucket setup (only when requested)

Only run this if `run_bucket_setup=yes`.

```bash
aws s3api put-public-access-block \
  --bucket uploading-sdk-wip \
  --region us-east-2 \
  --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

cat > /tmp/uploading-sdk-wip-public-policy.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPublicReadClineBuilds",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::uploading-sdk-wip/cline-builds/*"
    }
  ]
}
JSON

aws s3api put-bucket-policy \
  --bucket uploading-sdk-wip \
  --region us-east-2 \
  --policy file:///tmp/uploading-sdk-wip-public-policy.json
```

## 3) Build tarball

```bash
cd "$sdk_wip_dir"

bun install
bun run build:sdk
bun run -F @clinebot/cli build:tgz

TARBALL_PATH="$(ls -1t apps/cli/dist/*.tgz | head -n 1)"
echo "$TARBALL_PATH"
```

## 4) Validate tarball shape

```bash
tar -xOf "$TARBALL_PATH" package/package.json | jq -r '.name, .version, .bin.clite, .bin.cline'
tar -tzf "$TARBALL_PATH" | head -n 20
```

Confirm:
- `.bin.clite` exists
- `.bin.cline` exists
- entries are under `package/...`

## 5) Upload + verify public readability

```bash
cd "$sdk_wip_dir"

SHA="$(git rev-parse --short HEAD)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BASE="$(basename "$TARBALL_PATH" .tgz)"
KEY="new-cli-${BASE}-${STAMP}-${SHA}.tgz"
S3_URI="s3://uploading-sdk-wip/cline-builds/${KEY}"
PUBLIC_URL="https://uploading-sdk-wip.s3.us-east-2.amazonaws.com/cline-builds/${KEY}"

aws s3 cp "$TARBALL_PATH" "$S3_URI" --region us-east-2

curl -fsS -r 0-0 "$PUBLIC_URL" -o /tmp/tarball-byte-test.bin
wc -c /tmp/tarball-byte-test.bin

echo "$S3_URI"
echo "$PUBLIC_URL"
```

## 6) Optional: update `instance/robinCliScripts` defaults

Only run if `update_robin_cli_scripts=yes`.

```bash
cd "$harbor_dir"

NEW_S3_URI="$S3_URI"
NEW_PUBLIC_URL="$PUBLIC_URL"

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
- permanent public URL
- whether script defaults were updated
- any failed checks/errors

## Safety rules

- Use region `us-east-2` for this flow.
- Do not skip preflight.
- Do not claim success unless the 1-byte `curl` check succeeds.
