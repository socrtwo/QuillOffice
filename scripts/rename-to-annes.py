#!/usr/bin/env python3
"""Anne's Office rename: QuillPen → Anne's Pen, QuillGrid → Anne's Grid, QuillOffice → Anne's Office
(and Post, Stage, Loom, Press, Folio, Test), "the Quill suite" → "the Anne's Office suite".

Usage:
  rename-to-annes.py [--dry-run] <repo-dir> [<repo-dir> ...]   rewrite the tracked text files of each clone
  rename-to-annes.py --stdin                                     filter one text (a GitHub description, say)

Only display names change: app titles, web manifests, Android and iOS display names, installer and
desktop product names, UI strings, generator/producer fields, repository metadata and documentation.
Identifiers stay as they are so nothing already installed or saved breaks: repository names and
URLs, package and bundle ids, MIME types, release file-name patterns, executable and install-folder
names, storage keys, the embed protocol and every CamelCase code identifier (QuillNativePlugin,
openInQuillPen, QUILL_APP_IDS ...). Lookup keys that happen to be spelled like a product name are
kept too (suite.json app keys, the QuillPen styleSet, Gradle project and package names).

A few edits are more than a word swap and are made here, once, when the file exists:
  - electron-builder.config.cjs pins executableName to the old name, so only the product name changes;
  - electron/main.cjs (and QuillTest's main.js) pins the Electron userData/sessionData folders to the
    old name, so settings, drafts and keys stay where earlier versions put them;
  - QuillPen's "open in a sister app" check accepts the sister's new or old name;
  - QuillPost also searches "Anne's Pen" install folders for the embedded editor (its test follows);
  - QuillPost's desktop build gets a dockName, and QuillTest's package.json an artifactName/executableName;
  - *.meta.json / package.json keyword lists: quill-suite → annes-office-suite, quillpen → annes-pen, ...

Lines marked `rename:keep` are never touched. Re-running is a no-op. No file or folder is renamed.
"""
import os
import re
import subprocess
import sys

APPS = ['Pen', 'Post', 'Grid', 'Stage', 'Loom', 'Press', 'Folio', 'Test', 'Office']
ALT = '|'.join(APPS)
# A product name is "Quill<App>" as a word of its own: not glued to a path (/ \ ~ . $), not inside a
# CamelCase identifier or a file-name pattern (QuillPen-1.2.0, QuillPen.app, QuillPenEmbed).
# `\n`/`\t` written as escape sequences in a string literal still count as a boundary before it.
PRE = r"(?:(?<=\\n)|(?<=\\t)|(?<=\(/)|(?<![\w/\\~.$@`-]))"   # `(/` opens a regex literal; a backtick quotes an identifier
# A period after the name is a sentence end ("open in QuillGrid.") when whitespace, a closing quote
# or bracket, or the end of the line follows it; otherwise it starts an extension (QuillPen.app).
POST = r"(?![\w/\\\-])(?!\.(?![\s\"'`)\]}]|$))"
NAME = re.compile(PRE + r"Quill(" + ALT + r")" + POST)
# "QuillPen/QuillGrid/QuillStage" written as a list in prose.
CHAIN = re.compile(PRE + r"Quill(?:" + ALT + r")(?:/Quill(?:" + ALT + r"))+" + POST)
SUITE = re.compile(r"(?<![\w-])Quill (suite|apps?|Office)\b")
MAC_APP = re.compile(r'(?<!")/Applications/Quill(' + ALT + r')\.app\b')
KEYWORD = re.compile(r'^(\s*")(quill-suite|quill(?:' + ALT.lower() + r'))(",?\s*)$')

def annes(app: str) -> str:
    return "Anne's " + app

