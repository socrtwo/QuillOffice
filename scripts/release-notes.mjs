#!/usr/bin/env node
// Writes the release body: the apps and versions this Anne's Office release installs, and the file for each platform.
//   node scripts/release-notes.mjs manifest.json out/ > notes.md
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const [manifestPath, outDir] = process.argv.slice(2);
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const version = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).version;
const m = JSON.parse(readFileSync(manifestPath, 'utf8'));
const files = readdirSync(outDir).filter((f) => f.startsWith('QuillOffice-'));
const find = (re) => files.filter((f) => re.test(f)).map((f) => `\`${f}\``).join(', ') || '—';
const lines = [];
lines.push(`Anne\'s Office ${version} installs these releases of the Anne\'s Office apps (each one is also available on its own from its repository):`, '');
lines.push('| App | Version | Release |', '|---|---|---|');
for (const [name, a] of Object.entries(m.apps)) {
  if (!a.included) continue;
  lines.push(a.found ? `| ${name} (${a.summary}) | ${a.version}${a.prerelease ? ' (prerelease)' : ''} | [${a.tag}](${a.url}) |` : `| ${name} | no release found | — |`);
}
lines.push('', '| Platform | Download |', '|---|---|');
lines.push(`| Windows 10/11 x64 | ${find(/windows-x64-setup\.exe$/)} — one setup; tick the apps you want |`);
lines.push(`| Windows on ARM | ${find(/windows-arm64-setup\.exe$/)} (Anne\'s Post has no arm64 build yet; its x64 build runs through emulation) |`);
lines.push(`| macOS 12+ | ${find(/-mac\.pkg$/)} — installer package with one choice per app (Anne\'s Post: Apple silicon only) |`);
lines.push(`| Debian, Ubuntu, Raspberry Pi OS, ChromeOS (Linux) | ${find(/linux-(x64|arm64|armv7l)\.sh$/)} — \`sh QuillOffice-…-linux-<arch>.sh\` installs the .deb packages; \`--apps pen,grid\` picks some |`);
lines.push(`| Other Linux | ${find(/AppImages\.tar\.gz$/)} — the apps' AppImages |`);
lines.push(`| Android 7+ | ${find(/android\.zip$/)} — the APKs, installed one by one |`);
lines.push(`| iOS / iPadOS 15+ | ${find(/ios-unsigned\.zip$/)} — unsigned .ipa files to sign with your Apple ID |`);
lines.push(`| Web | ${find(/-web\.zip$/)} — all apps with a launcher page, for any web server |`);
lines.push('', 'The desktop apps are not code-signed (SmartScreen and Gatekeeper will ask once per app). `SHA256SUMS.txt` lists the checksum of every file. What each bundle does is described in [docs/INSTALL.md](https://github.com/socrtwo/QuillOffice/blob/main/docs/INSTALL.md).');
console.log(lines.join('\n'));
