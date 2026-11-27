import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildMessages, judgePair, parseAnswer } from '../ai.mjs';

const lost = { title: 'Black phone', category: 'electronics', description: 'blue case', location: 'Library', imageUrl: 'https://res.cloudinary.com/x/image/upload/v1/a.jpg' };
const found = { title: 'Phone found', category: 'electronics', description: 'black, blue case', location: 'Library', imageUrl: 'https://res.cloudinary.com/x/image/upload/v1/b.jpg' };

const answer = (score) => ({
  ok: true,
  status: 200,
  json: async () => ({ model: 'free/vision', choices: [{ message: { content: `{"score": ${score}, "reason": "same phone"}` } }] }),
});

const hasImages = (init) =>
  JSON.parse(init.body).messages[1].content.some((part) => part.type === 'image_url');

test('photos are included when both reports have one, and shrunk', () => {
  const content = buildMessages(lost, found)[1].content;
  const urls = content.filter((p) => p.type === 'image_url').map((p) => p.image_url.url);
  assert.equal(urls.length, 2);
  assert.ok(urls.every((u) => u.includes('c_limit,w_512')));
});

test('no photos are sent when only one report has one', () => {
  const content = buildMessages(lost, { ...found, imageUrl: '' })[1].content;
  assert.equal(content.filter((p) => p.type === 'image_url').length, 0);
});

test('without a key nothing is asked', async () => {
  let calls = 0;
  const r = await judgePair({ apiKey: '', lost, found, fetchFn: async () => { calls++; return answer(90); } });
  assert.equal(r, null);
  assert.equal(calls, 0);
});

test('a model that rejects pictures is asked again with the texts only', async () => {
  const seen = [];
  const fetchFn = async (_url, init) => {
    seen.push(hasImages(init));
    return hasImages(init) ? { ok: false, status: 404, json: async () => ({}) } : answer(88);
  };
  const r = await judgePair({ apiKey: 'k', lost, found, fetchFn });
  assert.deepEqual(seen, [true, false]);
  assert.equal(r.score, 88);
});

test('when both attempts fail the result is null (the rule score stands)', async () => {
  const fetchFn = async () => ({ ok: false, status: 429, json: async () => ({}) });
  assert.equal(await judgePair({ apiKey: 'k', lost, found, fetchFn }), null);
});

test('a network error does not throw', async () => {
  const fetchFn = async () => { throw new Error('offline'); };
  assert.equal(await judgePair({ apiKey: 'k', lost, found, fetchFn }), null);
});

test('only one request is made when there are no photos', async () => {
  let calls = 0;
  const fetchFn = async () => { calls++; return { ok: false, status: 500, json: async () => ({}) }; };
  await judgePair({ apiKey: 'k', lost: { ...lost, imageUrl: '' }, found, fetchFn });
  assert.equal(calls, 1);
});

test('answers are parsed leniently and clamped', () => {
  assert.equal(parseAnswer('Sure! {"score": 140, "reason": "x"}').score, 100);
  assert.equal(parseAnswer('{"score": -5}').score, 0);
  assert.equal(parseAnswer('no json here'), null);
  assert.equal(parseAnswer('{"score": "abc"}'), null);
});
