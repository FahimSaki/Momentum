# API Reference

Base URL:

- **Production**: `https://momentum-g7ah.onrender.com`
- **Local development**: `http://localhost:10000`

All protected endpoints require the header:

```
Authorization: Bearer <jwt_token>
```

---

## Authentication

### POST /auth/register

Register a new user account. Registration does **not** return a token — the account must verify its email before it can log in.

**Request body**

```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "password": "atleast6chars"
}
```

**Response 201**

```json
{
  "message": "Account created. Check your email for a 6-digit verification code.",
  "requiresVerification": true,
  "email": "jane@example.com"
}
```

A 6-digit OTP (5-minute expiry) is emailed via the Gmail REST API (see [DEPLOYMENT.md](DEPLOYMENT.md) for the required env vars). Re-registering with the same, still-unverified email resends a fresh code instead of erroring.

**Errors**: `400` missing fields / password under 6 chars / email already registered and verified

---

### POST /auth/verify-email

Confirm the OTP sent at registration (or by `resend-verification`).

**Request body**

```json
{ "email": "jane@example.com", "code": "123456" }
```

**Response 200** `{ "message": "Email verified successfully. You can now log in." }`

**Errors**: `400` missing/invalid/expired code, `404` account not found

---

### POST /auth/resend-verification

Request a new verification OTP. Rate-limited to one request per 60 seconds.

**Request body**

```json
{ "email": "jane@example.com" }
```

**Response 200** `{ "message": "Verification code sent to your email." }`

**Errors**: `404` account not found, `429` requested again too soon

---

### POST /auth/login

Authenticate an existing user. The response shape depends on the account's email-verification and 2FA state — check for `requiresVerification` / `requiresTwoFactor` before assuming `token` is present.

**Request body**

```json
{
  "email": "jane@example.com",
  "password": "atleast6chars"
}
```

**Response 200 — normal login**

```json
{
  "token": "<jwt>",
  "user": {
    "_id": "...",
    "name": "Jane Doe",
    "email": "jane@example.com",
    "isEmailVerified": true,
    "twoFactorEnabled": false,
    "inviteId": "swift-tiger-1234",
    "isPublic": true,
    "profileVisibility": { "showEmail": false, "showName": true, "showBio": true },
    "notificationSettings": { "email": true, "push": true, "inApp": true, "taskAssigned": true, "taskCompleted": true, "teamInvitations": true, "dailyReminder": false },
    "teams": [],
    "createdAt": "...",
    "updatedAt": "..."
  },
  "message": "Login successful"
}
```

**Response 200 — 2FA enabled** (no token yet — call `POST /auth/verify-2fa` next)

```json
{
  "message": "A verification code has been sent to your email.",
  "requiresTwoFactor": true,
  "email": "jane@example.com"
}
```

**Response 403 — email not verified** (no token; a fresh code was just sent — call `POST /auth/verify-email`)

```json
{
  "message": "Please verify your email first. A new code has been sent.",
  "requiresVerification": true,
  "email": "jane@example.com"
}
```

**Errors**: `401` invalid credentials, `401` Google-only account (no `password` set)

---

### POST /auth/verify-2fa

Complete login for an account with two-factor authentication enabled.

**Request body**

```json
{ "email": "jane@example.com", "code": "123456" }
```

**Response 200** — identical shape to a normal login (`token`, `user`, `"message": "Login successful"`)

**Errors**: `400` missing/invalid/expired code, `404` account not found

---

### POST /auth/google

Sign in with a Google ID token, registering the account automatically on first use.

**Request body**

```json
{ "idToken": "<google_id_token>" }
```

The backend verifies the token server-side against Google's `tokeninfo` endpoint (and checks the `aud` claim against `GOOGLE_CLIENT_ID` when that env var is set) — no separate client secret needs to reach the app beyond the OAuth client ID already configured for `google_sign_in` in Flutter.

**Response 200** — identical shape to a normal login, with `"message": "Google sign-in successful"`

**Errors**: `401` invalid Google token or wrong audience, `400` Google didn't return an email

---

### POST /auth/logout

Invalidate the session client-side (stateless – the client discards the token; there is no server-side token blacklist).

**Response 200** `{ "message": "Logged out successfully" }`

---

### GET /auth/validate  *(protected)*

Verify a JWT is still valid, belongs to an active (non-deactivated) account, and return the current user.

**Response 200**

```json
{
  "valid": true,
  "userId": "...",
  "user": {
    "id": "...",
    "name": "Jane Doe",
    "email": "jane@example.com",
    "isEmailVerified": true,
    "twoFactorEnabled": false
  }
}
```

**Errors**: `401` / `403` invalid, expired, or deactivated-account token

