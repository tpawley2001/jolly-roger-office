#!/usr/bin/env bash
# Build Jolly Roger Office for Linux: the launcher plus Captain's Log, Plunder Ledger and
# Broadside, in release mode, laid out in one folder with menu entries, file associations and
# icons, then packed into a tarball.
#
#   bundle/build.sh                  build every repo's committed `pirate` branch
#   FROM=worktree bundle/build.sh    build the repos' working trees as they are (uncommitted work too)
#   REF=<ref> bundle/build.sh        build another committed ref instead of `pirate`
#   APPS="captains-log broadside" bundle/build.sh   build only some apps (others are left out)
#   SKIP_APPS=1 bundle/build.sh      launcher only (quick check of the layout)
#   ALLOW_UPSTREAM=1 bundle/build.sh also bundle an app whose ref is still plain upstream
#
# An app whose ref has no commits of its own beyond upstream (origin/main) is left out by
# default: that is the un-rebranded app, whose self-updater would pull upstream builds.
#
# Output: bundle/out/jolly-roger-office-<version>-linux-<arch>/ and the .tar.gz beside it.
# Nothing is downloaded from ArtCraft: the apps are built from the local forks. (Cargo may still
# fetch crates it doesn't have in CARGO_HOME yet.)
#
# Committed builds export each repo's ref with `git archive` into bundle/.src/<repo> (re-exported
# only when the commit changes, so incremental builds stay incremental); the sibling repos and
# their working trees are never touched. Each repo builds into its own target dir under
# bundle/.target/.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
OUT="${OUT:-$HERE/out}"
FROM="${FROM:-commit}"
REF="${REF:-pirate}"
JOBS="${CARGO_BUILD_JOBS:-8}"
SUITE=jolly-roger-office

# The shared box's toolchain, unless the caller set their own.
if [[ -z "${CARGO_HOME:-}" && -d "$HOME/.cache/hillyard-rewrite/cargo" ]]; then
  export CARGO_HOME="$HOME/.cache/hillyard-rewrite/cargo" RUSTUP_HOME="$HOME/.cache/hillyard-rewrite/rustup"
  export PATH="$CARGO_HOME/bin:$PATH"
fi
export CARGO_BUILD_JOBS="$JOBS"

# This box has the ALSA runtime but not libasound2-dev's alsa.pc; Broadside's audio needs it.
SHIM="$HOME/.cache/hillyard-rewrite/broadside-shim/pkgconfig"
if ! pkg-config --exists alsa 2>/dev/null && [[ -f "$SHIM/alsa.pc" ]]; then
  export PKG_CONFIG_PATH="$SHIM${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
fi
# Bundled fonts (craft-fonts, OFL); without them the apps fall back to system fonts.
if [[ -z "${CRAFT_FONTS_DIR:-}" ]]; then
  for d in "$HOME"/.cache/hillyard-rewrite/craft-fonts-*/; do
    [[ -f "$d/fonts/manifest.txt" ]] && export CRAFT_FONTS_DIR="${d%/}" && break
  done
fi