# Lines that must keep the old spelling (lookup keys, build identifiers, legacy-compatibility code).
KEEP_LINE = [re.compile(p) for p in (
    r'rename:keep',
    r'\bstyleSet\b',                      # QuillPen style set id, saved inside documents
    r'\bpackageName\s*=',                 # Compose Multiplatform / jpackage package name
    r'\bmenuGroup\s*=',                   # Start-menu folder follows the package name
    r'Object\.entries\(suite\.apps\)',    # QuillOffice test: suite.json keys
    r'it\.app ===',                       # QuillOffice bundle script: manifest keys
    r'Quill\w+\) p=',                     # QuillOffice installers/windows/build.sh case labels
    r'^\s*"(apps|notYet)":',              # QuillOffice.meta.json: suite.json keys
    r'-scheme Quill|-project Quill',      # Xcode scheme/project names
    r'\bexecutableName\b',               # binaries keep their names
    r'^\s*Quill\w+:\s*\{',                # keys of a config map (QuillPen style set, suite icon table)
)]
# A `rename:keep` left by the earlier rename (QuillForge/QuillLattice/Quillbox -> QuillPen/QuillGrid/QuillPost)
# protects old extensions and ids on its line, not the product name next to them, which is display text here.
OLD_RENAME = re.compile(r'Quill(?:Forge|Lattice)|Quillbox|quillforge|quilllattice|quillbox')
# Files where only some lines carry display text.
ONLY_LINES = {
    'suite.json': re.compile(r'"(label|summary|\$comment)"'),
    'project.yml': re.compile(r'DisplayName|Description|^\s*#'),   # XcodeGen: target, scheme and folder keep their names
}
SKIP_FILES = (
    '.pbxproj', 'settings.gradle', 'settings.gradle.kts', 'package-lock.json', '.eml',
    'suite/rename.py', 'suite/termux-suite-setup.sh', 'scripts/rename-to-annes.py', 'scripts/rename-to-annes.sh',
)
JS_LIKE = ('.ts', '.js', '.mjs', '.cjs', '.gradle')


def js_context(line: str, pos: int):
    """'comment', 'code', or the quote character of the string literal open at `pos` (template
    literals with ${...} nesting included). A line that is the inside of a multi-line template
    literal reads as 'code' here; that is why code positions still get an escaped apostrophe."""
    if line.lstrip().startswith('*'):
        return 'comment'
    q = None          # the string literal we are in
    stack = []        # brace depth of each enclosing ${ ... } of a template literal
    depth = 0
    i = 0
    while i < pos:
        c = line[i]
        if q is None:
            if line.startswith('//', i):
                return 'comment'
            if line.startswith('/*', i):
                j = line.find('*/', i + 2)
                if j < 0 or j + 2 > pos:
                    return 'comment'
                i = j + 2
                continue
            if c in '\'"`':
                q = c
            elif stack and c == '{':
                depth += 1
            elif stack and c == '}':
                if depth == 0:
                    q = '`'
                    depth = stack.pop()
                else:
                    depth -= 1
        else:
            if c == '\\':
                i += 2
                continue
            if c == q:
                q = None
            elif q == '`' and line.startswith('${', i):
                stack.append(depth)
                depth = 0
                q = None
                i += 2
                continue
        i += 1
    return q or 'code'


def context(line: str, pos: int, ext: str):
    """What surrounds `pos`: 'comment' (also every prose file), 'code', or an open quote character."""
    if ext in JS_LIKE:
        return js_context(line, pos)
    if ext in ('.sh', '.yml', '.yaml', '.kts', '.nsi'):
        def possessive(i):
            return 0 < i < len(line) - 1 and line[i - 1].isalnum() and line[i + 1].isalnum()
        q = None
        for i in range(pos):
            c = line[i]
            if q is None:
                if c == '#' or (c == ';' and ext == '.nsi'):
                    return 'comment'
                if c in '\'"' and not possessive(i):
                    q = c
            elif c == q and not (ext == '.sh' and q == '"' and i and line[i - 1] == '\\'):
                q = None
        return q or 'code'
    return 'comment'