---

## Tasks  *(all protected)*

### GET /tasks

Fetch tasks assigned to the authenticated user.

**Query parameters**

| Param | Type | Description |
| ------- | ------ | ------------- |
| `userId` | string | Override – defaults to authenticated user |
| `teamId` | string | Filter by team |
| `type` | `personal` \| `team` \| `all` | Default: `all` |
| `status` | `active` \| `archived` \| `all` | Default: `active`. `active` includes non-archived tasks plus tasks archived earlier today |

**Response 200** – array of Task objects (see schema below)

---

### POST /tasks

Create a new task.

**Request body**

```json
{
  "name": "Write unit tests",
  "description": "Cover task_util.dart",
  "teamId": "<team_id>",
  "assignedTo": ["<user_id>", "<user_id>"],
  "priority": "high",
  "dueDate": "2024-12-31T23:59:59.000Z",
  "tags": ["testing"],
  "assignmentType": "individual"
}
```

`teamId`, `description`, `assignedTo`, `dueDate`, and `tags` are optional. If `teamId` is absent the task is personal (assigned to the creating user). If `assignmentType` is `"team"` and `teamId` is set, the task is assigned to every team member automatically.

**Permissions**: team tasks require the creator to be owner or admin of the team.

**Response 201** `{ "message": "Task created successfully", "task": { ... } }`

---

### PUT /tasks/:id

Update task fields (name, description, priority, dueDate, etc.).

**Permissions**: owner/admin of the team, or the original task creator.

**Response 200** `{ "message": "Task updated successfully", "task": { ... } }`

---

### PATCH /tasks/:id/complete

Toggle the completion state of a task for the current day.

**Request body**

```json
{ "isCompleted": true }
```

**Permissions**: only users in `assignedTo` can complete.

**Response 200**

```json
{
  "message": "Task completed successfully",
  "task": { ... }
}
```

(`"Task unmarked successfully"` when `isCompleted` is `false`.) The response `task` object contains the full updated document including `completedDays` and `completedBy`.

---

### DELETE /tasks/:id

Delete a task. The task's `completedDays` are saved to `TaskHistory` before deletion.

**Permissions**: owner/admin of the team, or the original task creator.

**Response 200** `{ "message": "Task deleted successfully and preserved in history" }`

---

### GET /tasks/history

Retrieve historical completion data for the heatmap.

**Query parameters**

| Param | Type | Description |
|-------|------|-------------|
| `userId` | string | Defaults to authenticated user |
| `teamId` | string | Filter by team |

**Response 200** – array of `TaskHistory` objects:

```json
[
  {
    "_id": "...",
    "userId": { "_id": "...", "name": "Jane", "email": "..." },
    "taskName": "Write unit tests",
    "completedDays": ["2024-01-01T00:00:00.000Z", "2024-01-02T00:00:00.000Z"],
    "teamId": null
  }
]
```

---

### GET /tasks/dashboard-stats

Dashboard statistics for the authenticated user.

**Query parameters**: `teamId` (optional)

**Response 200**

```json
{
  "totalTasks": 12,
  "completedToday": 3,
  "overdueTasks": 1,
  "upcomingTasks": 4
}
```

---

### GET /tasks/team/:teamId

Get tasks for a specific team.

**Query parameters**: `status` (`active` | `archived` | `all`, default: `active`)

**Permissions**: team members only.

**Response 200** – array of Task objects

---

## Teams  *(all protected)*

### GET /teams

List all teams the authenticated user belongs to.

**Response 200** – array of Team objects with populated `owner` and `members.user`

---

### POST /teams

Create a new team. The creator is automatically added as owner.

**Request body**

```json
{
  "name": "Frontend Squad",
  "description": "Optional description"
}
```

**Response 201** `{ "message": "Team created successfully", "team": { ... } }`

---

### GET /teams/:teamId

Get full team details.

**Permissions**: team members only.

**Response 200** – Team object with all members populated

---

### PUT /teams/:teamId/settings

Update team settings.

**Permissions**: owner or admin.

**Request body**

```json
{
  "settings": {
    "allowMemberInvite": true,
    "taskAutoDelete": true,
    "notificationSettings": {
      "taskAssigned": true,
      "taskCompleted": false,
      "memberJoined": true
    }
  }
}
```

**Response 200** `{ "message": "Team settings updated", "team": { ... } }`

---

### DELETE /teams/:teamId

Soft-delete the team (sets `isActive: false`).

**Permissions**: owner only.

**Response 200** `{ "message": "Team deleted successfully" }`

---

### POST /teams/:teamId/invite

Send a team invitation. Provide either `email` or `inviteId`.

**Request body**

