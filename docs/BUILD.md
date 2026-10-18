# Building QuillOffice bundles

QuillOffice compiles nothing. It downloads each app's released files and wraps them. You need Node.js 22 and, per bundle, the packaging tool of that platform.

```bash
npm test                                # unit tests for the release matcher
npm run check                           # syntax of the scripts and installers
node scripts/resolve.mjs manifest       # manifest.json: the newest release of each app and its files
node scripts/resolve.mjs manifest --stable   # non-prerelease releases only
```

Set `GITHUB_TOKEN` to raise the GitHub API rate limit (the workflows use the Actions token).

## Windows setup (any OS with NSIS 3)

```bash
node scripts/resolve.mjs download win-x64 --out payload      # or win-arm64
installers/windows/build.sh x64 payload out                  # Debian/Ubuntu: sudo apt install nsis
```

`installers/windows/QuillOffice.nsi` is the installer script: a components page with one section per app, each running that app's own installer silently (`/S` for the NSIS installers of QuillPen, QuillGrid and QuillStage; `msiexec /qn` for QuillPost's MSI). An app that fails to install is reported at the end instead of stopping the others.

## macOS package (macOS only)

```bash
node scripts/resolve.mjs download mac --out payload
installers/macos/build-pkg.sh payload out
```

Each app bundle is extracted from its `.zip` or `.dmg`, wrapped with `pkgbuild`, and combined with `productbuild` into one package with a choice per app. The package is unsigned; signing and notarizing need an Apple Developer account and are not part of this repository.

## Linux installer and AppImages

```bash
node scripts/resolve.mjs download linux-deb-x64 linux-appimage-x64 --out payload   # or arm64, armv7l
installers/linux/build.sh x64 payload out
sh out/QuillOffice-*-linux-x64.sh --list
```

The `.sh` is `installers/linux/install-header.sh` with a gzip tar of the `.deb` files appended.

## Web, Android and iOS archives

```bash
node scripts/resolve.mjs download web android ios --out payload
node scripts/bundle-portable.mjs web payload out
node scripts/bundle-portable.mjs android payload out
node scripts/bundle-portable.mjs ios payload out
```

## Adding or removing an app

Edit [suite.json](../suite.json): set `include`, and give the regular expressions that match the app's release file names (`{v}` is the version, `{tag}` the tag). Run `npm test` (the tests check the patterns against sample file lists) and `node scripts/resolve.mjs manifest` to see what a real release matches. QuillLoom is already listed with `"include": false`.

## Releasing

Push a tag `v<version>` (the version in `package.json`), run **Release** from the Actions tab, or push a commit whose message contains `[release]`. The release notes name the version of each app that went in.
