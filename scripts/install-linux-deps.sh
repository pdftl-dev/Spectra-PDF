#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Spectra PDF build dependencies"
echo

if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERROR: This script requires a Debian/Ubuntu system with apt-get."
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    echo "ERROR: sudo is required to install system packages."
    echo "Run this script as root or install sudo."
    exit 1
fi

echo "==> Updating package lists..."
$SUDO apt-get update

echo "==> Installing system dependencies..."
$SUDO apt-get install -y \
    build-essential \
    curl \
    pkg-config \
    libssl-dev \
    libwebkit2gtk-4.1-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev \
    patchelf \
    libglib2.0-dev \
    libgtk-3-dev \
    libjavascriptcoregtk-4.1-dev \
    libsoup-3.0-dev \
    python3 \
    python3-venv

echo
echo "==> Checking Python version..."

PYTHON_BIN=""

for candidate in python3.14 python3.13 python3.12 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
        if "$candidate" -c \
            'import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)' \
            >/dev/null 2>&1; then
            PYTHON_BIN="$(command -v "$candidate")"
            break
        fi
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    echo
    echo "ERROR: Python 3.12 or newer is required."
    echo
    echo "Install Python 3.12+ and its venv support, then run this script again."
    echo
    echo "For Ubuntu 22.04, for example:"
    echo "  sudo apt install python3.12 python3.12-venv"
    echo
    exit 1
fi

PYTHON_VERSION="$("$PYTHON_BIN" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"

echo "    Found Python $PYTHON_VERSION at $PYTHON_BIN"
echo
echo "==> Linux build dependencies are ready."
