// smartFind push + matching service (Cloudflare Worker, free plan is enough).
//
//   POST /v1/match    { itemId }          after a report was saved
//   POST /v1/message  { chatId, text }    after a chat message was sent
//   GET  /v1/health
//
// Both POST routes need `Authorization: Bearer <Firebase ID token>` of a user
// whose e-mail is verified. Secrets / variables (see wrangler.toml, README):
//   FIREBASE_PROJECT_ID      variable
//   FIREBASE_SERVICE_ACCOUNT secret   (service-account JSON)
//   OPENROUTER_API_KEY       secret   (optional - without it the rule engine decides alone)
//   OPENROUTER_MODEL         variable (optional, default "openrouter/free")
import * as engine from './match_engine.mjs';
import { judgePair } from './ai.mjs';
import {
  HttpError,
  accessToken,
  firestore,
  sendPush,
  verifyIdToken,
} from './google.mjs';

/**
 * Candidates considered per request (the newest ones). The free Cloudflare
 * plan allows ~10 ms CPU per request, so the default is modest; raise it with
 * the MAX_CANDIDATES variable on a paid plan.
 */
export const DEFAULT_MAX_CANDIDATES = 60;
/** Pairs sent to the AI per request. */
export const MAX_AI_PAIRS = 3;
/** Candidate ids the app may suggest per request. */
export const MAX_HINTS = 8;
const MAX_TOKENS_PER_USER = 5;

const json = (status, body) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });

// Best-effort per-isolate rate limit (the real protection is Cloudflare's).
const hits = new Map();
function rateLimit(uid, max = 20, windowMs = 60_000, now = Date.now()) {
  const list = (hits.get(uid) ?? []).filter((t) => now - t < windowMs);
  list.push(now);
  hits.set(uid, list);
  if (hits.size > 5000) hits.clear();
  if (list.length > max) throw new HttpError(429, 'Too many requests. Try again in a minute.');
}

const truncate = (s, n) => {
  const t = String(s ?? '').replace(/\s+/g, ' ').trim();
  const chars = Array.from(t);
  return chars.length <= n ? t : `${chars.slice(0, n - 1).join('')}…`;
};

const profileOf = (it) => ({
  id: it.id,
  reporterId: it.reporterId,
  status: it.status,
  category: it.category ?? 'other',
  title: it.title ?? '',
  description: it.description ?? '',
  location: it.location ?? '',
  latitude: Number(it.latitude ?? 0),
  longitude: Number(it.longitude ?? 0),
  eventDate: it.eventDate instanceof Date ? it.eventDate : it.createdAt instanceof Date ? it.createdAt : new Date(),
  reunited: it.reunited === true,
  imageUrl: it.imageUrl ?? '',
});

async function tokensOf(db, uid) {
  const user = await db.get(`users/${uid}`);
  const list = Array.isArray(user?.fcmTokens) ? user.fcmTokens.filter((t) => typeof t === 'string') : [];
  return list.slice(-MAX_TOKENS_PER_USER);
}

async function pushToUser(ctx, uid, message) {
  const { db, fcm } = ctx;
  const tokens = await tokensOf(db, uid);
  if (tokens.length === 0) return 0;
  const results = await Promise.all(tokens.map((t) => sendPush(fcm, t, message)));
  const dead = tokens.filter((_, i) => results[i] === 'invalid');
  if (dead.length > 0) {
    const all = (await db.get(`users/${uid}`))?.fcmTokens ?? [];
    await db.setArray(`users/${uid}`, 'fcmTokens', all.filter((t) => !dead.includes(t))).catch(() => {});
  }
  return results.filter((r) => r === 'sent').length;
}

function matchTexts(mine, other, score) {
  return {
    title: `Possible match found (${score}%)`,
    body:
      `A ${other.status} report, "${truncate(other.title, 48)}", looks like your ` +
      `${mine.status} report "${truncate(mine.title, 48)}". Open it to compare the details.`,
  };
}

