# Deployment Guide

This guide covers deploying Momentum's backend to Render.com (current production setup) and the Flutter frontend as a web app to Vercel, as well as building native app binaries for Android and iOS.

---

## Backend – Render.com

The production backend is hosted at `https://momentum-g7ah.onrender.com`.

### Initial Deploy

1. Push your repository to GitHub.
2. Go to [render.com](https://render.com) → New → **Web Service**.
3. Connect your GitHub repo and configure:

| Setting | Value |
|---------|-------|
| Runtime | Node |
| Root directory | `backend` |
| Build command | `npm install && npm run build` |
| Start command | `npm start` |
| Instance type | Free or Starter |

1. Under **Environment**, add the following variables:

| Key | Value |
|-----|-------|
| `MONGODB_URI` | Your MongoDB Atlas connection string |
| `JWT_SECRET` | A long random secret (use `openssl rand -hex 32`) |
| `PORT` | `10000` |
| `NODE_ENV` | `production` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Paste the full contents of your Firebase service account JSON as a single-line string |
| `ALLOWED_ORIGINS` | Comma-separated list of allowed CORS origins (e.g. `https://yourapp.vercel.app,https://yourcustomdomain.com`) |

> **Never use `FIREBASE_SERVICE_ACCOUNT_PATH` on Render** – the filesystem is ephemeral. Use `FIREBASE_SERVICE_ACCOUNT_JSON` instead. The notification service parses this variable at startup and uses it automatically.

> If `ALLOWED_ORIGINS` is not set, the server defaults to allowing all origins (`*`). Set it explicitly in production.

1. Click **Create Web Service**. Render runs `npm install && npm run build` to compile TypeScript, then starts the server with `npm start` (which runs `node dist/index.js`).

### Keep-Alive

Render free-tier instances spin down after 15 minutes of inactivity. The GitHub Actions workflow in `.github/workflows/build.yml` pings `/wake-up` before every build to wake the server. For production use you should either:

- Upgrade to a paid Render plan (always-on), or
- Set up an external cron (e.g. cron-job.org) to hit `GET /wake-up` every 10 minutes.

### Redeployment

Every push to `main` triggers a new Render build automatically if auto-deploy is enabled in the Render dashboard. Render re-runs the full build command (`npm install && npm run build`) on each deploy so compiled output is always up to date.

### MongoDB Atlas Setup

1. Create a free cluster at [cloud.mongodb.com](https://cloud.mongodb.com).
2. Create a database user with read/write access.
3. Whitelist `0.0.0.0/0` (all IPs) under Network Access – Render's outbound IPs change.
4. Copy the connection string (`mongodb+srv://...`) and set it as `MONGODB_URI`.

The app creates all collections automatically on first use. No migration scripts are required for a fresh deployment.

---

## Frontend – Web (Vercel)

The web build is served at `https://momentum-beryl-nine.vercel.app`.

### Build

```bash
flutter build web --release
```

Output goes to `build/web/`.

### Deploy to Vercel

1. Install the Vercel CLI: `npm i -g vercel`
2. From the project root:

```bash
cd build/web
vercel --prod
```

Or connect the GitHub repo in the Vercel dashboard and set:

| Setting | Value |
|---------|-------|
| Framework preset | Other |
| Build command | `flutter build web --release` |
| Output directory | `build/web` |

### CORS

The backend reads allowed origins from the `ALLOWED_ORIGINS` environment variable (comma-separated). Add your Vercel deployment URL and any custom domain to that variable on Render. If `ALLOWED_ORIGINS` is unset, all origins are allowed.

---

## Frontend – Android

### Debug APK (for testing)

```bash
flutter build apk --debug
# output: build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK / AAB

1. Generate a signing keystore if you don't have one:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

1. Create `android/key.properties` (do not commit):

```
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=<path-to>/upload-keystore.jks
```

1. Reference `key.properties` in `android/app/build.gradle.kts` (standard Flutter signing config).

2. Build:

```bash
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

APK files go to `build/app/outputs/flutter-apk/`.
The AAB goes to `build/app/outputs/bundle/release/`.

### Google Services

`android/app/google-services.json` is required for Firebase. It is listed in `.gitignore`. In CI (GitHub Actions) it is injected from the `GOOGLE_SERVICES_JSON` secret (base64-encoded):

```yaml
- name: Create google-services.json
  run: echo "${{ secrets.GOOGLE_SERVICES_JSON }}" | base64 --decode > android/app/google-services.json
```

---

## Frontend – iOS

### Prerequisites

- macOS with Xcode installed
- Apple Developer account for distribution builds

### Release Build

```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode, select the Runner target, set your Team and Bundle Identifier, and use **Product → Archive** to create a distributable build.

### Google Services

`ios/Runner/GoogleService-Info.plist` is required for Firebase. It is injected in CI from the `GOOGLE_SERVICES_PLIST` secret (base64-encoded):

```yaml
- name: Create GoogleService-Info.plist
  run: echo "${{ secrets.GOOGLE_SERVICES_PLIST }}" | base64 --decode > ios/Runner/GoogleService-Info.plist
```

---

## CI/CD – GitHub Actions

The workflow at `.github/workflows/build.yml` runs on every push and pull request:

1. **code-quality** – `flutter analyze`, `flutter test`, `dart format` check
2. **check-backend** – pings `/wake-up` and `/health` on the production server
3. **build** – matrix build for Android, Web, Windows, iOS simulator, and macOS
4. **release** – creates a GitHub Release with all build artifacts when a `v*` tag is pushed
5. **deploy-web** – placeholder step for web deployment on `main` branch pushes
6. **notify** – reports final build status

### Required Repository Secrets

| Secret | Used for |
|--------|---------|
| `GOOGLE_SERVICES_JSON` | Android Firebase config (base64-encoded) |
| `GOOGLE_SERVICES_PLIST` | iOS Firebase config (base64-encoded) |

---

## Environment Variable Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `MONGODB_URI` | Yes | MongoDB connection string |
| `JWT_SECRET` | Yes | Secret for signing JWTs |
| `PORT` | No | Server port (default 10000) |
| `NODE_ENV` | No | `development` or `production` |
| `ALLOWED_ORIGINS` | No | Comma-separated list of allowed CORS origins; defaults to `*` if unset |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | No* | Path to service account JSON file |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | No* | Full service account JSON as a single-line string |

\* One of these is required for push notifications. If neither is set the server starts normally but FCM calls are skipped.
