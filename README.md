# smartFind

> **Lost Items. Found Faster.** Report · Search · Reunite

A Flutter-based mobile lost-and-found application for communities and campuses. Built with Material 3, Firebase, and `flutter_map`.

![smartFind logo](https://via.placeholder.com/520x145/FFFFFF/2563EB?text=smartFind) <!-- replace with rendered logo -->

---

## 1. Features

| Screen | Purpose |
|--------|---------|
| Splash | App branding, Firebase init |
| Onboarding | 3-step intro with tagline |
| Login / Sign Up | Email + password auth, "Try Demo" button |
| Home | Search bar, quick-action grid (Report Lost / Report Found / Map), recent items feed |
| Search | Filter chips by category + live text search |
| Item Detail | Hero image, status badge, location, description, reporter info, Message/Share actions |
| Campus Map | `flutter_map` with OpenStreetMap tiles, item pins, tap-to-reveal bottom sheet |
| Report Lost / Found | Photo upload + title / category / location / date / description form |
| Profile | Avatar, stats, menu (My Posts, Saved, Settings, Help, Logout) |
| Notifications | Segmented filter (All / Lost / Found / Messages), match alerts, message previews |
| Chats | Conversation list, Chat Detail with realtime Firestore messaging |
| Settings | Account, notifications toggle, theme, privacy, about |

## 2. Tech Stack

- **Flutter 3.19+** + **Dart 3.3+**
- **Material 3** theming
- **google_fonts** (Poppins)
- **flutter_map** + **latlong2** (OpenStreetMap)
- **Firebase**: Auth, Firestore, Storage, Cloud Messaging, Analytics
- **ValueNotifier** + **Provider** for state

## 3. Setup

### 3.1 Prerequisites

- Flutter SDK 3.19+ (`flutter --version`)
- Dart 3.3+
- A Firebase project (free at https://console.firebase.google.com)

### 3.2 Install dependencies

```bash
cd smartfind
flutter pub get
```

### 3.3 Configure Firebase

1. **Create a Firebase project** at https://console.firebase.google.com.
2. **Add an Android app** (package name `com.smartfind.app`) — download `google-services.json` and place it at `android/app/google-services.json`.
3. **Add an iOS app** (bundle id `com.smartfind.app`) — download `GoogleService-Info.plist` and place it at `ios/Runner/GoogleService-Info.plist`.
4. **Enable** in the Firebase console:
   - **Authentication → Sign-in method → Email/Password**
   - **Cloud Firestore** (production mode, then deploy the rules below)
   - **Storage** (production mode, then deploy the rules below)
   - **Cloud Messaging** (no extra config needed)
5. **Open `lib/firebase_options.dart`** and replace the placeholder values (`YOUR_API_KEY`, etc.) with the values from your `google-services.json` / `GoogleService-Info.plist`. Or, better, install `flutterfire_cli` and run:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=your-firebase-project-id
   ```

   This will regenerate `lib/firebase_options.dart` automatically.

6. **Deploy Firestore + Storage rules**:

   ```bash
   firebase init firestore
   firebase init storage
   firebase deploy --only firestore:rules,storage
   ```

### 3.4 Run the app

```bash
flutter run
```

### 3.5 (Optional) Seed demo data

On first launch, if Firestore has no items, the app calls `SeedService.maybeSeed()` to insert ~15 sample items so the feed isn't empty. To re-seed:

```dart
// In a debug session, call:
await SeedService().reseed();
```

Or run the bundled script (if you have Dart SDK):

```bash
dart run scripts/seed.dart
```

## 4. Project Structure

```
lib/
├── main.dart                    # Entry point, Firebase init, app bootstrap
├── app.dart                     # MaterialApp, theme, router
├── firebase_options.dart        # ← REPLACE WITH YOUR FIREBASE CREDENTIALS
├── theme/
│   ├── app_colors.dart          # Design tokens (#2563EB, #0F172A, #64748B, #10B981, #EF4444)
│   ├── app_text_styles.dart     # Poppins H1/H2/H3/Body/Caption
│   └── app_theme.dart           # Material 3 ThemeData (light + dark)
├── models/
│   ├── item_model.dart          # Item (lost or found)
│   ├── user_model.dart          # AppUser profile
│   ├── chat_model.dart          # Chat + Message
│   └── notification_model.dart  # Local + remote notifications
├── services/
│   ├── auth_service.dart        # FirebaseAuth wrapper
│   ├── firestore_service.dart   # Items/users/notifications CRUD
│   ├── storage_service.dart     # Firebase Storage uploads
│   ├── messaging_service.dart   # Realtime chat streams
│   ├── push_notification_service.dart  # FCM + local notifications
│   └── seed_service.dart        # First-launch demo data seeder
├── state/
│   ├── auth_state.dart          # ValueNotifier<AuthState>
│   ├── items_state.dart         # ValueNotifier<List<Item>>
│   └── chat_state.dart          # Per-chat ValueNotifier<List<Message>>
├── widgets/
│   ├── smartfind_logo.dart      # CustomPainter recreation of the brand mark
│   ├── item_card.dart
│   ├── status_badge.dart
│   ├── category_chip.dart
│   ├── primary_button.dart
│   ├── custom_text_field.dart
│   ├── bottom_nav_bar.dart      # 5-tab bottom bar with central FAB
│   ├── empty_state.dart
│   └── loading_indicator.dart
├── screens/
│   ├── splash_screen.dart
│   ├── onboarding_screen.dart
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── home_screen.dart
│   ├── search_screen.dart
│   ├── item_detail_screen.dart
│   ├── campus_map_screen.dart
│   ├── report_lost_screen.dart
│   ├── report_found_screen.dart
│   ├── profile_screen.dart
│   ├── notifications_screen.dart
│   ├── chats_screen.dart
│   ├── chat_detail_screen.dart
│   └── settings_screen.dart
└── utils/
    ├── constants.dart           # Categories, locations, padding tokens
    ├── formatters.dart          # time-ago, date format
    └── validators.dart          # email, password, required
```

## 5. Design Tokens

| Token | Hex |
|-------|-----|
| Primary | `#2563EB` |
| PrimaryDark | `#1D4ED8` |
| Navy | `#0F172A` |
| Background | `#F8FAFC` |
| Surface | `#FFFFFF` |
| Border | `#E2E8F0` |
| TextPrimary | `#0F172A` |
| TextSecondary | `#64748B` |
| TextTertiary | `#94A3B8` |
| Success | `#10B981` |
| Error | `#EF4444` |
| Warning | `#F59E0B` |

Typography: **Poppins** (H1 24/700, H2 20/600, H3 16/500, Body 14/400, Caption 12/400).

## 6. License

MIT — see `LICENSE`.