```json
{
  "inviteId": "swift-tiger-1234",
  "role": "member",
  "message": "Hey, join our team!"
}
```

or

```json
{
  "email": "jane@example.com",
  "role": "admin"
}
```

**Permissions**: owner, admin, or any member if `settings.allowMemberInvite` is true.

**Response 200** `{ "message": "Invitation sent successfully", "invitation": { ... } }`

**Errors**: `400` already a member, `400` pending invitation already exists, `404` user not found

---

### GET /teams/invitations/pending

Get all pending invitations for the authenticated user.

**Response 200** – array of TeamInvitation objects with populated `team` and `inviter`

---

### PATCH /teams/invitations/:invitationId/respond

Accept or decline an invitation.

**Request body**

```json
{ "response": "accepted" }
```

or `"declined"`. Accepting automatically adds the user to the team and sends a `team_member_joined` notification to existing members.

**Response 200** `{ "message": "Invitation accepted successfully", "invitation": { ... } }`

---

### DELETE /teams/:teamId/members/:memberId

Remove a member from the team.

**Permissions**: owner can remove anyone; admin can remove members (not other admins); a user may remove themselves.

**Response 200** `{ "message": "Member removed successfully" }`

---

### PATCH /teams/:teamId/members/:memberId/role

Change a member's role between `member` and `admin`. The owner's role can't be changed here.

**Request body**

```json
{ "role": "admin" }
```

**Permissions**: owner can promote or demote any non-owner member; admin can only promote a `member` to `admin`.

**Response 200** `{ "message": "Member role updated successfully", "member": { ... } }`

**Errors**: `400` invalid role / target is the owner, `403` insufficient permission, `404` member not found

---

### POST /teams/:teamId/leave

Leave a team.

**Permissions**: any member except the owner (transfer ownership first).

**Response 200** `{ "message": "Left team successfully" }`

---

## Users  *(all protected)*

### GET /users/profile

Get the authenticated user's full profile.

**Response 200** – User object (password excluded)

---

### PUT /users/profile

Update profile fields including privacy and visibility settings.

**Request body** – all fields optional

```json
{
  "name": "Jane Doe",
  "bio": "Task enthusiast",
  "timezone": "Asia/Dhaka",
  "avatar": "https://...",
  "isPublic": true,
  "profileVisibility": {
    "showEmail": false,
    "showName": true,
    "showBio": true
  }
}
```

**Response 200** `{ "message": "Profile updated successfully", "user": { ... } }`

---

### PUT /users/notification-settings

Update the user's in-app and push notification preferences.

**Request body**

```json
{
  "notificationSettings": {
    "email": true,
    "push": true,
    "inApp": true,
    "taskAssigned": true,
    "taskCompleted": true,
    "teamInvitations": true,
    "dailyReminder": false
  }
}
```

**Response 200** `{ "message": "Notification settings updated", "user": { ... } }`

---

### GET /users/search

Search for users to invite to a team.

**Query parameters**

| Param | Type | Description |
|-------|------|-------------|
| `q` | string | Minimum 2 characters; matches name, email, or inviteId |
| `limit` | number | Default 20, max 50 |

Results are filtered by `isPublic` and `profileVisibility`. Users with `isPublic: false` do not appear.

**Response 200** – array of partial User objects:

```json
[
  {
    "_id": "...",
    "name": "Jane Doe",
    "inviteId": "swift-tiger-1234",
    "avatar": null,
    "bio": "...",
    "profileVisibility": { "showEmail": false, "showName": true, "showBio": true }
  }
]
```

---

### GET /users/invite/:inviteId

Look up a user by their Invite ID. Only returns users where `isPublic: true`.

**Response 200** – partial User object (same shape as search result)

**Errors**: `404` not found

---

### POST /users/fcm-token

Register or refresh an FCM device token for push notifications.

**Request body**

```json
{
  "token": "<fcm_registration_token>",
  "platform": "android"
}
```

`platform`: `android` | `ios` | `web`

**Response 200** `{ "message": "FCM token registered successfully" }`

---

### DELETE /users/fcm-token

Remove an FCM token (e.g. on logout from a specific device).

**Request body** `{ "token": "<fcm_registration_token>" }`

**Response 200** `{ "message": "FCM token removed" }`

---

### PUT /users/change-password

Change the authenticated user's password.

**Request body**

```json
{
  "currentPassword": "old-password",
  "newPassword": "new-password-min-6"
}
```

**Response 200** `{ "message": "Password changed successfully" }`

**Errors**: `400` current password incorrect, `400` Google accounts cannot use this endpoint

---

### POST /users/2fa/enable

