# Troubleshooting

Common problems and how to fix them.

---

## Flutter / Frontend

### App stays on the loading screen, or the first request is very slow

Render's free tier puts the backend to sleep after 15 minutes of inactivity, and the first request after that can take up to about a minute. `SplashPage` validates the stored JWT with `GET /auth/validate`; while the server wakes, the splash screen keeps loading.

If the server cannot be reached at all, the app does not log you out: the stored session is kept and the app opens on the last cached data with an "Offline" banner. Only an explicit `401`/`403` from the server signs you out.

**Fix**: hit `/wake-up` and reopen the app. Production keeps the service warm with a cron-job.org ping every 10 minutes (see [DEPLOYMENT.md](DEPLOYMENT.md)); for a permanent fix, upgrade to a paid Render plan.

---

### A task shows a cloud-off or sync-problem icon

Tasks created while offline are queued on the device and marked as waiting to sync (cloud-off icon). They sync automatically on the next poll once the server is reachable, and a task that hasn't synced yet cannot be completed or edited.

A sync-problem icon means the server rejected the task when it was replayed. Delete it and create it again. Team tasks are never queued; creating one needs a connection.

---

### `flutter pub get` fails with version conflicts

```bash
flutter upgrade
flutter pub get
```

If a specific package is the culprit, check `pubspec.lock` for the conflicting version and pin it explicitly in `pubspec.yaml`.

---

### Android emulator cannot reach the backend

The emulator's `localhost` is not the host machine. `lib/config/api_base_url.dart` maps debug builds on non-web platforms to `http://10.0.2.2:10000`. If you changed this file, revert to the original value.

Also confirm the backend is actually running on port 10000 on the host:

```bash
curl http://localhost:10000/health
```

---

### iOS simulator or desktop debug build cannot reach the backend

The compile-time `apiBaseUrl` uses the Android emulator address (`10.0.2.2`) for every non-web debug build. On an iOS simulator or a desktop target, change `apiBaseUrl` locally to `http://127.0.0.1:10000`, and ensure the backend is running and that no firewall is blocking port 10000.

---

### Web build always talks to production

Web builds use the production URL even in debug mode. To test backend changes, run the app on a mobile or desktop target, or change `apiBaseUrl` locally.

---

### `google-services.json` not found (Android build error)

This file is excluded from version control. For local development, download it from your Firebase project (Project Settings → Your apps → Android) and place it at `android/app/google-services.json`.

If you don't need Firebase locally, you can remove the `firebase_core` and `firebase_messaging` dependencies, but this will break push notifications.

---

### `GoogleService-Info.plist` not found (iOS build error)

Same as above – download from Firebase (Project Settings → Your apps → iOS) and place at `ios/Runner/GoogleService-Info.plist`.

---

### Google sign-in fails on web

- The redirect URI must be registered in Google Cloud Console exactly as the site origin **with a trailing slash** (for example `https://your-app.vercel.app/`). For local development, run on a fixed port (`flutter run -d chrome --web-port 5000`) and register that address too.
- If the backend answers "Token not issued for this application", the token's audience is not in `GOOGLE_CLIENT_ID`. Add the web client ID (and the mobile server client ID if different), comma-separated.
- After a redirect error the app shows a message with a "Back to Login" button. Choosing a different Google account from the picker is not an error.

---

### Tasks disappear after midnight

This is expected behaviour. The cleanup scheduler archives and deletes tasks completed on previous days. Their completion data is preserved in `TaskHistory` and visible in the heatmap. Only tasks relevant to today remain in the main `Task` collection.

---

### Heatmap shows no data for old dates

Historical data is loaded from `GET /tasks/history` when the app initialises. If the endpoint returns an empty array:

1. Check the backend logs – the `getTaskHistory` controller logs any errors.
2. Verify `TaskHistory` documents exist in MongoDB (`db.taskhistories.find()`).
3. If you migrated from an older version that didn't populate `TaskHistory`, run the manual cleanup once to backfill it:

```bash
curl -X POST https://your-backend/manual-cleanup
```

---

### Home screen widget shows "No tasks"

The widget reads from `HomeWidgetPreferences` shared preferences. This file is written by `WidgetService` every time `TaskCubit` loads or changes tasks. If the widget is empty:

1. Open the app and log in – this triggers a full data load and widget refresh.
2. If the widget still shows nothing, check the Android logcat for `[WidgetService]` entries to see what's being saved.
3. On some devices, adding the widget before ever opening the app will show empty state – this resolves on first login.

---

### Notifications not received on Android

1. Confirm `POST /users/fcm-token` is being called after login – check backend logs for the confirmation line.
2. Verify the device is not in battery saver mode (kills background FCM delivery on some OEMs).
3. Check that `POST_NOTIFICATIONS` permission was granted (Android 13+).
4. In the Firebase Console, use the **Send test message** tool with the device's FCM token to rule out a server-side issue.
5. Check the team's notification settings and your own: task-assigned and task-completed notifications are skipped when either side has them turned off.