def apostrophe(line: str, pos: int, path: str) -> str:
    """How to spell the apostrophe of "Anne's" at this position of this file."""
    ext = os.path.splitext(path)[1]
    if ext == '.xml' and '/res/values' in path.replace(os.sep, '/'):
        return "\\'"          # Android resource strings
    ctx = context(line, pos, ext)
    if ext in JS_LIKE:
        # \' is valid in every JavaScript/Groovy string literal, template or regex; only comments
        # (and bare code, handled by the caller) want a plain apostrophe.
        return "'" if ctx == 'comment' else "\\'"
    if ctx == "'":
        if ext in ('.yml', '.yaml'):
            return "''"
        if ext == '.sh':
            return "'\\''"
    return "'"


ARTICLE = re.compile(r"(?<![\w'])([Aa]) (?=Anne(?:'|\\'|'')s )")
KEY_BEFORE = re.compile(r'(?:^|[{,(])\s*$')
KEY_AFTER = re.compile(r'\s*:(?!:)')
IDENT_BEFORE = re.compile(r'\b(?:const|let|var|function|class|new|import|typeof|extends|interface|type|enum)\s+$')
IDENT_AFTER = re.compile(r'\s*(?:\(|\[|=(?!=))')
IDENT = []   # (path, line, token) left alone because they are code identifiers
KEYS = []    # (path, line, token) object keys that were quoted


def rewrite_line(line: str, path: str) -> str:
    base = os.path.basename(path)
    if base in ONLY_LINES and not ONLY_LINES[base].search(line):
        return line
    for rx in KEEP_LINE:
        if rx.search(line) and not (rx.pattern == 'rename:keep' and OLD_RENAME.search(line)):
            return line
    if base.endswith('.json'):
        m = KEYWORD.match(line)
        if m:
            kw = m.group(2)
            new = 'annes-office-suite' if kw == 'quill-suite' else 'annes-' + kw[5:]
            return m.group(1) + new + m.group(3)
    if base.endswith('.md'):
        line = MAC_APP.sub(lambda m: '"/Applications/' + annes(m.group(1)) + '.app"', line)

    ext = os.path.splitext(path)[1]

    def sub_names(text: str) -> str:
        out, last = [], 0
        for m in NAME.finditer(text):
            out.append(text[last:m.start()])
            rep = "Anne" + apostrophe(text, m.start(), path) + "s " + m.group(1)
            if ext in JS_LIKE and context(text, m.start(), ext) == 'code':
                before, after = text[:m.start()], text[m.end():]
                if KEY_BEFORE.search(before) and KEY_AFTER.match(after):
                    rep = "'Anne\\'s " + m.group(1) + "'"      # an object key: quote it
                    KEYS.append((path, text.strip(), m.group(0)))
                elif IDENT_BEFORE.search(before) or IDENT_AFTER.match(after):
                    rep = m.group(0)                              # a code identifier: leave it
                    IDENT.append((path, text.strip(), m.group(0)))
            out.append(rep)
            last = m.end()
        out.append(text[last:])
        return ''.join(out)

    def sub_chain(m):
        ap = apostrophe(line, m.start(), path)
        return '/'.join("Anne" + ap + "s " + part[5:] for part in m.group(0).split('/'))

    line = CHAIN.sub(sub_chain, line)
    line = sub_names(line)

    def sub_suite(m):
        a = "Anne" + apostrophe(line, m.start(), path) + "s Office"
        return a if m.group(1) == 'Office' else a + ' ' + m.group(1)

    return ARTICLE.sub(r'\1n ', SUITE.sub(sub_suite, line))


def rewrite(text: str, path: str) -> str:
    return ''.join(rewrite_line(l, path) for l in text.splitlines(keepends=True))


# --- Edits that are more than a word swap -------------------------------------------------------

