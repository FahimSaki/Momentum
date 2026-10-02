# Installation Guide

This guide covers development setup and production deployment for both the Flutter frontend and the Node.js backend.

---

## Prerequisites

| Tool | Version | Notes |
| ------ | --------- | ------- |
| Flutter SDK | ≥ 3.44.0 | Includes Dart 3.12+ (CI pins 3.47.5) |
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
cd Momentum
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

# Required – outgoing email (registration OTP, 2FA codes, password-reset,
# password-change, and account-deletion codes)
# Sent via the Gmail REST API over HTTPS, not SMTP — see "Gmail OAuth2 Setup" below.
GMAIL_CLIENT_ID=your-oauth-client-id.apps.googleusercontent.com
GMAIL_CLIENT_SECRET=your-oauth-client-secret
GMAIL_REFRESH_TOKEN=your-oauth-refresh-token
EMAIL_FROM=you@yourdomain.com

# Optional – Google Sign-In: OAuth client ID(s) the server accepts, comma-separated.
# If unset, the token audience is not checked.
# GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com

# Optional – restrict CORS to these origins (comma-separated). If unset, all origins are allowed.
# ALLOWED_ORIGINS=http://localhost:5000

# Optional – Firebase push notifications
# Option A: path to a downloaded service account JSON file
FIREBASE_SERVICE_ACCOUNT_PATH=./momentum-firebase-adminsdk.json

# Option B: paste the entire JSON as a single-line string (good for CI/hosting)
# FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"..."}
```

If neither Firebase option is set the app will still work – push notifications are silently skipped and in-app notifications still save to MongoDB.

### Gmail OAuth2 Setup (required for email)

Momentum sends registration, 2FA, password-reset, password-change, and account-deletion codes through the Gmail REST API over HTTPS instead of SMTP, because Render (the production host) blocks outbound SMTP on ports 465 and 587.

1. In the [Google Cloud Console](https://console.cloud.google.com/apis/credentials), create an OAuth 2.0 Client ID (type "Desktop app") for the Gmail account you want to send from.
2. Generate a refresh token for that client with the `https://www.googleapis.com/auth/gmail.send` scope — the [OAuth 2.0 Playground](https://developers.google.com/oauthplayground) is the quickest way to do this.
3. Set `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`, and `GMAIL_REFRESH_TOKEN` from that client.
4. Set `EMAIL_FROM` to the Gmail address the refresh token belongs to. Gmail overrides the `From` header unless the address matches a verified "Send mail as" alias on the account, so add one under Gmail → Settings → Accounts if you want a different display address.

If any of the four Gmail variables are missing, the server still starts and logs a warning ("Email disabled — missing env vars"). Registration will appear to succeed but the user never receives a code, and the other code flows (resend, 2FA, password reset and change, account deletion) answer with a server error.

### Run the Backend

```bash
npm run dev        # development – ts-node-dev compiles on the fly, auto-restarts on save
npm run build      # compile TypeScript → dist/
npm start          # production – runs compiled dist/index.js
npm run typecheck  # type-check without emitting files
```

> During development you never need to run `npm run build` manually. For production you must build before starting: `npm run build && npm start`.

Verify it's running:

```bash
curl http://localhost:10000/health
# {"status":"ok","timestamp":"...","uptime":...}
```

---

## 3 – Flutter Frontend Setup

### Install Flutter Dependencies

```bash
# from project root
flutter pub get
```

### API Base URL

`lib/config/api_base_url.dart` chooses the URL at compile time:

| Build | Platform | URL |
| ------- | --------- | ----- |
| Debug | Android emulator, and any other non-web platform | `http://10.0.2.2:10000` |
| Release | Any | `https://momentum-g7ah.onrender.com` |
| Any (debug included) | Web | `https://momentum-g7ah.onrender.com` |

`10.0.2.2` is the Android emulator's alias for the host machine. The same file defines `resolvedApiBaseUrl()`, which returns `http://127.0.0.1:10000` for the iOS simulator, but the services use the compile-time `apiBaseUrl`. On an iOS simulator or a desktop debug build, change `apiBaseUrl` locally to `http://127.0.0.1:10000`. Web builds always talk to production, so test backend changes from a mobile or desktop target.

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

### Web

1. Add a web app to the Firebase project and keep its config in `lib/firebase_options.dart` (regenerate it with `flutterfire configure`, below).
2. In Firebase Console → Project Settings → Cloud Messaging → **Web Push certificates**, generate a key pair and set its public key as `_webVapidKey` in `lib/services/push_notification_service.dart`.
3. Update the config object in `web/firebase-messaging-sw.js` to match your web app. The service worker runs in its own context and initialises Firebase separately from the app.

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

## 5 – Google Sign-In (Optional)

Email and password sign-in works without any of this. Google Sign-In needs an OAuth client of your own, because the client ID in the repository belongs to the production project.

1. In Google Cloud Console (or Firebase → Authentication → Sign-in method → Google), use the **Web client ID** of your project.
2. Set it as `_googleClientId` in `lib/services/auth_service.dart`. The app uses it as the client ID on web and as the server client ID on Android and iOS.
3. For web, add your site origin **with a trailing slash** as an authorised redirect URI, for example `https://your-app.vercel.app/`. For local web development, run on a fixed port and register that address too:

   ```bash
   flutter run -d chrome --web-port 5000   # register http://localhost:5000/
   ```

4. For Android, add your debug and release SHA-1 fingerprints to the Android app in Firebase.
5. Set `GOOGLE_CLIENT_ID` in the backend `.env` so the server accepts tokens issued for your client.

---

## 6 – Android Widget Setup

The home screen widget is fully configured in the repository. No additional setup is required for development. Its layout is `android/app/src/main/res/layout/momentum_home_widget.xml`, its background is `res/drawable/widget_background.xml`, and its size and update settings are in `res/xml/momentum_home_widget_info.xml`.

---

## 7 – Running Tests

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
cd backend && npm run typecheck
```

---

## 8 – Building for Release

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

Production web is served from the pre-built snapshot in `buildx/web/`; see [DEPLOYMENT.md](DEPLOYMENT.md).

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

### Linux

```bash
# Debian/Ubuntu build dependencies (the same ones CI installs)
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libsecret-1-dev libjsoncpp-dev

flutter config --enable-linux-desktop
flutter build linux --release
```

---

## Common Issues

See [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) for a complete list. Quick fixes:

| Symptom | Fix |
| --------- | ----- |
| `flutter pub get` fails | Run `flutter upgrade` then retry |
| Android emulator can't reach backend | Ensure backend is on port 10000; `10.0.2.2` maps to host machine |
| `google-services.json` missing | Add the file from Firebase Console or remove `firebase_core` if not needed |
| MongoDB connection refused | Ensure `mongod` is running locally or check Atlas URI |
| Verification/2FA emails never arrive | Confirm all four `GMAIL_*` / `EMAIL_FROM` vars are set — the server starts without them but cannot send codes |
| Google sign-in fails on web | Register the site origin with a trailing slash as an authorised redirect URI, and check `GOOGLE_CLIENT_ID` on the backend |
| `E11000` on `assignedBy_1_clientId_1` when creating tasks | Run `npx ts-node src/scripts/fixTaskClientIdIndex.ts` from `backend/` |
| Widget shows empty state | Open the app once after install to let `HomeWidget.saveWidgetData` run |
| TypeScript compile errors after `git pull` | Run `cd backend && npm install` to pick up any new type dependencies |
