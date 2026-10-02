# Architecture

This document describes Momentum's system design, data flow, state management strategy, and the reasoning behind key technical decisions.

---

## System Overview

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│                          Flutter App                           │
│                                                                │
│  Pages → Components → Cubits (TaskCubit, TeamCubit,            │
│                               NotificationCubit, SessionCubit) │
│                                                                │
│  REST services             Device and local services           │
│  ─────────────             ─────────────────────────           │
│  AuthService               PushNotificationService             │
│  TaskService               WidgetService                       │
│  TeamService               TimerService                        │
│  UserService               SyncQueueService                    │
│  NotificationService       LocalCacheService                   │
│                            InitializationService               │
│                                                                │
└──────────────┬─────────────────────────────────────────────────┘
               │ HTTPS / REST
┌──────────────▼─────────────────────────────────────────────────┐
│                                                                │
│                        Express Backend                         │
│                                                                │
│  Routes → Middleware (JWT) → Controllers → Services            │
│                                                │               │
│              ┌───────────────────┬─────────────┴─────┐         │
│           MongoDB          Firebase FCM          Gmail API     │
│         (Mongoose)            (push)          (email, HTTPS)   │
│              │                                                 │
│   ┌──────────┴──┬─────────────┐                                │
│  Task    TaskHistory       User                                │
│  Team    TeamInvitation    Notification                        │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## Frontend Architecture

### State Management – Cubit (flutter_bloc)

Application state is split across four `Cubit`s in `lib/blocs/`, each paired with an immutable state class. All four are constructed once in `main.dart` and registered at the root of the widget tree via `MultiProvider`, alongside `ThemeProvider`, which intentionally remains a plain `ChangeNotifier`.

```
main.dart
  └── MultiProvider
        ├── BlocProvider<NotificationCubit>
        ├── BlocProvider<TeamCubit>
        ├── BlocProvider<SessionCubit>
        ├── BlocProvider<TaskCubit>
        └── ChangeNotifierProvider<ThemeProvider>
```

Widgets subscribe with `BlocBuilder<XCubit, XState>`, `context.watch<XCubit>()`, or call methods directly via `context.read<XCubit>()`.

| Cubit | State | Responsibility |
| ------- | ------- | ----------------- |
| `TaskCubit` | `TaskState` | `currentTasks`, `historicalCompletions`, `dashboardStats`, `isOffline`; computed getters `activeTasks`, `completedTasks`, `personalTasks`, `teamTasks`; the offline cache (`LocalCacheService`) and sync queue (`SyncQueueService`); polling and midnight cleanup (`TimerService`); FCM setup (`PushNotificationService`); calls `WidgetService` after every mutation and every poll |
| `TeamCubit` | `TeamState` | `userTeams` (cached for offline use), `pendingInvitations`, `selectedTeam` |
| `NotificationCubit` | `NotificationState` | in-app notification list and unread count |
| `SessionCubit` | `SessionState` | `jwtToken`, `userId` |

`TaskCubit` takes `NotificationCubit`, `TeamCubit`, and `SessionCubit` as constructor dependencies and subscribes directly to `teamCubit.stream` to react to team-selection changes — switching teams reloads `TaskCubit`'s tasks and dashboard stats for the new scope. This is the one place state flows between Cubits; `TeamCubit`, `NotificationCubit`, and `SessionCubit` don't depend on each other or on `TaskCubit`.

### Service Layer

Each domain has a dedicated service class that owns HTTP communication or device-level I/O. `TaskCubit` builds `TaskService` after login, `TeamCubit.setToken()` builds `TeamService`, `NotificationCubit.setToken()` configures `NotificationService`, and pages that need the user endpoints construct `UserService` from the token held by `SessionCubit`. `AuthService` is a singleton. `userId` is owned by `SessionCubit`.

| Service | Responsibility |
| --------- | --------------- |
| `AuthService` | Register, login, Google Sign-In (native on mobile, redirect on web), email-code flows (verification, 2FA, password reset), token validation, logout |
| `TaskService` | CRUD for tasks, completion toggling via `PATCH /tasks/:id/complete`, history and dashboard stats |
| `TeamService` | Team lifecycle, invitations, member management |
| `UserService` | Profile fetch, user search, privacy settings, 2FA toggle, password change, account deletion |
| `NotificationService` | REST notification list: fetch, mark read, mark all read |
| `PushNotificationService` | FCM permission and token registration, foreground display through `flutter_local_notifications` |
| `WidgetService` | Write data to `HomeWidgetPreferences`, trigger widget redraw |
| `TimerService` | 10-second polling timer, midnight cleanup timer |
| `LocalCacheService` | Persist last-known tasks, teams, history, and stats for offline use |
| `SyncQueueService` | Persist personal-task creations made while offline |
| `InitializationService` | App startup: home_widget setup, widget-tap routing, push initialisation from a stored JWT |

