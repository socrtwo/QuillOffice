#!/usr/bin/env bash
# Builds the QuillOffice Windows setup for one architecture with makensis.
#   installers/windows/build.sh <x64|arm64> <payload dir> <out dir>
# The payload directory holds the apps' installers and payload.json from scripts/resolve.mjs.
set -euo pipefail
ARCH="$1"; PAYLOAD="$(cd "$2" && pwd)"; OUT="$(mkdir -p "$3" && cd "$3" && pwd)"
VERSION="$(node -p "require('$(dirname "$0")/../../package.json').version")"
KEY="win-$ARCH"
defs=()
# Maps each app to its NSIS define prefix.
while IFS=$'\t' read -r app file ver; do
  case "$app" in
    QuillPen) p=PEN;; QuillGrid) p=GRID;; QuillPost) p=POST;; QuillStage) p=STAGE;; *) continue;;
  esac
  defs+=("-D${p}_FILE=$file" "-D${p}_VERSION=$ver")
done < <(node -e "
  const p = require('$PAYLOAD/payload.json');
  for (const x of p) if (x.key === '$KEY') console.log([x.app, x.file, x.version].join('\t'));
")
if [ ${#defs[@]} -eq 0 ]; then echo "No Windows $ARCH installers in $PAYLOAD"; exit 1; fi
OUTFILE="$OUT/QuillOffice-$VERSION-windows-$ARCH-setup.exe"
makensis -V2 -DVERSION="$VERSION" -DARCH="$ARCH" -DPAYLOAD="$PAYLOAD" -DOUTFILE="$OUTFILE" "${defs[@]}" "$(dirname "$0")/QuillOffice.nsi"
ls -la "$OUTFILE"
