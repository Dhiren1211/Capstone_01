// Shared helpers for the smartFind emulator scripts (Node 18+, no packages).
//
// Environment variables (all optional):
//   PROJECT_ID      default "demo-smartfind"
//   AUTH_HOST       default "127.0.0.1:9099"
//   FIRESTORE_HOST  default "127.0.0.1:8080"

export const PROJECT_ID = process.env.PROJECT_ID || 'demo-smartfind';
export const AUTH_HOST = process.env.AUTH_HOST || '127.0.0.1:9099';
export const FIRESTORE_HOST = process.env.FIRESTORE_HOST || '127.0.0.1:8080';

const API_KEY = 'fake-api-key'; // the emulator accepts any key

export function fail(message) {
  console.error(`\n✗ ${message}\n`);
  process.exit(1);
}

/** Exits with a helpful message when the emulators are not running. */
export async function assertEmulatorsRunning() {
  for (const [name, host] of [
    ['Auth emulator', AUTH_HOST],
    ['Firestore emulator', FIRESTORE_HOST],
  ]) {
    try {
      await fetch(`http://${host}/`, { signal: AbortSignal.timeout(4000) });
    } catch {
      fail(
        `${name} is not reachable at http://${host}.\n` +
          '  Start the emulators first, in another terminal:\n' +
          '      firebase emulators:start\n' +
          '  (run it from the project folder; wait until it prints "All emulators ready!")',
      );
    }
  }
}

async function authPost(path, body, headers = {}) {
  const res = await fetch(`http://${AUTH_HOST}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(json?.error?.message || `HTTP ${res.status}`);
    err.code = json?.error?.message;
    throw err;
  }
  return json;
}

/** Creates the account (or signs in when it already exists). */
export async function ensureAccount({ email, password, displayName }) {
  let auth;
  try {
    auth = await authPost(
      `/identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
      { email, password, returnSecureToken: true },
    );
  } catch (e) {
    if (e.code !== 'EMAIL_EXISTS') throw e;
    auth = await authPost(
      `/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
      { email, password, returnSecureToken: true },
    );
  }
  if (displayName) {
    await authPost(
      `/identitytoolkit.googleapis.com/v1/accounts:update?key=${API_KEY}`,
      { idToken: auth.idToken, displayName, returnSecureToken: false },
    );
  }
  return { uid: auth.localId, idToken: auth.idToken };
}

/**
 * Marks [email] as verified in the Auth emulator by "clicking" the
 * verification link the emulator stored (exactly what a real user does with
 * the e-mail). Returns true when a link was found and opened.
 */
export async function verifyEmail(email, idToken) {
  const findLink = async () => {
    const res = await fetch(
      `http://${AUTH_HOST}/emulator/v1/projects/${PROJECT_ID}/oobCodes`,
    );
    const { oobCodes = [] } = await res.json();
    const mine = oobCodes.filter(
      (c) =>
        c.requestType === 'VERIFY_EMAIL' &&
        String(c.email).toLowerCase() === email.toLowerCase(),
    );
    return mine.length ? mine[mine.length - 1].oobLink : null;
  };

  let link = await findLink();
  if (!link && idToken) {
    // Ask the emulator to "send" a verification e-mail, then look again.
    await authPost(
      `/identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${API_KEY}`,
      { requestType: 'VERIFY_EMAIL', idToken },
    );
    link = await findLink();
  }
  if (!link) return false;
  const res = await fetch(link);
  return res.ok;
}

// ----------------------------------------------------------------- Firestore

/** Converts a JS value into the Firestore REST "Value" format. */
export function encode(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  switch (typeof value) {
    case 'string':
      return { stringValue: value };
    case 'boolean':
      return { booleanValue: value };
    case 'number':
      return Number.isInteger(value)
        ? { integerValue: String(value) }
        : { doubleValue: value };
    case 'object':
      if (Array.isArray(value)) {
        return { arrayValue: { values: value.map(encode) } };
      }
      return {
        mapValue: {
          fields: Object.fromEntries(
            Object.entries(value).map(([k, v]) => [k, encode(v)]),
          ),
        },
      };
    default:
      throw new Error(`Unsupported value: ${value}`);
  }
}

/** Creates / replaces a document. "Bearer owner" bypasses the security rules. */
export async function setDoc(path, data) {
  const url =
    `http://${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}` +
    `/databases/(default)/documents/${path}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer owner',
    },
    body: JSON.stringify({
      fields: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, encode(v)]),
      ),
    }),
  });
  if (!res.ok) {
    throw new Error(`Writing ${path} failed: HTTP ${res.status} ${await res.text()}`);
  }
}
