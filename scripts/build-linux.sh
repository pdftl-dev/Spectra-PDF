#!/usr/bin/env bash
set -euo pipefail

SKIP_PREP=false
if [[ "${1:-}" == "--fast" ]]; then
  SKIP_PREP=true
  shift
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLES="${1:-deb}"

cd "$PROJECT_ROOT"

echo "==> Building Spectra PDF for Linux"
echo

if ! command -v cargo >/dev/null 2>&1; then
    echo "ERROR: cargo is not installed."
    echo "Run scripts/install-rust-tauri.sh first."
    exit 1
fi

if ! cargo tauri --version >/dev/null 2>&1; then
    echo "ERROR: the Tauri CLI is not installed."
    echo "Run scripts/install-rust-tauri.sh first."
    exit 1
fi


if [ "$SKIP_PREP" = false ]; then
    echo "==> Preparing environment..."
    echo "0/3 ==> Stub out empty resources directories"
    for x in dictionaries jbig2enc libreoffice tesseract; do
	mkdir -p "$PROJECT_ROOT/resources/$x"
    done
    echo "1/3 ==> Provisioning Python environment..."
    ./scripts/setup-python-embed.sh
    echo "2/3 ==> Syncing Edit-tool fonts..."
    ./scripts/sync-edit-fonts.sh
    echo "3/3 ==> Bundling ICC profile data..."
    ./scripts/bundle-icc.sh
else
    echo "==> Skipping environment prep (--fast)"
fi


cd "$PROJECT_ROOT"
if [ ! -d "node_modules" ] || [ ! -d "node_modules/pdfjs-dist" ]; then
    echo "==> Installing frontend dependencies..."
    npm ci
fi

echo
echo "==> Building Linux package(s): $BUNDLES..."

cd "$PROJECT_ROOT/src-tauri"

EXTRA_FLAGS=()
if [ "$SKIP_PREP" = true ]; then
    EXTRA_FLAGS=(--config '{"build":{"beforeBuildCommand":"true"}}')
fi

cd "$PROJECT_ROOT/src-tauri"
cargo tauri build "${EXTRA_FLAGS[@]}" --bundles "$BUNDLES" -- -vv
# to debug last step add
# -- -vv

echo
echo "==> Package(s) created:"
for bundle in ${BUNDLES//,/ }; do
    find "$PROJECT_ROOT/src-tauri/target/release/bundle/$bundle" \
        -maxdepth 1 \
        -type f \
        -ls
done
