# Spectra PDF: Linux Installation

Spectra PDF currently targets Debian and Ubuntu Linux.

These instructions assume you have cloned the Linux fork of the repository.

## 1. Install Debian/Ubuntu dependencies

From the repository root:
```
bash scripts/install-linux-deps.sh
```

This installs the native libraries required to build and run the Tauri application, together with Python and Python virtual-environment support.

The script also checks that Python 3.12 or newer is available.

## 2. Install Rust and the Tauri CLI

Run:
```
bash scripts/install-rust-tauri.sh
```

This script installs:

- Rust using rustup
- Cargo, which is installed as part of Rust
- The Tauri CLI using cargo install tauri-cli

Rust and the Tauri CLI are developer toolchain components, so this step is kept separate from the Debian/Ubuntu package installation.

After installation, open a new terminal if necessary so that Cargo is available on your PATH.

## 3. Build the Debian package

Run:
```
bash scripts/build-linux.sh
```

The build script:

- Provisions Spectra PDF's Python environment using scripts/setup-python-embed.sh.
- Installs the Python dependencies from the repository lockfile.
- Builds Spectra PDF with Tauri.
- Creates a Debian .deb package.

The resulting package is placed in:
```
src-tauri/target/release/bundle/deb/
```

## 4. Install Spectra PDF

Install the package with:
```
sudo apt install ./src-tauri/target/release/bundle/deb/*.deb
```

Spectra PDF can then be launched by running `spectrapdf`.
