#!/usr/bin/env bash
set -euo pipefail

# Vendors the Edit-tool fallback font FAMILY
# into resources/fonts - the same repo-hygiene class as resources/python and
# resources/tesseract: assembled by script, gitignored, SHIPPED in the
# product bundle (tauri.conf.json resources maps ../resources/fonts -> fonts).
#
# This is the Bash/Linux counterpart of sync-edit-fonts.ps1. The source URLs,
# archive hashes, individual face hashes, and licence hashes are deliberately
# identical to the PowerShell implementation.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$PROJECT_ROOT/resources/fonts"

VERSION='2.1.5'
URL="https://github.com/liberationfonts/liberation-fonts/files/7261482/liberation-fonts-ttf-$VERSION.tar.gz"
SHA256='7191c669bf38899f73a2094ed00f7b800553364f90e2637010a69c0e268f25d0'

LIB_VERSION='7.051'
LIB_URL="https://github.com/alerque/libertinus/releases/download/v$LIB_VERSION/Libertinus-$LIB_VERSION.zip"
LIB_SHA256='4d9be29b5cb380c35af8ba967abcc752ad1e07be1f738a9789c33e0dd7478c92'

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/spectrapdf-fonts.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: $1 is required to sync Edit-tool fonts." >&2
        exit 1
    }
}

require_command curl
require_command sha256sum
require_command tar
require_command unzip

mkdir -p "$DEST"

verify_file() {
    local path="$1"
    local expected="$2"
    local actual

    actual="$(sha256sum "$path" | awk '{print $1}')"
    actual="${actual,,}"
    if [[ "$actual" != "$expected" ]]; then
        echo "ERROR: sha256 mismatch for $path" >&2
        echo "  expected $expected" >&2
        echo "  actual   $actual" >&2
        rm -f "$path"
        exit 1
    fi
}

download() {
    local url="$1"
    local out="$2"
    echo "Downloading $url..."
    curl --fail --location --silent --show-error \
        --output "$out" "$url"
}

# Name + SHA256 pairs for every file that must exist before the script can
# declare the font directory complete.
declare -A FACES=(
    [LiberationSans-Regular.ttf]=76d04c18ea243f426b7de1f3ad208e927008f961dc5945e5aad352d0dfde8ee8
    [LiberationSans-Bold.ttf]=788abee4c806d660e8aee46689dd8540cd4bb98da03dcc9d171ce3efd99a9173
    [LiberationSans-Italic.ttf]=e5bae5c4cde31f22142753855f4f8fb86da6ff39955ed3c0a11248b0d16948b0
    [LiberationSans-BoldItalic.ttf]=698da70fc191cc5f33ad4d6d3fe830fe4624b898ea2e3169955928b7c491f1ee
    [LiberationSerif-Regular.ttf]=058ea80864aef09a23f45cbec2bb5400bc3dfbdea01c3f10538a21fcb497fb74
    [LiberationSerif-Bold.ttf]=d754ba427cfe0bca54ae052384baa8f842da5bd6550ad4da024ac441e7a7d5ce
    [LiberationSerif-Italic.ttf]=0e3dea9f8d613e006ccfa62201f33e265d19167bd0907725c3e145368b04fc2e
    [LiberationSerif-BoldItalic.ttf]=f17db8af71e24d2066b587546021d4f0b296be389512b658dec3c09affeb11a7
    [LiberationMono-Regular.ttf]=f2b83c763e8afd21709333370bed4774337fae82267937e2b5aea7e2fbd922c1
    [LiberationMono-Bold.ttf]=bd62a0672d0b9b6710b01df434c80ad54fa5f0835207eb7b17b7a761463067bb
    [LiberationMono-Italic.ttf]=605c01c711b44480a7508d349dfbf3264e81fa43d69e61cfa7d10b86e764c4d1
    [LiberationMono-BoldItalic.ttf]=79451f3c09fe25116098853b7a2ca6e2436220ccc11af022979adbcf195be130
    [LibertinusSerif-Regular.otf]=fcf06307a77367394fcb0ccb241e59eea70dba3d732be309647611224679c733
    [LibertinusSerif-Bold.otf]=0264914210ed51b3231ebc92ce529e9f2e166ba9eebf0cd4a579558690a27b64
    [LibertinusSerif-Italic.otf]=9a393d63d6e05f620d3dc0190dfd35a8ede58c0808cf0fc9de7fcb9c723e4c24
    [LibertinusSerif-BoldItalic.otf]=47a665259f09f554f5d133d7718cdad43ff462c6a6b2328f38023465e62d57ce
    [NotoSansCJKsc-Regular.otf]=2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b
    [NotoSansCJKsc-Bold.otf]=b5f0d1a190a7f9b43c310a8850630af12553df32c4c050543f9059732d9b4c0a
    [IBMPlexSansArabic-Regular.ttf]=8e0f1046c736bf939d4939ee3ae0116acf61cbcd6592deae7656761627080981
    [IBMPlexSansArabic-Bold.ttf]=b74f809dead12442ed56e02a12c3bcc02076c9ad4e32f17d0a9ca6fc1aafc89e
    [NotoSansHebrew-Regular.ttf]=04272f5600d0ec816d31d0df73b23aa8d3501ea359ebe820da31c11ffcf00853
    [NotoSansHebrew-Bold.ttf]=dfdb3056de1f4542b888c77a1a8a750548a802e271479f56e52152423b64dde8
    [NotoSansMongolian-Regular.ttf]=e458bbdef2ac9579315293070b8f72abc290a42a0279a99b50a9829a7ccd8245
    [LICENSE-Liberation-OFL.txt]=93fed46019c38bbe566b479d22148e2e8a1e85ada614accb0211c37b2c61c19b
    [LICENSE-Libertinus-OFL.txt]=9aeecc8107c489ec1ec0068b0313e531a760edf3493705b32ab8ab8215a8794e
    [LICENSE-NotoCJK.txt]=6a73f9541c2de74158c0e7cf6b0a58ef774f5a780bf191f2d7ec9cc53efe2bf2
    [LICENSE-IBMPlexArabic-OFL.txt]=7e6b2818edbd8f6a01ae80641cc8f16a51080d08fb4e532be3a0b6f74adb07da
    [LICENSE-NotoHebrew-OFL.txt]=9b9fe028b5ba74d231659a1bbaf0ed09b11e759d1ca6a070999e16d151616b47
    [LICENSE-NotoMongolian-OFL.txt]=b0158b3c0b16c20e22ea662850503a7980111c5c704501e942cc1a7ed12dc011
)

