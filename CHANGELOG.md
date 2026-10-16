# Changelog

All notable changes to Momentum are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Planned

- WebSocket support for real-time collaborative updates
- Task comments and file attachments
- GraphQL endpoint (API v2)
- Enterprise SSO and audit logs

### Added

- Email verification with 6-digit codes, two-factor sign-in by email code, password reset, password change, and account deletion, all sent through the Gmail API
- Google Sign-In: native on mobile, full-page redirect on web
- Offline support: on-device cache of tasks, teams, history, and stats; queued personal task creation; idempotent creates through `clientId`
- Web push notifications (service worker and VAPID key)
- Per-user calendar days: completions are stamped with the user's own date from the device UTC offset, and each completed task carries `archiveExpiresAt`, the end of the completing user's day; an hourly job removes expired tasks after saving their days to history
- Development console fallback for one-time codes when `NODE_ENV=development` and email cannot be sent
- `ApiException`, so error messages from the backend reach the user

### Changed

- **State management migrated Provider → BLoC → Cubit.** `TaskDatabase` (the single `ChangeNotifier`) is replaced by four `Cubit`s in `lib/blocs/`: `TaskCubit`, `TeamCubit`, `NotificationCubit`, `SessionCubit`, each paired with an immutable state class; `ThemeProvider` remains a plain `ChangeNotifier`
- `TaskCubit` subscribes directly to `TeamCubit.stream` to reload tasks, history, and dashboard stats when the selected team changes
- `InitializationService.registerTaskBloc()` renamed to `registerTaskCubit()`
- Team members can view and complete every task in their team; personal tasks can only be completed by their assignee
- User search and invite lookup honor `profileVisibility` on the server: a hidden name is returned as "Private user", hidden email and bio are omitted, and search matches name and email only for users who allow them
- Team and user notification settings for task assignment and completion are enforced; the team `memberJoined` setting now controls member-joined notifications
- History reloads when a completed task leaves the list, when the selected team changes, and every five minutes
- Due dates are read and written as calendar dates
- `PORT` defaults to 10000
- The mail icon on the team selection page opens the Notifications page; `TeamInvitationsPage` was removed

### Removed

- The team `taskAutoDelete` setting, which was never enforced
- The `userId` parameter on `GET /tasks` and `GET /tasks/history`

### Fixed

- Any signed-in user could read another user's tasks and history through the `userId` parameter
- Firebase service account keys saved under the documented filename are now git-ignored
- Completed tasks could end up hidden, and heatmap days could be missing or shifted, because the app and the server disagreed about which day a completion belonged to
- Backend error messages were replaced by generic ones in the app

---

## [0.9.1] – Current

### Fixed

- Documentation corrected for `PATCH /tasks/:id/complete` (previously documented as `PUT`)
- Documentation corrected for `PATCH /teams/invitations/:invitationId/respond` (previously documented as `PUT`)
- Documentation corrected for `PATCH /notifications/:notificationId/read` and `PATCH /notifications/mark-all-read` (previously documented as `PUT`)
- CORS configuration documented correctly to reflect `ALLOWED_ORIGINS` environment variable (previously described as a hardcoded array in source)
- FCM token registration endpoint corrected to `POST /users/fcm-token` (previously documented as `/notifications/fcm-token`)

---

## [0.9.0]

### Added

- **Android Home Screen Widget** (`MomentumHomeWidget.kt`)
  - Shows up to 5 tasks with live completion status
  - Displays the currently selected team name in the header
  - Refresh and add-task tap targets in the widget header
  - Reads task data from `HomeWidgetPreferences` shared preferences
  - Handles cold-start and foreground widget-tap actions via `homeWidget://` URI scheme