def app_of(root: str) -> str:
    """Which app this clone is (Pen, Grid, ...): from the folder name, else package.json's name."""
    names = [os.path.basename(os.path.abspath(root))]
    pkg = os.path.join(root, 'package.json')
    if os.path.isfile(pkg):
        m = re.search(r'"name"\s*:\s*"([^"]+)"', open(pkg, encoding='utf-8').read())
        if m:
            names.append(m.group(1))
    for n in names:
        m = re.fullmatch(r'quill(' + ALT.lower() + r')', n.lower())
        if m:
            return m.group(1).capitalize()
    return ''


def edit_file(root, rel, fn, dry, changed):
    p = os.path.join(root, rel)
    if not os.path.isfile(p):
        return
    old = open(p, encoding='utf-8', newline='').read()
    new = fn(old)
    if new != old:
        changed.append(rel)
        if not dry:
            open(p, 'w', encoding='utf-8', newline='').write(new)


def special_edits(root: str, dry: bool, changed: list):
    app = app_of(root)
    quill = 'Quill' + app
    if not app:
        return

    # electron-builder: the binary and the install folder keep the old name; only the product name changes.
    def builder(t):
        if re.search(r'^  executableName:', t, re.M) or not re.search(r"^  productName: '", t, re.M):
            return t
        return re.sub(r"^(  productName: '[^\n]*',)\n", lambda m: m.group(1) + f"\n  executableName: '{quill}', // the binary keeps its old name; the product (display) name is {annes(app)}\n", t, count=1, flags=re.M)
    edit_file(root, 'electron-builder.config.cjs', builder, dry, changed)

    # Electron: the data folders keep the old name (they are derived from the product name otherwise).
    def pin_cjs(t):
        if "setPath('userData'" in t:
            return t
        m = re.search(r"^const path = require\('(?:node:)?path'\);\n", t, re.M)
        if not m:
            return t
        ins = (f"// The data folder keeps the app's former name ({quill}) so settings, drafts and keys stay where earlier versions put them. // rename:keep\n"
               f"app.setPath('userData', path.join(app.getPath('appData'), '{quill}')); // rename:keep\n"
               f"app.setPath('sessionData', app.getPath('userData')); // rename:keep\n")
        return t[:m.end()] + ins + t[m.end():]
    edit_file(root, 'electron/main.cjs', pin_cjs, dry, changed)

    def pin_esm(t):
        if "setPath('userData'" in t or 'from \'electron\'' not in t:
            return t
        imports = list(re.finditer(r"^import [^\n]*\n", t, re.M))
        if not imports:
            return t
        joiner = 'join' if re.search(r"^import \{[^}]*\bjoin\b[^}]*\} from 'node:path'", t, re.M) else 'path.join'
        end = imports[-1].end()
        ins = (f"\n// The data folder keeps the app's former name ({quill}) so settings and keys stay where earlier versions put them. // rename:keep\n"
               f"app.setPath('userData', {joiner}(app.getPath('appData'), '{quill}')); // rename:keep\n"
               f"app.setPath('sessionData', app.getPath('userData')); // rename:keep\n")
        return t[:end] + ins + t[end:]
    edit_file(root, 'electron/main.js', pin_esm, dry, changed)

    if app == 'Pen':
        # A sister app's file handler may carry its new name (Anne's Grid) or its old one (QuillGrid).
        def sisters(t):
            return t.replace(
                "    if (!new RegExp(id, 'i').test(handler.replace(/\\s+/g, '')))",
                "    // The sister app may be installed under its new name (Anne's Grid) or its old one (QuillGrid). // rename:keep\n"
                "    if (!new RegExp(`${id}|anne'?s${id.slice(5)}`, 'i').test(handler.replace(/\\s+/g, '')))")
        edit_file(root, 'electron/main.cjs', sisters, dry, changed)

    if app == 'Pen':
        # LaTeX import turns the straight apostrophe of the fixture into a typographic one.
        def latex(t):
            return t.replace("toContain('“Quoted” — Anne\\'s Pen red bold both')", "toContain('“Quoted” — Anne’s Pen red bold both')")
        edit_file(root, 'tests/unit/formats-b.test.ts', latex, dry, changed)

    if app == 'Post':
        kt = 'web/src/main/kotlin/info/socrtwo/quillpost/web/QuillPenEmbed.kt'
        def locations(t):
            if "Anne's Pen\\\\resources" in t:
                return t
            t = t.replace(
                'env("LOCALAPPDATA")?.takeIf { it.isNotBlank() }?.let { File(it, "Programs\\\\QuillPen\\\\resources\\\\embed") },\n',
                'env("LOCALAPPDATA")?.takeIf { it.isNotBlank() }?.let { File(it, "Programs\\\\Anne\'s Pen\\\\resources\\\\embed") },\n'
                '                env("LOCALAPPDATA")?.takeIf { it.isNotBlank() }?.let { File(it, "Programs\\\\QuillPen\\\\resources\\\\embed") }, // rename:keep — the folder name of earlier installs\n')
            t = t.replace(
                'env("PROGRAMFILES")?.takeIf { it.isNotBlank() }?.let { File(it, "QuillPen\\\\resources\\\\embed") }\n',
                'env("PROGRAMFILES")?.takeIf { it.isNotBlank() }?.let { File(it, "Anne\'s Pen\\\\resources\\\\embed") },\n'
                '                env("PROGRAMFILES")?.takeIf { it.isNotBlank() }?.let { File(it, "QuillPen\\\\resources\\\\embed") } // rename:keep\n')
            t = t.replace(
                '                File("/Applications/QuillPen.app/Contents/Resources/embed"),\n'
                '                File(home, "Applications/QuillPen.app/Contents/Resources/embed")\n',
                '                File("/Applications/Anne\'s Pen.app/Contents/Resources/embed"),\n'
                '                File(home, "Applications/Anne\'s Pen.app/Contents/Resources/embed"),\n'
                '                File("/Applications/QuillPen.app/Contents/Resources/embed"), // rename:keep\n'
                '                File(home, "Applications/QuillPen.app/Contents/Resources/embed") // rename:keep\n')
            t = t.replace(
                'else -> listOf(File("/opt/QuillPen/resources/embed"))\n',
                'else -> listOf(File("/opt/Anne\'s Pen/resources/embed"), File("/opt/QuillPen/resources/embed")) // rename:keep\n')
            return t
        edit_file(root, kt, locations, dry, changed)

        test = 'web/src/test/kotlin/info/socrtwo/quillpost/web/QuillPenEmbedTest.kt'
        def locations_test(t):
            if "Anne's Pen\\\\resources" in t:
                return t
            t = t.replace('        assertEquals(2, win.size)\n'
                          '        assertTrue(win[0].endsWith("Programs\\\\QuillPen\\\\resources\\\\embed"))\n'
                          '        assertTrue(win[1].endsWith("QuillPen\\\\resources\\\\embed"))\n',
                          '        assertEquals(4, win.size)\n'
                          '        assertTrue(win[0].endsWith("Programs\\\\Anne\'s Pen\\\\resources\\\\embed"))\n'
                          '        assertTrue(win[1].endsWith("Programs\\\\QuillPen\\\\resources\\\\embed")) // rename:keep\n'
                          '        assertTrue(win[2].endsWith("Anne\'s Pen\\\\resources\\\\embed"))   // java.io.File joins with the host separator\n'
                          '        assertTrue(win[3].endsWith("QuillPen\\\\resources\\\\embed")) // rename:keep\n')
            t = t.replace('assertEquals(listOf("/Applications/QuillPen.app/Contents/Resources/embed", "/Users/a/Applications/QuillPen.app/Contents/Resources/embed"), mac)\n',
                          'assertEquals(listOf("/Applications/Anne\'s Pen.app/Contents/Resources/embed", "/Users/a/Applications/Anne\'s Pen.app/Contents/Resources/embed",\n'
                          '            "/Applications/QuillPen.app/Contents/Resources/embed", "/Users/a/Applications/QuillPen.app/Contents/Resources/embed"), mac) // rename:keep\n')
            t = t.replace('assertEquals(listOf("/opt/QuillPen/resources/embed"), QuillPenEmbed.standardLocations("Linux", { null }, "/home/a").map { it.path })\n',
                          'assertEquals(listOf("/opt/Anne\'s Pen/resources/embed", "/opt/QuillPen/resources/embed"), QuillPenEmbed.standardLocations("Linux", { null }, "/home/a").map { it.path }) // rename:keep\n')
            return t
        edit_file(root, test, locations_test, dry, changed)

        # Compose desktop: the package (install folder, bundle) keeps its name; the Dock shows the new one.
        def dock(t):
            if 'dockName' in t:
                return t
            return t.replace('                bundleID = "info.socrtwo.quillpost.desktop"\n',
                             '                bundleID = "info.socrtwo.quillpost.desktop"\n'
                             '                dockName = "Anne\'s Post"\n')
        edit_file(root, 'desktop/build.gradle.kts', dock, dry, changed)

    if app == 'Test':
        # electron-builder config lives in package.json here; keep the binary and file names.
        def pkg(t):
            if '"executableName"' in t:
                return t
            return t.replace('    "productName": "Anne\'s Test",\n',
                             '    "productName": "Anne\'s Test",\n'
                             '    "executableName": "QuillTest",\n'
                             '    "artifactName": "QuillTest-${version}-${os}-${arch}.${ext}",\n')
        edit_file(root, 'package.json', pkg, dry, changed)

        def html_title(t):
            return t.replace("/<title>Anne\\'s Test report — https:\\/\\/w\\.test<\\/title>/",
                             "/<title>Anne&#39;s Test report — https:\\/\\/w\\.test<\\/title>/")
        edit_file(root, 'tests/report.test.mjs', html_title, dry, changed)