all_present=true
for name in "${!FACES[@]}"; do
    path="$DEST/$name"
    if [[ ! -f "$path" ]]; then
        all_present=false
        break
    fi
    if [[ "$(sha256sum "$path" | awk '{print $1}')" != "${FACES[$name]}" ]]; then
        all_present=false
        break
    fi
done

if "$all_present"; then
    echo "All faces and licence files present and verified in $DEST"
    exit 0
fi

# --- Liberation Fonts ---
TMP="$TMP_ROOT/liberation-fonts-$VERSION.tar.gz"
EXTRACT="$TMP_ROOT/liberation"

download "$URL" "$TMP"
verify_file "$TMP" "$SHA256"
mkdir -p "$EXTRACT"
tar -xzf "$TMP" -C "$EXTRACT"

for name in \
    LiberationSans-Regular.ttf \
    LiberationSans-Bold.ttf \
    LiberationSans-Italic.ttf \
    LiberationSans-BoldItalic.ttf \
    LiberationSerif-Regular.ttf \
    LiberationSerif-Bold.ttf \
    LiberationSerif-Italic.ttf \
    LiberationSerif-BoldItalic.ttf \
    LiberationMono-Regular.ttf \
    LiberationMono-Bold.ttf \
    LiberationMono-Italic.ttf \
    LiberationMono-BoldItalic.ttf
do
    source="$(find "$EXTRACT" -type f -name "$name" -print -quit)"
    [[ -n "$source" ]] || {
        echo "ERROR: $name not found in Liberation archive" >&2
        exit 1
    }
    cp "$source" "$DEST/$name"
    verify_file "$DEST/$name" "${FACES[$name]}"
    echo "Vendored: $DEST/$name"
done

source="$(find "$EXTRACT" -type f -name LICENSE -print -quit)"
[[ -n "$source" ]] || {
    echo "ERROR: LICENSE not found in Liberation archive" >&2
    exit 1
}
cp "$source" "$DEST/LICENSE-Liberation-OFL.txt"
verify_file "$DEST/LICENSE-Liberation-OFL.txt" "${FACES[LICENSE-Liberation-OFL.txt]}"
echo "Vendored: $DEST/LICENSE-Liberation-OFL.txt"

# --- Libertinus Serif OTF ---
TMP="$TMP_ROOT/libertinus-$LIB_VERSION.zip"
EXTRACT="$TMP_ROOT/libertinus"

download "$LIB_URL" "$TMP"
verify_file "$TMP" "$LIB_SHA256"
mkdir -p "$EXTRACT"
unzip -q "$TMP" -d "$EXTRACT"

for name in \
    LibertinusSerif-Regular.otf \
    LibertinusSerif-Bold.otf \
    LibertinusSerif-Italic.otf \
    LibertinusSerif-BoldItalic.otf
do
    source="$(find "$EXTRACT" -type f -name "$name" -print -quit)"
    [[ -n "$source" ]] || {
        echo "ERROR: $name not found in Libertinus archive" >&2
        exit 1
    }
    cp "$source" "$DEST/$name"
    verify_file "$DEST/$name" "${FACES[$name]}"
    echo "Vendored: $DEST/$name"
done

source="$(find "$EXTRACT" -type f -name OFL.txt -print -quit)"
[[ -n "$source" ]] || {
    echo "ERROR: OFL.txt not found in Libertinus archive" >&2
    exit 1
}
cp "$source" "$DEST/LICENSE-Libertinus-OFL.txt"
verify_file "$DEST/LICENSE-Libertinus-OFL.txt" "${FACES[LICENSE-Libertinus-OFL.txt]}"
echo "Vendored: $DEST/LICENSE-Libertinus-OFL.txt"

