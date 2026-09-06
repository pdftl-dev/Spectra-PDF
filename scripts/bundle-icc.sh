#!/usr/bin/env bash
set -euo pipefail

# Stages the bundled ICC colour profiles into resources/icc/.
#
# Source: committed copies under vendor/icc/.
# Nothing is fetched and no network is touched.
#
# The committed profile bytes are verified against the SHA256 values in
# scripts/icc-profiles.tsv. The copied files are then verified again.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

SOURCE_DIR="${SOURCE_DIR:-"$ROOT_DIR/vendor/icc"}"
DEST_DIR="${DEST_DIR:-"$ROOT_DIR/resources/icc"}"
MANIFEST="${MANIFEST:-"$SCRIPT_DIR/icc-profiles.tsv"}"
LICENSE_TEXT="${LICENSE_TEXT:-"$ROOT_DIR/vendor/icc/Adobe-Color-Profile-License.txt"}"
NOTICES="${NOTICES:-"$ROOT_DIR/THIRD-PARTY-LICENSES.md"}"

LICENSE_NAME="Adobe-Color-Profile-License.txt"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Basic input checks
# ---------------------------------------------------------------------------

[[ -d "$SOURCE_DIR" ]] ||
    die "committed profile directory not found: $SOURCE_DIR"

[[ -f "$MANIFEST" ]] ||
    die "manifest not found: $MANIFEST"

[[ -f "$LICENSE_TEXT" ]] ||
    die "the end-user licence text is missing: $LICENSE_TEXT"

[[ -s "$LICENSE_TEXT" ]] ||
    die "the end-user licence text is empty: $LICENSE_TEXT"

[[ -f "$NOTICES" ]] ||
    die "the notice inventory is missing: $NOTICES"

# ---------------------------------------------------------------------------
# Read manifest
#
# Expected columns:
#   description  role  member  sha256  condition  copyright
#
# Header/comment lines are ignored. TSV fields are parsed with bash's
# read -r -a, which preserves the tab-separated structure.
# ---------------------------------------------------------------------------

declare -a descriptions=()
declare -a roles=()
declare -a members=()
declare -a hashes=()
declare -a conditions=()
declare -a copyrights=()

header_seen=0

while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines.
    [[ -z "${line//[[:space:]]/}" ]] && continue

    # Skip comments.
    [[ "$line" == \#* ]] && continue

    # Header.
    if [[ "$line" == description$'\t'* ]]; then
        header_seen=1
        continue
    fi

    (( header_seen )) || continue

    # Parse strictly as TSV. awk is used here because Bash read treats IFS
    # whitespace delimiters differently and can collapse empty fields.
    field_count="$(awk -F '\t' '{ print NF }' <<< "$line")"
    (( field_count >= 6 )) ||
        die "malformed manifest row: $line"

    description="$(awk -F '\t' '{ print $1 }' <<< "$line")"
    role="$(awk -F '\t' '{ print $2 }' <<< "$line")"
    member="$(awk -F '\t' '{ print $3 }' <<< "$line")"
    sha256="$(awk -F '\t' '{ print $4 }' <<< "$line")"
    condition="$(awk -F '\t' '{ print $5 }' <<< "$line")"
    copyright="$(awk -F '\t' '{ print $6 }' <<< "$line")"

    [[ -n "$description" ]] ||
        die "malformed manifest row: missing description"

    [[ -n "$member" ]] ||
        die "$description: no upstream member"

    [[ -n "$sha256" ]] ||
        die "$description: no sha256 in manifest"

    [[ -n "$copyright" ]] ||
        die "$description: no copyright notice"

    case "$role" in
        cmyk|rgb)
            ;;
        *)
            die "$description: unknown role '$role'"
            ;;
    esac

    descriptions+=("$description")
    roles+=("$role")
    members+=("$member")
    hashes+=("${sha256,,}")
    conditions+=("$condition")
    copyrights+=("$copyright")

done < "$MANIFEST"

