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
| --------- | ------- |
| Runtime | Node |
| Root directory | `backend` |
| Build command | `npm install && npm run build` |
| Start command | `npm start` |
| Instance type | Free or Starter |

1. Under **Environment**, add the following variables:

| Key | Value |
| ----- | ------- |
| `MONGODB_URI` | Your MongoDB Atlas connection string |
| `JWT_SECRET` | A long random secret (use `openssl rand -hex 32`) |
| `PORT` | `10000` |
| `NODE_ENV` | `production` |
| `GMAIL_CLIENT_ID` | OAuth2 client ID for the Gmail account that sends OTP emails |
| `GMAIL_CLIENT_SECRET` | OAuth2 client secret for that same client |
| `GMAIL_REFRESH_TOKEN` | Refresh token scoped to `gmail.send` for that client |
| `EMAIL_FROM` | The Gmail address the refresh token belongs to (or a verified "Send mail as" alias on it) |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID(s) accepted by `POST /auth/google`; comma-separated if mobile and web use different IDs |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Paste the full contents of your Firebase service account JSON as a single-line string |
| `ALLOWED_ORIGINS` | Comma-separated list of allowed CORS origins (e.g. `https://yourapp.vercel.app,https://yourcustomdomain.com`) |

> **Never use `FIREBASE_SERVICE_ACCOUNT_PATH` on Render** – the filesystem is ephemeral. Use `FIREBASE_SERVICE_ACCOUNT_JSON` instead. The notification service parses this variable at startup and uses it automatically.

> **Why Gmail's REST API and not SMTP?** Render blocks outbound SMTP on ports 465 and 587, so a `nodemailer`/SMTP setup silently times out there. Momentum sends mail over HTTPS (port 443) via the Gmail API instead (`backend/src/services/emailService.ts`). Without all four `GMAIL_*` / `EMAIL_FROM` variables the server still boots, but verification, 2FA, password-reset, password-change, and account-deletion codes are never delivered – see [INSTALLATION.md](INSTALLATION.md) for how to obtain them.

> If `ALLOWED_ORIGINS` is not set, the server defaults to allowing all origins (`*`). Set it explicitly in production.

1. Click **Create Web Service**. Render runs `npm install && npm run build` to compile TypeScript, then starts the server with `npm start` (which runs `node dist/index.js`).

### Keep-Alive

Render free-tier instances spin down after 15 minutes of inactivity, and the first request after that can take up to about a minute. Production keeps the service warm with an external scheduler (cron-job.org) that pings the backend every 10 minutes; `GET /health` and `GET /wake-up` are both cheap, unauthenticated endpoints suited to this. The GitHub Actions workflow in `.github/workflows/build.yml` also pings `/wake-up` before every build. For an always-on service, upgrade to a paid Render plan.

### Redeployment

Every push to `main` triggers a new Render build automatically if auto-deploy is enabled in the Render dashboard. Render re-runs the full build command (`npm install && npm run build`) on each deploy so compiled output is always up to date.

**Deploy order.** When a release adds or changes a MongoDB index (for example the partial unique index on `assignedBy` + `clientId`), deploy the backend first so Mongoose builds the index before any client that depends on it goes live.

### MongoDB Atlas Setup

