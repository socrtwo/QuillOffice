#!/usr/bin/env node
// Finds the newest release of every bundled Quill app, writes manifest.json, and downloads the
// release files a bundle needs, checking them against the app's SHA256SUMS.txt when it publishes one.
//
//   node scripts/resolve.mjs manifest [--stable] [--out manifest.json]
//   node scripts/resolve.mjs download <asset-key>... [--manifest manifest.json] [--out payload/]
//
// Asset keys are the names under "assets" in suite.json (win-x64, mac, linux-deb-arm64, android, web…).
// An app that has no file for a key is skipped for that key; the manifest records what was found.
// GITHUB_TOKEN raises the API rate limit and is used when present.
import { readFileSync, writeFileSync, mkdirSync, createWriteStream, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const suite = JSON.parse(readFileSync(join(root, 'suite.json'), 'utf8'));
const args = process.argv.slice(2);
const cmd = args.shift();
const opt = (name, def) => { const i = args.indexOf(name); if (i < 0) return def; const v = args[i + 1]; args.splice(i, 2); return v; };
const flag = (name) => { const i = args.indexOf(name); if (i < 0) return false; args.splice(i, 1); return true; };

const headers = { 'User-Agent': 'QuillOffice-release-bundler', Accept: 'application/vnd.github+json' };
if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;

async function api(path) {
  const r = await fetch(`https://api.github.com${path}`, { headers });
  if (!r.ok) throw new Error(`GitHub API ${path}: ${r.status} ${r.statusText}`);
  return r.json();
}

/** The version a tag names: v0.1.1-build.7 → 0.1.1, v1.2.0 → 1.2.0. */
export function versionOf(tag) {
  return tag.replace(/^v/, '').replace(/-build\.\d+$/, '');
}

function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

/** Matches one release's assets against an app's patterns. */
export function matchAssets(app, release) {
  const v = versionOf(release.tag_name);
  const out = {};
  for (const [key, pattern] of Object.entries(app.assets || {})) {
    const re = new RegExp(pattern.replace('{v}', escapeRe(v)).replace('{tag}', escapeRe(release.tag_name)));
    const a = release.assets.find((x) => re.test(x.name));
    if (a) out[key] = { name: a.name, url: a.browser_download_url, size: a.size };
  }
  return out;
}

async function newestRelease(repo, stable) {
  const list = await api(`/repos/${suite.owner}/${repo}/releases?per_page=30`);
  const ok = list.filter((r) => !r.draft && (!stable || !r.prerelease) && r.assets.length);
  // Releases come newest first.
  return ok[0] || null;
}

async function buildManifest(stable) {
  const manifest = { generated: new Date().toISOString(), stable, apps: {} };
  for (const [name, app] of Object.entries(suite.apps)) {
    if (!app.include) { manifest.apps[name] = { included: false }; continue; }
    const rel = await newestRelease(app.repo, stable);
    if (!rel) { manifest.apps[name] = { included: true, found: false }; console.warn(`${name}: no ${stable ? 'stable ' : ''}release with files`); continue; }
    const assets = matchAssets(app, rel);
    manifest.apps[name] = { included: true, found: true, repo: app.repo, label: app.label, summary: app.summary, id: app.id, tag: rel.tag_name, version: versionOf(rel.tag_name), prerelease: rel.prerelease, url: rel.html_url, assets };
    const missing = Object.keys(app.assets).filter((k) => !assets[k]);
    console.log(`${name} ${rel.tag_name}: ${Object.keys(assets).length} files matched${missing.length ? `; none for ${missing.join(', ')}` : ''}`);
  }
  return manifest;
}

async function download(url, dest) {
  const r = await fetch(url, { headers: { 'User-Agent': headers['User-Agent'] }, redirect: 'follow' });
  if (!r.ok || !r.body) throw new Error(`Download ${url}: ${r.status}`);
  await pipeline(Readable.fromWeb(r.body), createWriteStream(dest));
}

function sha256(file) {
  return createHash('sha256').update(readFileSync(file)).digest('hex');
}

async function sumsFor(appEntry, cacheDir) {
  const s = appEntry.assets.sums;
  if (!s) return null;
  const dest = join(cacheDir, `${appEntry.repo}-SHA256SUMS.txt`);
  if (!existsSync(dest)) await download(s.url, dest);
  const map = new Map();
  for (const line of readFileSync(dest, 'utf8').split('\n')) {
    const m = /^([0-9a-f]{64})\s+\*?(.+)$/.exec(line.trim());
    if (m) map.set(m[2].replace(/^.*\//, ''), m[1]);
  }
  return map;
}

async function doDownload(keys, manifestPath, outDir) {
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  mkdirSync(outDir, { recursive: true });
  const got = [];
  for (const [name, e] of Object.entries(manifest.apps)) {
    if (!e.included || !e.found) continue;
    const sums = await sumsFor(e, outDir);
    for (const key of keys) {
      const a = e.assets[key];
      if (!a) { console.log(`${name}: no file for ${key}, skipped`); continue; }
      const dest = join(outDir, a.name);
      if (!existsSync(dest)) { console.log(`${name}: downloading ${a.name} (${(a.size / 1048576).toFixed(1)} MB)`); await download(a.url, dest); }
      if (sums && sums.has(a.name)) {
        const want = sums.get(a.name), have = sha256(dest);
        if (want !== have) throw new Error(`${a.name}: checksum mismatch (expected ${want}, got ${have})`);
        console.log(`${name}: ${a.name} checksum OK`);
      } else console.log(`${name}: ${a.name} has no published checksum; recorded ${sha256(dest).slice(0, 12)}…`);
      got.push({ app: name, key, file: a.name, version: e.version, tag: e.tag });
    }
  }
  writeFileSync(join(outDir, 'payload.json'), JSON.stringify(got, null, 2));
  return got;
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMain) {
  if (cmd === 'manifest') {
    const stable = flag('--stable');
    const out = opt('--out', 'manifest.json');
    const m = await buildManifest(stable);
    writeFileSync(out, JSON.stringify(m, null, 2));
    console.log(`Wrote ${out}`);
  } else if (cmd === 'download') {
    const manifestPath = opt('--manifest', 'manifest.json');
    const out = opt('--out', 'payload');
    if (!args.length) { console.error('download: give at least one asset key'); process.exit(2); }
    await doDownload(args, manifestPath, out);
  } else {
    console.error('usage: resolve.mjs manifest [--stable] [--out file] | download <keys…> [--manifest file] [--out dir]');
    process.exit(2);
  }
}
