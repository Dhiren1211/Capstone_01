#!/usr/bin/env node
// Turns the OpenStreetMap download (tool/osm_buildings.json, made by
// fetch-osm-buildings.mjs) into surveyed building positions that the app loads
// at start-up (assets/data/building_positions.json).
//
//   node tool/apply-osm-buildings.mjs               # match + write the file
//   node tool/apply-osm-buildings.mjs --dry-run     # only print the report
//   node tool/apply-osm-buildings.mjs --snap 40     # also snap unnamed building
//                                                   # outlines within 40 m
//   node tool/apply-osm-buildings.mjs --max-shift 250
//
// How a building is matched to an OSM feature (first rule that fits wins):
//   1. the OSM `ref` / house number equals the building number AND the name
//      shares a word with it,
//   2. the English name (name:en / name) shares all its distinctive words,
//   3. a Korean alias from tool/building_aliases.json
//      ({"Hansung Building": ["한성관"]}) equals the OSM name,
//   4. with --snap: the only OSM building outline within N metres of the
//      current approximate position.
// A match more than --max-shift metres (default 250) away from the current
// approximate position is rejected as a probable mix-up.
//
// Nothing is guessed: buildings without a match keep their built-in position
// and are listed at the end. For the last metres you can also edit
// assets/data/building_positions.json by hand: stand at the entrance, long-
// press the spot in Google Maps, and copy the two numbers shown.
//
// No packages needed (Node 18+).
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const num = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] !== undefined ? Number(args[i + 1]) : fallback;
};
const dryRun = flag('--dry-run');
const maxShift = num('--max-shift', 250);
const snap = num('--snap', 0);

const osmFile = join(here, 'osm_buildings.json');
const outFile = join(root, 'assets', 'data', 'building_positions.json');
const aliasFile = join(here, 'building_aliases.json');

if (!existsSync(osmFile)) {
  console.error('tool/osm_buildings.json not found. Run first:\n  node tool/fetch-osm-buildings.mjs');
  process.exit(1);
}

// --- the app's own building list (parsed from the Dart source) --------------
const dart = readFileSync(join(root, 'lib', 'utils', 'ksu_buildings.dart'), 'utf8');
const buildings = [];
const re =
  /KsuBuilding\(\s*number:\s*(\d+),\s*name:\s*'((?:[^'\\]|\\.)*)',\s*latitude:\s*(-?[\d.]+),\s*longitude:\s*(-?[\d.]+)/g;