Notifications are split across two classes that never call each other: `NotificationCubit` holds `NotificationService` (REST list calls) and `TaskCubit` holds `PushNotificationService` (FCM and local notifications). `InitializationService` also initialises a `PushNotificationService` at startup when a stored JWT exists.

### Offline Support

Reads fall back to a device cache, and one kind of write (creating a personal task) is queued for later.

- **Cache.** `LocalCacheService` stores the last successful tasks (per personal or team scope), team list, historical completions, and dashboard stats in `SharedPreferences`. Every successful load overwrites the cache, so the backend remains the source of truth. The cache holds no credentials and is cleared on logout.
- **Detection.** `isNetworkError()` (`lib/utils/network_utils.dart`) classifies connectivity failures (socket errors, timeouts, client exceptions). Cubits use it to choose between a cached fallback, which sets `isOffline` and shows an offline banner, and surfacing a real error.
- **Queue.** A personal task created while offline gets a `local_` id and `TaskSyncStatus.pendingCreate`, and `SyncQueueService` persists the request. The queue is flushed at session start and on every poll or pull-to-refresh, one flush at a time. A successful replay swaps the placeholder for the server's task; a rejection by the server marks the placeholder `syncFailed` and removes it from the queue. Team tasks are never queued because they need server-side permission checks.
- **Guards.** A task that has not synced yet cannot be completed or edited; deleting it removes it from the queue.
- **Idempotency.** Replays send the local id as `clientId`. The server returns the existing task for a known key instead of creating a duplicate (see Key Design Decisions).
- **Session.** `AuthService.validateToken()` keeps the stored session when the server is unreachable or answers 5xx; only an explicit 401 or 403 signs the user out.

### Google Sign-In

- **Mobile:** `google_sign_in`'s `authenticate()` returns an ID token, which `AuthService` posts to `POST /auth/google`.
- **Web:** the login button navigates the whole page to Google's OAuth endpoint (`response_type=id_token`). Google redirects back to the site root with `#id_token=...` in the URL fragment. `SplashPage` detects the fragment before the normal stored-session check, and `AuthService.completeWebGoogleRedirect()` removes it from the address bar and posts the token to `POST /auth/google`.
- If the account has 2FA enabled, the response is a challenge instead of a token and the app opens `TwoFactorPage`.

### Navigation

`app.dart` configures a named-route `MaterialApp`. The `navigatorKey` from `InitializationService` is wired in so widget-tap actions from the home screen can trigger navigation even when the app is in the foreground.

Route map:

| Route | Page |
| ------- | ------ |
| `/` or `/splash` | `SplashPage` – session check and Google redirect gate |
| `/login` | `LoginPage` |
| `/register` | `RegisterPage` |
| `/home` | `HomePage` – personal workspace |

Team views (`TeamHomePage`, `TeamSelectionPage`, etc.) are pushed with `Navigator.push` rather than named routes because they carry a `Team` argument. The auth sub-flows (`EmailVerificationPage`, `TwoFactorPage`, `ForgotPasswordPage`, `ResetPasswordPage`) are pushed the same way because they carry an email address.

### Theme

`ThemeProvider` wraps `ThemeData` for both light and dark modes (defined in `lib/theme/theme.dart`) and persists the user's choice in `SharedPreferences`.

---

## Backend Architecture

### Express Application (`backend/src/index.ts`)

The entry point connects to MongoDB, initialises Firebase, starts the cron scheduler, registers middleware (helmet, CORS, body parsers, request logger), and mounts the route groups. Gmail credentials are verified in the background so a mail problem never blocks startup.

```
Request
  → helmet (security headers)
  → CORS middleware (origin controlled by ALLOWED_ORIGINS env var)
  → JSON and URL-encoded body parsers
  → Request logger
  → Public routes: /health, /wake-up, /manual-cleanup, /auth/* (except /auth/validate)
  → authenticateToken middleware (JWT verify, User.findById, isActive check)
  → Protected routes: /tasks, /teams, /notifications, /users, /auth/validate
  → 404 handler
  → Error handler (500)
```

### Authentication Middleware (`backend/src/middleware/authMiddleware.ts`)

Verifies the `Authorization: Bearer <token>` header, resolves the full `User` document, rejects deactivated accounts (`isActive: false`), and attaches `req.user` and `req.userId` for use in controllers. It authenticates only; role checks are separate.

