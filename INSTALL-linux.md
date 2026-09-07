# Spectra PDF: Linux Installation

Spectra PDF currently targets Debian and Ubuntu Linux.

These instructions assume you have cloned the Linux fork of the repository.

## 1. Install system dependencies

From the repository root:
```
bash scripts/install-linux-deps.sh
```

This installs the native libraries needed to build and run the Tauri application, plus Python and Python virtual-environment support, and checks that Python 3.12 or newer is available.

It does **not** install everything the build needs -- also make sure these are present:

- **Node.js** (v20+) and npm. No script installs this; the build fails with a plain "npm: command not found" if it's missing.
- **`rsync`** and **`unzip`**. Usually already present on a desktop install, but not guaranteed on a minimal one, and not in `install-linux-deps.sh`'s package list:
  ```
  sudo apt install rsync unzip
  ```

## 2. Install Rust and the Tauri CLI

Run:
```
bash scripts/install-rust-tauri.sh
```

Installs Rust via rustup (skipped if `rustc`/`cargo` are already on `PATH`) and the Tauri CLI via `cargo install tauri-cli`.

After installation, open a new terminal if necessary so that Cargo is available on your `PATH`.

## 3. Build the Debian package

Run:
```
bash scripts/build-linux.sh
```

This one script does everything else:

- Stages the resource directories the Tauri bundler expects (`dictionaries`, `jbig2enc`, `libreoffice`, `tesseract`).
- Sanity-checks the build machine's Python (>= 3.12) and stages the dependency lockfile the `.deb`'s post-install step uses -- the build machine's Python is **not** bundled into the package; the `.deb` builds its own venv at install time against whatever Python is on the *install* machine (see the troubleshooting note below).
- Downloads and hash-verifies the Edit-tool fallback fonts (needs network on first run; skipped if already cached and verified).
- Bundles the ICC colour profiles from `vendor/icc/` (no network).
- Runs `npm ci` if `node_modules` is missing or stale, then `cargo tauri build --bundles deb`, which also builds the frontend.

Pass `--fast` to skip the resource-staging steps on a repeat build once they've already run once: `bash scripts/build-linux.sh --fast`.

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

### Troubleshooting: `python3.12-venv | ... is not installed`

Spectra PDF's post-install step needs a Python 3.12+ interpreter present on the *installing* machine, not just the one it was built on. If you're installing a `.deb` built elsewhere (a CI artifact, for example) rather than building it locally, `apt` can refuse the install with something like:

```
spectra-pdf depends on python3.12-venv | python3.13-venv | python3.14-venv | python3.15-venv; however:
  Package python3.12-venv is not installed.
  ...
```

Fix: install one of those exact packages from your distro's repositories, e.g.:
```
sudo apt install python3.12-venv
```

If your distro's default release doesn't carry Python 3.12+ yet (Debian 12/bookworm defaults to 3.11, for example), you need a release or backports that does. `apt`'s dependency check only recognises apt packages -- a Python 3.12+ interpreter installed by other means (`pyenv`, `uv python install`, etc.) won't satisfy it, and won't be found by the post-install step's own version check either, since that runs with a fixed `PATH` that doesn't include per-user install locations like `~/.local/bin`.
