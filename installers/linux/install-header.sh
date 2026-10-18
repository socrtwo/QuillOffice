#!/bin/sh
# QuillOffice @VERSION@ (@ARCH@): installs the Quill suite on Debian, Ubuntu, Raspberry Pi OS and other
# Debian-based systems. A gzip tar archive of the apps' .deb packages follows this script.
#   sh QuillOffice-@VERSION@-linux-@ARCH@.sh [--apps pen,grid,post,stage] [--list] [--extract DIR]
# Other distributions: use the AppImages archive from the same release.
set -eu
APPS="pen,grid,post,stage"
EXTRACT=""
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apps) APPS="$2"; shift 2 ;;
    --apps=*) APPS="${1#*=}"; shift ;;
    --list) LIST=1; shift ;;
    --extract) EXTRACT="$2"; shift 2 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "Unknown option $1"; exit 2 ;;
  esac
done
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LINE=$(awk '/^__PAYLOAD_BELOW__$/ { print NR + 1; exit 0; }' "$0")
tail -n +"$LINE" "$0" | tar -xzf - -C "$WORK"
if [ "$LIST" = 1 ]; then echo "QuillOffice @VERSION@ (@ARCH@) contains:"; cat "$WORK/APPS.txt"; exit 0; fi
if [ -n "$EXTRACT" ]; then mkdir -p "$EXTRACT"; cp "$WORK"/*.deb "$EXTRACT/"; echo "Packages copied to $EXTRACT"; exit 0; fi

want() { case ",$APPS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
PKGS=""
for f in "$WORK"/*.deb; do
  b="$(basename "$f" | tr '[:upper:]' '[:lower:]')"
  case "$b" in
    quillpen*) want pen && PKGS="$PKGS $f" ;;
    quillgrid*) want grid && PKGS="$PKGS $f" ;;
    quillpost*) want post && PKGS="$PKGS $f" ;;
    quillstage*) want stage && PKGS="$PKGS $f" ;;
  esac
done
if [ -z "$PKGS" ]; then echo "Nothing selected. Apps in this bundle:"; cat "$WORK/APPS.txt"; exit 1; fi
echo "QuillOffice @VERSION@ will install:"; for p in $PKGS; do echo "  $(basename "$p")"; done
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
# shellcheck disable=SC2086
if command -v apt-get >/dev/null 2>&1; then
  $SUDO apt-get install -y $PKGS
elif command -v dpkg >/dev/null 2>&1; then
  $SUDO dpkg -i $PKGS || $SUDO apt-get -f install -y
else
  echo "This system has no dpkg. Use the AppImages archive from the QuillOffice release instead."; exit 1
fi
echo "Done. The apps are in your applications menu (Office)."
exit 0
__PAYLOAD_BELOW__
