# Legal notes

QuillOffice is a packaging project: its releases contain the released builds of QuillPen, QuillGrid, QuillPost and QuillStage, unchanged. Each of those apps is an independent, clean-room project under the MIT License, with its own third-party notices for the open-source components it includes. QuillOffice's own scripts and installer definitions are under the MIT License in [LICENSE](../LICENSE).

**Trademarks.** The Quill apps are not affiliated with, endorsed by, or sponsored by Microsoft, Apple, Google, The Document Foundation, any AI provider, or any other vendor. Names such as Word, Excel, PowerPoint, Outlook, Office, Keynote, Pages and Numbers are trademarks of their owners and appear in the apps' documentation only to describe file-format compatibility or the origin of an idea (nominative use). "Quill", "QuillOffice" and the app names are used as project names and are not registered marks.

**Installer tooling.** The Windows setup is built with NSIS (zlib/libpng license), the macOS package with Apple's `pkgbuild` and `productbuild`, and the Linux installer with POSIX shell and tar. None of them adds code to the installed apps.

**No warranty.** The software is provided "as is", as the MIT License states. The installers are not code-signed; verify downloads with `SHA256SUMS.txt`.
