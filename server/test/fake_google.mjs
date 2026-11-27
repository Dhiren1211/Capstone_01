// An in-memory stand-in for the Google endpoints the Worker talks to, so the
// whole request flow can be tested without a network or real credentials.
import { bytesToB64url, toValue, resetCaches } from '../google.mjs';

const enc = new TextEncoder();
export const PROJECT = 'smartfind-test';

export async function makeKeys() {
  const pair = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  );
  const jwk = { ...(await crypto.subtle.exportKey('jwk', pair.publicKey)), kid: 'k1', alg: 'RS256', use: 'sig' };
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey));
  let bin = '';
  for (const b of pkcs8) bin += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(bin).match(/.{1,64}/g).join('\n')}\n-----END PRIVATE KEY-----\n`;
  return { pair, jwk, pem };
}

export async function signIdToken(keys, claims = {}, header = {}) {
  const now = Math.floor(Date.now() / 1000);
  const h = bytesToB64url(enc.encode(JSON.stringify({ alg: 'RS256', kid: 'k1', typ: 'JWT', ...header })));
  const p = bytesToB64url(
    enc.encode(
      JSON.stringify({
        iss: `https://securetoken.google.com/${PROJECT}`,
        aud: PROJECT,
        sub: 'alice',
        email_verified: true,
        iat: now - 10,
        exp: now + 3600,
        ...claims,
      }),
    ),
  );
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', keys.pair.privateKey, enc.encode(`${h}.${p}`));
  return `${h}.${p}.${bytesToB64url(sig)}`;
}

export function createFakeGoogle(keys, { openrouter } = {}) {
  resetCaches();
  const state = {
    docs: { items: new Map(), users: new Map(), chats: new Map(), notifications: new Map() },
    messages: new Map(), // chatId -> [{id, ...}]
    pushes: [],
    ai: [],
    fcmResult: () => 200,
    calls: 0,
  };
  const reply = (status, body) =>
    new Response(typeof body === 'string' ? body : JSON.stringify(body), {
      status,
      headers: { 'content-type': 'application/json' },
    });
  const encodeDoc = (col, id, data) => ({
    name: `projects/${PROJECT}/databases/(default)/documents/${col}/${id}`,
    fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, toValue(v)])),
  });
  const root = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

  const fetchFn = async (input, init = {}) => {
    state.calls += 1;
    const url = String(input);
    const method = init.method ?? 'GET';
    const body = init.body && typeof init.body === 'string' ? JSON.parse(init.body) : init.body;

    if (url.startsWith('https://www.googleapis.com/service_accounts/v1/jwk/')) {
      return new Response(JSON.stringify({ keys: [keys.jwk] }), {
        headers: { 'cache-control': 'public, max-age=3600' },
      });
    }
    if (url === 'https://oauth2.googleapis.com/token') {
      return reply(200, { access_token: 'ya29.test', expires_in: 3600 });
    }
    if (url.startsWith(root)) {
      const rest = url.slice(root.length);
      if (method === 'POST' && rest === ':runQuery') {
        const limit = body.structuredQuery.limit ?? 100;
        const rows = [...state.docs.items.entries()]
          .map(([id, d]) => ({ id, d }))
          .sort((a, b) => b.d.createdAt - a.d.createdAt)
          .slice(0, limit)
          .map(({ id, d }) => ({ document: encodeDoc('items', id, d) }));
        return reply(200, rows.length ? rows : [{}]);
      }
      const q = /^\/chats\/([^/]+):runQuery$/.exec(rest);
      if (method === 'POST' && q) {
        const msgs = [...(state.messages.get(q[1]) ?? [])].sort((a, b) => b.sentAt - a.sentAt).slice(0, 1);
        return reply(200, msgs.length ? msgs.map((m) => ({ document: encodeDoc(`chats/${q[1]}/messages`, m.id, m) })) : [{}]);
      }
      if (method === 'POST' && rest.startsWith('/notifications?documentId=')) {
        const id = decodeURIComponent(rest.split('=')[1]);
        if (state.docs.notifications.has(id)) return reply(409, { error: { status: 'ALREADY_EXISTS' } });
        const fields = body.fields;
        const decoded = {};
        for (const [k, v] of Object.entries(fields)) decoded[k] = v.stringValue ?? v.integerValue ?? v.booleanValue ?? v.timestampValue ?? null;
        state.docs.notifications.set(id, decoded);
        return reply(200, { name: `${root}/notifications/${id}` });
      }
      const get = /^\/(items|users|chats)\/([^/?]+)(\?.*)?$/.exec(rest);
      if (get) {
        const [, col, id, qs] = get;
        if (method === 'GET') {
          const d = state.docs[col].get(id);
          return d ? reply(200, encodeDoc(col, id, d)) : reply(404, { error: { status: 'NOT_FOUND' } });
        }
        if (method === 'PATCH' && col === 'users' && qs?.includes('fcmTokens')) {
          const cur = state.docs.users.get(id) ?? {};
          state.docs.users.set(id, {
            ...cur,
            fcmTokens: (body.fields.fcmTokens.arrayValue.values ?? []).map((v) => v.stringValue),
          });
          return reply(200, {});
        }
      }
    }
    if (url === `https://fcm.googleapis.com/v1/projects/${PROJECT}/messages:send`) {
      const status = state.fcmResult(body.message.token);
      if (status === 200) {
        state.pushes.push(body.message);
        return reply(200, { name: 'm1' });
      }
      return reply(status, { error: { status: 'NOT_FOUND', message: 'UNREGISTERED' } });
    }
    if (url === 'https://openrouter.ai/api/v1/chat/completions') {
      state.ai.push(body);
      if (!openrouter) return reply(500, {});
      const r = await openrouter(body);
      return reply(r.status ?? 200, r.body);
    }
    throw new Error(`unexpected request: ${method} ${url}`);
  };

  return { fetchFn, state };
}

export const baseItem = (over = {}) => ({
  title: 'Black iPhone 13 with blue case',
  description: 'Lost near the library, small crack on the corner',
  category: 'electronics',
  status: 'lost',
  location: 'Central Library Building',
  latitude: 35.138248,
  longitude: 129.099623,
  reporterId: 'alice',
  reporterName: 'Alice',
  imageUrl: '',
  reunited: false,
  createdAt: new Date(),
  eventDate: new Date(Date.now() - 86400000),
  ...over,
});
