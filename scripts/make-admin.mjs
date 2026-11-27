#!/usr/bin/env node
// Gives an existing account the admin role in the Firebase EMULATORS.
//
//   node scripts/make-admin.mjs someone@ks.ac.kr
//
// The person must have signed up in the app first. They see
// "Profile → Admin panel" right away (no restart needed).
//
// For the REAL (cloud) project, do the same by hand once:
//   Firebase console → Authentication → copy the person's User UID
//   Firebase console → Firestore → Start collection "admins"
//     → Document ID = that UID → add a field  email (string) = their e-mail
// After that first admin exists, further admins are added from the panel.

import { assertEmulatorsRunning, setDoc, AUTH_HOST, PROJECT_ID, fail } from './_emulator.mjs';

const email = (process.argv[2] || '').trim().toLowerCase();
if (!email.includes('@')) fail('Usage: node scripts/make-admin.mjs <email>');

await assertEmulatorsRunning();

const res = await fetch(
  `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:lookup`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
    body: JSON.stringify({ email: [email] }),
  },
);
const json = await res.json().catch(() => ({}));
const user = json.users?.[0];
if (!user) fail(`No account with the e-mail ${email}. Sign up in the app first.`);

await setDoc(`admins/${user.localId}`, {
  email,
  displayName: user.displayName || email.split('@')[0],
  addedBy: 'make-admin script',
  addedAt: new Date(),
});
console.log(`✓ ${email} (${user.localId}) is now an admin.`);