---

### Web push notifications not received

1. Allow notifications for the site in the browser.
2. Confirm `/firebase-messaging-sw.js` is served from the site root. For the production site it must be present in `buildx/web/` (see [DEPLOYMENT.md](DEPLOYMENT.md)).
3. Confirm `_webVapidKey` in `lib/services/push_notification_service.dart` matches the Web Push certificate in Firebase Console → Cloud Messaging.
4. Web push is registered after login, so log in again after changing any of the above.

---

### A new file doesn't appear on the deployed web app

Vercel serves the committed snapshot in `buildx/web/` and does not run a build. After `flutter build web --release`, copy the output into `buildx/web/` and commit it. Files such as `vercel.json` and `firebase-messaging-sw.js` only reach production if they are in that folder.

---

### `flutter analyze` reports errors on CI but not locally

Your local Flutter version may differ from the CI version (`3.47.5` in `build.yml`). Run:

```bash
flutter --version
```

And upgrade if needed:

```bash
flutter upgrade
```

---

## Backend

### MongoDB connection refused on startup

```
Failed to start: ...
```

**Local**: ensure `mongod` is running:

```bash
# macOS (Homebrew)
brew services start mongodb-community

# Linux
sudo systemctl start mongod
```

**Atlas**: check that your IP is whitelisted under Network Access and that the `MONGODB_URI` in `.env` is correct (password URL-encoded if it contains special characters).

---

### JWT secret mismatch – all requests return 403

If you change `JWT_SECRET` in production, all existing tokens become invalid. Users will need to log in again. This is expected. Make sure the secret is consistent across restarts (use an environment variable, not a hardcoded string).

---

### Verification, 2FA, and reset emails never arrive

The server logs "Email disabled — missing env vars" at startup when any of `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`, `GMAIL_REFRESH_TOKEN`, or `EMAIL_FROM` is missing, and "Gmail OAuth2 token refresh failed" when the credentials are rejected. Registration still reports success in that state, so the user is simply never sent a code. Fix the variables (see [INSTALLATION.md](INSTALLATION.md)) and use "Resend". Also check the spam folder, and that `EMAIL_FROM` is the mailbox the refresh token belongs to or a verified "Send mail as" alias.

---

### `E11000` duplicate key on `assignedBy_1_clientId_1` when creating tasks

An older version of the `Task` schema built this index with `sparse: true`, which on a compound index still indexes every task and collides on the second task a user creates without a `clientId`. The schema now uses a partial index. On a database that still has the old index, run once from `backend/`:

```bash
npx ts-node src/scripts/fixTaskClientIdIndex.ts
```

It drops the stale index and rebuilds the `Task` indexes from the current schema. Deploy the backend before the frontend when an index changes.

---

### Firebase not initialised – push notifications skipped

The server logs a warning that no service account was found. Set one of `FIREBASE_SERVICE_ACCOUNT_PATH` or `FIREBASE_SERVICE_ACCOUNT_JSON` in your `.env` (see [DEPLOYMENT.md](DEPLOYMENT.md)). The server still starts and works normally without Firebase – only push notifications are disabled.

---

### Cleanup job did not run

The cron is scheduled at `5 0 * * *` UTC (12:05 AM). Verify:

1. The server was running at that time (check Render logs).
2. The `startScheduler()` call in `backend/src/index.ts` is reached after DB connection.
3. Trigger manually to confirm the logic works: `POST /manual-cleanup` (or `GET /manual-cleanup`).

---

### `ECONNREFUSED` when backend tries to reach MongoDB Atlas

Atlas free clusters pause after 60 days of inactivity. Log in to Atlas and click **Resume** on the cluster.

---

### CORS error in browser

The browser console shows a CORS policy error when accessing the API from an origin not in the allowed list. Set the `ALLOWED_ORIGINS` environment variable on your hosting platform to a comma-separated list of allowed origins:

```
ALLOWED_ORIGINS=https://yourapp.vercel.app,https://yourcustomdomain.com
```

Restart the server after updating the variable. No code changes are needed.

---

### Team invitation returns 400 "pending invitation already exists"

A user already has a pending (not yet accepted or declined) invitation to this team. The inviter must wait for the invitee to respond, or the invitation must expire (7-day TTL). Once the invitee declines, a new invitation can be sent – the controller automatically cleans up declined/expired invitations before creating a new one.

---

### "You can only complete tasks assigned to you"

This message now applies only to **personal** tasks, which only their assignee can complete. Any member of a team can complete any of that team's tasks. If a team task returns "You are not a team member", the user was removed from the team after the task was created.
