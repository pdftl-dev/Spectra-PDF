# scripts/setup-python-embed.sh
#!/usr/bin/env bash
set -euo pipefail

# NOTE: This script no longer bundles a Python venv into the app resources.
# The Linux .deb depends on system python3 (>= 3.12) and builds its venv
# at install time via debian/postinst, using the lockfile below. This
# avoids shipping a venv whose bin/python symlink points at a build-machine
# interpreter path that may not exist on the install target.
#
# This script's remaining job at build time is to sanity-check that a
# suitable interpreter is available on THIS machine, and to stage the
# lockfile + vendored Linux wheels somewhere the .deb packaging step can
# pick up and ship as data files (not as a working venv).

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
cd "$SCRIPT_DIR"
SCRIPT_DIR="$(pwd)"
LOCK_FILE="$SCRIPT_DIR/python-requirements.txt"
PROJECT_ROOT="$SCRIPT_DIR/.."
STAGE_DIR="$PROJECT_ROOT/resources/python-provisioning"

echo "Checking for a suitable system Python (>= 3.12)..."

PYTHON_CMD=""
for candidate in python3.14 python3.13 python3.12 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
        VER=$("$candidate" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)
        if [[ "$VER" =~ ^3\.([0-9]+)$ ]] && [ "${BASH_REMATCH[1]}" -ge 12 ]; then
            PYTHON_CMD="$candidate"
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo
    echo "ERROR: Spectra PDF requires Python 3.12 or newer to be present on"
    echo "       this build machine (used only to sanity-check the lockfile;"
    echo "       the shipped .deb depends on python3 (>= 3.12) at install time"
    echo "       and builds its own venv via postinst)."
    echo
    echo "No suitable Python interpreter was found."
    echo
    echo "Please install Python 3.12+ with its virtual-environment support."
    echo
    echo "Ubuntu/Debian example:"
    echo "  sudo apt install python3.12 python3.12-venv"
    echo
    exit 1
fi

echo "Found $PYTHON_CMD ($($PYTHON_CMD -c 'import sys; print(".".join(map(str, sys.version_info[:3])))'))"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

if [ ! -f "$LOCK_FILE" ]; then
    echo "ERROR: Python dependency lockfile not found: $LOCK_FILE" >&2
    exit 1
fi
# Strip hashes so network installs succeed across any Python version >= 3.12
sed -E 's/ --hash=sha256:[a-f0-9]+//g' "$LOCK_FILE" > "$STAGE_DIR/python-requirements.txt"

echo "Staged Python provisioning files at $STAGE_DIR"
