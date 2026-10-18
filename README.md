# QuillOffice

*The Quill suite in one download: [QuillPen](https://github.com/socrtwo/QuillPen) (documents), [QuillGrid](https://github.com/socrtwo/QuillGrid) (spreadsheets), [QuillPost](https://github.com/socrtwo/QuillPost) (email) and [QuillStage](https://github.com/socrtwo/QuillStage) (presentations).*

The four apps are developed and released in their own repositories. QuillOffice adds nothing to them; it is the installer that puts them on a computer together. Each **QuillOffice release** takes the newest release of every app and packages them per platform:

| Platform | What you download | What it does |
|---|---|---|
| **Windows 10/11** (x64, ARM) | `QuillOffice-<version>-windows-<arch>-setup.exe` | One setup with a tick box per app. It runs each app's own installer silently, for the current user. Apps appear separately in the Start menu and in *Apps & features*, so any one can be removed on its own. |
| **macOS 12+** | `QuillOffice-<version>-mac.pkg` | An installer package with one choice per app; installs into *Applications*. |
| **Debian, Ubuntu, Raspberry Pi OS, ChromeOS (Linux)** | `QuillOffice-<version>-linux-<arch>.sh` | A self-extracting installer: `sh QuillOffice-….sh` installs the apps' `.deb` packages with `apt`. `--apps pen,grid` installs some; `--list` shows what is inside; `--extract DIR` only unpacks the packages. x64, arm64 and armv7l. |
| **Other Linux** | `QuillOffice-<version>-linux-<arch>-AppImages.tar.gz` | The apps' AppImages. |
| **Android 7+** | `QuillOffice-<version>-android.zip` | The apps' APKs with a README. Android has no multi-app installer, so each APK is opened in turn. |
| **iOS / iPadOS 15+** | `QuillOffice-<version>-ios-unsigned.zip` | The unsigned `.ipa` files, to sign with your own Apple ID (AltStore, Sideloadly). |
| **Web** | `QuillOffice-<version>-web.zip` | Every app's web build in its own folder plus a launcher page, for any web server or GitHub Pages. The apps work offline after the first visit and can be installed from the browser. |

The release notes list the exact version of each app in the bundle, and `SHA256SUMS.txt` the checksum of every file. [docs/INSTALL.md](docs/INSTALL.md) has the steps for each platform.

**QuillLoom** is not part of the bundle yet. It is listed in [suite.json](suite.json) with `"include": false` and joins the release when that is switched on.

## How a release is built

`.github/workflows/release.yml` runs on a tag `v<version>`, a manual run from the Actions tab, or a commit whose message contains `[release]` (the last two publish a prerelease named `v<version>-build.<run>`):

1. **Resolve** — `scripts/resolve.mjs` asks GitHub for the newest release of each app in [suite.json](suite.json) (prereleases included unless *stable only* is chosen) and matches its files against the patterns there. The result is `manifest.json`, which is also attached to the release.
2. **Download and verify** — each bundle job downloads only the files it needs and checks them against the app's `SHA256SUMS.txt` where the app publishes one.
3. **Bundle** — `installers/windows` (NSIS, built on Linux with `makensis`), `installers/macos` (`pkgbuild` and `productbuild`), `installers/linux` (a shell header with a tar payload), and `scripts/bundle-portable.mjs` for the web, Android and iOS archives.
4. **Publish** — checksums, release notes with the component versions, one GitHub release. A platform that fails is listed in the notes instead of blocking the others.

Nothing is recompiled here; the apps' own CI builds and tests them. See [docs/BUILD.md](docs/BUILD.md) to build a bundle locally.

## Known limits

- The desktop apps are not code-signed, so Windows SmartScreen and macOS Gatekeeper ask once per app (the installers say so).
- QuillPost's desktop builds exist for Windows x64, macOS on Apple silicon, and Linux x64/arm64 only. The Windows on ARM setup leaves it out (its x64 build runs through emulation when installed separately); the macOS package skips it on Intel Macs; its iOS release is a simulator build and is not bundled. Its web edition is a Java server rather than a static site and is included as its own zip with instructions.
- A bundle is only as current as the apps' releases at the moment it was built; it does not update itself. Each app keeps its own update path.

## The Quill suite

| App | What it is | Repository |
|---|---|---|
| **QuillPen** | Word processor | https://github.com/socrtwo/QuillPen |
| **QuillGrid** | Spreadsheet | https://github.com/socrtwo/QuillGrid |
| **QuillPost** | Email, calendar and contacts | https://github.com/socrtwo/QuillPost |
| **QuillStage** | Presentations | https://github.com/socrtwo/QuillStage |
| **QuillOffice** | The suite's combined installers (this project) | https://github.com/socrtwo/QuillOffice |

## License

[MIT](LICENSE). Copyright (c) 2026 Paul D Pruitt. The bundled apps are each MIT-licensed in their own repositories, with their own third-party notices.

## Legal

QuillOffice and the Quill apps are independent, clean-room projects. They are not affiliated with, endorsed by, or sponsored by Microsoft, Apple, Google, The Document Foundation, or any other vendor. Product names appear only to describe file-format compatibility (nominative use). See [docs/LEGAL.md](docs/LEGAL.md).
