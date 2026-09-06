#!/usr/bin/env bash
set -euo pipefail

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

echo "==> Provisioning Python environment..."
./scripts/setup-python-embed.sh

echo "==> Syncing Edit-tool fonts..."
./scripts/sync-edit-fonts.sh

echo "==> Bundling ICC profile data..."
./scripts/bundle-icc.sh

cd "$PROJECT_ROOT"
if [ ! -d "node_modules" ] || [ ! -d "node_modules/pdfjs-dist" ]; then
    echo "==> Installing frontend dependencies..."
    npm ci
fi

echo
echo "==> Building Linux package(s): $BUNDLES..."

# stub out empty directories for build
for x in dictionaries jbig2enc libreoffice tesseract; do
    mkdir -p "$PROJECT_ROOT/resources/$x"
done


cd "$PROJECT_ROOT/src-tauri"
cargo tauri build --bundles "$BUNDLES"

echo
echo "==> Package(s) created:"
for bundle in ${BUNDLES//,/ }; do
    find "$PROJECT_ROOT/src-tauri/target/release/bundle/$bundle" \
        -maxdepth 1 \
        -type f \
        -print
done