Turn on two-factor authentication for the authenticated account. Future logins require an emailed OTP in addition to the password (see `POST /auth/login` / `POST /auth/verify-2fa`).

**Response 200** `{ "message": "Two-factor authentication enabled", "twoFactorEnabled": true }`

---

### POST /users/2fa/disable

Turn off two-factor authentication.

**Response 200** `{ "message": "Two-factor authentication disabled", "twoFactorEnabled": false }`

---

### POST /users/request-account-deletion

Start account deletion. Emails a 6-digit OTP (10-minute expiry) to the user; does **not** deactivate the account by itself.

**Response 200** `{ "message": "A verification code has been sent to your email." }`

**Errors**: `429` requested again too soon

---

### POST /users/confirm-account-deletion

Confirm the OTP from `request-account-deletion` and deactivate the account (`isActive: false`, soft-delete).

**Request body**

```json
{ "code": "123456" }
```

**Response 200** `{ "message": "Account deleted successfully" }`

**Errors**: `400` missing/invalid/expired code

---

## Notifications  *(all protected)*

### GET /notifications

Fetch notifications for the authenticated user.

**Query parameters**

| Param | Type | Default | Description |
| ------- | ------ | --------- | ------------- |
| `page` | number | 1 | Page number |
| `limit` | number | 20 | Results per page (max 50) |
| `unreadOnly` | boolean | false | Return only unread notifications |

**Response 200**

```json
{
  "notifications": [
    {
      "_id": "...",
      "type": "task_assigned",
      "title": "New Task Assigned",
      "message": "Jane assigned you \"Write tests\" in Frontend Squad",
      "isRead": false,
      "createdAt": "...",
      "sender": { "_id": "...", "name": "Jane Doe", "email": "...", "avatar": null },
      "team": { "_id": "...", "name": "Frontend Squad" },
      "task": { "_id": "...", "name": "Write tests" },
      "data": { "type": "task_assigned", "taskId": "...", "taskName": "..." }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 42,
    "pages": 3
  },
  "unreadCount": 5
}
```

Notification `type` values: `task_assigned`, `task_completed`, `team_invitation`, `team_member_joined`, `task_due_reminder`

---

### GET /notifications/unread-count

Get the count of unread notifications for the authenticated user.

**Response 200** `{ "count": 5 }`

---

### PATCH /notifications/:notificationId/read

Mark a single notification as read.

**Response 200** `{ "message": "Notification marked as read", "notification": { ... } }`

---

### PATCH /notifications/mark-all-read

Mark all of the user's notifications as read.

**Response 200** `{ "message": "N notifications marked as read", "count": N }`

---

### DELETE /notifications/:notificationId

Delete a single notification.

**Response 200** `{ "message": "Notification deleted" }`

---

## Utility Endpoints

### GET /health

Liveness check, no authentication required.

**Response 200** `{ "status": "ok", "timestamp": "...", "uptime": 123.45 }`

---

### GET /wake-up

Ping to wake a sleeping Render.com instance.

**Response 200** `{ "message": "Server is awake", "timestamp": "...", "uptime": 123.45 }`

---

### GET /manual-cleanup

### POST /manual-cleanup

Trigger the daily cleanup job immediately.

**Response 200**

```json
{
  "message": "Manual cleanup completed",
  "archivedTasks": 3,
  "deletedAndPreservedTasks": 2,
  "cleanedTasks": 5,
  "processedDate": "Fri May 15 2026",
  "timestamp": "...",
  "status": "success"
}
```

---

## Task Object Schema

```json
{
  "_id": "string",
  "name": "string",
  "description": "string | null",
  "assignedTo": [{ "_id": "...", "name": "...", "email": "...", "avatar": null }],
  "assignedBy": { "_id": "...", "name": "...", "email": "...", "avatar": null },
  "team": { "_id": "...", "name": "..." } | null,
  "priority": "low | medium | high | urgent",
  "dueDate": "ISO8601 | null",
  "tags": ["string"],
  "completedDays": ["ISO8601"],
  "completedBy": [{ "user": { ... }, "completedAt": "ISO8601" }],
  "lastCompletedDate": "ISO8601 | null",
  "isArchived": false,
  "archivedAt": "ISO8601 | null",
  "isTeamTask": false,
  "assignmentType": "individual | multiple | team",
  "createdAt": "ISO8601",
  "updatedAt": "ISO8601"
}
```

---

## Error Response Format

All errors return:

```json
{
  "message": "Human-readable description"
}
```

| Status | Meaning |
| -------- | --------- |
| 400 | Bad request / validation error |
| 401 | Missing or invalid token |
| 403 | Valid token but insufficient permission |
| 404 | Resource not found |
| 500 | Unexpected server error |
