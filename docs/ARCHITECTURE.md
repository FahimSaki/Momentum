# Architecture

This document describes Momentum's system design, data flow, state management strategy, and the reasoning behind key technical decisions.

---

## System Overview

```
┌──────────────────────────────────────────────────────────┐
│                     Flutter App                           │
│                                                             │
│  Pages → Components → Cubits (TaskCubit, TeamCubit,        │
│                        NotificationCubit, SessionCubit)     │
│                         │                                   │
│              ┌──────────┴──────────┐                        │
│          TaskService          NotificationService           │
│          TeamService          WidgetService                 │
│          UserService          TimerService                  │
└──────────────┬────────────────────────────────────────────┘
               │ HTTPS / REST
┌──────────────▼────────────────────────────────────────────┐
│                   Express Backend                          │
│                                                              │
│  Routes → Middleware (JWT) → Controllers → Services         │
│                                   │                          │
│                          ┌────────┴────────┐                 │
│                       MongoDB          Firebase FCM           │
│                       (Mongoose)                              │
│                          │                                    │
│              ┌───────────┼───────────┐                        │
│           Task        TaskHistory  User                       │
│           Team        TeamInvit.   Notification                │
└─────────────────────────────────────────────────────────────┘
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
| `TaskCubit` | `TaskState` | `currentTasks`, `historicalCompletions`, `dashboardStats`; computed getters `activeTasks`, `completedTasks`, `personalTasks`, `teamTasks`; the offline sync queue (`SyncQueueService`); polling and midnight cleanup (`TimerService`); calls `WidgetService` after every mutation |
| `TeamCubit` | `TeamState` | `userTeams`, `pendingInvitations`, `selectedTeam` |
| `NotificationCubit` | `NotificationState` | in-app notification list and unread count |
| `SessionCubit` | `SessionState` | `jwtToken`, `userId` |

`TaskCubit` takes `NotificationCubit`, `TeamCubit`, and `SessionCubit` as constructor dependencies and subscribes directly to `teamCubit.stream` to react to team-selection changes — switching teams reloads `TaskCubit`'s tasks, history, and dashboard stats for the new scope. This is the one place state flows between Cubits; `TeamCubit`, `NotificationCubit`, and `SessionCubit` don't depend on each other or on `TaskCubit`.

### Service Layer

Each domain has a dedicated service class that owns HTTP communication. Services are instantiated by their owning Cubit after authentication — `TaskCubit` builds `TaskService`, `TeamCubit.setToken()` builds `TeamService`, and so on — and hold `jwtToken` for the lifetime of the session. `userId` is owned separately by `SessionCubit`.

| Service | Responsibility |
| --------- | --------------- |
| `TaskService` | CRUD for tasks, completion toggling via `PATCH /tasks/:id/complete`, history fetch |
| `TeamService` | Team lifecycle, invitations, member management |
| `UserService` | Profile fetch, search, privacy settings |
| `NotificationService` | Firebase FCM init, in-app notification fetch/mark-read |
| `AuthService` | Login, register, token validation, logout |
| `WidgetService` | Write data to `HomeWidgetPreferences`, trigger widget redraw |
| `TimerService` | 10-second polling timer, midnight cleanup timer |
| `InitializationService` | App startup: Firebase, home_widget, JWT restoration |

`NotificationService` is instantiated twice, once per consumer: `TaskCubit` holds an instance purely for FCM/local-notification setup, and `NotificationCubit` holds a separate instance purely for the REST notification-list calls (`getNotifications`, `markAsRead`, `markAllAsRead`). The two never call each other's methods.

### Navigation

`app.dart` configures a named-route `MaterialApp`. The `navigatorKey` from `InitializationService` is wired in so widget-tap actions from the home screen can trigger navigation even when the app is in the foreground.

Route map:

| Route | Page |
| ------- | ------ |
| `/` or `/splash` | `SplashPage` – JWT validation gate |
| `/login` | `LoginPage` |
| `/register` | `RegisterPage` |
| `/home` | `HomePage` – personal workspace |

Team views (`TeamHomePage`, `TeamSelectionPage`, etc.) are pushed with `Navigator.push` rather than named routes because they carry a `Team` argument.

### Theme

`ThemeProvider` wraps `ThemeData` for both light and dark modes (defined in `lib/theme/theme.dart`) and persists the user's choice in `SharedPreferences`.

---

## Backend Architecture

### Express Application (`backend/src/index.ts`)

The entry point connects to MongoDB, registers middleware (CORS, JSON body parser, request logger), mounts authenticated route groups, and starts the cron scheduler.

```
Request
  → CORS middleware (origin controlled by ALLOWED_ORIGINS env var)
  → JSON body parser
  → Request logger
  → Public routes: /health, /wake-up, /manual-cleanup, /auth/*
  → authenticateToken middleware (JWT verify + User.findById)
  → Protected routes: /tasks, /teams, /notifications, /users
  → Error handler (500)
  → 404 handler
```

### Authentication Middleware (`backend/src/middleware/middle_auth.ts`)

Verifies the `Authorization: Bearer <token>` header, resolves the full `User` document, and attaches `req.user` and `req.userId` for use in controllers.

### Controllers

Controllers are thin: they validate input, check permissions, call Mongoose models or services, and return a clean JSON response. Business logic (history saving, cleanup steps, notification dispatch) lives in service files.

### Cleanup Scheduler (`backend/src/services/cleanupScheduler.ts`)

Runs at **12:05 AM UTC** every day via `node-cron`:

1. **Archive** – marks tasks with `lastCompletedDate < today` as `isArchived: true`
2. **Delete & preserve** – finds archived tasks older than today, saves their `completedDays` to `TaskHistory`, then deletes them
3. **Clean active tasks** – removes `completedDays` entries older than today from still-active tasks (saves history first)

This design means the `Task` collection only ever contains tasks relevant to the current day. All historical data lives in `TaskHistory` and is never deleted.

### Notification Service (`backend/src/services/notificationService.ts`)

- Detects the Firebase service account from the `FIREBASE_SERVICE_ACCOUNT_JSON` env var, `FIREBASE_SERVICE_ACCOUNT_PATH`, or well-known file locations
- Sends FCM messages to all valid tokens for a user (up to 5 per user, refreshed on each login)
- Removes tokens that return `messaging/registration-token-not-registered`
- Saves in-app `Notification` documents to MongoDB in parallel with the FCM send

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
}
```

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

### User (key fields)

```
User {
  email, password (bcrypt), name
  inviteId: String (unique, auto-generated, e.g. "swift-tiger-1234")
  isPublic: Boolean
  profileVisibility: { showEmail, showName, showBio }
  teams: [Team]
  notificationSettings: { email, push, inApp, taskAssigned, ... }
  fcmTokens: [{ token, platform, lastUsed }]  # max 5 per user
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

Widget taps send a `homeWidget://widget?widget_action=...` URI intent which is intercepted by `MainActivity` and routed through `InitializationService._handleWidgetAction()`.
