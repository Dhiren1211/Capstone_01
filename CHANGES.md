# Audit report and change log

What was found in the uploaded `smartfind.zip`, what was changed, and why.
Run instructions are in [`README.md`](README.md).

## 0. Second round: redesign, matching, alerts (latest)

This round answers the request for a polished, fully functional app. In short:

| Area | What changed |
|---|---|
| **Design** | New design system (`lib/theme`, `lib/widgets`): ink-navy primary with a single bronze accent on a warm paper background, bundled Poppins, no gradients and no emoji, light **and dark** theme (Settings), reduce-motion-aware animations. Every screen was rebuilt on it: splash, onboarding, login, sign-up, verification, home, search, map, building details, report form, item details, chats, notifications, profile, settings, legal pages. Scrolling bodies, flexible text and bounded sheets are used everywhere to prevent overflow errors. |
| **Demo removed** | The "Try Demo" button, the anonymous sessions and `ENABLE_DEMO_LOGIN` are gone; the rules deny anonymous sessions entirely. |
| **Search bug** | Searching and going back to Home showed the search result. Cause: one shared, filtered feed. Now `ItemsState` holds the unfiltered feed and every screen applies its own `ItemFilter` (unit-tested). |
| **Buildings** | The drop-down shows *building number + name* (name in smaller text). Each building has a **details page** (description, number, category, coordinates and whether they are surveyed, reports at the building, directions, report here, Campus VR). The map card keeps its pop-up and gains a *View details* button. |
| **Where can you be found?** | New report fields: meeting building, room/spot, availability, preferred contact method and details. Shown on the report as "Where to find {name}". |
| **Matching (70 %)** | `MatchEngine` (title 28 / description 22 / category 15 / location 25 / date 10, EN + KR synonyms, digits must match) with a 70 threshold, identical in Dart and in the server (generated from `shared/match_data.json`). Works without any AI. Optional OpenRouter free-model second opinion (45 % weight, text and photos, automatic text-only retry, falls back to the rules). Unit-tested on both sides. |
| **Notifications** | Firebase Cloud Messaging push through a small Cloudflare Worker (`server/`) for closed apps; on-device pop-ups (`flutter_local_notifications`) while the app runs; message pop-ups; Android 13 permission, channels, deep links on tap, token cleanup on log-out. The notification list shows the **whole message wrapped** and opens a side-by-side comparison. |
| **Map accuracy** | Pins can now be replaced by surveyed positions (`assets/data/building_positions.json`, produced by `tool/fetch-osm-buildings.mjs` + `tool/apply-osm-buildings.mjs`). Honest limit: the shipped positions are approximate (about 100 m); 2 m needs surveyed data and phone GPS itself is rarely better than 3-10 m. |
| **Campus VR** | In-app WebView of the university's VR tour with a progress bar, error state and "open in browser" fallback. |
| **Dependencies** | No deprecated APIs (`withOpacity`, `WillPopScope`, `MaterialState*`, old `Radio` API, `textScaleFactor` are not used); version ranges follow the newest majors that share one API. |
| **Rules** | `meetBuilding` was missing from the item whitelist (new reports would have been rejected): fixed. Added push-token storage, `otherItemId`/`score` for notifications, and an ownership check so a stranger cannot forge match alerts about someone else's report. |
| **Tooling** | `tool/setup.dart` now also handles desugaring, notification permission, alert channel, Google services plugin (when `google-services.json` exists) and the iOS background mode, and checks `MATCH_API_URL`. |

Sections 1-8 below describe the first round (audit and repair). Where a
statement there was overtaken by this round, it is marked **(superseded)**.

---

## 1. Summary

