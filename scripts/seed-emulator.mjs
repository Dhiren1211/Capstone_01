#!/usr/bin/env node
// Fills the Firebase EMULATORS with demo accounts and sample reports.
//
//   1. firebase emulators:start          (leave it running)
//   2. node scripts/seed-emulator.mjs    (this script)
//
// Safe to run repeatedly: accounts are re-used and sample items are
// overwritten in place. Needs Node 18+ and no npm packages.
//
// Demo accounts (all e-mail-verified):
//   demo@ks.ac.kr    / Demo1234!      "Demo Student"
//   finder@ks.ac.kr  / Finder1234!    "Min-jun Kim"
//   owner@ks.ac.kr   / Owner1234!     "Seo-yeon Park"
//   admin@ks.ac.kr   / Admin1234!     "smartFind Admin"  (has the admin panel)

import {
  ensureAccount,
  verifyEmail,
  setDoc,
  assertEmulatorsRunning,
  AUTH_HOST,
  FIRESTORE_HOST,
  PROJECT_ID,
  fail,
} from './_emulator.mjs';

await assertEmulatorsRunning();
console.log(`Seeding project "${PROJECT_ID}" (auth ${AUTH_HOST}, firestore ${FIRESTORE_HOST})\n`);

// ------------------------------------------------------------------ accounts
const people = [
  { key: 'demo', email: 'demo@ks.ac.kr', password: 'Demo1234!', name: 'Demo Student', studentId: '2024000001' },
  { key: 'finder', email: 'finder@ks.ac.kr', password: 'Finder1234!', name: 'Min-jun Kim', studentId: '2023000042' },
  { key: 'owner', email: 'owner@ks.ac.kr', password: 'Owner1234!', name: 'Seo-yeon Park', studentId: '2022000318' },
  { key: 'admin', email: 'admin@ks.ac.kr', password: 'Admin1234!', name: 'smartFind Admin', studentId: '' },
];

const uid = {};
for (const p of people) {
  try {
    const { uid: id, idToken } = await ensureAccount({
      email: p.email,
      password: p.password,
      displayName: p.name,
    });
    uid[p.key] = id;
    const verified = await verifyEmail(p.email, idToken);
    await setDoc(`users/${id}`, {
      email: p.email,
      displayName: p.name,
      avatarUrl: '',
      studentId: p.studentId,
      createdAt: new Date(),
      postsCount: 0, // corrected below
      savedItemIds: [],
    });
    console.log(`✓ account ${p.email}  (${verified ? 'verified' : 'verification pending'})`);
  } catch (e) {
    fail(`Could not create ${p.email}: ${e.message}`);
  }
}

// --------------------------------------------------------------------- items
// Approximate Kyungsung University building positions (see lib/utils/ksu_buildings.dart).
const where = {
  library: ['Central Library Building', 35.138248, 129.099623],
  hansung: ['Hansung Building', 35.138881, 129.096791],
  science: ['Natural Sciences Building', 35.139427, 129.098617],
  union: ['Student Union Building I', 35.137710, 129.098496],
  eng1: ['Engineering Building I', 35.142071, 129.100751],
  arts: ['Arts Building', 35.138871, 129.096048],
  gate: ['Front Gate', 35.136999, 129.097011],
  commerce: ['Commerce Building', 35.140069, 129.095647],
};

const daysAgo = (n, hour = 12) => {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(hour, 0, 0, 0);
  return d;
};

const items = [
  ['lost', 'owner', 'Black Backpack', 'electronics', 'library', 0,
    'Black Nike backpack with a laptop inside and a blue keychain on the zipper. Left on the second-floor reading desk.'],
  ['found', 'finder', 'Black Nike Backpack', 'bags', 'library', 0,
    'Found a black Nike backpack with a blue keychain on a desk on the second floor of the library. Handed in at the front desk.'],
  ['lost', 'owner', 'AirPods Pro Case', 'electronics', 'hansung', 1,
    'White AirPods Pro charging case with a small scratch on the lid and a green sticker.'],
  ['found', 'finder', 'Student ID Card', 'wallets', 'union', 1,
    'Kyungsung student ID card found near the cafeteria entrance. Name starts with K.'],
  ['lost', 'demo', 'Silver Water Bottle', 'other', 'science', 2,
    'Silver Hydro Flask bottle with a few stickers (a cat and a mountain). Lost after the chemistry lecture.'],
  ['found', 'owner', 'Blue Umbrella', 'other', 'arts', 2,
    'Large navy umbrella with a wooden handle left beside the Arts Building door.'],
  ['lost', 'finder', 'Calculus Textbook', 'books', 'eng1', 3,
    'Thomas Calculus 14th edition with yellow highlights and my name written inside the cover.'],
  ['found', 'demo', 'Set of Keys', 'keys', 'gate', 3,
    'Three keys on a red lanyard with a small Totoro charm, found next to the front gate.'],
  ['lost', 'owner', 'Prescription Glasses', 'accessories', 'commerce', 4,
    'Thin black-frame glasses in a brown leather case.'],
  ['found', 'finder', 'Wireless Mouse', 'electronics', 'hansung', 5,
    'Logitech wireless mouse (grey) found in room 301.'],
];

const counts = {};
let n = 0;
for (const [status, who, title, category, place, ago, description] of items) {
  const person = people.find((p) => p.key === who);
  const [location, lat, lng] = where[place];
  n += 1;
  counts[who] = (counts[who] || 0) + 1;
  const when = daysAgo(ago, 9 + (n % 8));
  await setDoc(`items/seed-${String(n).padStart(2, '0')}`, {
    title,
    description,
    category,
    status,
    location,
    latitude: lat,
    longitude: lng,
    reporterId: uid[who],
    reporterName: person.name,
    contactInfo: person.email,
    imageUrl: '',
    reunited: false,
    availabilitySchedule: 'Weekdays 12:00 – 13:00',
    pickupLocation: location,
    meetBuilding: location,
    preferredContactMethod: 'chat',
    createdAt: when,
    updatedAt: when,
    eventDate: when,
  });
}
console.log(`✓ ${items.length} sample reports`);

// keep the "posts" counters honest
for (const p of people) {
  await setDoc(`users/${uid[p.key]}`, {
    email: p.email,
    displayName: p.name,
    avatarUrl: '',
    studentId: p.studentId,
    createdAt: new Date(),
    postsCount: counts[p.key] || 0,
    savedItemIds: [],
  });
}

await setDoc(`admins/${uid.admin}`, {
  email: 'admin@ks.ac.kr',
  displayName: 'smartFind Admin',
  addedBy: 'seed',
  addedAt: new Date(),
});
console.log('✓ admin role for admin@ks.ac.kr');

console.log(`
Done. Sign in on the app with e.g.
    demo@ks.ac.kr   /  Demo1234!
    admin@ks.ac.kr  /  Admin1234!   (Profile → Admin panel)
Emulator UI: http://${AUTH_HOST.split(':')[0]}:4000
`);
