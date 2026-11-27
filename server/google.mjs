// Small, dependency-free helpers for talking to Google APIs from a Cloudflare
// Worker (or Node 20+): Firebase ID-token verification, service-account OAuth,
// Firestore REST and FCM HTTP v1.

const enc = new TextEncoder();

export const b64urlToBytes = (s) => {
  const pad = '='.repeat((4 - (s.length % 4)) % 4);
  const bin = atob(s.replace(/-/g, '+').replace(/_/g, '/') + pad);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
};
export const bytesToB64url = (bytes) => {
  let bin = '';
  for (const b of new Uint8Array(bytes)) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
const jsonB64url = (obj) => bytesToB64url(enc.encode(JSON.stringify(obj)));
const decodeJson = (part) => JSON.parse(new TextDecoder().decode(b64urlToBytes(part)));

// ------------------------------------------------------------------ ID tokens

const JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
let jwksCache = { keys: null, until: 0 };

async function loadJwks(fetchFn) {
  const now = Date.now();
  if (jwksCache.keys && jwksCache.until > now) return jwksCache.keys;
  const res = await fetchFn(JWKS_URL);
  if (!res.ok) throw new HttpError(503, 'Could not load Firebase signing keys.');
  const body = await res.json();
  const maxAge = Number(/max-age=(\d+)/.exec(res.headers.get('cache-control') ?? '')?.[1] ?? 3600);
  jwksCache = { keys: body.keys ?? [], until: now + Math.min(maxAge, 6 * 3600) * 1000 };
  return jwksCache.keys;
}

export function resetCaches() {
  jwksCache = { keys: null, until: 0 };
  tokenCache = { token: null, until: 0 };
}

export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/**
 * Verifies a Firebase ID token. Returns its claims, or throws HttpError(401).
 * https://firebase.google.com/docs/auth/admin/verify-id-tokens#verify_id_tokens_using_a_third-party_jwt_library
 */
export async function verifyIdToken(token, projectId, { fetchFn = fetch, now = Date.now() } = {}) {
  const parts = String(token ?? '').split('.');
  if (parts.length !== 3) throw new HttpError(401, 'Invalid sign-in token.');
  let header;
  let claims;
  try {
    header = decodeJson(parts[0]);
    claims = decodeJson(parts[1]);
  } catch {
    throw new HttpError(401, 'Invalid sign-in token.');
  }
  if (header.alg !== 'RS256' || !header.kid) throw new HttpError(401, 'Invalid sign-in token.');

  const keys = await loadJwks(fetchFn);
  const jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new HttpError(401, 'Unknown signing key.');
  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const ok = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    b64urlToBytes(parts[2]),
    enc.encode(`${parts[0]}.${parts[1]}`),
  );
  if (!ok) throw new HttpError(401, 'Invalid sign-in token.');

  const sec = Math.floor(now / 1000);
  if (claims.aud !== projectId || claims.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new HttpError(401, 'This token belongs to another Firebase project.');
  }
  if (!claims.sub || typeof claims.sub !== 'string') throw new HttpError(401, 'Invalid sign-in token.');
  if (!(claims.exp > sec)) throw new HttpError(401, 'The sign-in token has expired.');
  if (claims.iat > sec + 300) throw new HttpError(401, 'Invalid sign-in token.');
  if (claims.email_verified !== true) throw new HttpError(403, 'Verify your e-mail address first.');
  return claims;
}

// ----------------------------------------------------- service account OAuth

let tokenCache = { token: null, until: 0 };

