# Troubleshooting

Common problems and how to fix them.

---

## Flutter / Frontend

### App shows blank screen or infinite loading after login

The `SplashPage` validates the stored JWT by calling `GET /auth/validate`. If the backend is unreachable (e.g. Render free-tier is sleeping) the request times out and the app falls through to the login page.

**Fix**: wake the backend first by hitting `/wake-up`, then reopen the app. For a permanent fix, upgrade to a paid Render plan or set up a keep-alive cron.

---

### `flutter pub get` fails with version conflicts

```bash
flutter upgrade
flutter pub get
```

If a specific package is the culprit, check `pubspec.lock` for the conflicting version and pin it explicitly in `pubspec.yaml`.

---

### Android emulator cannot reach the backend

The emulator's `localhost` is not the host machine. `api_base_url.dart` automatically maps debug Android builds to `http://10.0.2.2:10000`. If you changed this file, revert to the original value.

Also confirm the backend is actually running on port 10000 on the host:

```bash
curl http://localhost:10000/health
```

---

### iOS simulator cannot reach the backend

Debug iOS builds use `http://127.0.0.1:10000`. Ensure the backend is running and that macOS firewall is not blocking port 10000.

---

### `google-services.json` not found (Android build error)

This file is excluded from version control. For local development, download it from your Firebase project (Project Settings → Your apps → Android) and place it at `android/app/google-services.json`.

If you don't need Firebase locally, you can remove the `firebase_core` and `firebase_messaging` dependencies, but this will break push notifications.

---

### `GoogleService-Info.plist` not found (iOS build error)

Same as above – download from Firebase (Project Settings → Your apps → iOS) and place at `ios/Runner/GoogleService-Info.plist`.

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

The widget reads from `HomeWidgetPreferences` shared preferences. This file is written by `WidgetService` every time `TaskDatabase` changes state. If the widget is empty:

1. Open the app and log in – this triggers a full data load and widget refresh.
2. If the widget still shows nothing, check the Android logcat for `[WidgetService]` entries to see what's being saved.
3. On some devices, adding the widget before ever opening the app will show empty state – this resolves on first login.

---

### Notifications not received on Android

1. Confirm `POST /users/fcm-token` is being called after login – check backend logs for the confirmation line.
2. Verify the device is not in battery saver mode (kills background FCM delivery on some OEMs).
3. Check that `POST_NOTIFICATIONS` permission was granted (Android 13+).
4. In the Firebase Console, use the **Send test message** tool with the device's FCM token to rule out a server-side issue.

---

### `flutter analyze` reports errors on CI but not locally

Your local Flutter version may differ from the CI version (`3.41.4` in `build.yml`). Run:

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
MongoDB connection error: ...
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

### "You can only complete tasks assigned to you" on a team task

The `completeTask` controller checks that `task.assignedTo` contains the requesting user. This happens when:

- The task was assigned to the entire team but the `assignedTo` array was not populated correctly at creation time.
- The user was removed from the team after the task was created.

Check the task document in MongoDB and confirm `assignedTo` contains the user's `_id`.
