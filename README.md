# smartFind

> **Lost items. Found faster.** A lost-and-found app for Kyungsung University.

Students report a lost or found item (photo, building, date and *where they can
be found*). The app compares every new report with the open reports of the
opposite kind, and when two reports look at least **70 % alike** (title,
description, category, place and date) both people get a pop-up notification,
also when the phone is locked and the app is closed (this part needs the small
free server from [section 19](#19-alerts-when-the-app-is-closed-optional-server-free)).
They can then chat inside the app to arrange the hand-over.

* **Flutter** (Material 3, light and dark theme, Android + iOS) with **Firebase Auth + Cloud Firestore**
* **Matching engine** that works without any server or AI key; an optional **OpenRouter free model** gives a second opinion on borderline pairs
* **Pop-up notifications** (Firebase Cloud Messaging + on-device notifications)
* **Numbered campus map** with a details page per building, walking routes and the university's **Campus VR** tour
* **Cloudinary** (free plan) for photo hosting; Firebase Storage is not used
* Runs against the **Firebase Local Emulator Suite**, or against a real (free "Spark") Firebase project

> What changed compared with the original upload, and why, is listed in
> [`CHANGES.md`](CHANGES.md).

---

## Contents

1. [Quick start](#1-quick-start-about-15-minutes)
2. [What you need installed](#2-what-you-need-installed)
3. [Step 1 – prepare the project (`dart tool/setup.dart`)](#3-step-1--prepare-the-project)
4. [Step 2 – free photo hosting with Cloudinary](#4-step-2--free-photo-hosting-with-cloudinary)
5. [Step 3 – create `env.json`](#5-step-3--create-envjson)
6. [Step 4A – run against the local emulators (recommended first run)](#6-step-4a--run-against-the-local-emulators-recommended-first-run)
7. [Step 4B – run against a real Firebase project](#7-step-4b--run-against-a-real-firebase-project)
8. [Running from VS Code / Android Studio](#8-running-from-vs-code--android-studio)
9. [Smoke test – is everything working?](#9-smoke-test--is-everything-working)
10. [Tests and health check](#10-tests-and-health-check)
11. [Configuration reference](#11-configuration-reference)
12. [Project layout](#12-project-layout)
13. [Troubleshooting](#13-troubleshooting)
14. [Security notes and production checklist](#14-security-notes-and-production-checklist)
15. [Free-tier and usage-policy notes](#15-free-tier-and-usage-policy-notes)
16. [What has and has not been verified](#16-what-has-and-has-not-been-verified)
17. [Campus map positions – accuracy and calibration](#17-campus-map-positions--accuracy-and-calibration)
18. [How matching works](#18-how-matching-works)
19. [Alerts when the app is closed (optional server, free)](#19-alerts-when-the-app-is-closed-optional-server-free)
20. [Admin panel](#20-admin-panel)
21. [Building the Android and iOS apps](#21-building-the-android-and-ios-apps)

---

## 1. Quick start (about 15 minutes)

Assuming Flutter, Node and Java are installed (see [section 2](#2-what-you-need-installed))
and you have a Cloudinary account with an **unsigned** upload preset
([section 4](#4-step-2--free-photo-hosting-with-cloudinary)):

```bash
cd smartfind

dart tool/setup.dart                 # creates android/ + ios/, patches them, flutter pub get
cp env.example.json env.json         # Windows (cmd):  copy env.example.json env.json
#   → open env.json and fill in CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET

# Terminal 1 – the local backend (leave it running)
firebase emulators:start

# Terminal 2 – sample accounts + sample reports
node scripts/seed-emulator.mjs
flutter run --dart-define-from-file=env.json
```

Sign in with **`owner@ks.ac.kr` / `Owner1234!`** (more accounts in [section 6](#6-step-4a--run-against-the-local-emulators-recommended-first-run)).

> **Always start the app with `--dart-define-from-file=env.json`.** The app has
> no secrets in its source code; everything comes from that file. If you forget
> it, the app opens a "Setup required" screen that tells you what is missing -
> that is not a crash, it is the safety net.

> **Pop-ups on a locked phone** need a real Firebase project and the small free
> server in `server/` ([section 19](#19-alerts-when-the-app-is-closed-optional-server-free)).
> Without it, alerts still pop up while the app is open or running in the
> background.

---

## 2. What you need installed

| Tool | Version | Needed for | Check with |
|---|---|---|---|
| **Flutter** (stable) | **3.38 or newer** (Dart 3.10+) | everything | `flutter --version` |
| **Android Studio** + Android SDK | current | Android builds / emulator | `flutter doctor -v` |
| **Xcode** + **CocoaPods** | current (macOS only) | iOS builds | `flutter doctor -v` |
| **Node.js** | **20 or newer** | Firebase CLI, seed scripts | `node --version` |
| **Firebase CLI** | current (v15 at the time of writing) | emulators, deploying rules | `firebase --version` |
| **Java (JDK)** | **21 or newer** | the Firestore *emulator* only | `java -version` |
| **Cloudinary** account | free | photo uploads | – |

Install notes:

* **Flutter:** <https://docs.flutter.dev/get-started/install>. If `flutter --version` shows something older than 3.38 run `flutter upgrade`.
* **Android licences** (once): `flutter doctor --android-licenses` and answer `y` to everything. `flutter doctor` must show no red ✗ for *Android toolchain*.
* **Firebase CLI:** `npm install -g firebase-tools`. You do **not** need to run `firebase login` for the emulators — the project id `demo-smartfind` is an offline "demo" project. You only need to log in for [Path B](#7-step-4b--run-against-a-real-firebase-project).
* **Java 21:** current versions of the Firebase CLI refuse to start the Firestore emulator on older Java (its documentation still says "11+", the code requires 21). Any distribution works, e.g. [Eclipse Temurin 21](https://adoptium.net/). Java is *not* needed for the app itself or for Path B.
* **Supported targets:** Android (7.0 / API 24+) and iOS 15+. Web and desktop are not configured.

---

## 3. Step 1 – prepare the project

The zip contains only the Dart code, assets and configuration — not the
generated `android/` and `ios/` folders (the ones in the original upload had a
stale package name and a broken iOS icon set). One command creates and
configures them:

```bash
dart tool/setup.dart
```

It is safe to run again at any time. It does the following:

1. checks that Flutter ≥ 3.38 is installed;
2. runs `flutter create` for Android + iOS (application id / bundle id **`com.smartfind.smartfind`**);
3. patches the generated files: Android `minSdk 24` (required by Firebase), `INTERNET`, location and notification permissions, core-library desugaring (needed by the notification plugin), the default alert channel, the Google services plugin *if* `android/app/google-services.json` exists, app name "smartFind", cleartext traffic for the local emulators *in debug builds only*; iOS location/photo/camera usage texts, the remote-notification background mode, iOS 15 deployment target, app name;
4. installs the smartFind launcher icons (`tool/branding`);
5. runs `flutter pub get`;
6. at the end it prints a checklist of anything still missing (for example an empty Cloudinary value in `env.json`).

At any later time `dart tool/setup.dart --check` re-runs only the checks and
changes nothing.

On **Windows** use PowerShell or cmd; the commands are identical. On **macOS**
the first iOS build also needs `sudo gem install cocoapods` (or
`brew install cocoapods`) if `pod --version` fails.

---

## 4. Step 2 – free photo hosting with Cloudinary

Photos are uploaded straight from the phone to Cloudinary with an **unsigned
upload preset**. The app never needs an API secret, and you do not need a credit
card.

1. Create a free account at <https://cloudinary.com/users/register_free>.
2. Note your **Cloud name** (shown on the dashboard under *Product Environment Credentials*, also under *Settings → API Keys*). Example: `dxyz12abc`.
3. Open **Settings (gear icon) → Upload → Upload presets → "Add upload preset"** and set:
   * **Upload preset name:** `smartfind` (any name; you will paste it into `env.json`)
   * **Signing mode:** **Unsigned**  ← *this is the one setting that matters most*
   * **Folder** (called *Asset folder* in newer accounts): `smartfind`
   * Recommended hardening: **Allowed formats** `jpg,jpeg,png,webp,heic`, **Disallow public ID** *on* (so an upload cannot choose — and overwrite — a name that already exists), and optionally an incoming transformation such as `c_limit,w_1600,h_1600` to cap the size of stored images.
4. **Save.**

That is all. The app resizes pictures before uploading, rejects files over 10 MB
and shows readable messages if something is wrong — "upload preset not found"
(name typed wrong), "preset must be unsigned" (signing mode still *Signed*),
"cloud name not found".

Pictures are displayed through Cloudinary's on-the-fly resizing
(`c_limit,w_…,q_auto`), so lists stay light on mobile data.

---

## 5. Step 3 – create `env.json`

```bash
cp env.example.json env.json       # Windows (cmd):  copy env.example.json env.json
```

Open `env.json` (it is git-ignored — never commit it) and set at least:

```json
{
  "USE_EMULATOR": true,
  "EMULATOR_HOST": "localhost",

  "CLOUDINARY_CLOUD_NAME": "dxyz12abc",
  "CLOUDINARY_UPLOAD_PRESET": "smartfind",

  "ALLOWED_EMAIL_DOMAINS": "",
  "MATCH_API_URL": ""
}
```

The `FIREBASE_*` keys can stay empty while `USE_EMULATOR` is `true`.
Every key is explained in [section 11](#11-configuration-reference). The file
must be valid JSON (double quotes, no trailing commas) — `dart tool/setup.dart
--check` tells you if it is not.

---

## 6. Step 4A – run against the local emulators (recommended first run)

No Google account, no cloud project and no cost: Firebase Auth and Firestore run
on your own computer, and the app talks to them. Data is lost when you stop the
emulators (unless you export it) — perfect for trying things out.

### 6.1 Start the backend

In the project folder:

```bash
firebase emulators:start
```

Wait until it prints **"All emulators ready!"**. The first start downloads the
Firestore emulator (~60 MB) and therefore needs internet. Leave this terminal
open. You can browse the data at <http://localhost:4000>.

It loads `firestore.rules` automatically, so the *real* security rules are active
even in the emulator.

### 6.2 Fill it with sample data

In a **second** terminal:

```bash
node scripts/seed-emulator.mjs
```

This creates three already-verified accounts and ten sample reports at real
Kyungsung buildings. It can be run as often as you like.

| Account | Password | Role in the sample data |
|---|---|---|
| `owner@ks.ac.kr` | `Owner1234!` | lost a black backpack, AirPods case, glasses |
| `finder@ks.ac.kr` | `Finder1234!` | found the backpack, a student card, a mouse |
| `demo@ks.ac.kr` | `Demo1234!` | a plain extra user for trying the matching (there is no demo mode in the app itself) |

### 6.3 Run the app

Pick a device (`flutter devices`):

* **Android emulator:** start it from Android Studio → *Device Manager*, then run
  ```bash
  flutter run --dart-define-from-file=env.json
  ```
  `EMULATOR_HOST` stays `localhost` — FlutterFire automatically maps it to `10.0.2.2` (the emulator's name for your computer).
* **iOS simulator (macOS):** same command; `localhost` works as is.
* **A real phone** (USB or Wi-Fi debugging) — the phone cannot reach `localhost` of your computer, so:
  1. connect the phone and the computer to the **same Wi-Fi**;
  2. find the computer's LAN address (macOS/Linux: `ipconfig getifaddr en0` / `hostname -I`; Windows: `ipconfig`), e.g. `192.168.0.23`;
  3. set `"EMULATOR_HOST": "192.168.0.23"` in `env.json`;
  4. start the emulators so they listen on all interfaces: `firebase emulators:start --config firebase.lan.json`;
  5. allow ports **8080** and **9099** through the computer's firewall (Windows asks the first time — choose *Private networks*);
  6. `flutter run --dart-define-from-file=env.json -d <phone id>`.

### 6.4 Registering a new account in emulator mode

The emulator cannot send e-mail. In a **debug build** the app therefore opens the
verification link for you a moment after sign-up, and the "Check your inbox"
screen moves on by itself within a few seconds. If you ever see it waiting
forever, verify by hand:

```bash
node scripts/verify-email.mjs you@example.com     # or:  --all
```

and press **"I've verified my e-mail"** in the app.

---

## 7. Step 4B – run against a real Firebase project

Use this when you want real accounts, real verification e-mails and data that
persists. The free **Spark** plan is sufficient: no Cloud Functions and no
Storage are used. (Pop-ups on a locked phone use Cloud Messaging, which is free,
plus the free server in [section 19](#19-alerts-when-the-app-is-closed-optional-server-free).)

1. **Create the project:** <https://console.firebase.google.com> → *Add project* (Google Analytics can be turned off).
2. **Authentication → Get started → Sign-in method:** enable **Email/Password**. Leave **Anonymous** switched off; the app has no guest mode.
3. **Firestore Database → Create database:** choose a location near your users (e.g. `asia-northeast3` Seoul) and *Production mode*.
4. **Publish the security rules** (they are what protects your data — do not skip):
   * either copy the content of `firestore.rules` into *Firestore → Rules → Publish*, or
   * from the project folder: `firebase login`, then `firebase deploy --only firestore --project YOUR_PROJECT_ID` (deploys rules and indexes).
5. **Register the apps:** *Project settings (gear) → General → Your apps → Add app → Android*, package name **`com.smartfind.smartfind`** (skip the SHA-1 and the optional steps; you do **not** need to put `google-services.json` into the project). Repeat for iOS with bundle id `com.smartfind.smartfind` if you build for iPhone.
6. **Copy the values into `env.json`.** Easiest: in the Android-app step download `google-services.json` once, open it, and copy:

   | `env.json` key | value in `google-services.json` |
   |---|---|
   | `FIREBASE_PROJECT_ID` | `project_info.project_id` |
   | `FIREBASE_MESSAGING_SENDER_ID` | `project_info.project_number` |
   | `FIREBASE_APP_ID_ANDROID` | `client[0].client_info.mobilesdk_app_id` |
   | `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |

   For iOS, take `GOOGLE_APP_ID` from `GoogleService-Info.plist` into `FIREBASE_APP_ID_IOS`. Then set **`"USE_EMULATOR": false`**.

   *(Alternative: `dart pub global activate flutterfire_cli && flutterfire configure` generates its own `lib/firebase_options.dart`; the app works with that file as well.)*
7. **Run:** `flutter run --dart-define-from-file=env.json`.
8. **Create the first account in the app.** A verification e-mail is sent by Firebase (check the spam folder); tap the link, return to the app and press *"I've verified my e-mail"*. Writing data is blocked until the e-mail is verified — that is intended.

**Restrict sign-up to your university (recommended):**
* in `env.json` set `"ALLOWED_EMAIL_DOMAINS": "ks.ac.kr"` (a friendly check on the phone), **and**
* in `firestore.rules` change `campusEmail()` to `return request.auth.token.email.matches('.*@ks[.]ac[.]kr');` and publish the rules again. The rules are the real protection; the app setting alone can be bypassed by anyone with the REST API.

---

## 8. Running from VS Code / Android Studio

The `--dart-define-from-file=env.json` argument must be passed by the IDE as well.

**VS Code** – create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "smartFind",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "toolArgs": ["--dart-define-from-file=env.json"]
    }
  ]
}
```

**Android Studio / IntelliJ** – *Run → Edit Configurations… → Flutter → main.dart →
"Additional run args"* → `--dart-define-from-file=env.json`.

Release build (real Firebase only — emulator mode is ignored in release builds on purpose):

```bash
flutter build apk --release --dart-define-from-file=env.json          # Android
flutter build ipa --release --dart-define-from-file=env.json          # iOS (needs signing set up in Xcode)
```

For a Play Store release you must also create your own signing key
(<https://docs.flutter.dev/deployment/android#sign-the-app>) — the generated
project signs release builds with the debug key until you do.

---

## 9. Smoke test – is everything working?

With the emulator running and the seed script executed:

1. Start the app → splash → onboarding (first run only) → **Login** (no demo button).
2. Sign in as `owner@ks.ac.kr` / `Owner1234!` → **Home** shows the sample reports. Open **Search**, type `backpack`, press back to **Home**: Home still shows the full feed (each screen has its own filter).
3. Open a report: photo, the **building number and name**, a **"Where to find …"** block (building, room/spot, availability, preferred contact), possible matches, and your own report offers *Mark as reunited* / *Delete* instead of *Message*.
4. **Map** tab → numbered buildings and report pins. Tap a building → the card shows **View details** (description, number, position source, reports at this building, *Directions*, *Report here*, *Campus VR*) next to **Navigate**.
5. **Report lost / found**: the building drop-down lists *number + name* (name in smaller text). Fill **Where can you be found?** (building, spot, availability, how to contact you), add a photo and submit. The photo appears in the feed (this proves Cloudinary works).
6. **Matching:** sign in as `demo@ks.ac.kr`, report a **Lost** item titled `Black backpack`, building *Central Library Building*, today, description `Black Nike backpack with a blue keychain on a desk on the second floor of the library`. Home then shows **Possible matches for your reports**; the **bell** shows "Possible match found (NN%)" for you **and** for `finder@ks.ac.kr`, with the whole message wrapped (never cut off). Tap it for the side-by-side comparison.
7. Open the matching report → **Message** → send a text. Sign in as the other account on a second device/emulator: the conversation arrives live, with an unread badge.
8. **Profile → Settings**: theme (System / Light / Dark), alert toggles, location switch, reset password, log out.
9. **Pop-up check:** on a real phone with a real Firebase project, press the home button after step 6 and report a matching item from another account; a heads-up notification appears. Locked-phone delivery needs [section 19](#19-alerts-when-the-app-is-closed-optional-server-free).

---

## 10. Tests and health check

```bash
flutter test                  # unit tests: validators, matching engine, filters, building data, Cloudinary client
flutter analyze               # static analysis (should report no errors or warnings)
dart tool/setup.dart --check  # environment / configuration checklist

# the matching engine exists twice (Dart + the server); both are generated from shared/match_data.json
node tool/gen-match-data.mjs --check
cd server && node --test       # server tests (matching, push, AI parsing)
```

---

## 11. Configuration reference

All keys go into `env.json` (see `env.example.json`).

| Key | Default | Meaning |
|---|---|---|
| `USE_EMULATOR` | `false` | `true` → use the local emulators. **Ignored in release builds.** |
| `EMULATOR_HOST` | `localhost` | Computer running `firebase emulators:start`. Real phone → its LAN IP. |
| `AUTH_EMULATOR_PORT` | `9099` | Only add this key if you changed the port in `firebase.json`. |
| `FIRESTORE_EMULATOR_PORT` | `8080` | Same for Firestore. |
| `CLOUDINARY_CLOUD_NAME` | – | Your Cloudinary cloud name. Required for photo upload. |
| `CLOUDINARY_UPLOAD_PRESET` | – | Name of the **unsigned** preset. Required for photo upload. |
| `ALLOWED_EMAIL_DOMAINS` | empty = anyone | Comma-separated, e.g. `ks.ac.kr`. Sub-domains are accepted. |
| `MATCH_API_URL` | empty | URL of the deployed server in `server/` ([section 19](#19-alerts-when-the-app-is-closed-optional-server-free)). Empty = rules-only matching on the phone, alerts while the app runs. |
| `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID_ANDROID`, `FIREBASE_APP_ID_IOS`, `FIREBASE_APP_ID_WEB`, `FIREBASE_AUTH_DOMAIN` | – | Real-project values (Path B). Not needed with `USE_EMULATOR=true`. |

If photo upload is not configured, the rest of the app still works; the report
form simply tells the user that photos are unavailable and lets them submit
without one.

---

## 12. Project layout

```
smartfind/
├─ lib/
│  ├─ main.dart                  start-up: Firebase / emulator, settings, building positions, alerts, providers
│  ├─ app.dart                   routes, light/dark theme, alert binding, auth gate
│  ├─ config/app_config.dart     all --dart-define values in one place
│  ├─ firebase_options.dart      builds FirebaseOptions from env.json (or flutterfire's file)
│  ├─ matching/                  MatchEngine (pure Dart) + generated match_data.g.dart
│  ├─ models/                    UserModel, ItemModel, ChatModel, NotificationModel
│  ├─ services/
│  │   ├─ auth_service.dart      register / sign-in / e-mail verification / profile
│  │   ├─ firestore_service.dart items, notifications, saved items
│  │   ├─ messaging_service.dart chats and messages
│  │   ├─ matching_service.dart  ranks candidates, creates match notifications
│  │   ├─ notification_service.dart  FCM + on-device pop-ups, deep links
│  │   ├─ push_api.dart          client of the optional server (AI + push)
│  │   ├─ image_upload_service.dart  Cloudinary unsigned upload + URL optimiser
│  │   ├─ routing_service.dart   OSRM walking routes
│  │   └─ geocoding_service.dart OpenStreetMap Nominatim reverse geocoding
│  ├─ state/                     AuthState, ItemsState (shared feed), SettingsStore (Provider)
│  ├─ screens/                   one file per screen (home, search, map, building detail, report, item detail, chats, notifications, profile, settings, Campus VR, auth)
│  ├─ widgets/  theme/  utils/   design system (AppColors/AppTextStyles/AppTheme, AppCard, motion), validators, ItemFilter, building list
├─ assets/data/building_positions.json   surveyed building positions (empty until you generate them)
├─ shared/match_data.json        weights, threshold and synonyms used by BOTH the app and the server
├─ server/                       optional Cloudflare Worker: push (FCM) + OpenRouter second opinion
├─ test/                         unit tests
├─ tool/setup.dart               one-time project preparation + health check
├─ tool/fetch-osm-buildings.mjs  downloads building outlines from OpenStreetMap
├─ tool/apply-osm-buildings.mjs  matches them to the app's buildings, writes building_positions.json
├─ tool/gen-match-data.mjs       regenerates the Dart and JS copies of match_data.json
├─ tool/branding/                launcher icons (Android + iOS) used by setup.dart
├─ scripts/                      seed-emulator.mjs, verify-email.mjs (Node, no packages)
├─ firestore.rules               security rules  ← deploy these for real projects
├─ firestore.indexes.json        (empty: all queries work without composite indexes)
├─ firebase.json / firebase.lan.json / .firebaserc   emulator configuration
├─ env.example.json              template for env.json
└─ assets/                       logo, onboarding images, Poppins font (SIL OFL)
```

---

## 13. Troubleshooting

| Symptom | Cause → fix |
|---|---|
| App opens a **"Setup required"** screen | `env.json` missing, or the app was started without `--dart-define-from-file=env.json`. Create the file ([section 5](#5-step-3--create-envjson)) and start with that argument (IDE: [section 8](#8-running-from-vs-code--android-studio)). With `USE_EMULATOR=false` all `FIREBASE_*` values are required. |
| `dart tool/setup.dart`: *"Flutter is required"* | Flutter is not on the `PATH` of this terminal. Open a new terminal; `flutter --version` must work. |
| `flutter pub get` → *"version solving failed"* / *"requires SDK version"* | Flutter is older than 3.38. Run `flutter upgrade`, then `dart tool/setup.dart` again. |
| Login / sign-up spins, then *"network error"* or *"connection refused"* (emulator mode) | The emulators are not running or not reachable. Check the first terminal says **All emulators ready!**. Real phone: `EMULATOR_HOST` must be the LAN IP, start with `--config firebase.lan.json`, same Wi-Fi, firewall open for 8080/9099. |
| `firebase emulators:start` → *"Port 8080 is not open"* / *"port taken"* | Another program uses the port. Stop it, or change the port in `firebase.json` **and** add `FIRESTORE_EMULATOR_PORT` / `AUTH_EMULATOR_PORT` to `env.json`. |
| `firebase emulators:start` → Java error (*"Could not spawn java"*, *"requires Java 21"*) | Install JDK 21+, reopen the terminal, check `java -version`. |
| `firebase` command complains about Node | Install Node 20+. |
| Everything signs in but lists are empty / `permission-denied` in the log | The account's e-mail is not verified yet (the rules only let verified users write). Emulator: `node scripts/verify-email.mjs --all`. Real Firebase: click the link in the e-mail. Also make sure the rules you published are the ones from `firestore.rules`. |
| No pop-up arrives | (1) Allow notifications for smartFind in the phone settings (Android 13+ and iOS ask once). (2) *Profile → Settings → Alerts* must be on. (3) Pop-ups for a **closed** app need a real Firebase project and the server from [section 19](#19-alerts-when-the-app-is-closed-optional-server-free); the emulators cannot send push. (4) On some phones (Xiaomi, Huawei, Samsung "sleeping apps") battery savers block background pop-ups: remove smartFind from the restricted list. |
| iOS gets no push | iOS push needs a paid Apple Developer account: create an APNs key, upload it in Firebase → Project settings → Cloud Messaging, and enable the *Push Notifications* capability in Xcode. Android needs none of this. |
| Gradle: *"requires core library desugaring"* | Run `dart tool/setup.dart` again (it enables desugaring for the notification plugin). |
| Match score looks too low / no match | See [section 18](#18-how-matching-works): pick the right building, use the same key words (colour, brand, type) in both titles, and report the same day or soon after. |
| Message *"Photo upload is not set up yet…"* | `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_UPLOAD_PRESET` are empty in `env.json` (restart the app after editing — values are compiled in). |
| *"Cloudinary upload preset not found…"* | The preset name in `env.json` differs from Cloudinary (case-sensitive), or it was created in another Cloudinary account. |
| *"…upload preset must be set to Unsigned…"* | Cloudinary → Settings → Upload → your preset → **Signing mode: Unsigned** → Save. |
| *"Cloudinary cloud name looks wrong…"* / HTTP 401–404 from Cloudinary | Wrong `CLOUDINARY_CLOUD_NAME` (it is *not* your user name or e-mail). |
| Gradle: *"minSdkVersion 21 cannot be smaller than version 24"* | Run `dart tool/setup.dart` again (it raises `minSdk`). |
| Gradle: *"Could not find…"*, SDK / licence errors | `flutter doctor -v`; `flutter doctor --android-licenses`; in Android Studio *SDK Manager* install "Android SDK Command-line Tools". |
| Android build: *"Unsupported class file major version"* | Gradle is running with the wrong Java. Use Android Studio's bundled JDK: `flutter config --jdk-dir "<Android Studio>/jbr"`. |
| iOS: `pod install` fails | `cd ios && pod repo update && pod install && cd ..`. On Apple-silicon Macs make sure CocoaPods was installed natively. The first iOS build with Firebase takes many minutes — this is normal. |
| Cleartext HTTP traffic blocked (Android, emulator mode) | The debug manifest is patched by `dart tool/setup.dart`; run it again if you recreated the `android/` folder. |
| Map is grey / no tiles | No internet, or OpenStreetMap is rate-limiting your network. Tiles are fetched live from `tile.openstreetmap.org`. |
| "Use my current location" puts the report far away from the campus (emulator) | Emulators and simulators have a fake GPS (Android emulators default to California). Set it to the campus: Android emulator → **⋮ (Extended controls) → Location** → latitude `35.1398`, longitude `129.0985` → *Set location*; iOS simulator → **Features → Location → Custom Location…** with the same numbers. A real phone on campus needs no setting. |
| Location button does nothing / says denied | Grant the location permission in the phone settings, make sure *Settings → Location services* inside the app is on. The app falls back to the campus centre. |
| *"Could not fetch a road-following route…"* / a dashed line instead of a route | The free public OSRM server is rate-limited or offline — the app then shows the straight-line distance. See [section 15](#15-free-tier-and-usage-policy-notes). |
| Windows: `cp` not found | Use `copy env.example.json env.json` in cmd, or `Copy-Item env.example.json env.json` in PowerShell. |
| Changes in `env.json` have no effect | Values are compiled into the app: stop it and run `flutter run …` again (hot reload / hot restart is not enough). |

If something else goes wrong, `flutter run -v --dart-define-from-file=env.json`
and the red/`[auth]` / `[firebase]` / `[upload]` lines in the console are the
first things to look at.

---

## 14. Security notes and production checklist

What `firestore.rules` enforce:

* only users with a **verified e-mail** may read or write anything except their own profile; anonymous sessions have no access at all;
* a profile (e-mail, student number, push tokens) is readable **only by its owner**;
* an item can be created/changed only by its reporter, with validated fields (including the "where can you be found" fields) and a server-checked timestamp; image links must point to Cloudinary;
* chats and messages are readable/writable only by the two participants; a message's sender must be the signed-in user;
* a notification can be read/changed only by its owner. Another person may only create a `match_found` notification for someone, and only when its `itemId` is a report that **they own** (the rule looks the report up), so a stranger cannot forge alerts about reports that are not theirs.

Things you should know / do before real users arrive:

1. **Match notifications are created by the reporter's phone** (the free plan has no Cloud Functions). The rules above limit what a client may write; with the optional server the matching and the push are done by the server instead, using verified tokens.
2. **Unsigned upload presets can be abused** by anyone who finds the preset name (it is inside the app). Keep *Allowed formats*, the folder and an incoming size limit set, watch the Cloudinary usage page, and rotate the preset (create a new one, update `env.json`) if it is abused.
3. The app cannot delete photos from Cloudinary (that needs the API secret). Deleted reports leave their pictures behind; clean them up from the Cloudinary media library if needed.
4. Keep **Anonymous** sign-in off in Firebase.
5. Set `ALLOWED_EMAIL_DOMAINS` **and** tighten `campusEmail()` in the rules ([section 7](#7-step-4b--run-against-a-real-firebase-project)).
6. Never put `env.json`, the Firebase service-account file or the OpenRouter key into a public repository (`env.json` is in `.gitignore`; the server's secrets live in Cloudflare, not in files). Firebase "API keys" in the app are identifiers, not secrets - the security comes from the rules and from Authentication.
7. Create your own Android signing key and bundle id/package name if you publish under your own brand; update the Firebase app registration accordingly.
8. Privacy: reports show the reporter's display name, the contact text they type and the building where they can be found. If you enable the AI step, the **text of two reports** (title, category, description, building) and, when both reports have one, their **photos** (as links to the pictures on Cloudinary) are sent to OpenRouter and to the model provider behind it for each borderline pair; never e-mail addresses, names or contact details. The in-app Privacy Policy (`lib/screens/legal_screens.dart`) is a template - have it checked for your legal situation (Korean PIPA / GDPR).

---

## 15. Free-tier and usage-policy notes

* **Firebase Spark plan:** Firestore has a daily free quota (at the time of writing roughly 50 000 reads / 20 000 writes / 1 GiB stored — check the current numbers on the Firebase pricing page). The feed is a single query for the newest 200 reports, which is plenty for a campus-sized community and keeps reads low.
* **Cloudinary free plan:** a monthly credit allowance shared by storage, bandwidth and transformations. Photos are limited to 10 MB in the app and delivered resized.
* **OpenStreetMap tiles** (`tile.openstreetmap.org`) are for light use only; for a large public app use a tile provider with an API key or host your own (<https://operations.osmfoundation.org/policies/tiles/>).
* **Nominatim** (address from GPS) allows about one request per second and requires an identifying User-Agent — the app sends `smartFind/1.0.0 (Kyungsung University lost-and-found app)` and only calls it when the user taps the location button.
* **Cloudflare Workers free plan:** 100 000 requests per day and a few milliseconds of CPU per request; the server keeps each request small for that reason (check the current limits on Cloudflare's pricing page).
* **OpenRouter free models:** rate-limited by OpenRouter, and the limits depend on whether you have added credits to your account (see <https://openrouter.ai/docs/api/reference/limits>). When a free model is busy, slow or answers badly, the server ignores it and the rule engine alone decides, so matching keeps working.
* **Firebase Cloud Messaging** is free.
* **OSRM public server** (`router.project-osrm.org`) is a demo server without guarantees. The app degrades to a straight dashed line when it fails. Host your own or use a commercial routing API for production.

---

## 16. What has and has not been verified

Being upfront about this so you know what to expect on the very first run:

**Checked while preparing this package**

* Static analysis of all of `lib/` with the Dart analyzer (against the real Flutter framework sources and hand-written API stubs for the plugins) with a broad `flutter_lints` rule set plus `prefer_const_*`: **0 errors, 0 warnings**. Deprecated Flutter APIs (`withOpacity`, `WillPopScope`, `MaterialState*`, `textScaleFactor`) are not used. (Plugin code itself was not analysed, so a plugin-version mismatch on your machine is the one thing this cannot rule out.)
* 53 Dart unit tests pass on the plain Dart VM: validators, matching engine (including Korean/English cases and the 70 % threshold), candidate ranking, the search/home filter, the building data (every building lies on the campus), the Cloudinary upload client against a mocked server.
* 37 server tests pass (`cd server && node --test`): matching parity with the app, push payloads, the AI step (including the text-only retry), limits.
* `tool/setup.dart` Android and iOS patching (desugaring, notification permission, channel, Google services plugin, background mode) was run against a mock Flutter project and is idempotent. `tool/apply-osm-buildings.mjs` was run against synthetic OpenStreetMap data.

**Could not be executed in the preparation environment**

* A real `flutter run` / device build (no Flutter SDK or Android/iOS toolchain), so **layout, animations and overflow behaviour on an actual phone are untested**. The screens were written with scrolling bodies, `Expanded`/`Flexible` text and bounded sheets to avoid overflow, but only a device run can prove it; please try small phones and large font sizes.
* **Push notifications, the Worker, OpenRouter and Firestore rules were never run against the real services.** The Worker's logic is unit-tested with mocked Google/OpenRouter calls only.
* A live Cloudinary upload, the Firebase emulators and the public OSRM server.
* **Building positions of 2 m or better are not guaranteed by the shipped data**; see [section 17](#17-campus-map-positions--accuracy-and-calibration).

If `flutter run` shows a compile error on your machine, it is most likely a
plugin version difference - send the first error line and the output of
`flutter --version`; the fix is normally a one-liner. If the Firestore emulator
reports `permission-denied` for something that should work, its UI
(<http://localhost:4000>, *Firestore → Requests*) shows which rule rejected it.

---

## 17. Campus map positions – accuracy and calibration

**Honest limits.** The positions shipped in `lib/utils/ksu_buildings.dart` were
placed from the university's *illustrated* campus map and are only right to
roughly **100 m**. Nobody can promise "2 metres" from a drawing: that needs
surveyed coordinates. Phone GPS itself is typically 3-10 m off in the open and
worse between buildings, so the blue "you are here" dot will never be better
than that either. What the app can do is make the **building pins** as exact as
the best available source.

**How to get them (about 5 minutes, needs internet):**

```bash
node tool/fetch-osm-buildings.mjs          # downloads buildings, gates, sports grounds from OpenStreetMap
node tool/apply-osm-buildings.mjs --dry-run   # shows which app building matched which OpenStreetMap outline
node tool/apply-osm-buildings.mjs          # writes assets/data/building_positions.json
```

Then fully restart the app (not hot reload). The positions are loaded at
start-up and override the built-in numbers; the building details page shows
**Surveyed** or **Approximate** for each building.

* Matching is by number + name, English name, or Korean aliases you add to `tool/building_aliases.json` (for example `"Hansung Building": ["한성관"]`). `--snap 40` additionally accepts the only unnamed outline within 40 m. A match more than 250 m from the old position is rejected as a probable mix-up. Nothing is guessed: unmatched buildings are listed and keep their old position.
* OpenStreetMap outline centres are usually within a few metres, but they are only as good as OpenStreetMap's mapping. You can add or fix a building at <https://www.openstreetmap.org> (free account) and run the commands again.
* **For true metre accuracy:** stand at the building's entrance, long-press the spot in Google Maps (satellite view) and copy the two numbers. Put them into `assets/data/building_positions.json` as `"Hansung Building": [35.1388xxx, 129.0967xxx]`. Do this for the buildings that matter most, and compare with a second reading.

`test/ksu_buildings_test.dart` fails if the built-in data ever drifts away from
the campus again (an earlier version was 4 km off).

Map data (c) OpenStreetMap contributors (ODbL).

---

## 18. How matching works

A new report is compared with every open report of the *opposite* kind from
*other* people (lost vs found; reunited reports are ignored). Five signals give
a score from 0 to 100:

| Signal | Weight | What counts |
|---|---|---|
| Title | 28 % | shared words, with synonyms (English and Korean, e.g. "wallet" = "지갑"), colours, typos; digits must match exactly (iPhone 13 is not 14) |
| Description | 22 % | the same on title + description together |
| Category | 15 % | equal, or closely related (e.g. electronics / accessories) |
| Location | 25 % | same building, otherwise distance on campus |
| Date | 10 % | found on or after the day it was lost, fading over about three weeks |

The rule engine does not look at photos. (The optional AI step below also
receives both photos when both reports have one.)

From **70** upwards both people are notified (at most 3 matches per new
report). The notification states the percentage and the reasons ("similar
title, close location"), and opening it shows both reports side by side. The
weights, threshold and synonyms are in `shared/match_data.json`; after editing
it run `node tool/gen-match-data.mjs` so the app and the server stay identical.

**With the optional server**, up to three pairs per new report whose rule score
is 45 or more are also shown to an OpenRouter model, which judges "same
object?" from the texts and, when both reports have a photo, the photos. The
final score is 55 % rules + 45 % AI. If the model is busy, slow, answers
badly, or cannot read pictures (then it is asked again with the texts only),
the rule score stands. So the feature **works without any AI or internet
service**, and the AI can only add a second opinion.

Tuning tips for users are shown in the report form: a "may already be
reported" hint appears while typing when a similar open report exists.

---

## 19. Alerts when the app is closed (optional server, free)

There are three layers, so something always reaches the person:

1. **Server push (this section):** arrives with the app closed and the screen off; the phone's system draws the pop-up.
2. **While the app is open:** incoming push messages are turned into heads-up pop-ups.
3. **No server at all:** new matches and messages (read from Firestore) pop up while the app process is alive (open or in the background). When Android has killed the app, nothing can wake it without a server; that is a platform rule, not a bug.

The server is a small **Cloudflare Worker** in `server/` (free plan). It
verifies the caller's Firebase login, finds matches, optionally asks OpenRouter,
writes the notifications and sends the push through Firebase Cloud Messaging.

```bash
# 1. Firebase console → Project settings → Service accounts → "Generate new private key"
#    (keep the downloaded JSON private; never commit it)
# 2. Optional AI: create a free key at https://openrouter.ai/keys

cd server
npm install
npx wrangler login
# edit wrangler.toml: set FIREBASE_PROJECT_ID to your project id
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT    # paste the whole JSON
npx wrangler secret put OPENROUTER_API_KEY          # optional
npx wrangler deploy                                  # prints https://smartfind-push.<you>.workers.dev
curl https://smartfind-push.<you>.workers.dev/v1/health
```

Put that URL into `env.json` as `"MATCH_API_URL"` and rebuild the app. For
Android also download `google-services.json` (Firebase console → Android app)
into `android/app/` and run `dart tool/setup.dart` again; for iOS upload an APNs
key (needs a paid Apple Developer account). `OPENROUTER_MODEL` defaults to
`openrouter/free`, which lets OpenRouter pick a currently free model; you can set
any model id in `wrangler.toml`.

Check: `dart tool/setup.dart --check` reports whether `MATCH_API_URL` is set.

---

## 20. Admin panel

Admins see **Profile → Admin panel**, with four tabs:

| Tab | What it does |
|---|---|
| **Overview** | Number of registered users (and sign-ups in the last 7 days), admins, suspended accounts, and report totals: lost, found, reunited, verified, awaiting review. Pull down to refresh. |
| **Reports** | Review queue. *Verify* adds a green "Verified" check on the report for everyone; *Remove* deletes it. Filter by awaiting review / verified / closed, or search. |
| **Users** | Every account, searchable by name, e-mail or student ID. *Suspend* (with a reason shown to the person) blocks posting and chatting and shows a "suspended" screen. *Make admin* / *Remove admin*. Also lists each person's reports. |
| **Buildings** | Fix map coordinates: drag the map under the pin or type latitude / longitude, then save. Every signed-in phone picks up the change within seconds. *Reset* returns a building to its built-in position. |

**Making the first admin.** Admins are users with a document at
`admins/{uid}`, and only an admin can create one. So the first admin is made by hand:

* **Emulators:** `node scripts/make-admin.mjs someone@ks.ac.kr`. The seed
  script also creates `admin@ks.ac.kr / Admin1234!`.
* **Real project:** Firebase console → Authentication → copy the person's
  *User UID* → Firestore → start collection `admins` → document ID = that UID →
  add field `email` (string). After that, add more admins from the panel.

**Deploy the rules** after updating: `firebase deploy --only firestore:rules`.
The rules enforce all of the above on the server, so a modified app cannot
use admin actions, and no admin can remove their own role (so the project
always keeps at least one admin). Deleting a Firebase *Auth* account is not possible from the app;
suspend the user instead, or delete them in the Firebase console.

## 21. Building the Android and iOS apps

* **Android (any PC):** `flutter build apk --release --dart-define-from-file=env.json`
  → `build/app/outputs/flutter-apk/app-release.apk`.
* **iOS (needs a Mac):** Apple only allows iOS builds on macOS. On Windows, use
  the included GitHub Actions workflow `.github/workflows/build-apps.yml`:
  push the project to GitHub, add your `env.json` contents as the secret
  `ENV_JSON`, then run *Actions → Build apps*. It produces the APK and an
  unsigned `.ipa`. Installing on an iPhone or publishing to the App Store
  needs an Apple Developer account and signing (see the comments in the
  workflow file).

## Licence

See [`LICENSE`](LICENSE). The Poppins font is distributed under the SIL Open Font
License (`assets/fonts/OFL.txt`); map data © OpenStreetMap contributors.