log() { printf '\033[1m==> %s\033[0m\n' "$*" >&2; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v cargo >/dev/null || die "cargo not found (set CARGO_HOME/PATH)"
command -v python3 >/dev/null || die "python3 is needed to read cargo metadata"

# app id | source repo | package names to look for, the fork's first
APP_TABLE=(
  "captains-log|wordcraft|captains-log captainslog wordcraft"
  "plunder-ledger|gridcraft|plunder-ledger plunderledger gridcraft"
  "broadside|deckcraft|broadside deckcraft"
)
WANT_APPS="${APPS:-captains-log plunder-ledger broadside}"
[[ -n "${SKIP_APPS:-}" ]] && WANT_APPS=""

# The source folder to build `repo` from: its working tree, or an export of $REF.
source_dir() {
  local repo="$1" src="$ROOT/$1"
  [[ -d "$src/.git" || -f "$src/.git" ]] || die "$src is not a git checkout"
  if [[ "$FROM" == worktree ]]; then
    local branch
    branch="$(git -C "$src" rev-parse --abbrev-ref HEAD)"
    [[ "$branch" == "$REF" ]] || warn "$repo's working tree is on '$branch', not '$REF'"
    echo "$src"
    return
  fi
  local ref="$REF"
  if ! git -C "$src" rev-parse --verify -q "$ref^{commit}" >/dev/null; then
    warn "$repo has no '$ref'; using its HEAD"
    ref=HEAD
  fi
  local commit dest="$HERE/.src/$repo"
  commit="$(git -C "$src" rev-parse "$ref^{commit}")"
  if [[ "$(cat "$dest/.bundle-commit" 2>/dev/null)" != "$commit" ]]; then
    log "exporting $repo $ref ($(git -C "$src" log -1 --format='%h %s' "$commit"))"
    rm -rf "$dest"
    mkdir -p "$dest"
    git -C "$src" archive --format=tar "$commit" | tar -x -C "$dest"
    echo "$commit" >"$dest/.bundle-commit"
  else
    log "$repo $ref unchanged since the last export ($(git -C "$src" log -1 --format='%h' "$commit"))"
  fi
  echo "$dest"
}

# "<package> <binary>" of the first package in `candidates` that the workspace at `dir` has, with
# its default-run binary (or the bin named like the package, or its only bin).
find_bin() {
  local dir="$1"; shift
  (cd "$dir" && cargo metadata --no-deps --format-version 1) |
    python3 -c '
import json, sys
meta = json.load(sys.stdin)
want = sys.argv[1:]
pkgs = {p["name"]: p for p in meta["packages"]}
for name in want:
    p = pkgs.get(name)
    if not p:
        continue
    bins = [t["name"] for t in p["targets"] if "bin" in t["kind"]]
    if not bins:
        continue
    pick = p.get("default_run") or (name if name in bins else bins[0])
    print(name, pick)
    sys.exit(0)
sys.exit(1)
' "$@"
}

# Build `pkg` in release mode from `dir` into its own target dir; echo the binary's path.
build() {
  local repo="$1" dir="$2" pkg="$3" bin="$4"
  local target="$HERE/.target/$repo"
  log "building $repo: $pkg (release, -j $JOBS)"
  (cd "$dir" && CARGO_TARGET_DIR="$target" cargo build --release -j "$JOBS" -p "$pkg" --bin "$bin" >&2)
  echo "$target/release/$bin"
}

# --- the launcher -------------------------------------------------------------------------
LAUNCHER_SRC="$(source_dir craft-launcher)"
read -r LPKG LBIN < <(find_bin "$LAUNCHER_SRC" jolly-roger-office) || die "craft-launcher has no jolly-roger-office package at $REF"
LAUNCHER_BIN="$(build craft-launcher "$LAUNCHER_SRC" "$LPKG" "$LBIN")"
VERSION="$("$LAUNCHER_BIN" --version | awk '{print $2}')"
ARCH="$(uname -m)"
NAME="$SUITE-$VERSION-linux-$ARCH"
STAGE="$OUT/$NAME"

log "staging $STAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE/apps" "$STAGE/share" "$STAGE/licenses"
install -m755 "$LAUNCHER_BIN" "$STAGE/$SUITE"
for f in LICENSE-MIT LICENSE-APACHE NOTICE ATTRIBUTION.md; do
  [[ -f "$LAUNCHER_SRC/$f" ]] && install -m644 "$LAUNCHER_SRC/$f" "$STAGE/$f"
done
"$STAGE/$SUITE" --export-icons "$STAGE/share/icons"
# Reference entries that find the launcher on PATH; install.sh writes ones with the real path.
"$STAGE/$SUITE" --desktop-files "$STAGE/share" --launcher "$SUITE"

# --- the apps -----------------------------------------------------------------------------
BUILT=()
MISSING=()
for row in "${APP_TABLE[@]}"; do
  IFS='|' read -r app repo candidates <<<"$row"
  if [[ " $WANT_APPS " != *" $app "* ]]; then
    MISSING+=("$app (not asked for)")
    continue
  fi
  if [[ ! -d "$ROOT/$repo" ]]; then
    warn "$ROOT/$repo is missing; leaving $app out"
    MISSING+=("$app (no $repo checkout)")
    continue
  fi
  if [[ -z "${ALLOW_UPSTREAM:-}" && "$FROM" != worktree ]] \
    && git -C "$ROOT/$repo" rev-parse -q --verify origin/main >/dev/null \
    && git -C "$ROOT/$repo" merge-base --is-ancestor "$REF" origin/main 2>/dev/null; then
    warn "$repo's $REF is still plain upstream (no rebrand yet); leaving $app out (ALLOW_UPSTREAM=1 to include it)"
    MISSING+=("$app (not rebranded yet)")
    continue
  fi
  src="$(source_dir "$repo")"
  # shellcheck disable=SC2086
  if ! read -r pkg bin < <(find_bin "$src" $candidates); then
    warn "$repo has none of the packages: $candidates; leaving $app out"
    MISSING+=("$app (no package)")
    continue
  fi
  if ! binpath="$(build "$repo" "$src" "$pkg" "$bin")"; then
    warn "$repo failed to build; leaving $app out"
    MISSING+=("$app (build failed)")
    continue
  fi
  install -m755 "$binpath" "$STAGE/apps/$app"
  mkdir -p "$STAGE/licenses/$app"
  for f in LICENSE-MIT LICENSE-APACHE NOTICE ATTRIBUTION.md; do
    [[ -f "$src/$f" ]] && install -m644 "$src/$f" "$STAGE/licenses/$app/$f"
  done
  [[ -d "$src/licenses" ]] && cp -R "$src/licenses/." "$STAGE/licenses/$app/"
  BUILT+=("$app ($repo $(cat "$src/.bundle-commit" 2>/dev/null | cut -c1-8 || true) package $pkg)")
done

install -m755 "$HERE/install.sh" "$STAGE/install.sh"
cat >"$STAGE/README.txt" <<EOF
Jolly Roger Office $VERSION for Linux ($ARCH)

  ./$SUITE              the start page
  ./$SUITE FILE...      open files in the right app
  ./install.sh          add the suite to your menu and file associations (per user, no root)
  ./install.sh --uninstall

Apps in this bundle (apps/):
$(for b in "${BUILT[@]}"; do echo "  - $b"; done)
$( ((${#MISSING[@]})) && { echo "Left out:"; for m in "${MISSING[@]}"; do echo "  - $m"; done; })

Based on the ArtCraft Crafting Apps (MIT OR Apache-2.0): Captain's Log, Plunder Ledger and
Broadside are based on WordCraft, GridCraft and DeckCraft by the ArtCraft team. Licences and
notices: LICENSE-MIT, LICENSE-APACHE, NOTICE, ATTRIBUTION.md and licenses/<app>/.
EOF

log "packing $OUT/$NAME.tar.gz"
tar -C "$OUT" -czf "$OUT/$NAME.tar.gz" "$NAME"
log "done: $OUT/$NAME.tar.gz"
log "apps: ${BUILT[*]:-none}"
((${#MISSING[@]})) && warn "left out: ${MISSING[*]}"
"$STAGE/$SUITE" --list || true