The original project could not be built, and — more importantly — its backend
was open: anybody could read the verification codes and student records, and the
"verification" could be completed by reading the code out of the database. The
code base has been reworked so that it compiles (static analysis is clean), is
secured with real Firestore rules, no longer depends on Firebase Storage
(photos go to Cloudinary's free plan), and can be set up with a handful of
commands.

## 2. Errors found (build-breaking)

Against the current plugin versions the original had dozens of compile errors,
for example:

| Where | Problem |
|---|---|
| `student_auth_service.dart` | Called `String.padStart` — that method does not exist in Dart (`padLeft`). |
| `chat_detail_screen.dart`, `profile_screen.dart` | Syntax errors (`AppColors.` with no member name). |
| `notifications_screen.dart`, `bottom_nav_bar.dart` | `context` used where no `BuildContext` was in scope. |
| `app.dart`, `main_shell.dart` | Called methods that do not exist (`markOnboardingSeen`, `context.findAncestorState`). |
| `forgot_password_screen.dart` | `AuthState.sendPasswordReset` did not exist. |
| `campus_map_screen.dart` | flutter_map 8 API changes (`maxBounds`, `StrokePattern`), geolocator's removed `desiredAccuracy`, nullable arithmetic. |
| `settings_screen.dart` | Passed a `WidgetStateProperty` where a `Color` was required. |
| `ksu_buildings.dart` | `Icons.door_front_rounded` does not exist. |
| `saved_items_screen.dart` | Type error (`String` passed where `List<String>` is needed). |
| `android/`, `ios/` | Partial scaffolds with a stale package id and an unusable iOS icon set. |

## 3. Security and privacy risks found

| Risk | Fix |
|---|---|
| `verification_codes` and `students` collections were **world-readable / world-writable** (`allow read, write: if true`). The sign-in code was even shown in the UI. Anyone could take over any student account. | Removed the whole custom "student ID + code" login. Standard Firebase **e-mail + password with e-mail verification** is used. |
| Passwords were **derived deterministically from the student id** — guessable by anyone who knew the scheme. | Gone with the above; users choose their own password (validated), Firebase stores the hash. |
| Any signed-in user could read **every user profile** (e-mail, student number). | `users/{uid}` is readable only by its owner; others only see the display name that is copied onto reports and chats. |
| Notifications could be created for anyone with any content; items/chats/messages had no field validation; `createdAt` could be forged. | New `firestore.rules`: verified e-mail required for writes, whitelisted fields, size limits, `createdAt == request.time`, sender must be the signed-in user, only the reporter can edit/delete a report (and only the allowed fields), only `match_found` notifications may target other users. |
| The "Try Demo" restrictions existed only in the UI; the rules accepted any signed-in user. | **(superseded)** Demo mode was removed completely; anonymous sessions have no access in the rules. |
| Storage rules let any signed-in user write to anyone's chat folder. | Storage is no longer used. |
| Firebase options and emulator hosts were hard-coded; `localhost` meant real phones could never reach the emulator; the emulator could leak into a release build. | `--dart-define-from-file=env.json` configuration; emulator mode is ignored in release builds; LAN host supported; `google-services.json` removed from the repository; `.gitignore` extended. |
| Unbounded user input (names, descriptions, locations). | Length limits in the validators and in the rules. |

## 4. Logic and quality bugs fixed

* **Item date handling:** `createdAt` was overwritten with the date the item was lost/found, which broke sorting and "new" ordering. There is now a separate `eventDate`.
* **Matching:** the 0.80 threshold made the feature effectively silent (two people rarely describe an object with >80 % identical words) → 0.60 **(superseded: now the 70-point `MatchEngine`, see section 0)**; Korean text is now tokenised (the old tokeniser only kept `a-z`); the author of the *new* report is notified as well as the author of the old one; at most 3 matches are announced per report; candidates are read with a bounded query instead of downloading every open item, and the query no longer needs a composite index. **(Superseded: the weights are now title 28 / description 22 / category 15 / location 25 / date 10.)**
* **Chats:** one shared unread counter for both people (reading cleared the other person's badge) → per-user counters; stream creation inside `build()` (re-subscribed on every rebuild) → created once.
* **Queries that needed composite indexes** (and failed at run time without them) were rewritten so no index is required.
* **Navigation:** login / verification redirect loops, and `mounted` checks after `await` so screens do not use a disposed context.
* **Item detail:** optimistic save toggle now rolls back on failure; confirmation before *Mark as reunited* and *Delete*; own posts can be deleted.
* **Report form:** GPS timeouts and permission denial handled, stale coordinates invalidated when the address is edited, the form keeps its data when an upload fails, photo can be removed.
* **Settings:** removed switches that did nothing (push, e-mail, profile visibility); *Reset password* added; *Location services* is honoured by the map and the report form.
* **Wrong campus coordinates:** the map centre, the campus/camera limits and all 30 building positions were about 4 km west of the real campus (35.1338 N, 129.0552 E instead of about 35.1398 N, 129.0985 E). They were moved onto the campus and a unit test guards against it. Positions are approximate (≈100 m) until replaced with OpenStreetMap values — see README §17 and `tool/fetch-osm-buildings.mjs`.
* `print` → `debugPrint`, Nominatim User-Agent made specific (no personal data), `const` and lint clean-up, `google_fonts` (downloads fonts at run time) replaced by the bundled Poppins files.

## 5. Image hosting: Firebase Storage → Cloudinary

* New `lib/services/image_upload_service.dart`: unsigned multipart upload to `https://api.cloudinary.com/v1_1/<cloud>/image/upload`; 10 MB limit; friendly errors for unknown preset / signed preset / wrong cloud name / quota / network; `optimizedUrl()` adds `c_limit,w_N,q_auto` so lists load small images.
* Photos are picked with `image_picker` (`XFile`, so it also works with `Image.memory` previews), resized on the phone (1280 px / 512 px avatars, quality 80) and uploaded before the report is saved.
* Removed: `firebase_storage`, `storage_service.dart`, `storage.rules`, the Storage emulator.
* Rules only accept image links that start with `https://res.cloudinary.com/`.

## 6. Other removals

`uuid`, `google_fonts` and the old `push_notification_service.dart` were removed. (`firebase_messaging` and `flutter_local_notifications` were removed in the first round and **are back in the second round**, together with a free Cloudflare Worker instead of Cloud Functions - see section 0.) `data_service.dart` and `seed_service.dart` (in-app demo-data helpers) were replaced by the external seed script, so demo data never ships inside the app.

## 7. New files

| File | Purpose |
|---|---|
| `README.md`, `CHANGES.md` | Run instructions, this report |
| `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `firebase.lan.json`, `.firebaserc` | Security rules and emulator setup |
| `env.example.json` | Template for all build-time settings |
| `tool/setup.dart`, `tool/branding/` | One-command project preparation, health check, launcher icons |
| `scripts/seed-emulator.mjs`, `scripts/verify-email.mjs`, `scripts/_emulator.mjs` | Demo data and manual e-mail verification for the emulators |
| `lib/config/app_config.dart`, `lib/services/image_upload_service.dart`, `lib/screens/setup_required_screen.dart`, `lib/state/settings_store.dart` | Configuration, uploads, friendly "something is not configured" screen, persisted settings |
| `test/*.dart` | unit tests (53 on the Dart side, 37 in `server/`) |
| `tool/fetch-osm-buildings.mjs`, `tool/apply-osm-buildings.mjs` | Download real building outlines from OpenStreetMap and turn them into `assets/data/building_positions.json` |
| `server/` , `shared/match_data.json`, `tool/gen-match-data.mjs` | Cloudflare Worker (push + AI second opinion) and the matching settings shared with the app |

## 8. Known limitations (honest list)

* Without the optional server, match notifications are written by the reporter's phone and pop-ups need the app process to be alive - see README §14 and §19.
* Building pins are approximate until surveyed positions are installed (README §17); a 2 m guarantee is not possible from the shipped data.
* iOS push needs a paid Apple Developer account (APNs key).
* Free OpenRouter models are rate-limited and may be slow; the app then uses the rule score alone.
* Unsigned Cloudinary uploads can be abused by someone who extracts the preset name from the app; photos cannot be deleted from the client.
* The public OSRM routing server and OpenStreetMap tile server are for light use only.
* Not run on a real device, and not run against the real Firebase emulators, Cloudinary, FCM, Cloudflare or OpenRouter from the preparation environment - see README §16. Layout was reviewed in code, not on screen.
