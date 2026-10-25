#!/usr/bin/env bash
# Builds QuillOffice-<version>-mac.pkg: a macOS installer package with one selectable choice per app.
# Each app's .app bundle is taken from its release (.zip or .dmg) and installed into /Applications.
#   installers/macos/build-pkg.sh <payload dir> <out dir>      (runs on macOS: pkgbuild, productbuild, hdiutil)
set -euo pipefail
PAYLOAD="$(cd "$1" && pwd)"; OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(node -p "require('$HERE/../../package.json').version")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/pkgs" "$WORK/apps"

choices=""; outline=""; refs=""
while IFS=$'\t' read -r app file ver id summary; do
  src="$PAYLOAD/$file"
  dest="$WORK/apps/$app"; mkdir -p "$dest"
  case "$file" in
    *.zip) ditto -x -k "$src" "$dest" ;;
    *.dmg)
      mnt="$(hdiutil attach -nobrowse -readonly "$src" | awk -F'\t' '/\/Volumes\//{print $NF}')"
      ditto "$(find "$mnt" -maxdepth 1 -name '*.app' | head -n 1)" "$dest/$(basename "$(find "$mnt" -maxdepth 1 -name '*.app' | head -n 1)")"
      hdiutil detach "$mnt" -quiet ;;
    *) echo "Unknown payload type: $file"; exit 1 ;;
  esac
  appdir="$(find "$dest" -maxdepth 1 -name '*.app' | head -n 1)"
  [ -d "$appdir" ] || { echo "No .app found in $file"; exit 1; }
  pkgbuild --component "$appdir" --install-location /Applications --identifier "$id" --version "$ver" "$WORK/pkgs/$app.pkg"
  choices+="<choice id=\"$app\" title=\"$app $ver\" description=\"$summary\" visible=\"true\" start_selected=\"true\"><pkg-ref id=\"$id\"/></choice>"
  outline+="<line choice=\"$app\"/>"
  refs+="<pkg-ref id=\"$id\" version=\"$ver\" onConclusion=\"none\">$app.pkg</pkg-ref>"
done < <(node -e "
  const p = require('$PAYLOAD/payload.json');
  const m = require('$PAYLOAD/../manifest.json').apps;
  for (const x of p) if (x.key === 'mac') console.log([x.app, x.file, x.version, m[x.app].id, m[x.app].summary].join('\t'));
")
[ -n "$outline" ] || { echo "No macOS apps in $PAYLOAD"; exit 1; }

cat > "$WORK/distribution.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Anne's Office $VERSION</title>
  <welcome file="welcome.html"/>
  <options customize="always" require-scripts="false" hostArchitectures="arm64,x86_64"/>
  <domains enable_localSystem="true" enable_anywhere="false" enable_currentUserHome="false"/>
  <choices-outline>$outline</choices-outline>
  $choices
  $refs
</installer-gui-script>
EOF
mkdir -p "$WORK/res"
cat > "$WORK/res/welcome.html" <<'EOF'
<html><body style="font-family:-apple-system,sans-serif;font-size:13px">
<p>Anne's Office installs the Anne's Office suite into Applications: Anne's Pen (documents), Anne's Grid (spreadsheets), Anne's Post (email) and Anne's Stage (presentations). Untick any app you do not want on the next screen.</p>
<p>The apps are open source (MIT License). They are not notarized, so the first time you open each one, right-click it and choose Open, or allow it in System Settings &gt; Privacy &amp; Security.</p>
<p>Anne's Post's macOS build is for Apple silicon only; on an Intel Mac it is left out automatically by the installer, and its portable (Java) edition is available from its releases page.</p>
</body></html>
EOF
productbuild --distribution "$WORK/distribution.xml" --resources "$WORK/res" --package-path "$WORK/pkgs" --version "$VERSION" "$OUT/QuillOffice-$VERSION-mac.pkg"
ls -la "$OUT"
