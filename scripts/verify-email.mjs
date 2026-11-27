#!/usr/bin/env node
// Marks an account as "e-mail verified" in the Firebase Auth EMULATOR.
//
// The emulator never sends real e-mails. The app normally verifies new
// accounts automatically in debug mode; use this script if you want to do it
// by hand (or if the automatic step could not reach the emulator).
//
//   node scripts/verify-email.mjs you@ks.ac.kr
//   node scripts/verify-email.mjs --all          (every pending account)
//
// In the app, press "I've verified my e-mail" afterwards (it also checks by
// itself every few seconds).

import { AUTH_HOST, PROJECT_ID, assertEmulatorsRunning, fail } from './_emulator.mjs';

const arg = process.argv[2];
if (!arg || arg === '--help' || arg === '-h') {
  console.log('Usage: node scripts/verify-email.mjs <email>   |   --all');
  process.exit(arg ? 0 : 1);
}

await assertEmulatorsRunning();

const res = await fetch(
  `http://${AUTH_HOST}/emulator/v1/projects/${PROJECT_ID}/oobCodes`,
);
const { oobCodes = [] } = await res.json();
const pending = oobCodes.filter(
  (c) =>
    c.requestType === 'VERIFY_EMAIL' &&
    (arg === '--all' || String(c.email).toLowerCase() === arg.toLowerCase()),
);

if (pending.length === 0) {
  fail(
    arg === '--all'
      ? 'No pending verification e-mails in the emulator.'
      : `No pending verification e-mail for ${arg}.\n` +
          '  Register the account in the app first (or press "Resend e-mail" on the\n' +
          '  verification screen), then run this command again.',
  );
}

// One link per address (the newest one).
const newest = new Map();
for (const c of pending) newest.set(String(c.email).toLowerCase(), c);

for (const [email, code] of newest) {
  const ok = (await fetch(code.oobLink)).ok;
  console.log(`${ok ? '✓' : '✗'} ${email} ${ok ? 'verified' : 'could not be verified'}`);
}
