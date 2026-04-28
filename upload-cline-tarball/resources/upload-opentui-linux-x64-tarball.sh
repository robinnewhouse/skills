#!/usr/bin/env bash
set -euo pipefail

SDK_WIP_DIR="${SDK_WIP_DIR:-/Users/robin/dev/sdk-wip}"
HARBOR_DIR="${HARBOR_DIR:-/Users/robin/dev/harbor-ara}"
UPDATE_ROBIN_CLI_SCRIPTS="${UPDATE_ROBIN_CLI_SCRIPTS:-no}"
RUN_BUCKET_SETUP="${RUN_BUCKET_SETUP:-no}"
SKIP_INSTALL="${SKIP_INSTALL:-no}"
SKIP_SDK_BUILD="${SKIP_SDK_BUILD:-no}"

REGION="us-east-2"
BUCKET="uploading-sdk-wip"
PREFIX="cline-builds"
TARGET_OS="linux"
TARGET_ARCH="x64"
TARGET_NAME="linux-x64"

usage() {
  cat <<'USAGE'
Usage: bash upload-opentui-linux-x64-tarball.sh [options]

Builds the OpenTUI CLI as a Linux x64 compiled Bun binary, wraps it in a
minimal npm-compatible tarball with both clite and cline bin entries, uploads
it to S3, and verifies public byte-range readability.

Options:
  --sdk-wip-dir <path>            Path to sdk-wip repo (default: /Users/robin/dev/sdk-wip)
  --harbor-dir <path>             Path to harbor repo (default: /Users/robin/dev/harbor-ara)
  --update-robin-cli-scripts      Update harbor-ara script defaults after upload (default: off)
  --run-bucket-setup              Run one-time S3 bucket public policy setup (default: off)
  --skip-install                  Skip bun install --os="*" --cpu="*" (default: off)
  --skip-sdk-build                Skip bun run build:sdk and CLI JS bundle build (default: off)
  -h, --help                      Show this help

Environment variable equivalents:
  SDK_WIP_DIR, HARBOR_DIR, UPDATE_ROBIN_CLI_SCRIPTS, RUN_BUCKET_SETUP,
  SKIP_INSTALL, SKIP_SDK_BUILD
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
    --skip-install)
      SKIP_INSTALL="yes"
      shift
      ;;
    --skip-sdk-build)
      SKIP_SDK_BUILD="yes"
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
require_cmd aws
require_cmd curl
require_cmd tar
require_cmd git
require_cmd perl
require_cmd grep
require_cmd mktemp

validate_yes_no "UPDATE_ROBIN_CLI_SCRIPTS" "$UPDATE_ROBIN_CLI_SCRIPTS"
validate_yes_no "RUN_BUCKET_SETUP" "$RUN_BUCKET_SETUP"
validate_yes_no "SKIP_INSTALL" "$SKIP_INSTALL"
validate_yes_no "SKIP_SDK_BUILD" "$SKIP_SDK_BUILD"

echo "==> OpenTUI Linux x64 tarball preflight (${SDK_WIP_DIR})"
cd "$SDK_WIP_DIR"

node <<'NODE'
const fs = require("fs")
const p = JSON.parse(fs.readFileSync("apps/cli/package.json", "utf8"))
const errors = []

if (!p.dependencies?.["@opentui/core"]) {
  errors.push("apps/cli/package.json must depend on @opentui/core")
}
if (p.scripts?.["build:platforms"] !== "bun script/build.ts") {
  errors.push("apps/cli package should expose scripts.build:platforms = bun script/build.ts")
}
if (p.bin?.clite !== "src/index.ts") {
  errors.push("OpenTUI development package is expected to keep bin.clite = src/index.ts")
}

if (errors.length) {
  console.error("Preflight failed:")
  for (const e of errors) console.error(`- ${e}`)
  process.exit(1)
}

console.log("Preflight OK: OpenTUI platform-binary build system detected")
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

CLI_DIR="${SDK_WIP_DIR}/apps/cli"
DIST_DIR="${CLI_DIR}/dist"
TARGET_DIST_DIR="${DIST_DIR}/cli-${TARGET_NAME}"
PACKAGE_DIR="$(mktemp -d /tmp/cline-opentui-linux-x64-package.XXXXXX)"
TMP_BUILD_DIR="$(mktemp -d /tmp/cline-opentui-linux-x64-build.XXXXXX)"

cleanup() {
  rm -rf "$PACKAGE_DIR" "$TMP_BUILD_DIR"
}
trap cleanup EXIT

OPENTUI_VERSION="$(
  node -e 'const p=require("./apps/cli/package.json"); process.stdout.write(p.dependencies["@opentui/core"])'
)"

if [ "$SKIP_INSTALL" != "yes" ]; then
  echo "==> Installing target native package variants for OpenTUI (${OPENTUI_VERSION})"
  (
    cd "$CLI_DIR"
    bun install --os="*" --cpu="*" "@opentui/core@${OPENTUI_VERSION}"
  )
fi

if [ "$SKIP_SDK_BUILD" != "yes" ]; then
  echo "==> Building SDK packages"
  bun run build:sdk

  echo "==> Building CLI JS bundle"
  bun -F @clinebot/cli build
fi

echo "==> Compiling OpenTUI CLI for ${TARGET_NAME}"
rm -rf "$TARGET_DIST_DIR"
mkdir -p "${TARGET_DIST_DIR}/bin"

BINARY_OUT="${TARGET_DIST_DIR}/bin/clite"
TMP_BINARY="${TMP_BUILD_DIR}/clite"
bun build "${CLI_DIR}/src/index.ts" \
  --compile \
  --target "bun-${TARGET_OS}-${TARGET_ARCH}" \
  --outfile "$TMP_BINARY" \
  --minify \
  --external @anthropic-ai/vertex-sdk

