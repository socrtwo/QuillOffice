import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { versionOf, matchAssets } from '../scripts/resolve.mjs';

const suite = JSON.parse(readFileSync(new URL('../suite.json', import.meta.url), 'utf8'));

test('versionOf strips v and build suffixes', () => {
  assert.equal(versionOf('v0.1.1-build.7'), '0.1.1');
  assert.equal(versionOf('v1.2.0'), '1.2.0');
  assert.equal(versionOf('2.0.0'), '2.0.0');
});

test('electron-builder style releases match every key', () => {
  const names = ['QuillStage-0.1.1-ios-unsigned.ipa', 'QuillStage-0.1.1-linux-amd64.deb', 'QuillStage-0.1.1-linux-arm64.AppImage', 'QuillStage-0.1.1-linux-arm64.deb', 'QuillStage-0.1.1-linux-armv7l.AppImage', 'QuillStage-0.1.1-linux-armv7l.deb', 'QuillStage-0.1.1-linux-x86_64.AppImage', 'QuillStage-0.1.1-mac-universal.dmg', 'QuillStage-0.1.1-mac-universal.zip', 'QuillStage-0.1.1-web.zip', 'QuillStage-0.1.1-windows-arm64-setup.exe', 'QuillStage-0.1.1-windows-portable.exe', 'QuillStage-0.1.1-windows-setup.exe', 'QuillStage-0.1.1-windows-x64-setup.exe', 'QuillStage-0.1.1.aab', 'QuillStage-0.1.1.apk', 'SHA256SUMS.txt'];
  const rel = { tag_name: 'v0.1.1-build.7', assets: names.map((n) => ({ name: n, browser_download_url: 'u/' + n, size: 1 })) };
  const got = matchAssets(suite.apps.QuillStage, rel);
  assert.deepEqual(Object.keys(got).sort(), Object.keys(suite.apps.QuillStage.assets).sort());
  assert.equal(got['win-x64'].name, 'QuillStage-0.1.1-windows-x64-setup.exe');
  assert.equal(got.mac.name, 'QuillStage-0.1.1-mac-universal.zip');
});

test('Anne\'s Post releases match by tag', () => {
  const names = ['quillpost-desktop-v1.4.0-windows-x64.msi', 'quillpost-desktop-v1.4.0-windows-x64-portable.zip', 'quillpost-desktop-v1.4.0-macos-arm64.dmg', 'quillpost-desktop-v1.4.0-linux-x64.deb', 'quillpost-desktop-v1.4.0-linux-arm64.deb', 'quillpost-v1.4.0-unsigned.apk', 'quillpost-v1.4.0-debug.apk', 'quillpost-web-v1.4.0-any-jvm.zip', 'QuillPost-iOS-simulator-v1.4.0.app.zip'];
  const rel = { tag_name: 'v1.4.0', assets: names.map((n) => ({ name: n, browser_download_url: 'u/' + n, size: 1 })) };
  const got = matchAssets(suite.apps.QuillPost, rel);
  assert.equal(got['win-x64'].name, 'quillpost-desktop-v1.4.0-windows-x64.msi');
  assert.equal(got.android.name, 'quillpost-v1.4.0-unsigned.apk');
  assert.equal(got.ios, undefined);
  assert.equal(got['win-arm64'], undefined);
});

test('Anne\'s Loom is listed but not included', () => {
  assert.equal(suite.apps.QuillLoom.include, false);
  assert.deepEqual(Object.entries(suite.apps).filter(([, a]) => a.include).map(([n]) => n), ['QuillPen', 'QuillGrid', 'QuillPost', 'QuillStage']);
});
