#!/usr/bin/env node
// Builds the bundles that are plain archives: web, Android and iOS.
//   node scripts/bundle-portable.mjs <web|android|ios> <payload dir> <out dir>
// web:     QuillOffice-<v>-web.zip — each app's web build in its own folder plus an index.html launcher;
//          QuillPost's web edition (a Java server) is included as its own zip with instructions.
// android: QuillOffice-<v>-android.zip — the apps' APKs and a README (Android has no multi-app installer).
// ios:     QuillOffice-<v>-ios-unsigned.zip — the unsigned .ipa files to sign with your own Apple ID.
import { readFileSync, mkdirSync, cpSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const [kind, payloadArg, outArg] = process.argv.slice(2);
if (!kind || !payloadArg || !outArg) { console.error('usage: bundle-portable.mjs <web|android|ios> <payload dir> <out dir>'); process.exit(2); }
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const version = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).version;
const payload = resolve(payloadArg);
const out = resolve(outArg);
mkdirSync(out, { recursive: true });
const items = JSON.parse(readFileSync(join(payload, 'payload.json'), 'utf8'));
const manifest = JSON.parse(readFileSync(join(payload, '..', 'manifest.json'), 'utf8'));
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
const work = join(out, `.work-${kind}`);
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });

function zip(name, dir) {
  const target = join(out, name);
  rmSync(target, { force: true });
  execFileSync('zip', ['-qr', target, '.'], { cwd: dir, stdio: 'inherit' });
  console.log(`wrote ${target}`);
}

const app = (name) => manifest.apps[name];

if (kind === 'web') {
  const cards = [];
  for (const it of items.filter((x) => x.key === 'web')) {
    const a = app(it.app);
    if (it.app === 'QuillPost') {
      cpSync(join(payload, it.file), join(work, it.file));
      cards.push(`<a class="card jvm" href="${esc(it.file)}"><b>QuillPost ${esc(a.version)}</b><span>${esc(a.summary)}</span><small>A Java server, not a static page: unzip it and run <code>bin/quillpost-web</code> (needs Java 17+), then open the address it prints.</small></a>`);
      continue;
    }
    const dir = join(work, it.app);
    mkdirSync(dir, { recursive: true });
    execFileSync('unzip', ['-qo', join(payload, it.file), '-d', dir]);
    cards.push(`<a class="card" href="${esc(it.app)}/"><b>${esc(a.label)} ${esc(a.version)}</b><span>${esc(a.summary)}</span><small>Open in a browser, or install it as an app from the browser menu.</small></a>`);
  }
  writeFileSync(join(work, 'index.html'), `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>QuillOffice ${esc(version)}</title>
<style>
body{margin:0;font-family:system-ui,sans-serif;background:#eef1f5;color:#1d2330}header{background:#3a2a5e;color:#fff;padding:28px 24px}h1{margin:0;font-size:26px}p{margin:6px 0 0}
main{display:grid;gap:16px;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));padding:24px}.card{display:block;background:#fff;border-radius:12px;padding:18px;text-decoration:none;color:inherit;box-shadow:0 1px 3px rgba(0,0,0,.15)}
.card b{display:block;font-size:18px}.card span{display:block;color:#555;margin:4px 0 8px}.card small{color:#777}.jvm{border-left:5px solid #0D7C86}footer{padding:0 24px 24px;color:#555;font-size:13px}code{background:#eee;padding:1px 4px;border-radius:3px}
</style></head><body>
<header><h1>QuillOffice ${esc(version)}</h1><p>The Quill suite as web apps. Serve this folder from any web server (the apps need http:// or https://, not file://), or host it on GitHub Pages.</p></header>
<main>${cards.join('')}</main>
<footer>Open source, MIT License. Each app works offline after the first visit and can be installed from the browser. Sources: github.com/socrtwo.</footer>
</body></html>
`);
  zip(`QuillOffice-${version}-web.zip`, work);
} else if (kind === 'android') {
  const lines = ['QuillOffice ' + version + ' for Android', '', 'Android installs one app at a time. Open each APK (allow installs from this source when asked):', ''];
  for (const it of items.filter((x) => x.key === 'android')) {
    cpSync(join(payload, it.file), join(work, it.file));
    lines.push(`  ${it.file}  (${it.app} ${app(it.app).version}${/unsigned/.test(it.file) ? ', debug-signed' : ''})`);
  }
  lines.push('', 'The apps register for Open with and Share to on their document types and use the system file picker.', 'Sources and the Play Store bundles (.aab): github.com/socrtwo');
  writeFileSync(join(work, 'README.txt'), lines.join('\n') + '\n');
  zip(`QuillOffice-${version}-android.zip`, work);
} else if (kind === 'ios') {
  const lines = ['QuillOffice ' + version + ' for iOS and iPadOS', '', 'These .ipa files are unsigned. Sign and install each one with your own Apple ID using a sideloading tool (for example AltStore or Sideloadly):', ''];
  for (const it of items.filter((x) => x.key === 'ios')) { cpSync(join(payload, it.file), join(work, it.file)); lines.push(`  ${it.file}  (${it.app} ${app(it.app).version})`); }
  lines.push('', 'QuillPost has no device build for iOS yet; its releases include a simulator build only.');
  writeFileSync(join(work, 'README.txt'), lines.join('\n') + '\n');
  zip(`QuillOffice-${version}-ios-unsigned.zip`, work);
} else {
  console.error(`unknown bundle kind ${kind}`);
  process.exit(2);
}
rmSync(work, { recursive: true, force: true });
if (!existsSync(out)) process.exit(1);
