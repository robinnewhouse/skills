#!/usr/bin/env bash
set -euo pipefail

SDK_DIR="${SDK_DIR:-${SDK_WIP_DIR:-/Users/robin/dev/cline/sdk}}"
HARBOR_DIR="${HARBOR_DIR:-/Users/robin/dev/harbor-ara}"
UPDATE_ROBIN_CLI_SCRIPTS="${UPDATE_ROBIN_CLI_SCRIPTS:-no}"
RUN_BUCKET_SETUP="${RUN_BUCKET_SETUP:-no}"

REGION="us-east-2"
BUCKET="uploading-sdk-wip"
PREFIX="cline-builds"

usage() {
  cat <<'USAGE'
Usage: bash upload-cline-tarball.sh [options]

Options:
  --sdk-dir <path>                Path to Cline SDK repo (default: /Users/robin/dev/cline/sdk)
  --harbor-dir <path>             Path to harbor repo (default: /Users/robin/dev/harbor-ara)
  --update-robin-cli-scripts      Update harbor-ara script defaults after upload (default: off)
  --run-bucket-setup              Run one-time S3 bucket public policy setup (default: off)
  -h, --help                      Show this help

Environment variable equivalents:
  SDK_DIR, SDK_WIP_DIR, HARBOR_DIR, UPDATE_ROBIN_CLI_SCRIPTS, RUN_BUCKET_SETUP
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sdk-dir|--sdk-wip-dir)
      SDK_DIR="$2"
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

echo "==> Preflight check (${SDK_DIR})"
cd "$SDK_DIR"

node <<'NODE'
const fs = require('fs')
const path = 'apps/cli/package.json'

function collectErrors(pkg) {
  const errors = []
  if (pkg.name !== '@cline/cli') {
    errors.push('apps/cli/package.json name must be @cline/cli')
  }
  if (pkg.bin?.cline !== 'dist/index.js') {
    errors.push('bin.cline must be dist/index.js')
  }
  if (typeof pkg.scripts?.['build:tgz'] !== 'string') {
    errors.push('scripts.build:tgz must exist')
  }
  return errors
}

const pkg = JSON.parse(fs.readFileSync(path, 'utf8'))
const errors = collectErrors(pkg)

if (errors.length) {
  console.error('Preflight failed:')
  for (const e of errors) console.error(`- ${e}`)
  process.exit(1)
}

console.log('Preflight OK: cline support is present in apps/cli/package.json')
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
bun run -F @cline/cli build:tgz

TARBALL_PATH="$(ls -1t apps/cli/dist/*.tgz | head -n 1)"
if [ -z "$TARBALL_PATH" ]; then
  echo "No tarball found under apps/cli/dist/*.tgz" >&2
  exit 1
fi

echo "==> Validating tarball shape"
PKG_NAME="$(tar -xOf "$TARBALL_PATH" package/package.json | jq -r '.name')"
PKG_VERSION="$(tar -xOf "$TARBALL_PATH" package/package.json | jq -r '.version')"
BIN_CLINE="$(tar -xOf "$TARBALL_PATH" package/package.json | jq -r '.bin.cline')"

if [ "$BIN_CLINE" = "null" ] || [ -z "$BIN_CLINE" ]; then
  echo "Tarball validation failed: .bin.cline missing" >&2
  exit 1
fi
if ! tar -tzf "$TARBALL_PATH" | grep -q '^package/'; then
  echo "Tarball validation failed: entries are not under package/..." >&2
  exit 1
fi

echo "Package: ${PKG_NAME}@${PKG_VERSION}"
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
echo "tarball path: ${SDK_DIR}/${TARBALL_PATH}"
echo "S3 URI: ${S3_URI}"
echo "public URL: ${PUBLIC_URL}"
echo "robinCliScripts defaults updated: ${UPDATED_DEFAULTS}"
