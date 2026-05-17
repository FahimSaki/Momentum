# Architecture

This document describes Momentum's system design, data flow, state management strategy, and the reasoning behind key technical decisions.

---

## System Overview

```
┌──────────────────────────────────────────────────────────┐
│                     Flutter App                          │
│                                                          │
│  Pages → Components → TaskDatabase (ChangeNotifier)      │
│                         │                                │
│              ┌──────────┴──────────┐                     │
│          TaskService          NotificationService        │
│          TeamService          WidgetService              │
│          UserService          TimerService               │
└──────────────┬──────────────────────────────────────────┘
               │ HTTPS / REST
┌──────────────▼──────────────────────────────────────────┐
│                   Express Backend                        │
│                                                          │
│  Routes → Middleware (JWT) → Controllers → Services      │
│                                   │                      │
│                          ┌────────┴────────┐             │
│                       MongoDB          Firebase FCM      │
│                       (Mongoose)                         │
│                          │                               │
│              ┌───────────┼───────────┐                   │
│           Task        TaskHistory  User                  │
│           Team        TeamInvit.   Notification          │
└──────────────────────────────────────────────────────────┘
```

---

## Frontend Architecture

### State Management – Provider + TaskDatabase

All application state is held in a single `ChangeNotifier` called `TaskDatabase` (`lib/database/task_database.dart`). It is registered at the root of the widget tree via `MultiProvider` in `main.dart`.

```
main.dart
  └── MultiProvider
        ├── TaskDatabase   ← task state, team state, notifications
        └── ThemeProvider  ← dark/light theme persistence
```

Widgets subscribe with `Consumer<TaskDatabase>` or `context.watch<TaskDatabase>()` and rebuild automatically when `notifyListeners()` is called.

`TaskDatabase` responsibilities:

- Holds `currentTasks`, `userTeams`, `pendingInvitations`, `notifications`
- Exposes computed getters: `activeTasks` (tasks not completed today), `completedTasks` (tasks completed today), `historicalCompletions`
- Delegates HTTP calls to the service layer (`TaskService`, `TeamService`, etc.)
- Calls `WidgetService.updateWidgetWithHistoricalData()` after every mutation
- Starts/stops `TimerService` (polling + midnight cleanup)

### Service Layer

Each domain has a dedicated service class that owns HTTP communication. Services are instantiated by `TaskDatabase` after authentication and hold `jwtToken` and `userId` for the lifetime of the session.

| Service | Responsibility |
|---------|---------------|
| `TaskService` | CRUD for tasks, completion toggling via `PATCH /tasks/:id/complete`, history fetch |
| `TeamService` | Team lifecycle, invitations, member management |
| `UserService` | Profile fetch, search, privacy settings |
| `NotificationService` | Firebase FCM init, in-app notification fetch/mark-read |
| `AuthService` | Login, register, token validation, logout |
| `WidgetService` | Write data to `HomeWidgetPreferences`, trigger widget redraw |
| `TimerService` | 10-second polling timer, midnight cleanup timer |
| `InitializationService` | App startup: Firebase, home_widget, JWT restoration |

### Navigation

`app.dart` configures a named-route `MaterialApp`. The `navigatorKey` from `InitializationService` is wired in so widget-tap actions from the home screen can trigger navigation even when the app is in the foreground.

Route map:

| Route | Page |
|-------|------|
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

### Why Provider Instead of Riverpod/Bloc?

Provider is sufficient for a single-domain state tree (`TaskDatabase`). The app does not require code generation, and Provider's `ChangeNotifier` pattern is straightforward to test and extend.

### Why a Single `TaskDatabase` ChangeNotifier?

All task and team state is interdependent (e.g. completing a task affects dashboard stats, the heatmap, and the widget simultaneously). A single notifier avoids cross-provider synchronisation complexity.

### Why Archive Instead of Delete on Completion?

Deleting completed tasks immediately would lose the activity history used by the heatmap and productivity analytics. Archiving them for the day, then moving data to `TaskHistory` during the cleanup job, preserves history indefinitely with minimal storage cost.

### Why `completedDays` Array Instead of a Boolean?

The same task can be completed on multiple days (recurring habit tracking). The array approach supports streak calculation and the heatmap without needing a separate completion record per day.

### Why JWT Over Sessions?

The app supports multiple platforms (Android, iOS, web, desktop) and a stateless REST API is simpler to deploy and scale. JWTs are stored in the device keychain/keystore via `flutter_secure_storage` on mobile.

### Home Widget Data Flow

```
TaskDatabase.updateWidget()
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