1. Create a free cluster at [cloud.mongodb.com](https://cloud.mongodb.com).
2. Create a database user with read/write access.
3. Whitelist `0.0.0.0/0` (all IPs) under Network Access – Render's outbound IPs change.
4. Copy the connection string (`mongodb+srv://...`) and set it as `MONGODB_URI`.

The app creates all collections and indexes automatically on first use. No migration scripts are required for a fresh deployment.

### Maintenance Scripts

Scripts live in `backend/src/scripts/`. Run them from `backend/` with `MONGODB_URI` set, for example `npx ts-node src/scripts/fixTaskClientIdIndex.ts`.

| Script | Purpose |
| -------- | --------- |
| `addInviteIds.ts` | One-time backfill: gives existing users an invite ID and default visibility settings |
| `cleanupOldNotification.ts [days]` | Deletes read notifications older than the given number of days (default 30) after a 5-second confirmation delay |
| `fixTaskClientIdIndex.ts` | Drops the stale `assignedBy_1_clientId_1` index and rebuilds the Task indexes from the current schema |

---

## Frontend – Web (Vercel)

The web build is served at `https://momentum-beryl-nine.vercel.app`.

Vercel does not build the Flutter app. It serves a pre-built static snapshot committed under `buildx/web/`, so there is no build command and no Flutter SDK on Vercel.

### Publish a New Web Build

1. Build locally:

```bash
flutter build web --release
```

1. Replace the contents of `buildx/web/` with the contents of `build/web/`.
2. Confirm the files that must reach production are present in `buildx/web/`: `index.html`, `vercel.json`, `firebase-messaging-sw.js`, and `manifest.json`. They originate in `web/` and are copied into `build/web/` by the build.
3. Commit and push. Vercel serves the new snapshot.

`vercel.json` sets `Cross-Origin-Opener-Policy: same-origin-allow-popups` and `Cross-Origin-Embedder-Policy: unsafe-none` on every response.

### CORS and Google Sign-In

The backend reads allowed origins from the `ALLOWED_ORIGINS` environment variable (comma-separated). Add your Vercel deployment URL and any custom domain to that variable on Render. If `ALLOWED_ORIGINS` is unset, all origins are allowed.

Google Sign-In on web redirects back to the site origin. Whenever the web domain changes, register the new origin with a trailing slash (for example `https://your-app.vercel.app/`) as an authorised redirect URI for the OAuth client in Google Cloud Console.

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

1. Reference `key.properties` in `android/app/build.gradle.kts` (standard Flutter signing config). The release build type currently signs with the debug key.

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

The workflow at `.github/workflows/build.yml` runs on every push, on pull requests to `main` and `develop`, on `v*` tags, and on manual dispatch. It pins Flutter to the version in its `FLUTTER_VERSION` variable (currently `3.47.5`).

1. **code-quality** – `flutter analyze --fatal-infos`, `flutter test` (non-blocking), and a `dart format` check
2. **check-backend** – pings `/wake-up` and `/health` on the production server
3. **build** – matrix build for Android, Web, Linux, Windows, iOS simulator, and macOS
4. **release** – creates a GitHub Release with all build artifacts when a `v*` tag is pushed
5. **deploy-web** – placeholder step for web deployment on `main` branch pushes (production web is published through `buildx/web/`, see above)
6. **notify** – reports final build status

### Required Repository Secrets

| Secret | Used for |
| -------- | --------- |
| `GOOGLE_SERVICES_JSON` | Android Firebase config (base64-encoded) |
| `GOOGLE_SERVICES_PLIST` | iOS Firebase config (base64-encoded) |

The CI workflow only checks the already-deployed production server (`/wake-up`, `/health`); it doesn't run the backend or send email, so the `GMAIL_*` variables aren't needed as repository secrets — they only live on Render.

---

## Environment Variable Reference

| Variable | Required | Description |
| ---------- | ---------- | ------------- |
| `MONGODB_URI` | Yes | MongoDB connection string |
| `JWT_SECRET` | Yes | Secret for signing JWTs |
| `PORT` | No | Server port (default 10000) |
| `NODE_ENV` | No | `development` or `production` |
| `ALLOWED_ORIGINS` | No | Comma-separated list of allowed CORS origins; defaults to `*` if unset |
| `GOOGLE_CLIENT_ID` | No | Google OAuth client ID(s) accepted by `POST /auth/google`, comma-separated; the token audience is not checked if unset |
| `GMAIL_CLIENT_ID` | Yes† | OAuth2 client ID for outgoing email |
| `GMAIL_CLIENT_SECRET` | Yes† | OAuth2 client secret for outgoing email |
| `GMAIL_REFRESH_TOKEN` | Yes† | OAuth2 refresh token (`gmail.send` scope) |
| `EMAIL_FROM` | Yes† | Sending address; must match a verified alias on the Gmail account |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | No* | Path to service account JSON file |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | No* | Full service account JSON as a single-line string |

\* One of these is required for push notifications. If neither is set the server starts normally but FCM calls are skipped.

† The server still boots without these, but registration, 2FA, password-reset, password-change, and account-deletion emails are never delivered — treat them as required for a usable deployment. See [INSTALLATION.md](INSTALLATION.md) for how to obtain them.
