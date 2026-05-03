# Performance

Notes on how Momentum handles performance on both the frontend and backend, and what to watch for when scaling.

---

## Frontend

### State Updates

`TaskDatabase` extends `ChangeNotifier` and calls `notifyListeners()` after every mutation. Widgets that subscribe with `Consumer<TaskDatabase>` or `context.watch<TaskDatabase>()` rebuild in full. For screens with a large number of tasks, use `context.select()` or `Consumer` on the smallest subtree that actually needs to update.

The `activeTasks` and `completedTasks` getters iterate `currentTasks` on every access. If `currentTasks` grows large (hundreds of tasks), consider caching these lists and invalidating the cache on mutation rather than recomputing on every access.

### Polling Frequency

`TimerService` polls the backend every **10 seconds** while the app is in the foreground. This is intentional for near-real-time team updates. On the web target, polling is disabled (`if (kIsWeb) return`) to avoid excessive background requests in the browser.

If battery life or data usage is a concern, the interval can be increased in `TimerService`:

```dart
_pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
  await onPollingTick();
});
```

### Widget Refresh Throttling

`WidgetService` is called after every task mutation. Each call writes multiple keys to `HomeWidgetPreferences` and then triggers an Android widget redraw. On devices with slow storage this can add latency to task completion. Consider debouncing the widget update if multiple mutations happen in quick succession.

### Heatmap Rendering

`HeatMapComponent` recalculates `datasets` from `currentTasks` and `historicalCompletions` on every rebuild. The calculation iterates all tasks and all completion days. For users with long history (thousands of entries) this can be slow. The calculation runs on the UI thread – if profiling shows frame drops on the Analytics tab, move it to a `compute()` isolate.

The heatmap displays a maximum of 39 days. The `startDate` is clamped so it never requests more data than necessary.

### Image Assets

The splash and drawer logo (`momentum_app_logo_main.png`) is loaded from `assets/images/`. The same file is used for both light and dark mode (see `splash_page.dart` where both branches reference the same path). If you add separate light/dark logos, use `Image.asset` with the `ThemeProvider` to select the correct one rather than loading both.

---

## Backend

### Database Indexes

The following indexes are defined in Mongoose schemas:

| Collection | Index |
|-----------|-------|
| `Task` | `assignedTo`, `assignedBy`, `team`, `dueDate`, `isArchived + team` |
| `TaskHistory` | `userId`, `teamId`, `userId + taskName` |
| `Notification` | `recipient + isRead`, `recipient + createdAt` |
| `Team` | `members.user`, `owner` |
| `User` | `teams`, `inviteId` (unique sparse) |
| `TeamInvitation` | `team + invitee + status` (unique) |

The most common query patterns (fetch tasks for a user, fetch notifications for a user, search by inviteId) are covered. If you add new query patterns, add corresponding indexes.

### Cleanup Job Performance

The daily cleanup job (`cleanupScheduler.js`) runs three sequential passes over the `Task` collection. Each pass uses `Task.find()` without a limit, which is fine at small scale but will become slow with tens of thousands of tasks. For high-volume deployments:

- Add a `lastCompletedDate` index to speed up the archive step.
- Process deletions in batches instead of one-by-one in a for loop.
- Move the history-saving step to a background job queue.

### FCM Token Cleanup

Each user stores up to 5 FCM tokens. Stale tokens (older than 60 days) are filtered out before sending but not removed from the database. Add a periodic job to prune them:

```js
await User.updateMany({}, {
  $pull: {
    fcmTokens: {
      lastUsed: { $lt: new Date(Date.now() - 60 * 24 * 60 * 60 * 1000) }
    }
  }
});
```

### Notification Volume

`sendBulkNotification` uses `Promise.allSettled` to send notifications to multiple users in parallel. For teams with many members, this can spike outbound Firebase requests. Firebase's free tier allows 500k messages/month and has no documented rate limit for server-side sends, but if you see FCM throttling errors, switch to batched multicast (`sendMulticast` already used) and add a delay between batches.

### MongoDB Connection Pooling

Mongoose uses a default connection pool size of 5. For a production server handling many concurrent requests, increase this in the `mongoose.connect` options:

```js
await mongoose.connect(process.env.MONGODB_URI, {
  maxPoolSize: 20,
  serverSelectionTimeoutMS: 10000,
});
```

### Response Payload Size

`GET /tasks/assigned` populates `assignedTo`, `assignedBy`, `team`, and `completedBy.user` in a single query. For tasks with many assignees or completions, the response payload grows. Consider paginating this endpoint or limiting the fields returned with Mongoose `select` if payload size becomes an issue.

---

## Monitoring

### Backend Health Endpoints

- `GET /health` – basic liveness check; returns `{ "status": "ok" }`
- `GET /wake-up` – returns uptime alongside the timestamp; useful for monitoring dashboards

### Logging

The backend logs every incoming request (method, URL, headers, body) to stdout. On Render this is visible in the Logs tab. For production, consider replacing `console.log` with a structured logger (e.g. `pino`) and shipping logs to a log aggregation service.

On the Flutter side, all service calls use the `logger` package. In release builds, the `Logger` defaults to `Level.warning` – verbose debug logs are suppressed automatically.

### Node.js Memory

The cleanup job calls `global.gc()` if garbage collection is available (requires the `--expose-gc` Node.js flag). On Render and most hosts this flag is not set, so the call is a no-op. Monitor memory usage in the Render dashboard; if memory grows steadily over days, a daily server restart (via Render's native restart option) is a practical workaround until the leak is diagnosed.
