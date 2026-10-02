# Performance

Notes on how Momentum handles performance on both the frontend and backend, and what to watch for when scaling.

---

## Frontend

### State Updates

`TaskCubit`, `TeamCubit`, `NotificationCubit`, and `SessionCubit` each `emit()` a new immutable state after every mutation. Widgets that subscribe with `BlocBuilder<TaskCubit, TaskState>` or `context.watch<TaskCubit>()` rebuild in full on every emission from that Cubit. For screens that only need part of the state, use `BlocSelector<TaskCubit, TaskState, T>` or a narrower `BlocBuilder` scoped to the smallest subtree that actually needs to update.

The `activeTasks` and `completedTasks` getters on `TaskState` iterate `currentTasks` on every access, calling `isCompletedToday()` on each task. If `currentTasks` grows large (hundreds of tasks), consider caching these lists and invalidating the cache on mutation rather than recomputing on every access.

### Polling Frequency

`TimerService` polls the backend every **10 seconds** while the app is in the foreground. This is intentional for near-real-time team updates. Each tick flushes the offline queue and reloads tasks, notifications, pending invitations, and dashboard stats. A tick is skipped if the previous one is still running, so a slow backend (for example one waking from sleep) never stacks up overlapping refreshes. On the web target, polling is disabled (`if (kIsWeb) return`) to avoid excessive background requests in the browser.

If battery life or data usage is a concern, the interval can be increased in `TimerService`:

```dart
_pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
  await onPollingTick();
});
```

### Widget Refresh Throttling

`WidgetService` runs after every task mutation and at the end of every poll. Each call writes three keys to `HomeWidgetPreferences`, waits a fixed 300 ms for the writes to flush, and then triggers an Android widget redraw. That means a widget write and redraw roughly every 10 seconds while the app is open, even when nothing changed. On devices with slow storage this can add latency to task completion. Consider skipping the update when the serialised widget payload is identical to the last one, and debouncing it when several mutations happen in quick succession.

### Offline Cache Writes

Every successful task load writes the task list to `SharedPreferences` through `LocalCacheService`, and loads run on each poll tick. For large task lists, consider skipping the write when the payload hasn't changed.

### Heatmap Rendering

`HeatMapComponent` recalculates `datasets` from `currentTasks` and `historicalCompletions` on every rebuild. The calculation iterates all tasks and all completion days. For users with long history (thousands of entries) this can be slow. The calculation runs on the UI thread – if profiling shows frame drops on the Analytics tab, move it to a `compute()` isolate.

The heatmap displays a maximum of 39 days. The `startDate` is clamped so it never requests more data than necessary.

### Image Assets

The splash and drawer logo (`momentum_app_logo_main.png`) is loaded from `assets/images/`. The same file is used for both light and dark mode. If you add separate light/dark logos, use `Image.asset` with the `ThemeProvider` to select the correct one rather than loading both.

---

## Backend

### Database Indexes

The following indexes are defined in Mongoose schemas:

| Collection | Index |
| ----------- | ------- |
| `Task` | `assignedTo`, `assignedBy`, `team`, `dueDate`, `isArchived + team`, `assignedBy + clientId` (unique, partial) |
| `TaskHistory` | `userId`, `teamId`, `userId + taskName` |
| `Notification` | `recipient + isRead`, `recipient + createdAt` |
| `Team` | `members.user`, `owner` |
| `User` | `teams`, `email` (unique), `inviteId` (unique, sparse) |
| `TeamInvitation` | `team + invitee + status` (unique) |

The `assignedBy + clientId` index only covers documents that have a `clientId` (`partialFilterExpression`), so it stays small. The most common query patterns (fetch tasks for a user, fetch notifications for a user, search by inviteId) are covered. If you add new query patterns, add corresponding indexes.

### Cleanup Job Performance

The daily cleanup job (`cleanupScheduler.ts`) runs three sequential passes over the `Task` collection. The archive pass is a single `updateMany`. The delete pass loads every archived task from before today and removes them one by one, and the completion-day pass calls `Task.find({})` with no filter, loading every task into memory. That is fine at small scale but will become slow with tens of thousands of tasks. For high-volume deployments:

- Add a `lastCompletedDate` index to speed up the archive step.
- Filter the completion-day pass to tasks that actually have old entries instead of loading every task.
- Process deletions in batches instead of one-by-one in a for loop.
- Move the history-saving step to a background job queue.

### FCM Token Cleanup

The app re-registers its FCM token on each start (`POST /users/fcm-token`), which refreshes `lastUsed`. Tokens that Firebase reports as invalid or unregistered are removed when a send fails. The registration endpoint does not cap the number of tokens per user, and tokens that never fail but are no longer used stay in the database. Add a periodic job to prune them:

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

`sendNotification` uses `Promise.allSettled` to send notifications to multiple tokens in parallel. For teams with many members, this can spike outbound Firebase requests. Firebase's free tier allows 500k messages/month and has no documented rate limit for server-side sends, but if you see FCM throttling errors, add a delay between batches. Task-assigned and task-completed notifications each cost two extra lookups (the team's settings and the recipient's settings) before sending.

### MongoDB Connection Pooling

The server connects with `serverSelectionTimeoutMS: 10000`. Mongoose 8 uses the MongoDB driver's default `maxPoolSize` of 100, which is ample for a single small instance. If you run several instances against one Atlas cluster, set a smaller pool explicitly so the total stays within the cluster's connection limit:

```js
await mongoose.connect(process.env.MONGODB_URI, {
  maxPoolSize: 20,
  serverSelectionTimeoutMS: 10000,
});
```

### Response Payload Size

`GET /tasks` populates `assignedTo`, `assignedBy`, `team`, and `completedBy.user` in a single query. For tasks with many assignees or completions, the response payload grows. Consider paginating this endpoint or limiting the fields returned with Mongoose `select` if payload size becomes an issue.

---

## Monitoring

### Backend Health Endpoints

- `GET /health` – basic liveness check; returns `{ "status": "ok", "timestamp": "...", "uptime": ... }`
- `GET /wake-up` – returns uptime alongside the timestamp; useful for monitoring dashboards and keep-alive pings

### Logging

The backend logs every incoming request (method, URL) to stdout. On Render this is visible in the Logs tab. For production, consider replacing `console.log` with a structured logger (e.g. `pino`) and shipping logs to a log aggregation service.

On the Flutter side, all service calls use the `logger` package. With the package's default filter, log output is emitted in debug builds only, so release builds are silent.

### Node.js Memory

Monitor memory usage in the Render dashboard. The daily cleanup loads tasks into memory (see Cleanup Job Performance above), so watch for growth as data grows. If memory grows steadily over days, a daily server restart (via Render's native restart option) is a practical workaround until the cause is diagnosed.
