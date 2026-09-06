#!/usr/bin/env bash
set -euo pipefail


SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
cd "$SCRIPT_DIR"
SCRIPT_DIR="$(pwd)"
DEST_DIR="$SCRIPT_DIR/../resources/python"
mkdir -p "$DEST_DIR"
LOCK_FILE="$SCRIPT_DIR/python-requirements.txt"
WHEELS_SCRIPT="$SCRIPT_DIR/install-vendored-wheels.sh"

cd "$DEST_DIR"
DEST_DIR="$(pwd)"

echo "Setting up Python runtime for Linux at $DEST_DIR..."
echo "The application uses an isolated virtual environment; system Python packages are not used."


# Locate a Python >= 3.12 interpreter matching the lockfile constraints
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
    echo "ERROR: Spectra PDF requires Python 3.12 or newer to build its Linux"
    echo "       application runtime."
    echo
    echo "A system Python is required only to CREATE the application's isolated"
    echo "virtual environment. Spectra PDF does NOT use your system Python"
    echo "packages, and you do not need to install pikepdf, numpy, or any other"
    echo "application dependency system-wide."
    echo
    echo "No suitable Python interpreter was found."
    echo
    echo "Please install Python 3.12+ with its virtual-environment support."
    echo
    echo "Ubuntu/Debian example:"
    echo "  sudo apt install python3.12 python3.12-venv"
    echo
    echo "Then verify:"
    echo "  python3.12 --version"
    echo
    echo "and run this setup script again."
    exit 1
fi

# Check existing virtualenv and recreate if it was initialized with Python < 3.12
if [ -f "$DEST_DIR/bin/python" ]; then
    EXISTING_VER=$("$DEST_DIR/bin/python" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)
    if [[ ! "$EXISTING_VER" =~ ^3\.([0-9]+)$ ]] || [ "${BASH_REMATCH[1]}" -lt 12 ]; then
        echo "Existing environment at $DEST_DIR uses Python $EXISTING_VER (< 3.12). Recreating..."
        rm -rf "$DEST_DIR"
    fi
fi
if [ ! -f "$DEST_DIR/bin/python" ]; then
    echo "Creating virtual environment at $DEST_DIR using $PYTHON_CMD..."
    if ! "$PYTHON_CMD" -m venv "$DEST_DIR"; then
        echo
        echo "ERROR: Could not create the application's Python virtual environment."
        echo
        echo "The Python interpreter '$PYTHON_CMD' is installed, but its"
        echo "virtual-environment support is missing or not usable."
        echo
        echo "On Ubuntu/Debian, install the matching venv package, for example:"
        echo "  sudo apt install python3.12-venv"
        echo
        echo "Then remove the incomplete environment and try again:"
        echo "  rm -rf '$DEST_DIR'"
        echo "  bash scripts/setup-python-embed.sh"
        exit 1
    fi
fi
# Create a root executable symlink for cross-platform launcher compatibility
if [ -f "$DEST_DIR/bin/python" ] && [ ! -e "$DEST_DIR/python" ]; then
    ln -s bin/python "$DEST_DIR/python"
fi

# Ensure pip is present in case a previous run uninstalled it during cleanup.
# Do not silently ignore failure: a venv without pip cannot be provisioned.
if ! "$DEST_DIR/bin/python" -m ensurepip --default-pip >/dev/null 2>&1; then
    echo
    echo "ERROR: Python's ensurepip module is unavailable."
    echo
    echo "The virtual environment was created, but pip could not be installed"
    echo "inside it. This usually means the system Python was installed without"
    echo "its venv/ensurepip support."
    echo
    echo "On Ubuntu/Debian, install the matching package, for example:"
    echo "  sudo apt install python3.12-venv"
    echo
    echo "Then remove the incomplete environment and try again:"
    echo "  rm -rf '$DEST_DIR'"
    echo "  bash scripts/setup-python-embed.sh"
    exit 1
fi

# Upgrade pip inside the venv
echo "Upgrading pip, setuptools, and wheel..."
if ! "$DEST_DIR/bin/python" -m pip install --upgrade pip setuptools wheel --no-warn-script-location; then
    echo
    echo "ERROR: Failed to install the Python packaging tools into the"
    echo "       application's isolated environment."
    echo
    echo "Check that this machine has network access to PyPI and try again."
    exit 1