function pemToDer(pem) {
  const body = pem.replace(/-----[A-Z ]+-----/g, '').replace(/\s+/g, '');
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

export async function accessToken(serviceAccount, { fetchFn = fetch, now = Date.now() } = {}) {
  if (tokenCache.token && tokenCache.until > now) return tokenCache.token;
  const iat = Math.floor(now / 1000);
  const header = jsonB64url({ alg: 'RS256', typ: 'JWT' });
  const claims = jsonB64url({
    iss: serviceAccount.client_email,
    scope:
      'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',
    aud: serviceAccount.token_uri || 'https://oauth2.googleapis.com/token',
    iat,
    exp: iat + 3600,
  });
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(`${header}.${claims}`));
  const assertion = `${header}.${claims}.${bytesToB64url(sig)}`;

  const res = await fetchFn(serviceAccount.token_uri || 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) throw new HttpError(502, `Google rejected the service account (${res.status}).`);
  const body = await res.json();
  tokenCache = { token: body.access_token, until: now + (Number(body.expires_in ?? 3600) - 120) * 1000 };
  return tokenCache.token;
}

// ------------------------------------------------------------------ Firestore

export function toValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, toValue(x)])) } };
}

export function fromValue(v) {
  if (!v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(fromValue);
  if ('mapValue' in v) return fromFields(v.mapValue.fields ?? {});
  return null;
}

export const fromFields = (fields) =>
  Object.fromEntries(Object.entries(fields ?? {}).map(([k, v]) => [k, fromValue(v)]));

export const docId = (name) => String(name).split('/').pop();

export function firestore({ projectId, token, fetchFn = fetch }) {
  const root = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  const headers = { authorization: `Bearer ${token}`, 'content-type': 'application/json' };

  return {
    /** Returns { id, ...fields } or null when the document does not exist. */
    async get(path) {
      const res = await fetchFn(`${root}/${path}`, { headers });
      if (res.status === 404) return null;
      if (!res.ok) throw new HttpError(502, `Firestore read failed (${res.status}).`);
      const doc = await res.json();
      return { id: docId(doc.name), ...fromFields(doc.fields) };
    },

    /** structuredQuery against a collection (optionally below `parent`). */
    async query(structuredQuery, parent = '') {
      const res = await fetchFn(`${root}${parent ? `/${parent}` : ''}:runQuery`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ structuredQuery }),
      });
      if (!res.ok) throw new HttpError(502, `Firestore query failed (${res.status}).`);
      const rows = await res.json();
      return rows.filter((r) => r.document).map((r) => ({ id: docId(r.document.name), ...fromFields(r.document.fields) }));
    },

    /** Creates a document with a fixed id. Returns false when it already exists. */
    async create(collection, id, data) {
      const res = await fetchFn(`${root}/${collection}?documentId=${encodeURIComponent(id)}`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, toValue(v)])) }),
      });
      if (res.status === 409) return false;
      if (!res.ok) throw new HttpError(502, `Firestore write failed (${res.status}).`);
      return true;
    },

    /** Replaces one array field of a document. */
    async setArray(path, field, values) {
      const res = await fetchFn(`${root}/${path}?updateMask.fieldPaths=${field}`, {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ fields: { [field]: toValue(values) } }),
      });
      if (!res.ok) throw new HttpError(502, `Firestore update failed (${res.status}).`);
    },
  };
}

// ------------------------------------------------------------------------ FCM

/**
 * Sends one notification message. Returns 'sent' | 'invalid' (token should be
 * removed) | 'failed'.
 */
export async function sendPush({ projectId, token, fetchFn = fetch }, deviceToken, message) {
  const res = await fetchFn(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      message: {
        token: deviceToken,
        notification: { title: message.title, body: message.body },
        data: message.data ?? {},
        android: {
          priority: 'HIGH',
          notification: {
            channel_id: message.channelId ?? 'smartfind_matches',
            sound: 'default',
            default_vibrate_timings: true,
            notification_priority: 'PRIORITY_MAX',
            visibility: 'PUBLIC',
          },
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: { aps: { sound: 'default', 'interruption-level': 'time-sensitive' } },
        },
      },
    }),
  });
  if (res.ok) return 'sent';
  if (res.status === 404 || res.status === 400) {
    const text = await res.text();
    if (/UNREGISTERED|registration-token-not-registered|not a valid FCM registration token/.test(text)) return 'invalid';
  }
  return 'failed';
}
