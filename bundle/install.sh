#!/usr/bin/env bash
# Install Jolly Roger Office for this user (no root): menu entries, file associations and icons
# under ~/.local/share, and `jolly-roger-office` in ~/.local/bin. The suite runs from where this
# bundle is, unless --copy puts it in ~/.local/opt/jolly-roger-office first.
#
#   ./install.sh                 register this folder
#   ./install.sh --copy          copy the bundle to ~/.local/opt/jolly-roger-office, register that
#   ./install.sh --set-default   also make the suite the default for its file types (xdg-mime)
#   ./install.sh --uninstall     remove the menu entries, icons, MIME package and ~/.local/bin link

set -euo pipefail

SUITE=jolly-roger-office
APP_ID=tech.hillyard.JollyRogerOffice
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="$HOME/.local/bin"
OPT="$HOME/.local/opt/$SUITE"

copy=0 set_default=0 uninstall=0
for a in "$@"; do
  case "$a" in
    --copy) copy=1 ;;
    --set-default) set_default=1 ;;
    --uninstall) uninstall=1 ;;
    -h | --help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option $a" >&2; exit 2 ;;
  esac
done

refresh() {
  command -v update-desktop-database >/dev/null && update-desktop-database -q "$DATA/applications" || true
  command -v update-mime-database >/dev/null && update-mime-database "$DATA/mime" >/dev/null 2>&1 || true
  command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$DATA/icons/hicolor" 2>/dev/null || true
}

if ((uninstall)); then
  rm -f "$DATA/applications/$APP_ID".*desktop "$DATA/applications/$APP_ID.desktop"
  rm -f "$DATA/mime/packages/$APP_ID.xml"
  find "$DATA/icons/hicolor" -name "$APP_ID*" -delete 2>/dev/null || true
  [[ -L "$BIN_DIR/$SUITE" ]] && rm -f "$BIN_DIR/$SUITE"
  refresh
  echo "Removed the menu entries, icons and file associations. The suite's files are where they were."
  exit 0
fi

dir="$HERE"
if ((copy)); then
  mkdir -p "$OPT"
  cp -R "$HERE/." "$OPT/"
  dir="$OPT"
fi
launcher="$dir/$SUITE"
[[ -x "$launcher" ]] || { echo "no $launcher" >&2; exit 1; }

"$launcher" --desktop-files "$DATA" --launcher "$launcher"
mkdir -p "$DATA/icons"
cp -R "$dir/share/icons/hicolor" "$DATA/icons/"
mkdir -p "$BIN_DIR"
ln -sfn "$launcher" "$BIN_DIR/$SUITE"
refresh

if ((set_default)); then
  mimes="$(grep -h '^MimeType=' "$DATA/applications/$APP_ID".*.desktop | cut -d= -f2 | tr ';' '\n' | sort -u)"
  for app_file in "$DATA/applications/$APP_ID".*.desktop; do
    name="$(basename "$app_file")"
    for m in $(grep '^MimeType=' "$app_file" | cut -d= -f2 | tr ';' ' '); do
      xdg-mime default "$name" "$m"
    done
  done
  echo "Set as the default for: $(echo "$mimes" | tr '\n' ' ')"
fi
echo "Installed Jolly Roger Office from $dir. Find it in your menu, or run $SUITE."
