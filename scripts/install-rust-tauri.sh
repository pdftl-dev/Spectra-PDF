#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Rust and the Tauri CLI"
echo

if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
    echo "==> Rust is already installed:"
    rustc --version
    cargo --version
else
    echo "==> Installing Rust using rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

    # Make Rust available to this script immediately.
    if [ -f "$HOME/.cargo/env" ]; then
        # shellcheck disable=SC1091
        source "$HOME/.cargo/env"
    fi
fi

if ! command -v cargo >/dev/null 2>&1; then
    echo "ERROR: cargo was not found after installing Rust."
    echo "Open a new shell and run this script again."
    exit 1
fi

echo
echo "==> Installing the Tauri CLI..."
cargo install tauri-cli

echo
echo "==> Rust and Tauri CLI are ready."
echo
rustc --version
cargo --version
cargo tauri --version
