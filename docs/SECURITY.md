# Security

An overview of Momentum's authentication model, permission system, data protection practices, and guidance for secure self-hosting.

---

## Authentication

### Registration and Login

Passwords are hashed with **bcryptjs** (12 salt rounds) before being stored. Plain-text passwords never touch the database.

On login the server returns a signed **JSON Web Token** (JWT) with a 7-day expiry (`expiresIn: '7d'`). The JWT payload contains only `{ userId }` – no sensitive user data.

Google OAuth is scaffolded (`passport-google-oauth20` is in `package.json`) but not yet implemented. Accounts created via email/password have a `password` field; the login controller checks for its absence and returns an appropriate error if a user tries to log in with a password on a Google-only account.

### Token Storage

| Platform | Storage mechanism |
|----------|------------------|
| Android | Android Keystore via `flutter_secure_storage` |
| iOS | iOS Keychain via `flutter_secure_storage` |
| Web | In-memory only (`SharedPreferences` on web is not used for tokens) |
| Desktop | OS credential store via `flutter_secure_storage` |

Tokens are never stored in plain `SharedPreferences` or `localStorage`.

### Token Validation

On every app launch, `SplashPage` calls `GET /auth/validate`. The backend verifies the JWT signature and expiry, then fetches the full `User` document to confirm the account still exists. An invalid or expired token triggers a full logout and clears all stored credentials.

### Token Rotation

There is no refresh token mechanism. When a token expires after 7 days, the user is redirected to the login page. Changing `JWT_SECRET` on the server invalidates all existing tokens immediately (useful for incident response).

---

## Authorisation

### Backend Middleware

Every protected route passes through `authenticateToken` (`backend/middleware/middle_auth.js`). This middleware:

1. Extracts the `Authorization: Bearer <token>` header.
2. Verifies the JWT signature with `JWT_SECRET`.
3. Fetches the `User` document and attaches it to `req.user` and `req.userId`.

If any step fails, the request is rejected with `401` or `403` before reaching the controller.

### Task Permissions

Task creation, editing, and deletion are gated by three helper functions in `taskController.js`:

| Action | Who can perform it |
|--------|--------------------|
| Create task | Any authenticated user (personal); team owner or admin (team task) |
| Edit task | Team owner / admin, or the user who created the task (`assignedBy`) |
| Delete task | Team owner / admin, or the user who created the task |
| Complete task | Only users in the task's `assignedTo` array |

These checks run server-side on every request. The frontend enforces the same rules via `TeamPermissions` and `PermissionHelper` for a consistent UI, but server-side enforcement is the authoritative gate.

### Team Permissions

| Role | Can create tasks | Can edit/delete tasks | Can invite members | Can change settings | Can delete team |
|------|:-:|:-:|:-:|:-:|:-:|
| owner | ✓ | ✓ (all) | ✓ | ✓ | ✓ |
| admin | ✓ | ✓ (all) | ✓ | ✓ | ✗ |
| member | ✗ | ✗ | ✗ (unless `allowMemberInvite`) | ✗ | ✗ |

Members can only complete tasks assigned to them.

### Invite ID Privacy

User search (`GET /users/search` and `GET /users/invite/:inviteId`) only returns users where `isPublic: true`. Each result is further filtered by the user's `profileVisibility` settings before being sent to the client – email and bio are withheld unless the user has enabled them. The `inviteId` and `name` are always included in search results (they are the minimum required to send an invitation).

---

## Input Validation

All controller inputs are validated before touching the database:

- `name` fields are trimmed and checked for empty strings.
- `email` is lowercased and trimmed; the auth controller does not apply format validation at login (only at registration).
- `password` minimum length is enforced at registration (6 characters).
- Enum values (`priority`, `role`, `assignmentType`, `status`) are validated by Mongoose schema enums.
- `profileVisibility` keys are checked against a whitelist before being saved.
- MongoDB ObjectId parameters (`:teamId`, `:taskId`, etc.) are implicitly validated by Mongoose's `findById` – invalid IDs cause a `CastError` which the error handler returns as a 500 (could be improved to 400 in a future version).

---

## Data Protection

### Passwords

Stored as bcrypt hashes with 12 rounds. The `User` model `select: false` is not set on the `password` field, but all profile endpoints explicitly `select('-password')` to exclude it from responses.

### JWT Secret

The `JWT_SECRET` environment variable must be a long, random string. Generate one with:

```bash
openssl rand -hex 32
```

Never commit this value to source control. On Render, set it as an environment variable in the dashboard.

### FCM Tokens

Up to 5 FCM tokens are stored per user (one per device, sorted by `lastUsed`). Tokens that return `messaging/registration-token-not-registered` from Firebase are automatically removed. Tokens older than 60 days are excluded from notification sends.

### MongoDB

- Use MongoDB Atlas with TLS enabled (the default for Atlas connection strings).
- Restrict database user permissions to the specific database – avoid using the Atlas admin user in production.
- Whitelist only necessary IPs, or use VPC peering for production deployments.

---

## CORS

The `allowedOrigins` list in `backend/index.js` includes the Vercel production domain and `localhost`. The current configuration also allows any `*.vercel.app` subdomain to support preview deployments. For a hardened production deployment, replace the pattern match with an explicit list of allowed origins.

Credentials (`credentials: true`) are enabled so the browser can send the `Authorization` header cross-origin.

---

## Recommendations for Production Self-Hosting

1. **Use HTTPS everywhere.** Render provides TLS automatically. For self-hosted servers, use Let's Encrypt via Caddy or Nginx.
2. **Set `NODE_ENV=production`.** This disables stack traces in API error responses.
3. **Use a strong, unique `JWT_SECRET`.** Rotate it if you suspect it has been compromised (this logs out all users).
4. **Restrict MongoDB network access** to the server's IP only.
5. **Keep dependencies updated.** Run `npm audit` and `flutter pub outdated` regularly.
6. **Add rate limiting** to the auth endpoints (`/auth/login`, `/auth/register`) using `express-rate-limit` to prevent brute-force attacks. This is not currently implemented.
7. **Store Firebase service account as an environment variable**, not a file on disk, especially on platforms with ephemeral filesystems (Render, Heroku).

---

## Reporting a Security Vulnerability

Please do not open a public GitHub issue for security vulnerabilities. Contact the maintainer directly via GitHub's private security advisory feature or email. Include a description of the issue, steps to reproduce, and potential impact. You will receive a response within 48 hours.
