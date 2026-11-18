#!/usr/bin/env bash
# Build the Windows installer for Jolly Roger Office on Linux: cross-compile the launcher and
# the three apps (x86_64-pc-windows-gnu, MinGW), stage them, and pack one NSIS Setup.exe.
#
#   bundle/build-windows.sh          uses the sources build.sh exported to bundle/.src/
#                                    (run build.sh first, or FROM=... as there)
#
# Output: bundle/out/JollyRogerOffice-Setup-<version>.exe
# Needs: rustup target x86_64-pc-windows-gnu, mingw-w64 (posix threads), makensis, python3 + Pillow.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
SRC="$HERE/.src"
TGT="$HERE/.wintarget"
STAGE="$HERE/.winstage"
OUT="${OUT:-$HERE/out}"
TRIPLE=x86_64-pc-windows-gnu
JOBS="${CARGO_BUILD_JOBS:-10}"

if [[ -z "${CARGO_HOME:-}" && -d "$HOME/.cache/hillyard-rewrite/cargo" ]]; then
  export CARGO_HOME="$HOME/.cache/hillyard-rewrite/cargo" RUSTUP_HOME="$HOME/.cache/hillyard-rewrite/rustup"
  export PATH="$CARGO_HOME/bin:$PATH"
fi
export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc-posix
if [[ -z "${CRAFT_FONTS_DIR:-}" ]]; then
  for d in "$HOME"/.cache/hillyard-rewrite/craft-fonts-*/; do
    [[ -f "$d/fonts/manifest.txt" ]] && export CRAFT_FONTS_DIR="${d%/}" && break
  done
fi

log() { printf '\033[1m==>\033[0m %s\n' "$*" >&2; }
die() { printf 'build-windows: %s\n' "$*" >&2; exit 1; }

[[ -d "$SRC/craft-launcher" ]] || die "no $SRC; run bundle/build.sh first"
rustup target list --installed | grep -qx "$TRIPLE" || rustup target add "$TRIPLE"

# repo:bin:installed-name
TARGETS=(
  "craft-launcher:jolly-roger-office:jolly-roger-office"
  "wordcraft:wordcraft:apps/captains-log"
  "gridcraft:plunder-ledger:apps/plunder-ledger"
  "deckcraft:broadside:apps/broadside"
)

for t in "${TARGETS[@]}"; do
  IFS=: read -r repo bin _ <<<"$t"
  log "building $repo ($bin.exe)"
  (cd "$SRC/$repo" && cargo build --release -j "$JOBS" --target "$TRIPLE" --target-dir "$TGT/$repo" --bin "$bin")
done

rm -rf "$STAGE"; mkdir -p "$STAGE/apps" "$STAGE/icons" "$STAGE/licenses"
for t in "${TARGETS[@]}"; do
  IFS=: read -r repo bin dest <<<"$t"
  install -m 0755 "$TGT/$repo/$TRIPLE/release/$bin.exe" "$STAGE/$dest.exe"
done

# MinGW runtime DLLs the binaries import (normally none: libgcc/winpthread link statically).
SYSROOT_DLLS="$(dirname "$(x86_64-w64-mingw32-gcc-posix -print-libgcc-file-name)")"
for exe in "$STAGE"/*.exe "$STAGE"/apps/*.exe; do
  for dll in $(x86_64-w64-mingw32-objdump -p "$exe" | awk '/DLL Name:/ {print $3}' | grep -iE '^(libgcc|libwinpthread|libstdc)' || true); do
    found="$(find /usr/lib/gcc/x86_64-w64-mingw32 /usr/x86_64-w64-mingw32 "$SYSROOT_DLLS" -name "$dll" 2>/dev/null | head -1)"
    [[ -n "$found" ]] || die "$exe needs $dll, which wasn't found"
    cp -n "$found" "$(dirname "$exe")/"
  done
done

# Icons: the launcher's from its own drawing; the apps' from their repos.
LINUX_LAUNCHER="$(ls "$OUT"/jolly-roger-office-*-linux-*/jolly-roger-office 2>/dev/null | head -1 || true)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
if [[ -x "$LINUX_LAUNCHER" ]]; then
  "$LINUX_LAUNCHER" --export-icons "$tmp" >/dev/null
  python3 - "$tmp" "$STAGE/icons/jolly-roger-office.ico" <<'EOF'
import sys, glob
from PIL import Image
png = glob.glob(f"{sys.argv[1]}/**/256x256/apps/tech.hillyard.JollyRogerOffice.png", recursive=True)[0]
Image.open(png).convert("RGBA").save(sys.argv[2], sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
EOF
else
  cp "$HERE/win/icons/jolly-roger-office.ico" "$STAGE/icons/"
fi
cp "$SRC/wordcraft/assets/app-icon/wordcraft.ico" "$STAGE/icons/captains-log.ico"
cp "$SRC/gridcraft/assets/app-icon/plunder-ledger.ico" "$STAGE/icons/plunder-ledger.ico"
cp "$SRC/deckcraft/assets/app-icon/broadside.ico" "$STAGE/icons/broadside.ico"

# Licences and notices (MIT OR Apache-2.0 upstream; keep every notice).
for pair in craft-launcher:jolly-roger-office wordcraft:captains-log gridcraft:plunder-ledger deckcraft:broadside; do
  IFS=: read -r repo name <<<"$pair"
  mkdir -p "$STAGE/licenses/$name"
  for f in LICENSE-MIT LICENSE-APACHE NOTICE ATTRIBUTION.md; do
    [[ -f "$SRC/$repo/$f" ]] && cp "$SRC/$repo/$f" "$STAGE/licenses/$name/"
  done
  [[ -d "$SRC/$repo/licenses" ]] && cp -r "$SRC/$repo/licenses/." "$STAGE/licenses/$name/"
done
{
  echo "Jolly Roger Office is licensed under the MIT License or the Apache License 2.0, at your option."
  echo "It is based on the ArtCraft Crafting Apps (WordCraft, GridCraft, DeckCraft, Craft Launcher)."
  echo "Full licence texts and notices for every part are in the licenses folder after install."
  echo
  sed 's/$/\r/' "$SRC/craft-launcher/LICENSE-MIT"
} > "$STAGE/LICENSE.txt"
cat > "$STAGE/README.txt" <<'EOF'
Jolly Roger Office
==================
Start "Jolly Roger Office" from the Start menu or desktop to open the start page, or start
Captain's Log (documents), Plunder Ledger (spreadsheets) or Broadside (presentations) directly.

Word, Excel, PowerPoint and OpenDocument files show Jolly Roger Office under "Open with";
your default apps are not changed. Settings live in %APPDATA%. Uninstall from
Settings > Apps, or run Uninstall.exe in this folder.
EOF
sed -i 's/$/\r/' "$STAGE/README.txt"

VERSION="$(grep -m1 '^version' "$SRC/craft-launcher/Cargo.toml" | cut -d'"' -f2 || echo 0.1.0)"
VERSION="${VERSION:-0.1.0}"
mkdir -p "$OUT"
log "packing installer"
makensis -V2 -DSTAGE="$STAGE" -DVERSION="$VERSION" -DOUTFILE="$OUT/JollyRogerOffice-Setup-$VERSION.exe" "$HERE/win/jolly-roger-office.nsi"
log "done: $OUT/JollyRogerOffice-Setup-$VERSION.exe ($(du -h "$OUT/JollyRogerOffice-Setup-$VERSION.exe" | cut -f1))"