fi

# Correctly clean multiline requirements and strip hashes from the lockfile
if [ -f "$LOCK_FILE" ]; then
    echo "Installing dependencies from lockfile..."
    TEMP_REQ=$(mktemp)
    "$DEST_DIR/bin/python" -c '
import re, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    lines = f.read().splitlines()

joined = []
current = ""
for line in lines:
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    if current:
        current += " " + stripped
    else:
        current = stripped
    if not stripped.endswith("\\"):
        joined.append(current[:-1].rstrip() if current.endswith("\\") else current)
        current = ""
if current:
    joined.append(current)

clean = []
for line in joined:
    line = re.sub(r"--hash=[^\s]+", "", line)
    line = re.sub(r"\s+", " ", line).strip()
    if line:
        clean.append(line)

with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write("\n".join(clean))
' "$LOCK_FILE" "$TEMP_REQ"
    if ! "$DEST_DIR/bin/python" -m pip install --no-cache-dir -r "$TEMP_REQ" --no-warn-script-location; then
        rm -f "$TEMP_REQ"
        echo
        echo "ERROR: Failed to install Spectra PDF's Python dependencies."
        echo
        echo "The dependencies are installed into the application's private"
        echo "virtual environment, not into system Python."
        echo
        echo "Check the error above for the failing package and try again."
        exit 1
    fi
    rm -f "$TEMP_REQ"
else
    echo
    echo "ERROR: Python dependency lockfile not found:"
    echo "       $LOCK_FILE"
    echo
    echo "This file is required to provision the application's Python runtime."
    exit 1
fi
# Install vendored wheels if script exists
if [ -f "$WHEELS_SCRIPT" ]; then
    echo "Installing vendored wheels..."
    if ! bash "$WHEELS_SCRIPT" "$DEST_DIR/bin/python"; then
        echo
        echo "ERROR: Failed to install Spectra PDF's vendored Python wheels."
        echo "       See the error above for details."
        exit 1
    fi
fi

# Create sitecustomize.py to pre-load stdlib modules (e.g. inspect)
# into sys.modules before local script directories on sys.path can shadow them
SITE_PACKAGES=$(find "$DEST_DIR" -type d -name "site-packages" | head -n 1)
if [ -n "$SITE_PACKAGES" ]; then
    cat << 'EOF' > "$SITE_PACKAGES/sitecustomize.py"
import sys

_orig_path = list(sys.path)
sys.path = [p for p in _orig_path if p.startswith(sys.prefix) or p.startswith('/usr/lib') or 'site-packages' in p]
try:
    import inspect
finally:
    sys.path = _orig_path
EOF
fi
# Cleanup caches and unnecessary test folders to keep bundle size small
echo "Cleaning up..."
find "$DEST_DIR" -type d -name "__pycache__" -exec rm -rf {} +
find "$DEST_DIR" -type d -name "tests" -exec rm -rf {} +
find "$DEST_DIR" -type d -name "test" -exec rm -rf {} +

# Prune dist-info contents (keep METADATA, RECORD, DELVEWHEEL, licenses)
find "$DEST_DIR" -type d -name "*.dist-info" | while read -r di; do
    find "$di" -type f | while read -r f; do
        filename=$(basename "$f")
        if [[ ! "$filename" =~ ^(METADATA|RECORD|DELVEWHEEL|LICEN[CS]E.*|COPYING.*|COPYRIGHT.*|NOTICE.*|AUTHORS.*|LEGAL.*)$ ]]; then
            rm -f "$f"
        fi
    done
    find "$di" -mindepth 1 -maxdepth 1 -type d ! -name "licenses" -exec rm -rf {} +
done
# Remove pip to match setup-python-embed.ps1 payload size
"$DEST_DIR/bin/python" -m pip uninstall pip -y >/dev/null 2>&1 || true

SIZE_MB=$(du -sh "$DEST_DIR" | cut -f1)
echo "Done. Linux Python environment ready: $SIZE_MB"
