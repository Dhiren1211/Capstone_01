import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as M from '../match_engine.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const fixtures = JSON.parse(readFileSync(join(root, 'test/fixtures/match_cases.json'), 'utf8'));

const profile = (p) => {
  const [y, m, d] = p.date.split('-').map(Number);
  return { ...p, eventDate: new Date(Date.UTC(y, m - 1, d, 3, 0, 0)) }; // 12:00 KST
};

for (const c of fixtures.cases) {
  test(c.name, () => {
    const a = profile(c.a);
    const b = profile(c.b);
    const candidate = M.isCandidate(a, b);
    if (c.expectCandidate === false) {
      assert.equal(candidate, false);
      return;
    }
    assert.equal(candidate, true);
    const s = M.score(a, b);
    assert.equal(
      s.ruleScore >= M.THRESHOLD,
      c.expectMatch,
      `score ${s.ruleScore} ${JSON.stringify(s)}`,
    );
  });
}

test('prints the scores (for the Dart twin)', () => {
  const out = fixtures.cases
    .filter((c) => c.expectCandidate !== false)
    .map((c) => `${c.name}: ${M.score(profile(c.a), profile(c.b)).ruleScore}`);
  console.log(out.join('\n'));
});

test('digits must match exactly (13 is not 14)', () => {
  const x = M.tokenize('iPhone 13');
  const y = M.tokenize('iPhone 14');
  assert.ok(M.softSimilarity(x, y) < 0.8);
  assert.ok(M.softSimilarity(x, M.tokenize('iPhone 13')) > 0.99);
});

test('korean particles are stripped and synonyms unify', () => {
  assert.deepEqual([...M.tokenize('지갑을').keys()], ['wallet']);
  assert.ok(M.tokenize('핸드폰').has('phone'));
  assert.ok(M.tokenize('아이폰 13').has('iphone'));
  assert.ok(M.tokenize('아이폰 13').has('phone'));
});

test('blend keeps the score inside 0..100', () => {
  assert.equal(M.blend(60, 100), Math.round(0.55 * 60 + 0.45 * 100));
  assert.equal(M.blend(60, 500), M.blend(60, 100));
  assert.equal(M.blend(60, -5), M.blend(60, 0));
});