/** POST /v1/match */
export async function handleMatch(ctx, uid, body, env) {
  const itemId = String(body?.itemId ?? '');
  if (!/^[A-Za-z0-9_-]{4,64}$/.test(itemId)) throw new HttpError(400, 'itemId is missing.');

  const { db } = ctx;
  const raw = await db.get(`items/${itemId}`);
  if (!raw) throw new HttpError(404, 'Report not found.');
  if (raw.reporterId !== uid) throw new HttpError(403, 'Only the author of a report can match it.');
  const mine = profileOf(raw);
  if (mine.reunited) return { matches: [], notified: 0 };

  // The app already knows the likely candidates (it has the whole feed) and may
  // name up to MAX_HINTS of them. The Worker re-scores every one of them itself,
  // so a hint can never make a notification happen that the engine would not
  // produce. Without hints the newest reports are read instead.
  const hints = Array.isArray(body?.candidateIds)
    ? [...new Set(body.candidateIds.map(String))].filter((x) => /^[A-Za-z0-9_-]{4,64}$/.test(x) && x !== itemId).slice(0, MAX_HINTS)
    : [];
  const rows =
    hints.length > 0
      ? (await Promise.all(hints.map((id) => db.get(`items/${id}`)))).filter(Boolean)
      : await db.query({
          from: [{ collectionId: 'items' }],
          orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'DESCENDING' }],
          limit: Math.min(300, Math.max(10, Number(env.MAX_CANDIDATES) || DEFAULT_MAX_CANDIDATES)),
        });

  const scored = [];
  const preparedMine = engine.prepare(mine);
  for (const row of rows) {
    const other = profileOf(row);
    if (!engine.isCandidate(mine, other)) continue;
    const s = engine.scorePrepared(preparedMine, engine.prepare(other));
    scored.push({ other, raw: row, rule: s, final: s.ruleScore, ai: null });
  }
  scored.sort((a, b) => b.rule.ruleScore - a.rule.ruleScore);

  // Optional AI second opinion for the most plausible pairs.
  const apiKey = env.OPENROUTER_API_KEY;
  if (apiKey) {
    const eligible = scored.filter((c) => c.rule.ruleScore >= engine.AI_MIN_RULE_SCORE).slice(0, MAX_AI_PAIRS);
    await Promise.all(
      eligible.map(async (c) => {
        const lost = mine.status === 'lost' ? mine : c.other;
        const found = mine.status === 'lost' ? c.other : mine;
        const verdict = await judgePair({
          apiKey,
          model: env.OPENROUTER_MODEL || 'openrouter/free',
          lost,
          found,
          fetchFn: ctx.fetchFn,
        });
        if (verdict) {
          c.ai = verdict;
          c.final = engine.blend(c.rule.ruleScore, verdict.score);
        }
      }),
    );
  }

  const winners = scored
    .filter((c) => c.final >= engine.THRESHOLD)
    .sort((a, b) => b.final - a.final)
    .slice(0, engine.MAX_NOTIFICATIONS_PER_ITEM);

  let notified = 0;
  const out = [];
  for (const c of winners) {
    const [lowId, highId] = [mine.id, c.other.id].sort();
    const reasons = engine.reasons(c.rule);
    out.push({ itemId: c.other.id, score: c.final, ruleScore: c.rule.ruleScore, ai: c.ai?.score ?? null, reasons });

    const targets = [
      { uid: c.other.reporterId, mine: c.other, other: mine, openItem: mine.id },
      { uid, mine, other: c.other, openItem: c.other.id },
    ];
    for (const t of targets) {
      const id = `m_${t.uid}_${lowId}_${highId}`;
      const text = matchTexts(t.mine, t.other, c.final);
      const created = await db.create('notifications', id, {
        userId: t.uid,
        type: 'match_found',
        title: text.title,
        body: text.body,
        createdAt: new Date(),
        isRead: false,
        itemId: t.openItem,
        itemStatus: t.other.status,
        otherItemId: t.mine.id,
        score: c.final,
      });
      if (!created) continue; // this pair was announced before: no second popup
      notified += 1;
      await pushToUser(ctx, t.uid, {
        ...text,
        data: { type: 'match_found', itemId: t.openItem, notificationId: id, score: String(c.final) },
      }).catch(() => 0);
    }
  }
  return { matches: out, notified };
}

