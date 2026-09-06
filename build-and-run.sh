#!/usr/bin/env bash

# A relatively fast way to build and run spectrapdf on linux during development/testing

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# 1. Automatically ensure embedded Python environment is provisioned
PYTHON_DIR="$PROJECT_ROOT/resources/python"
PYTHON_BIN="$PYTHON_DIR/bin/python"
if [ ! -x "$PYTHON_BIN" ] ||
   ! "$PYTHON_BIN" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)' >/dev/null 2>&1; then
    echo "==> Embedded Python environment missing, incomplete, or too old. Provisioning..."
    bash scripts/setup-python-embed.sh
fi

# 2. Build Tauri app in debug mode
echo "==> Building Tauri app (debug mode)..."
cd "$PROJECT_ROOT/src-tauri"
cargo tauri build --debug

# 3. Launch application
echo "==> Launching Spectra PDF..."
exec "$PROJECT_ROOT/src-tauri/target/debug/spectrapdf"
