// JavaScript twin of lib/matching/match_engine.dart. Both read the same tables
// (shared/match_data.json) and are checked against the same test cases
// (test/fixtures/match_cases.json). Change them together.
import { MATCH_DATA as D } from './match_data.mjs';

export const THRESHOLD = D.threshold;
export const AI_BLEND = D.aiBlend;
export const AI_MIN_RULE_SCORE = D.aiMinRuleScore;
export const MAX_NOTIFICATIONS_PER_ITEM = D.maxNotificationsPerItem;

const stopwords = new Set(D.stopwords);
const colors = new Set(D.colors);
const generic = new Set(D.generic);
const nonWord = /[^\p{L}\p{N}\s]/gu;
const boundary = /(?<=\p{L})(?=\p{N})|(?<=\p{N})(?=\p{L})/gu;
const hangul = /\p{Script=Hangul}/u;
const digits = /^\d+$/;

const runeLength = (s) => Array.from(s).length;

function weightOf(token) {
  if (colors.has(token)) return D.tokenWeights.color;
  if (generic.has(token)) return D.tokenWeights.generic;
  if (digits.test(token)) return D.tokenWeights.number;
  return D.tokenWeights.default;
}

function stripKoreanSuffix(token) {
  if (token in D.aliasToCanon) return token;
  let best = null;
  for (const s of D.koreanSuffixes) {
    if (token.endsWith(s) && (best === null || s.length > best.length)) best = s;
  }
  if (best === null) return token;
  const rest = token.slice(0, token.length - best.length);
  const n = runeLength(rest);
  if (n >= 2 || (n === 1 && rest in D.aliasToCanon)) return rest;
  return token;
}

export function tokenize(text, ignore = new Set()) {
  const out = new Map();
  const put = (token) => {
    const w = weightOf(token);
    const old = out.get(token);
    if (old === undefined || w > old) out.set(token, w);
  };
  const cleaned = String(text ?? '')
    .toLowerCase()
    .replace(nonWord, ' ')
    .replace(boundary, ' ');
  for (const raw of cleaned.split(/\s+/)) {
    if (!raw) continue;
    let token = raw;
    if (hangul.test(token)) token = stripKoreanSuffix(token);
    if (stopwords.has(token) || stopwords.has(raw)) continue;
    let canon = D.aliasToCanon[token];
    if (canon === undefined) {
      if (runeLength(token) < 2) continue;
      canon = token;
    }
    if (ignore.has(canon)) continue;
    put(canon);
    for (const e of D.expansions[canon] ?? []) put(e);
  }
  return out;
}

function locationWords(location) {
  const out = new Set();
  for (const k of tokenize(location).keys()) {
    if (!(k in D.aliasToCanon)) out.add(k);
  }
  return out;
}

const total = (m) => {
  let s = 0;
  for (const v of m.values()) s += v;
  return s;
};

// Per-token facts, computed once (the fuzzy comparison below asks for them
// many times). Cleared when it grows, so a long-lived isolate stays small.
const infoCache = new Map();
function info(token) {
  let v = infoCache.get(token);
  if (v) return v;
  const chars = Array.from(token);
  const grams = new Set();
  for (let i = 0; i + 1 < chars.length; i++) grams.add(chars[i] + chars[i + 1]);
  v = { len: chars.length, digit: digits.test(token), hangul: hangul.test(token), grams };
  if (infoCache.size > 20000) infoCache.clear();
  infoCache.set(token, v);
  return v;
}

function fuzzyEqual(x, y) {
  const a = info(x);
  const b = info(y);
  if (a.digit || b.digit) return false;
  if (a.hangul && b.hangul) {
    return a.len >= 2 && b.len >= 2 && (x.includes(y) || y.includes(x));
  }
  if (a.len < 4 || b.len < 4) return false;
  if (Math.abs(a.len - b.len) > Math.max(a.len, b.len) * 0.34) return false; // cannot reach 0.8
  if (a.grams.size === 0 || b.grams.size === 0) return false;
  let inter = 0;
  for (const g of a.grams) if (b.grams.has(g)) inter++;
  return (2 * inter) / (a.grams.size + b.grams.size) >= 0.8;
}