for (const m of dart.matchAll(re)) {
  buildings.push({
    number: Number(m[1]),
    name: m[2].replace(/\\'/g, "'"),
    lat: Number(m[3]),
    lng: Number(m[4]),
  });
}
if (buildings.length === 0) {
  console.error('Could not read the building list from lib/utils/ksu_buildings.dart.');
  process.exit(1);
}

const osm = JSON.parse(readFileSync(osmFile, 'utf8'));
const features = osm.features ?? [];
const aliases = existsSync(aliasFile) ? JSON.parse(readFileSync(aliasFile, 'utf8')) : {};

// --- helpers ----------------------------------------------------------------
const toRad = (d) => (d * Math.PI) / 180;
function meters(aLat, aLng, bLat, bLng) {
  const R = 6371008.8;
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

const NOISE = new Set(['building', 'hall', 'the', 'of', 'and', 'bldg', 'no', 'university', 'ksu']);
const ROMAN = { i: '1', ii: '2', iii: '3', iv: '4' };
function words(s) {
  return String(s ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9ㄱ-ㆎ가-힣 ]+/g, ' ')
    .split(/\s+/)
    .filter(Boolean)
    .map((w) => ROMAN[w] ?? w)
    .filter((w) => !NOISE.has(w));
}
const sameName = (a, b) => String(a ?? '').replace(/\s+/g, '') === String(b ?? '').replace(/\s+/g, '') && a;

function englishNames(f) {
  return [f.name_en, /[a-z]/i.test(f.name) ? f.name : ''].filter(Boolean);
}

function matchBuilding(b) {
  const bw = words(b.name);
  const own = features.filter((f) => meters(b.lat, b.lng, f.lat, f.lng) <= maxShift);

  // 1. same number + shared word
  for (const f of own) {
    if (String(f.ref).trim() === String(b.number)) {
      const fw = new Set(englishNames(f).flatMap(words));
      if (bw.some((w) => fw.has(w))) return { f, rule: 'number + name' };
    }
  }
  // 2. English name contains all distinctive words
  for (const f of own) {
    for (const n of englishNames(f)) {
      const fw = new Set(words(n));
      if (bw.length > 0 && bw.every((w) => fw.has(w)) && fw.size <= bw.length + 1) {
        return { f, rule: 'English name' };
      }
    }
  }
  // 3. Korean alias
  const list = aliases[b.name] ?? [];
  for (const f of own) {
    if (list.some((a) => sameName(a, f.name) || sameName(a, f.name_ko))) return { f, rule: 'alias' };
  }
  // 4. snap to the single building outline close by
  if (snap > 0) {
    const near = features.filter(
      (f) => !f.name && f.kind && !['entrance', 'gate'].includes(f.kind) && meters(b.lat, b.lng, f.lat, f.lng) <= snap,
    );
    if (near.length === 1) return { f: near[0], rule: `only outline within ${snap} m` };
  }
  return null;
}

// --- run --------------------------------------------------------------------
const existing = existsSync(outFile) ? JSON.parse(readFileSync(outFile, 'utf8')) : {};
const positions = { ...(existing.positions ?? {}) };

const matched = [];
const unmatched = [];
const usedFeatures = new Map();
for (const b of buildings) {
  const hit = matchBuilding(b);
  if (!hit) {
    unmatched.push(b);
    continue;
  }
  const shift = meters(b.lat, b.lng, hit.f.lat, hit.f.lng);
  matched.push({ b, hit, shift });
  const key = hit.f.osm;
  usedFeatures.set(key, [...(usedFeatures.get(key) ?? []), b.name]);
}

console.log(`${buildings.length} buildings, ${features.length} OSM features\n`);
console.log('MATCHED');
for (const { b, hit, shift } of matched) {
  const shared = usedFeatures.get(hit.f.osm).length > 1 ? '  (shared outline - check)' : '';
  console.log(
    `  No.${String(b.number).padEnd(3)} ${b.name.padEnd(42)} -> ${hit.f.lat.toFixed(7)}, ${hit.f.lng.toFixed(7)}` +
      `  [${hit.rule}, moves ${shift.toFixed(0)} m]${shared}`,
  );
}
console.log('\nNOT MATCHED (built-in approximate position stays)');
for (const b of unmatched) console.log(`  No.${String(b.number).padEnd(3)} ${b.name}`);

if (matched.length === 0) {
  console.log('\nNothing matched, so nothing was written.');
  console.log('Add Korean names to tool/building_aliases.json, or try --snap 40, then run again.');
  process.exit(0);
}

for (const { b, hit } of matched) positions[b.name] = [hit.f.lat, hit.f.lng];

if (dryRun) {
  console.log('\n--dry-run: nothing was written.');
} else {
  writeFileSync(
    outFile,
    JSON.stringify(
      {
        version: 1,
        note: 'Surveyed building positions. Generate with: node tool/fetch-osm-buildings.mjs && node tool/apply-osm-buildings.mjs',
        source: 'OpenStreetMap contributors (ODbL), matched by tool/apply-osm-buildings.mjs',
        generatedAt: new Date().toISOString(),
        positions,
      },
      null,
      2,
    ) + '\n',
  );
  console.log(`\nWrote ${matched.length} positions to assets/data/building_positions.json`);
  console.log('Restart the app (full restart, not hot reload) to load them.');
}
