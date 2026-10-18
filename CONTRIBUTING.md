# Contributing to QuillOffice

QuillOffice only packages the Quill apps. A bug in an app belongs in that app's repository ([QuillPen](https://github.com/socrtwo/QuillPen/issues), [QuillGrid](https://github.com/socrtwo/QuillGrid/issues), [QuillPost](https://github.com/socrtwo/QuillPost/issues), [QuillStage](https://github.com/socrtwo/QuillStage/issues)). Issues here are for the installers and bundles: an app missing from a bundle, an installer that fails on a platform, a wrong version in the release notes.

When you report an installer problem, include the platform and version, the bundle file name, and the installer's output (the Windows setup shows a details log; the Linux `.sh` prints to the terminal; macOS keeps `/var/log/install.log`).

Changes to the installers should keep these rules:

- Nothing is recompiled or modified; the apps' released files are used as they are and verified against the apps' checksums where published.
- Every app is optional in every installer that has a chooser.
- An app that fails to install must not stop the others, and the failure must be reported.
- Interface text and documentation use American English.

Run `npm test` and `npm run check` before opening a pull request. The CI workflow also compiles the NSIS script and resolves the apps' current releases.
