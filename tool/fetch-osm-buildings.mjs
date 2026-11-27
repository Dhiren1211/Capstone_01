#!/usr/bin/env node
// Downloads the buildings of the Kyungsung University campus from OpenStreetMap
// (Overpass API) so the building positions in lib/utils/ksu_buildings.dart can be
// replaced by real, surveyed coordinates.
//
//   node tool/fetch-osm-buildings.mjs                 # writes tool/osm_buildings.json
//   node tool/fetch-osm-buildings.mjs --radius 900    # search radius in metres (default 700)
//
// Needs Node 18+ and an internet connection; no packages. Data (c) OpenStreetMap
// contributors, ODbL. Please do not run it in a loop - the public Overpass servers
// are shared.
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Google Maps place pin of the campus (Suyeong-ro 309, Nam-gu, Busan).
const CENTER = { lat: 35.1397716, lng: 129.0984966 };

const args = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const radius = Number(arg('--radius', '700'));
const outFile = arg('--out', join(dirname(fileURLToPath(import.meta.url)), 'osm_buildings.json'));

const SERVERS = process.env.OVERPASS_URL
  ? [process.env.OVERPASS_URL]
  : [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];

const around = `(around:${radius},${CENTER.lat},${CENTER.lng})`;
const query = `[out:json][timeout:60];
(
  way["building"]${around};
  relation["building"]${around};
  nwr["name"]["amenity"~"^(university|college|library|parking|dormitory)$"]${around};
  nwr["name"]["leisure"~"^(stadium|pitch|sports_centre|track)$"]${around};
  node["entrance"]${around};
  nwr["barrier"="gate"]${around};
);
out center tags;`;

async function fetchOverpass() {
  let lastError;
  for (const url of SERVERS) {
    try {
      console.log(`Asking ${url} ...`);
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'smartFind-campus-calibration/1.0 (student project)',
        },
        body: 'data=' + encodeURIComponent(query),
        signal: AbortSignal.timeout(90_000),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      if (!Array.isArray(json.elements)) throw new Error('unexpected answer');
      return json;
    } catch (e) {
      lastError = e;
      console.log(`  failed: ${e.message}`);
    }
  }
  throw new Error(`No Overpass server answered (${lastError?.message}). Try again in a minute.`);
}

let data;
try {
  data = await fetchOverpass();
} catch (e) {
  console.error(`\n${e.message}`);
  process.exit(1);
}

const features = [];
const seen = new Set();
for (const el of data.elements) {
  const key = `${el.type}/${el.id}`;
  if (seen.has(key)) continue;
  seen.add(key);
  const lat = el.lat ?? el.center?.lat;
  const lng = el.lon ?? el.center?.lon;
  if (lat == null || lng == null) continue;
  const tags = el.tags ?? {};
  features.push({
    osm: key,
    name: tags.name ?? '',
    name_ko: tags['name:ko'] ?? '',
    name_en: tags['name:en'] ?? '',
    kind: tags.building ?? tags.amenity ?? tags.leisure ?? tags.barrier ?? (tags.entrance ? 'entrance' : ''),
    ref: tags.ref ?? tags['addr:housenumber'] ?? '',
    lat: Number(lat.toFixed(7)),
    lng: Number(lng.toFixed(7)),
  });
}
features.sort((a, b) => (b.name ? 1 : 0) - (a.name ? 1 : 0) || a.name.localeCompare(b.name, 'ko'));

writeFileSync(
  outFile,
  JSON.stringify(
    { source: 'OpenStreetMap via Overpass', fetchedAt: new Date().toISOString(), center: CENTER, radius, features },
    null,
    1,
  ),
);

const named = features.filter((f) => f.name);
console.log(`\n${features.length} features (${named.length} with a name) saved to ${outFile}\n`);
for (const f of named) {
  console.log(`${f.lat.toFixed(6)}, ${f.lng.toFixed(6)}  ${f.kind.padEnd(12)} ${f.name}${f.name_en ? '  /  ' + f.name_en : ''}`);
}
if (features.length === 0) {
  console.log('Nothing found - is the radius too small? Try --radius 1000.');
}
console.log(`\nNext: send ${outFile} back to Claude so the positions can be matched to the building list.`);
