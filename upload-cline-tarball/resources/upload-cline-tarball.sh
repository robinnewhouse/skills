#!/usr/bin/env bash
set -euo pipefail

SDK_WIP_DIR="${SDK_WIP_DIR:-/Users/robin/dev/sdk-wip}"
HARBOR_DIR="${HARBOR_DIR:-/Users/robin/dev/harbor-ara}"
UPDATE_ROBIN_CLI_SCRIPTS="${UPDATE_ROBIN_CLI_SCRIPTS:-no}"
RUN_BUCKET_SETUP="${RUN_BUCKET_SETUP:-no}"
AUTO_FIX_CLITE_CLINE="${AUTO_FIX_CLITE_CLINE:-no}"

REGION="us-east-2"
BUCKET="uploading-sdk-wip"
PREFIX="cline-builds"

usage() {
  cat <<'USAGE'
Usage: bash upload-cline-tarball.sh [options]

Options:
  --sdk-wip-dir <path>            Path to sdk-wip repo (default: /Users/robin/dev/sdk-wip)
  --harbor-dir <path>             Path to harbor repo (default: /Users/robin/dev/harbor-ara)
  --update-robin-cli-scripts      Update harbor-ara script defaults after upload (default: off)
  --run-bucket-setup              Run one-time S3 bucket public policy setup (default: off)
  --auto-fix-clite-cline          Auto-fix clite/cline package.json preflight issues (default: off)
  -h, --help                      Show this help

Environment variable equivalents:
  SDK_WIP_DIR, HARBOR_DIR, UPDATE_ROBIN_CLI_SCRIPTS, RUN_BUCKET_SETUP, AUTO_FIX_CLITE_CLINE
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sdk-wip-dir)
      SDK_WIP_DIR="$2"
      shift 2
      ;;
    --harbor-dir)
      HARBOR_DIR="$2"
      shift 2
      ;;
    --update-robin-cli-scripts)
      UPDATE_ROBIN_CLI_SCRIPTS="yes"
      shift
      ;;
    --run-bucket-setup)
      RUN_BUCKET_SETUP="yes"
      shift
      ;;
    --auto-fix-clite-cline)
      AUTO_FIX_CLITE_CLINE="yes"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

validate_yes_no() {
  local name="$1"
  local value="$2"
  if [ "$value" != "yes" ] && [ "$value" != "no" ]; then
    echo "$name must be 'yes' or 'no' (got: $value)" >&2
    exit 1
  fi
}

require_cmd node
require_cmd bun
require_cmd jq
require_cmd aws
require_cmd curl
require_cmd tar
require_cmd git
require_cmd perl
require_cmd grep

validate_yes_no "UPDATE_ROBIN_CLI_SCRIPTS" "$UPDATE_ROBIN_CLI_SCRIPTS"
validate_yes_no "RUN_BUCKET_SETUP" "$RUN_BUCKET_SETUP"
validate_yes_no "AUTO_FIX_CLITE_CLINE" "$AUTO_FIX_CLITE_CLINE"

echo "==> Preflight check (${SDK_WIP_DIR})"
cd "$SDK_WIP_DIR"

AUTO_FIX_CLITE_CLINE="$AUTO_FIX_CLITE_CLINE" node <<'NODE'
const fs = require('fs')
const autoFix = process.env.AUTO_FIX_CLITE_CLINE === 'yes'
const path = 'apps/cli/package.json'
const cpStep = 'cp ./dist/cline ./dist/clite'

function collectErrors(pkg) {
  const errors = []
  if (pkg.bin?.clite !== 'dist/index.js') {
    errors.push('bin.clite must be dist/index.js')
  }
  if (pkg.bin?.cline !== 'dist/index.js') {
    errors.push('bin.cline must be dist/index.js')
  }
  if (typeof pkg.scripts?.['build:binary'] !== 'string' || !pkg.scripts['build:binary'].includes(cpStep)) {
    errors.push('scripts.build:binary must copy dist/cline -> dist/clite')
  }
  return errors
}

function applyTextFixes(source) {
  let updated = source
  let changed = false
  const fixErrors = []

  if (!/"cline"\s*:\s*"dist\/index\.js"/.test(updated)) {
    const binBlockRe = /("bin"\s*:\s*\{)([\s\S]*?)(\n[ \t]*\})/m
    const binMatch = updated.match(binBlockRe)
    if (!binMatch) {
      fixErrors.push('bin object missing; cannot auto-fix safely')
    } else {
      const cliteLineRe = /(\n([ \t]*)"clite"\s*:\s*"dist\/index\.js")([ \t]*,?)/m
      if (!cliteLineRe.test(binMatch[2])) {
        fixErrors.push('bin.clite line missing; cannot auto-fix safely')
      } else {
        const newBinBody = binMatch[2].replace(cliteLineRe, (_m, cliteLine, indent, maybeComma) => {
          const withComma = maybeComma.includes(',') ? cliteLine : `${cliteLine},`
          return `${withComma}\n${indent}"cline": "dist/index.js"`
        })
        updated = updated.replace(binBlockRe, `${binMatch[1]}${newBinBody}${binMatch[3]}`)
        changed = true
      }
    }
  }

  if (!updated.includes(cpStep)) {
    const buildBinaryLineRe = /^([ \t]*"build:binary"\s*:\s*")([^"\n]*)(")/m
    const buildMatch = updated.match(buildBinaryLineRe)
    if (!buildMatch) {
      fixErrors.push('scripts.build:binary missing or non-string; cannot auto-fix safely')
    } else {
      const trimmed = buildMatch[2].trim()
      const next = trimmed ? `${trimmed} && ${cpStep}` : cpStep
      updated = updated.replace(buildBinaryLineRe, `${buildMatch[1]}${next}${buildMatch[3]}`)
      changed = true
    }
  }

  return { updated, changed, fixErrors }
}

