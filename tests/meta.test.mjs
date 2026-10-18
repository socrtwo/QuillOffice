import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (f) => JSON.parse(readFileSync(new URL('../' + f, import.meta.url), 'utf8'));
const meta = read('QuillOffice.meta.json');
const suite = read('suite.json');
const pkg = read('package.json');

test('description and topics fit GitHub limits', () => {
  assert.ok(meta.description.length > 0 && meta.description.length <= 350, `description is ${meta.description.length} characters`);
  assert.ok(meta.topics.length <= 20, `${meta.topics.length} topics`);
  for (const t of meta.topics) assert.match(t, /^[a-z0-9][a-z0-9-]{0,49}$/, t);
  assert.equal(new Set(meta.topics).size, meta.topics.length, 'duplicate topic');
  assert.ok(meta.homepage === '' || meta.homepage.startsWith('https://'));
});

test('apps match suite.json', () => {
  const on = Object.entries(suite.apps).filter(([, a]) => a.include).map(([n]) => n);
  const off = Object.entries(suite.apps).filter(([, a]) => !a.include).map(([n]) => n);
  assert.deepEqual(meta.apps, on);
  assert.deepEqual(meta.notYet, off);
});

test('package.json carries the same keywords and homepage', () => {
  assert.deepEqual(pkg.keywords, meta.keywords);
  assert.equal(pkg.homepage, meta.homepage);
});