### Controllers and Permission Checks

Controllers are thin: they validate input, check permissions, call Mongoose models or services, and return a clean JSON response. Role checks are plain functions in `backend/src/helpers/taskHelpers.ts` (create, edit, delete) and inline checks in `teamController.ts` (invite, settings, roles, removal), called from the controllers on every request. Update endpoints build their changes from explicit field whitelists rather than passing `req.body` to Mongoose.

### Scheduler and Cleanup (`schedulerService.ts`, `cleanupScheduler.ts`)

`node-cron` runs three jobs, all in UTC:

| Schedule | Job |
| ---------- | ----- |
| Daily, 12:05 AM | Task cleanup (below) |
| Daily, 9:00 AM | Due-date reminders for tasks due the next day |
| Sundays, 2:00 AM | Delete read notifications older than 30 days |

The daily cleanup has three steps:

1. **Archive** – marks tasks with `lastCompletedDate < today` as `isArchived: true`
2. **Delete & preserve** – finds archived tasks older than today, saves their `completedDays` to `TaskHistory`, then deletes them
3. **Clean active tasks** – removes `completedDays` entries older than today from still-active tasks (saves history first)

This design means the `Task` collection only ever contains tasks relevant to the current day. All historical data lives in `TaskHistory` and is never deleted.

### Notification Service (`backend/src/services/notificationService.ts`)

- Detects the Firebase service account from the `FIREBASE_SERVICE_ACCOUNT_JSON` env var, `FIREBASE_SERVICE_ACCOUNT_PATH`, or a well-known local file
- Sends FCM messages to every token registered for a user
- Removes tokens that Firebase reports as invalid or unregistered
- Saves in-app `Notification` documents to MongoDB alongside each FCM send
- Task-assigned and task-completed notifications are skipped when the team's setting or the recipient's own setting turns them off

### Email and OTP Services (`emailService.ts`, `otpService.ts`)

`emailService.ts` sends mail through the Gmail REST API over HTTPS using an OAuth2 refresh token; the access token is cached in memory and refreshed lazily. `otpService.ts` provides `generateAndSendOtp()`, the shared shape of every code flow: generate a 6-digit code, persist it with an expiry, then try to send it and report `sent` to the caller, which decides whether a send failure fails the request.

| Flow | Code expiry |
| ------ | ------------- |
| Email verification (registration, resend) | 5 minutes |
| Two-factor sign-in (password and Google) | 10 minutes |
| Password reset, password change, account deletion | 10 minutes |

Resend and request endpoints enforce a 60-second cooldown derived from the stored expiry timestamp.

---

## Data Models

### Task

```
Task {
  name, description
  assignedTo: [User]          # array for multi-assignee support
  assignedBy: User
  team: Team                  # null for personal tasks
  priority: low|medium|high|urgent
  dueDate: Date
  tags: [String]
  completedDays: [Date]       # one entry per day the task was completed
  completedBy: [{ user, completedAt }]
  lastCompletedDate: Date
  isArchived: Boolean
  archivedAt: Date
  isTeamTask: Boolean
  assignmentType: individual|multiple|team
  clientId: String            # idempotency key, set only for offline-queued creates
}
```

A partial unique index on `assignedBy` + `clientId` (only for documents that have a `clientId`) makes replayed creates idempotent.

### TaskHistory

Preserved after a Task is deleted by the cleanup job:

```
TaskHistory {
  userId: User
  taskName: String
  completedDays: [Date]
  teamId: Team
}
```

### Team

```
Team {
  name, description
  owner: User
  members: [{ user, role: owner|admin|member, joinedAt, invitedBy }]
  settings: {
    allowMemberInvite: Boolean
    taskAutoDelete: Boolean
    notificationSettings: { taskAssigned, taskCompleted, memberJoined }
  }
  isActive: Boolean
}
```

### TeamInvitation

```
TeamInvitation {
  team: Team
  inviter: User
  invitee: User
  email: String
  role: admin|member
  status: pending|accepted|declined|expired
  expiresAt: Date             # 7 days after creation
  message: String
}
```

A unique index on `team` + `invitee` + `status` prevents duplicate invitations in the same state.

### Notification

```
Notification {
  recipient: User
  sender: User
  team: Team
  task: Task
  type: task_assigned|task_completed|team_invitation|team_member_joined|task_due_reminder
  title, message, data
  isRead, readAt
  isSent, fcmMessageId
}
```

### User (key fields)

