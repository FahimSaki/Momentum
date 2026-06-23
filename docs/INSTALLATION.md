# Installation Guide

This guide covers development setup and production deployment for both the Flutter frontend and the Node.js backend.

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Flutter SDK | ≥ 3.41.0 | Includes Dart 3.11+ |
| Node.js | ≥ 20 LTS (24 LTS recommended) | Backend runtime |
| npm | ≥ 10 | Bundled with Node.js |
| MongoDB | ≥ 6 | Local or Atlas |
| Android Studio | Latest stable | Android builds + emulator |
| Xcode | Latest stable | iOS/macOS builds |
| Git | Any recent version | |

---

## 1 – Clone the Repository

```bash
git clone https://github.com/FahimSaki/Momentum.git
cd momentum
```

---

## 2 – Backend Setup

The backend is written in TypeScript. Source files live in `backend/src/`. Compiled output goes to `backend/dist/` (git-ignored).

### Install Dependencies

```bash
cd backend
npm install
```

### Environment Variables

Create a `.env` file in the `backend/` directory. **Never commit this file.**

```env
# Required
MONGODB_URI=mongodb://localhost:27017/momentum
JWT_SECRET=replace-with-a-long-random-string
PORT=10000
NODE_ENV=development

# Optional – Firebase push notifications
# Option A: path to a downloaded service account JSON file
FIREBASE_SERVICE_ACCOUNT_PATH=./momentum-firebase-adminsdk.json

# Option B: paste the entire JSON as a single-line string (good for CI/hosting)
# FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"..."}
```

If neither Firebase option is set the app will still work – push notifications are silently skipped and in-app notifications still save to MongoDB.

### Run the Backend

```bash
npm run dev      # development – ts-node-dev compiles on the fly, auto-restarts on save
npm run build    # compile TypeScript → dist/
npm start        # production – runs compiled dist/index.js
```

> During development you never need to run `npm run build` manually. For production you must build before starting: `npm run build && npm start`.

Verify it's running:

```bash
curl http://localhost:10000/health
# {"status":"ok"}
```

---

## 3 – Flutter Frontend Setup

### Install Flutter Dependencies

```bash
# from project root
flutter pub get
```

### API Base URL

`lib/constants/api_base_url.dart` automatically selects the right URL:

| Build | Platform | URL |
|-------|---------|-----|
| Debug | Android emulator | `http://10.0.2.2:10000` |
| Debug | iOS simulator | `http://127.0.0.1:10000` |
| Release / Web | Any | `https://momentum-g7ah.onrender.com` |

For a custom server, edit the file locally before running. Do not commit personal server addresses.

### Run on a Device or Emulator

```bash
flutter devices                 # list available targets
flutter run                     # picks a connected device
flutter run -d emulator-5554    # specific Android emulator
flutter run -d chrome           # web
```

---

## 4 – Firebase Configuration (Optional)

Firebase is required only for push notifications. The app runs fully without it.

### Create a Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com) and create a project named **momentum-51138** (or any name – update `firebase_options.dart` accordingly).
2. Enable **Cloud Messaging** in the project settings.

### Android

1. Add an Android app with package name `com.example.momentum`.
2. Download `google-services.json`.
3. Place it at `android/app/google-services.json`.

### iOS

1. Add an iOS app with bundle ID `com.example.momentum`.
2. Download `GoogleService-Info.plist`.
3. Place it at `ios/Runner/GoogleService-Info.plist`.

### Backend Service Account

1. In Firebase Console → Project Settings → Service Accounts → **Generate new private key**.
2. Save the downloaded JSON as `backend/momentum-firebase-adminsdk.json`.
3. Add to `.env`:

   ```env
   FIREBASE_SERVICE_ACCOUNT_PATH=./momentum-firebase-adminsdk.json
   ```

### Regenerate `firebase_options.dart`

If you created your own Firebase project, regenerate the Dart options file:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

---

## 5 – Android Widget Setup

The home screen widget is fully configured in the repository. No additional setup is required for development. For a production release you may want to update the widget preview image at `android/app/src/main/res/drawable/widget_background.xml`.

---

## 6 – Running Tests

```bash
# Flutter
flutter test

# Flutter with coverage
flutter test --coverage

# Lint check
flutter analyze

# Format check
dart format . --set-exit-if-changed

# Backend type check (no emit)
cd backend && npx tsc --noEmit
```

---

## 7 – Building for Release

### Android APK / AAB

```bash
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

Output: `build/app/outputs/flutter-apk/` and `build/app/outputs/bundle/release/`

### iOS

```bash
flutter build ios --release
# then archive and distribute via Xcode
```

### Web

```bash
flutter build web --release
# output in build/web/
```

### Windows

```bash
flutter config --enable-windows-desktop
flutter build windows --release
```

### macOS

```bash
flutter config --enable-macos-desktop
flutter build macos --release
```

---

## Common Issues

See [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) for a complete list. Quick fixes:

| Symptom | Fix |
|---------|-----|
| `flutter pub get` fails | Run `flutter upgrade` then retry |
| Android emulator can't reach backend | Ensure backend is on port 10000; `10.0.2.2` maps to host machine |
| `google-services.json` missing | Add the file from Firebase Console or remove `firebase_core` if not needed |
| MongoDB connection refused | Ensure `mongod` is running locally or check Atlas URI |
| Widget shows empty state | Open the app once after install to let `HomeWidget.saveWidgetData` run |
| TypeScript compile errors after `git pull` | Run `cd backend && npm install` to pick up any new type dependencies |