# --- Driver -------------------------------------------------------------------------------------

def tracked_files(root: str):
    out = subprocess.run(['git', '-C', root, 'ls-files', '-z'], capture_output=True, check=True).stdout
    return [f for f in out.decode('utf-8', 'surrogateescape').split('\0') if f]


def process_repo(root: str, dry: bool) -> int:
    changed = []
    for f in tracked_files(root):
        if any(f.endswith(s) for s in SKIP_FILES):
            continue
        p = os.path.join(root, f)
        if not os.path.isfile(p) or os.path.islink(p):
            continue
        raw = open(p, 'rb').read()
        if b'\0' in raw[:8000]:
            continue
        try:
            text = raw.decode('utf-8')
        except UnicodeDecodeError:
            continue
        new = rewrite(text, p)
        if new != text:
            changed.append(f)
            if not dry:
                open(p, 'w', encoding='utf-8', newline='').write(new)
    special_edits(root, dry, changed)
    for f in sorted(set(changed)):
        print(f'  {f}')
    print(f'{root}: {len(set(changed))} files {"would be " if dry else ""}rewritten')
    return len(set(changed))


def main(argv):
    if '--stdin' in argv:
        sys.stdout.write(rewrite(sys.stdin.read(), 'stdin.txt'))
        return
    dry = '--dry-run' in argv
    roots = [a for a in argv if not a.startswith('--')]
    if not roots:
        sys.exit(__doc__)
    total = 0
    for root in roots:
        if not os.path.isdir(os.path.join(root, '.git')):
            print(f'{root}: not a git clone, skipped')
            continue
        total += process_repo(root, dry)
    print(f'{total} files in {len(roots)} repositories')
    for title, items in (('Object keys quoted (review)', KEYS), ('Left alone as code identifiers (review)', IDENT)):
        if items:
            print(f'\n{title}:', file=sys.stderr)
            for path, line, tok in items:
                print(f'  {path}: {tok}  |  {line[:110]}', file=sys.stderr)


if __name__ == '__main__':
    main(sys.argv[1:])