# --- Noto Sans CJK SC ---
NOTO_BASE='https://github.com/notofonts/noto-cjk/raw/Sans2.004/Sans/OTF/SimplifiedChinese'

for name in NotoSansCJKsc-Regular.otf NotoSansCJKsc-Bold.otf; do
    download "$NOTO_BASE/$name" "$DEST/$name"
    verify_file "$DEST/$name" "${FACES[$name]}"
    echo "Vendored: $DEST/$name"
done

download \
    'https://github.com/notofonts/noto-cjk/raw/Sans2.004/LICENSE' \
    "$DEST/LICENSE-NotoCJK.txt"
verify_file "$DEST/LICENSE-NotoCJK.txt" "${FACES[LICENSE-NotoCJK.txt]}"
echo "Vendored: $DEST/LICENSE-NotoCJK.txt"

# --- Right-to-left faces ---
#
# These archives are intentionally read only for the exact files requested;
# they contain many other weights/widths that are not shipped.
sync_zip_member() {
    local url="$1"
    local archive_sha="$2"
    local member="$3"
    local output="$4"
    local expected="$5"
    local tmp="$TMP_ROOT/$(basename "$output").zip"

    download "$url" "$tmp"
    verify_file "$tmp" "$archive_sha"

    unzip -p "$tmp" "$member" > "$DEST/$output"
    verify_file "$DEST/$output" "$expected"
    echo "Vendored: $DEST/$output"
}

IBM_URL='https://github.com/IBM/plex/releases/download/%40ibm%2Fplex-sans-arabic%401.1.0/ibm-plex-sans-arabic.zip'
IBM_SHA256='f03915581aea37d82792c188b08064023a73494d679b8e19f85f5971db714013'

sync_zip_member "$IBM_URL" "$IBM_SHA256" \
    'ibm-plex-sans-arabic/fonts/complete/ttf/IBMPlexSansArabic-Regular.ttf' \
    'IBMPlexSansArabic-Regular.ttf' \
    "${FACES[IBMPlexSansArabic-Regular.ttf]}"

sync_zip_member "$IBM_URL" "$IBM_SHA256" \
    'ibm-plex-sans-arabic/fonts/complete/ttf/IBMPlexSansArabic-Bold.ttf' \
    'IBMPlexSansArabic-Bold.ttf' \
    "${FACES[IBMPlexSansArabic-Bold.ttf]}"

sync_zip_member "$IBM_URL" "$IBM_SHA256" \
    'ibm-plex-sans-arabic/LICENSE.txt' \
    'LICENSE-IBMPlexArabic-OFL.txt' \
    "${FACES[LICENSE-IBMPlexArabic-OFL.txt]}"

HEBREW_URL='https://github.com/notofonts/hebrew/releases/download/NotoSansHebrew-v3.001/NotoSansHebrew-v3.001.zip'
HEBREW_SHA256='df0a71814b4e63644cf40fcc4529111b61266b7a2dafbe95068b29a7520cc3cb'

sync_zip_member "$HEBREW_URL" "$HEBREW_SHA256" \
    'NotoSansHebrew/unhinted/ttf/NotoSansHebrew-Regular.ttf' \
    'NotoSansHebrew-Regular.ttf' \
    "${FACES[NotoSansHebrew-Regular.ttf]}"

sync_zip_member "$HEBREW_URL" "$HEBREW_SHA256" \
    'NotoSansHebrew/unhinted/ttf/NotoSansHebrew-Bold.ttf' \
    'NotoSansHebrew-Bold.ttf' \
    "${FACES[NotoSansHebrew-Bold.ttf]}"

sync_zip_member "$HEBREW_URL" "$HEBREW_SHA256" \
    'OFL.txt' \
    'LICENSE-NotoHebrew-OFL.txt' \
    "${FACES[LICENSE-NotoHebrew-OFL.txt]}"

MONGOLIAN_URL='https://github.com/notofonts/mongolian/releases/download/NotoSansMongolian-v3.002/NotoSansMongolian-v3.002.zip'
MONGOLIAN_SHA256='a5d3085d4040ecd92d44bf5c4f8faaeae7ba3147cf82e09aa2ef5ad46475de6c'

sync_zip_member "$MONGOLIAN_URL" "$MONGOLIAN_SHA256" \
    'NotoSansMongolian/full/ttf/NotoSansMongolian-Regular.ttf' \
    'NotoSansMongolian-Regular.ttf' \
    "${FACES[NotoSansMongolian-Regular.ttf]}"

sync_zip_member "$MONGOLIAN_URL" "$MONGOLIAN_SHA256" \
    'OFL.txt' \
    'LICENSE-NotoMongolian-OFL.txt' \
    "${FACES[LICENSE-NotoMongolian-OFL.txt]}"

echo "All Edit-tool fonts synced and verified in $DEST"