cp "$TMP_BINARY" "$BINARY_OUT"
chmod 755 "$BINARY_OUT"

BOOTSTRAP_SRC="${SDK_WIP_DIR}/packages/core/dist/extensions/plugin-sandbox-bootstrap.js"
if [ -f "$BOOTSTRAP_SRC" ]; then
  mkdir -p "${TARGET_DIST_DIR}/extensions"
  cp "$BOOTSTRAP_SRC" "${TARGET_DIST_DIR}/extensions/plugin-sandbox-bootstrap.js"
fi

VERSION="$(
  node <<'NODE'
const fs = require("fs")
const cli = JSON.parse(fs.readFileSync("apps/cli/package.json", "utf8"))
const shared = JSON.parse(fs.readFileSync("packages/shared/package.json", "utf8"))
process.stdout.write(cli.version !== "0.0.0" ? cli.version : shared.version)
NODE
)"

cat > "${TARGET_DIST_DIR}/package.json" <<JSON
{
  "name": "@clinebot/cli-opentui-linux-x64",
  "version": "${VERSION}",
  "description": "Temporary OpenTUI Cline CLI Linux x64 tarball for Harbor",
  "license": "Apache-2.0",
  "os": ["linux"],
  "cpu": ["x64"],
  "bin": {
    "clite": "bin/clite",
    "cline": "bin/clite"
  }
}
JSON

echo "==> Packing npm-compatible tarball"
mkdir -p "${PACKAGE_DIR}/package"
cp -R "${TARGET_DIST_DIR}/." "${PACKAGE_DIR}/package/"

SHA="$(git rev-parse --short HEAD)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TARBALL_PATH="${DIST_DIR}/cline-opentui-linux-x64-${VERSION}-${STAMP}-${SHA}.tgz"
tar -czf "$TARBALL_PATH" -C "$PACKAGE_DIR" package

echo "==> Validating tarball shape"
PKG_NAME="$(tar -xOf "$TARBALL_PATH" package/package.json | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>process.stdout.write(JSON.parse(s).name))')"
PKG_VERSION="$(tar -xOf "$TARBALL_PATH" package/package.json | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>process.stdout.write(JSON.parse(s).version))')"
BIN_CLITE="$(tar -xOf "$TARBALL_PATH" package/package.json | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>process.stdout.write(JSON.parse(s).bin?.clite || ""))')"
BIN_CLINE="$(tar -xOf "$TARBALL_PATH" package/package.json | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>process.stdout.write(JSON.parse(s).bin?.cline || ""))')"

if [ "$BIN_CLITE" != "bin/clite" ]; then
  echo "Tarball validation failed: .bin.clite must be bin/clite" >&2
  exit 1
fi
if [ "$BIN_CLINE" != "bin/clite" ]; then
  echo "Tarball validation failed: .bin.cline must be bin/clite" >&2
  exit 1
fi
if ! tar -tzf "$TARBALL_PATH" | grep -q '^package/bin/clite$'; then
  echo "Tarball validation failed: package/bin/clite missing" >&2
  exit 1
fi

echo "Package: ${PKG_NAME}@${PKG_VERSION}"
echo "bin.clite: ${BIN_CLITE}"
echo "bin.cline: ${BIN_CLINE}"
echo "Tarball: ${TARBALL_PATH}"

echo "==> Uploading tarball"
BASE="$(basename "$TARBALL_PATH" .tgz)"
KEY="new-cli-${BASE}.tgz"
S3_URI="s3://${BUCKET}/${PREFIX}/${KEY}"
PUBLIC_URL="https://${BUCKET}.s3.${REGION}.amazonaws.com/${PREFIX}/${KEY}"

aws s3 cp "$TARBALL_PATH" "$S3_URI" --region "$REGION"

echo "==> Verifying public byte-range readability"
BYTE_TEST="$(mktemp /tmp/tarball-byte-test.XXXXXX.bin)"
curl -fsS -r 0-0 "$PUBLIC_URL" -o "$BYTE_TEST"
BYTE_COUNT="$(wc -c < "$BYTE_TEST" | tr -d '[:space:]')"
rm -f "$BYTE_TEST"
if [ "$BYTE_COUNT" != "1" ]; then
  echo "Public URL byte-range verification failed: expected 1 byte, got ${BYTE_COUNT}" >&2
  exit 1
fi

if [ "$UPDATE_ROBIN_CLI_SCRIPTS" = "yes" ]; then
  echo "==> Updating harbor robinCliScripts defaults (${HARBOR_DIR})"
  cd "$HARBOR_DIR"
  NEW_S3_URI="$S3_URI" NEW_PUBLIC_URL="$PUBLIC_URL" \
  perl -0pi -e '
    s|TARBALL_S3_URI="\$\{TARBALL_S3_URI:-[^}]*\}"|TARBALL_S3_URI="${TARBALL_S3_URI:-$ENV{NEW_S3_URI}}"|g;
    s|TARBALL_URL="\$\{TARBALL_URL:-[^}]*\}"|TARBALL_URL="${TARBALL_URL:-$ENV{NEW_PUBLIC_URL}}"|g;
    s|^TARBALL_URL=""$|TARBALL_URL="$ENV{NEW_PUBLIC_URL}"|mg;
  ' instance/robinCliScripts/*.sh
fi

cat <<REPORT
==> Done
Tarball path: ${TARBALL_PATH}
S3 URI:       ${S3_URI}
Public URL:   ${PUBLIC_URL}
Harbor defaults updated: ${UPDATE_ROBIN_CLI_SCRIPTS}
REPORT