let preflightErrors = []
let autoFixErrors = []
let changed = false
const original = fs.readFileSync(path, 'utf8')

let pkg = JSON.parse(original)
preflightErrors = collectErrors(pkg)

if (autoFix && preflightErrors.length > 0) {
  const { updated, changed: didChange, fixErrors } = applyTextFixes(original)
  changed = didChange
  autoFixErrors = fixErrors
  if (didChange) {
    fs.writeFileSync(path, updated)
    console.log('Auto-fix applied to apps/cli/package.json for clite/cline preflight checks')
  }
  pkg = JSON.parse(fs.readFileSync(path, 'utf8'))
  preflightErrors = collectErrors(pkg)
}

const errors = Array.from(new Set([...autoFixErrors, ...preflightErrors]))

if (errors.length) {
  console.error('Preflight failed:')
  for (const e of errors) console.error(`- ${e}`)
  process.exit(1)
}

console.log('Preflight OK: clite + cline support is present in sdk-wip/apps/cli/package.json')
NODE

if [ "$RUN_BUCKET_SETUP" = "yes" ]; then
  echo "==> Running one-time bucket setup (${BUCKET}, ${REGION})"
  aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

  POLICY_FILE="$(mktemp /tmp/uploading-sdk-wip-policy.XXXXXX.json)"
  cat > "$POLICY_FILE" <<'JSON'
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
    --bucket "$BUCKET" \
    --region "$REGION" \
    --policy "file://${POLICY_FILE}"
fi

echo "==> Building tarball"
bun install
bun run build:sdk
bun run -F @clinebot/cli build:tgz

TARBALL_PATH="$(ls -1t apps/cli/dist/*.tgz | head -n 1)"
if [ -z "$TARBALL_PATH" ]; then
  echo "No tarball found under apps/cli/dist/*.tgz" >&2
  exit 1
fi

echo "==> Validating tarball shape"
PKG_NAME="$(tar -xOf "$TARBALL_PATH" package/package.json | jq -r '.name')"
PKG_VERSION="$(tar -xOf "$TARBALL_PATH" package/package.json | jq -r '.version')"
BIN_CLITE="$(tar -xOf "$TARBALL_PATH" package/package.json | jq -r '.bin.clite')"
BIN_CLINE="$(tar -xOf "$TARBALL_PATH" package/package.json | jq -r '.bin.cline')"

if [ "$BIN_CLITE" = "null" ] || [ -z "$BIN_CLITE" ]; then
  echo "Tarball validation failed: .bin.clite missing" >&2
  exit 1
fi
if [ "$BIN_CLINE" = "null" ] || [ -z "$BIN_CLINE" ]; then
  echo "Tarball validation failed: .bin.cline missing" >&2
  exit 1
fi
if ! tar -tzf "$TARBALL_PATH" | grep -q '^package/'; then
  echo "Tarball validation failed: entries are not under package/..." >&2
  exit 1
fi

echo "Package: ${PKG_NAME}@${PKG_VERSION}"
echo "bin.clite: ${BIN_CLITE}"
echo "bin.cline: ${BIN_CLINE}"

echo "==> Uploading tarball"
SHA="$(git rev-parse --short HEAD)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BASE="$(basename "$TARBALL_PATH" .tgz)"
KEY="new-cli-${BASE}-${STAMP}-${SHA}.tgz"
S3_URI="s3://${BUCKET}/${PREFIX}/${KEY}"
PUBLIC_URL="https://${BUCKET}.s3.${REGION}.amazonaws.com/${PREFIX}/${KEY}"

aws s3 cp "$TARBALL_PATH" "$S3_URI" --region "$REGION"

echo "==> Verifying public readability (1-byte range request)"
BYTE_TEST_FILE="$(mktemp /tmp/uploaded-tarball-byte.XXXXXX.bin)"
curl -fsS -r 0-0 "$PUBLIC_URL" -o "$BYTE_TEST_FILE"
BYTE_COUNT="$(wc -c < "$BYTE_TEST_FILE" | tr -d '[:space:]')"
if [ "$BYTE_COUNT" != "1" ]; then
  echo "Public readability check failed: expected 1 byte, got ${BYTE_COUNT}" >&2
  exit 1
fi

UPDATED_DEFAULTS="no"
if [ "$UPDATE_ROBIN_CLI_SCRIPTS" = "yes" ]; then
  echo "==> Updating harbor-ara robinCliScripts defaults"
  cd "$HARBOR_DIR"

  NEW_S3_URI="$S3_URI" NEW_PUBLIC_URL="$PUBLIC_URL" \
  perl -0pi -e '
    s|TARBALL_S3_URI="\$\{TARBALL_S3_URI:-[^}]*\}"|TARBALL_S3_URI="${TARBALL_S3_URI:-$ENV{NEW_S3_URI}}"|g;
    s|TARBALL_URL="\$\{TARBALL_URL:-[^}]*\}"|TARBALL_URL="${TARBALL_URL:-$ENV{NEW_PUBLIC_URL}}"|g;
  ' instance/robinCliScripts/*.sh

  grep -nE 'TARBALL_S3_URI="\$\{TARBALL_S3_URI:-|TARBALL_URL="\$\{TARBALL_URL:-' \
    instance/robinCliScripts/*.sh || true
  UPDATED_DEFAULTS="yes"
fi

echo
echo "Done."
echo "tarball path: ${SDK_WIP_DIR}/${TARBALL_PATH}"
echo "S3 URI: ${S3_URI}"
echo "public URL: ${PUBLIC_URL}"
echo "robinCliScripts defaults updated: ${UPDATED_DEFAULTS}"