/** POST /v1/message */
export async function handleMessage(ctx, uid, body) {
  const chatId = String(body?.chatId ?? '');
  const text = String(body?.text ?? '').trim();
  if (!/^[A-Za-z0-9_-]{4,200}$/.test(chatId) || !text) throw new HttpError(400, 'chatId or text is missing.');
  const { db } = ctx;

  const chat = await db.get(`chats/${chatId}`);
  const people = Array.isArray(chat?.participantIds) ? chat.participantIds : [];
  if (!people.includes(uid)) throw new HttpError(403, 'You are not part of this conversation.');
  const recipient = people.find((p) => p !== uid);
  if (!recipient) throw new HttpError(400, 'No recipient.');

  // Only announce a message that really was just written by this user.
  const latest = await db.query(
    {
      from: [{ collectionId: 'messages' }],
      orderBy: [{ field: { fieldPath: 'sentAt' }, direction: 'DESCENDING' }],
      limit: 1,
    },
    `chats/${chatId}`,
  );
  const msg = latest[0];
  const fresh = msg?.sentAt instanceof Date && Date.now() - msg.sentAt.getTime() < 120_000;
  if (!msg || msg.senderId !== uid || !fresh || String(msg.text ?? '').trim() !== text) {
    throw new HttpError(409, 'That message was not found.');
  }

  const names = Array.isArray(chat.participantNames) ? chat.participantNames : [];
  const sender = names[people.indexOf(uid)] || 'New message';
  const sent = await pushToUser(ctx, recipient, {
    title: truncate(sender, 40),
    body: truncate(text, 140),
    channelId: 'smartfind_messages',
    data: { type: 'new_message', chatId },
  });
  return { sent };
}

export default {
  async fetch(request, env, _ctx, overrides = {}) {
    const url = new URL(request.url);
    try {
      if (request.method === 'GET' && url.pathname === '/v1/health') {
        return json(200, { ok: true, ai: Boolean(env.OPENROUTER_API_KEY) });
      }
      if (request.method !== 'POST' || !['/v1/match', '/v1/message'].includes(url.pathname)) {
        return json(404, { error: 'Not found.' });
      }

      const fetchFn = overrides.fetchFn ?? fetch;
      const projectId = env.FIREBASE_PROJECT_ID;
      if (!projectId || !env.FIREBASE_SERVICE_ACCOUNT) {
        throw new HttpError(500, 'The server is not configured (project id / service account).');
      }
      let serviceAccount;
      try {
        serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
      } catch {
        throw new HttpError(500, 'FIREBASE_SERVICE_ACCOUNT is not valid JSON.');
      }

      const bearer = /^Bearer (.+)$/.exec(request.headers.get('authorization') ?? '')?.[1];
      const claims = await verifyIdToken(bearer, projectId, { fetchFn, now: overrides.now ?? Date.now() });
      rateLimit(claims.sub);

      let body;
      try {
        body = await request.json();
      } catch {
        throw new HttpError(400, 'Send a JSON body.');
      }

      const token = await accessToken(serviceAccount, { fetchFn, now: overrides.now ?? Date.now() });
      const ctx = {
        fetchFn,
        db: firestore({ projectId, token, fetchFn }),
        fcm: { projectId, token, fetchFn },
      };
      const result =
        url.pathname === '/v1/match'
          ? await handleMatch(ctx, claims.sub, body, env)
          : await handleMessage(ctx, claims.sub, body);
      return json(200, result);
    } catch (e) {
      if (e instanceof HttpError) return json(e.status, { error: e.message });
      console.error('worker error', e);
      return json(500, { error: 'Something went wrong on the server.' });
    }
  },
};