(( header_seen )) ||
    die "manifest $MANIFEST has no header row"

((${#descriptions[@]} > 0)) ||
    die "manifest contains no profiles"

# ---------------------------------------------------------------------------
# Notice gate
# ---------------------------------------------------------------------------

NOTICE_BODY="$(cat "$NOTICES")"

cmyk_count=0
rgb_count=0

declare -A seen_descriptions=()

for i in "${!descriptions[@]}"; do
    description="${descriptions[$i]}"
    role="${roles[$i]}"
    member="${members[$i]}"

    # Duplicate description strings are forbidden because the engine resolves
    # profiles by description.
    if [[ -n "${seen_descriptions[$description]+x}" ]]; then
        die "$description: two rows claim one description string"
    fi
    seen_descriptions["$description"]=1

    # Every shipped description must occur in the third-party notice inventory.
    if ! grep -Fq -- "$description" "$NOTICES"; then
        die "$description: ships with no row in THIRD-PARTY-LICENSES.md"
    fi

    case "$role" in
        cmyk) ((++cmyk_count)) ;;
        rgb)  ((++rgb_count)) ;;
    esac
done

(( cmyk_count > 0 )) ||
    die "no CMYK profile in the manifest: destination-profile default has no source"

# ---------------------------------------------------------------------------
# Resolve committed source files.
#
# The PowerShell version takes the basename of the upstream member path.
# ---------------------------------------------------------------------------

declare -a source_paths=()

for i in "${!members[@]}"; do
    member="${members[$i]}"
    leaf="$(basename "$member")"
    src="$SOURCE_DIR/$leaf"

    [[ -f "$src" ]] ||
        die "${descriptions[$i]}: committed profile missing: $src"

    source_paths+=("$src")
done

# ---------------------------------------------------------------------------
# Stage everything first.
# ---------------------------------------------------------------------------

STAGING="${DEST_DIR}.staging"

rm -rf -- "$STAGING"
mkdir -p -- "$STAGING"

cleanup() {
    rm -rf -- "$STAGING"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Verify and copy profiles.
# ---------------------------------------------------------------------------

for i in "${!descriptions[@]}"; do
    src="${source_paths[$i]}"
    expected="${hashes[$i]}"
    leaf="$(basename "${members[$i]}")"

    actual="$(sha256sum "$src" | awk '{print tolower($1)}')"

    [[ "$actual" == "$expected" ]] ||
        die "${members[$i]}: sha256 $actual does not match pinned $expected"

    cp -- "$src" "$STAGING/$leaf"
done

# The licence is part of the shipped ICC resource tree.
cp -- "$LICENSE_TEXT" "$STAGING/$LICENSE_NAME"

# ---------------------------------------------------------------------------
# Re-verify the files actually written to staging.
# ---------------------------------------------------------------------------

for i in "${!descriptions[@]}"; do
    leaf="$(basename "${members[$i]}")"
    expected="${hashes[$i]}"
    target="$STAGING/$leaf"

    actual="$(sha256sum "$target" | awk '{print tolower($1)}')"

    [[ "$actual" == "$expected" ]] ||
        die "$leaf: written bytes do not match pinned $expected"
done

# ---------------------------------------------------------------------------
# Atomically-ish replace the destination tree.
#
# We deliberately remove the old resources/icc only after the complete
# staging tree has been verified.
# ---------------------------------------------------------------------------

rm -rf -- "$DEST_DIR"
mv -- "$STAGING" "$DEST_DIR"

trap - EXIT

size_bytes="$(
    find "$DEST_DIR" -type f -printf '%s\n' |
    awk '{sum += $1} END {print sum+0}'
)"

size_mb="$(awk -v bytes="$size_bytes" 'BEGIN {printf "%.1f", bytes / 1048576}')"

echo "Done. $cmyk_count CMYK + $rgb_count RGB profiles, ${size_mb}MB in $DEST_DIR"
echo "Licence: $DEST_DIR/$LICENSE_NAME"