```
User {
  email, password (bcrypt), name, googleId
  isEmailVerified, twoFactorEnabled, isActive
  inviteId: String (unique, auto-generated, e.g. "swift-tiger-1234")
  isPublic: Boolean
  profileVisibility: { showEmail, showName, showBio }
  teams: [Team]
  notificationSettings: { email, push, inApp, taskAssigned, ... }
  fcmTokens: [{ token, platform, lastUsed }]
  one-time code fields (verification, 2FA, reset, change, deletion)  # select: false
}
```

---

## Key Design Decisions

### Why Cubit Instead of Bloc or Riverpod?

State management moved twice: Provider/`ChangeNotifier` → BLoC → Cubit. BLoC's event model required threading a `Completer` through any event whose result a caller needed to await — a workaround that had spread across most event handlers and was a sign of fighting the framework rather than using its strengths. None of the app's flows need BLoC's actual benefits (event replay, `droppable`/`sequential` concurrency transformers, testing against a recorded event log), so Cubit's direct method calls — which return a value or throw like any other `async` function — removed the workaround entirely without losing anything the app was using.

### Why Four Cubits Instead of One?

Task, team, notification, and session state used to live together in a single object. Splitting them by domain (`TaskCubit`, `TeamCubit`, `NotificationCubit`, `SessionCubit`) means each state class is sized to what it actually holds, and a widget that only cares about, say, unread notifications doesn't rebuild on every task mutation. The one genuine cross-domain dependency — task data needing to reload when the selected team changes — is handled by `TaskCubit` subscribing directly to `TeamCubit.stream`, rather than folding team state back into `TaskCubit` or routing the change through a shared parent object.

### Why Archive Instead of Delete on Completion?

Deleting completed tasks immediately would lose the activity history used by the heatmap and productivity analytics. Archiving them for the day, then moving data to `TaskHistory` during the cleanup job, preserves history indefinitely with minimal storage cost.

### Why `completedDays` Array Instead of a Boolean?

The same task can be completed on multiple days (recurring habit tracking). The array approach supports streak calculation and the heatmap without needing a separate completion record per day.

### Why JWT Over Sessions?

The app supports multiple platforms (Android, iOS, web, desktop) and a stateless REST API is simpler to deploy and scale. JWTs are stored in the device keychain/keystore via `flutter_secure_storage` on mobile.

### Why Idempotency Keys for Offline Sync?

A personal task created while offline is queued and replayed later. Mobile connections are unreliable enough that a replay can arrive after the original request already succeeded, so the client generates the task's id up front and sends it as `clientId`. `POST /tasks` looks the key up first and returns the existing task (HTTP 200) instead of creating a second one, and a partial unique index on `assignedBy` + `clientId` settles concurrent retries. The index uses `partialFilterExpression` rather than `sparse`: on a compound index, `sparse` only skips documents missing every indexed field, and every task has `assignedBy`, so a sparse index would collide on the second task a user created without a `clientId`. Only replayed creates carry a `clientId`; a direct create does not.

### Why a Full-Page Redirect for Google Sign-In on Web?

The popup used by Google's rendered button relays its result back through `postMessage`, and `accounts.google.com`'s own Cross-Origin-Opener-Policy blocks that relay no matter which headers the host page sends. A full-page redirect with `response_type=id_token` involves no popup and no cross-window messaging. The redirect URI is the site origin with a trailing slash and must be registered in Google Cloud Console.

### Why the Gmail REST API Instead of SMTP?

Render blocks outbound SMTP on ports 465 and 587. Mail is sent through the Gmail REST API over HTTPS (port 443) with an OAuth2 refresh token, which works on every host that allows outbound HTTPS.

### Why the Backend Owns Timestamps

Completion timestamps (`completedDays`, `completedBy.completedAt`) are always set by the server. Clients never send them, because device clocks and timezones can't be trusted.

### Home Widget Data Flow

```
TaskCubit.updateWidget()
  → WidgetService.updateWidgetWithHistoricalData(tasks, selectedTeam)
    → HomeWidget.saveWidgetData('widget_tasks', jsonEncoded(taskList))
    → HomeWidget.saveWidgetData('widget_team_name', teamName)
    → HomeWidget.updateWidget(androidName: 'MomentumHomeWidget')
      → Android OS calls MomentumHomeWidget.onUpdate()
        → reads from HomeWidgetPreferences
        → builds RemoteViews
        → AppWidgetManager.updateAppWidget()
```

Widget taps send a `homeWidget://widget?widget_action=...` URI. The home_widget plugin surfaces it to Dart (on cold start and while the app is running), and `InitializationService._handleWidgetAction()` routes it: toggling a task, refreshing data, or navigating to the home page.