export function softSimilarity(a, b) {
  if (a.size === 0 || b.size === 0) return 0;
  const aSmall = total(a) <= total(b);
  const small = aSmall ? a : b;
  const large = aSmall ? b : a;
  const used = new Set();
  const exact = new Set();
  let matched = 0;
  for (const [k, v] of small) {
    const other = large.get(k);
    if (other !== undefined) {
      matched += Math.min(v, other);
      used.add(k);
      exact.add(k);
    }
  }
  for (const [k, v] of small) {
    if (exact.has(k)) continue;
    for (const [j, w] of large) {
      if (used.has(j)) continue;
      if (fuzzyEqual(k, j)) {
        matched += 0.8 * Math.min(v, w);
        used.add(j);
        break;
      }
    }
  }
  const wSmall = total(small);
  const wLarge = total(large);
  return 0.6 * (matched / wSmall) + 0.4 * (matched / (wSmall + wLarge - matched));
}

export function categorySimilarity(a, b) {
  const x = String(a ?? '').trim().toLowerCase();
  const y = String(b ?? '').trim().toLowerCase();
  if (x === y) return 1;
  if (x === 'other' || y === 'other' || !x || !y) return 0.5;
  for (const [p, q] of D.relatedCategories) {
    if ((p === x && q === y) || (p === y && q === x)) return 0.35;
  }
  return 0;
}

export function locationSimilarity(a, b, meters) {
  const na = String(a ?? '').trim().toLowerCase();
  const nb = String(b ?? '').trim().toLowerCase();
  if (na && na === nb) return 1;
  if (meters <= 40) return 0.95;
  if (meters <= 100) return 0.8;
  if (meters <= 200) return 0.6;
  if (meters <= 400) return 0.35;
  if (meters <= 800) return 0.12;
  return 0;
}

const DAY_MS = 86400000;
const KST_OFFSET_MS = 9 * 3600 * 1000; // the campus is on Korean Standard Time
const kstDay = (d) => Math.floor((d.getTime() + KST_OFFSET_MS) / DAY_MS);

export function dateSimilarity(lost, found) {
  const days = kstDay(found) - kstDay(lost);
  if (days < -1) return 0.15;
  if (days <= 3) return 1;
  return Math.max(0, 1 - (days - 3) / 18);
}

export function distanceMeters(lat1, lng1, lat2, lng2) {
  const r = 6371000;
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

export function isCandidate(a, b) {
  if (a.id === b.id) return false;
  if (a.reunited || b.reunited) return false;
  if (a.reporterId === b.reporterId) return false;
  const kinds = new Set([a.status, b.status]);
  return kinds.size === 2 && kinds.has('lost') && kinds.has('found');
}

/**
 * Tokenises one report once, so that scoring it against many candidates does
 * not repeat that work (matters on the Worker's tiny CPU budget).
 */
export function prepare(p) {
  const ignore = locationWords(p.location);
  return {
    p,
    title: tokenize(p.title, ignore),
    full: tokenize(`${p.title} ${p.description}`, ignore),
  };
}

/** a, b: { id, reporterId, status, category, title, description, location, latitude, longitude, eventDate: Date } */
export function score(a, b) {
  return scorePrepared(prepare(a), prepare(b));
}

export function scorePrepared(pa, pb) {
  const a = pa.p;
  const b = pb.p;
  const title = softSimilarity(pa.title, pb.title);
  const description = softSimilarity(pa.full, pb.full);
  const category = categorySimilarity(a.category, b.category);
  const dist = distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);
  const location = locationSimilarity(a.location, b.location, dist);
  const lost = a.status === 'lost' ? a : b;
  const found = a.status === 'lost' ? b : a;
  const date = dateSimilarity(lost.eventDate, found.eventDate);

  const w = D.weights;
  const totalScore =
    w.title * title +
    w.description * description +
    w.category * category +
    w.location * location +
    w.date * date;
  return {
    title,
    description,
    category,
    location,
    date,
    ruleScore: Math.round(totalScore * 100),
    distanceMeters: dist,
  };
}

export function blend(ruleScore, aiScore) {
  const ai = Math.min(100, Math.max(0, aiScore));
  return Math.round((1 - AI_BLEND) * ruleScore + AI_BLEND * ai);
}

export function reasons(b) {
  const r = [
    [b.title, 'similar title'],
    [b.description, 'similar description'],
    [b.category, 'same category'],
    [b.location, 'close location'],
    [b.date, 'close in time'],
  ];
  r.sort((x, y) => y[0] - x[0]);
  return r.filter((e) => e[0] >= 0.6).map((e) => e[1]);
}