- **Invite ID system** – every user gets a unique human-readable ID (e.g. `swift-tiger-1234`) generated on registration; used for frictionless team invitations
- **User Profile page** – shows name, email, bio, Invite ID with one-tap copy, and privacy toggle switches (show email, show name, show bio, discoverable in search)
- **Privacy controls** – `isPublic` and `profileVisibility` fields on the User model; search results are filtered accordingly
- **User search** – search by name, email, or Invite ID when inviting to a team
- **Team Invitation dialog** (`team_invitation_dialog.dart`) – tabbed UI with Search Users and Invite ID tabs, role selector, and optional personal message
- **User Search page** (`user_search_page.dart`) – standalone search page with three invite modes: search, Invite ID, and email
- **Permission system** – `TeamPermissions` model with static `owner`, `admin`, and `member` constants; `PermissionHelper` resolves a user's effective permissions in a team
- **Team Home page** (`team_home_page.dart`) – dedicated team view showing role badge, active/completed task sections, and permission-gated FAB
- **Dashboard stats widget** (`dashboard_stats.dart`) – real-time counters for active, completed today, overdue, and upcoming tasks calculated locally from `TaskDatabase`
- **Quick Invite widget** (`quick_invite_widget.dart`) – inline card on the home dashboard that shows and copies the current user's Invite ID
- **Notifications page** (`notifications_page.dart`) – tabbed Invitations and Activity views; mark-all-read action
- **`InitializationService`** – centralises Firebase, home_widget, and JWT setup; exposes a `GlobalKey<NavigatorState>` for widget-triggered navigation
- **`WidgetService`** – writes task JSON and team name to `HomeWidgetPreferences` and calls `HomeWidget.updateWidget` after every state change
- **`TimerService`** – encapsulates 10-second polling timer and midnight cleanup timer; no-ops on web

### Changed

- `TaskDatabase.activeTasks` getter now excludes tasks completed today (they move to `completedTasks`)
- `TaskDatabase.completedTasks` getter returns only tasks completed today
- `TaskDatabase.calculateDashboardStats()` computes stats synchronously from in-memory lists instead of making an API call
- `TaskService.completeTask` now hits `PATCH /tasks/:id/complete` and returns the full updated `Task` object
- `SplashPage` validates stored JWT against `/auth/validate` before allowing entry; invalid tokens trigger logout and redirect to login
- `api_base_url.dart` selects the correct host for web, Android emulator, iOS simulator, and production automatically
- `ThemeProvider` persists and loads dark/light preference via `SharedPreferences`

### Backend Changes

- `taskController.ts` – permission helpers (`canUserCreateTask`, `canUserEditTask`, `canUserDeleteTask`) gate task mutations by team role
- `teamController.ts` – `inviteToTeam` deletes stale declined/expired invitations before re-creating; returns clean invitation objects
- `teamController.ts` – `getPendingInvitations` serialises team and inviter as plain objects to avoid Mongoose population issues on the client
- `userController.ts` – `getUserProfile` auto-generates `inviteId` for existing users who lack one
- `userController.ts` – `searchUsers` filters results by `profileVisibility` before responding
- `notificationController.ts` – returns `{ notifications, pagination, unreadCount }` shape from `GET /notifications`
- `cleanupScheduler.ts` – three-step midnight job: (1) archive tasks completed before today, (2) delete archived tasks and save to `TaskHistory`, (3) remove old `completedDays` entries from active tasks
- `User.ts` – `inviteId` field with unique sparse index; pre-save middleware generates a collision-free human-readable ID with up to 10 retries
- `Task.ts` – added `team`, `isTeamTask`, `assignmentType`, `completedBy`, `priority`, `dueDate`, and `tags` fields
- `TaskHistory.ts` – added `teamId` field and compound index on `userId + taskName`

---

## [0.5.1]

### Added

- Activity heatmap with 39-day progressive window (`flutter_heatmap_calendar`)
- Firebase FCM push notifications for task assignment, completion, and due-date reminders
- Background sync (10-second polling, midnight cleanup)
- JWT stored in device keychain / keystore via `flutter_secure_storage`
- Team creation, membership, and role management
- Automated daily cleanup scheduler (node-cron, 12:05 AM UTC)
- Dark and light themes with persistence

---

## [0.5.0]

### Added

- Initial Flutter frontend with Provider state management
- Node.js/Express backend with MongoDB
- Basic task CRUD (create, read, update, delete)
- User registration and JWT login
- Team creation

---

## Version Policy

| Release type | When used | Example |
| --- | --- | --- |
| PATCH | Bug fixes, security patches | 0.9.0 → 0.9.1 |
| MINOR | New backward-compatible features | 0.9.0 → 0.10.0 |
| MAJOR | Breaking API or schema changes | 0.9.0 → 1.0.0 |

Security fixes for critical vulnerabilities are backported to the previous two minor versions.
