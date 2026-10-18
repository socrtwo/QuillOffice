#!/usr/bin/env bash
# Builds the Linux bundles for one architecture:
#   QuillOffice-<version>-linux-<arch>.sh          self-extracting installer: installs the apps' .deb packages
#   QuillOffice-<version>-linux-<arch>-AppImages.tar.gz   the apps' AppImages for other distributions
#   installers/linux/build.sh <x64|arm64|armv7l> <payload dir> <out dir>
set -euo pipefail
ARCH="$1"; PAYLOAD="$(cd "$2" && pwd)"; OUT="$(mkdir -p "$3" && cd "$3" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(node -p "require('$HERE/../../package.json').version")"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/debs" "$WORK/appimages"

node -e "
  const p = require('$PAYLOAD/payload.json');
  for (const x of p) { if (x.key === 'linux-deb-$ARCH') console.log('deb\t' + x.file + '\t' + x.app + '\t' + x.version); if (x.key === 'linux-appimage-$ARCH') console.log('appimage\t' + x.file + '\t' + x.app + '\t' + x.version); }
" > "$WORK/list.tsv"
apps=""
while IFS=$'\t' read -r kind file app ver; do
  case "$kind" in
    deb) cp "$PAYLOAD/$file" "$WORK/debs/"; apps+="$app $ver"$'\n' ;;
    appimage) cp "$PAYLOAD/$file" "$WORK/appimages/" ;;
  esac
done < "$WORK/list.tsv"

if ls "$WORK/debs"/*.deb >/dev/null 2>&1; then
  printf '%s' "$apps" > "$WORK/debs/APPS.txt"
  tar -C "$WORK/debs" -czf "$WORK/payload.tar.gz" .
  SH="$OUT/QuillOffice-$VERSION-linux-$ARCH.sh"
  { sed -e "s/@VERSION@/$VERSION/g" -e "s/@ARCH@/$ARCH/g" "$HERE/install-header.sh"; cat "$WORK/payload.tar.gz"; } > "$SH"
  chmod +x "$SH"
  ls -la "$SH"
else
  echo "No .deb packages for $ARCH"
fi

if ls "$WORK/appimages"/*.AppImage >/dev/null 2>&1; then
  chmod +x "$WORK/appimages"/*.AppImage
  tar -C "$WORK/appimages" -czf "$OUT/QuillOffice-$VERSION-linux-$ARCH-AppImages.tar.gz" .
  ls -la "$OUT/QuillOffice-$VERSION-linux-$ARCH-AppImages.tar.gz"
fi
