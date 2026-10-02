# Security

An overview of Momentum's authentication model, permission system, data protection practices, and guidance for secure self-hosting.

---

## Authentication

### Token Lifecycle

Two different things both get casually called "the JWT" — worth being precise about which is which:

- **`JWT_SECRET`** — the signing key, held only in the server's environment variables. It stays fixed by design: the same secret has to be present both when a token is signed and later when it's verified, or every previously issued token would suddenly fail validation. Rotating it is a deliberate, rare action (see Token Rotation below), not something that happens per request.
- **The token itself** — the string returned to the client after login. A new one is minted on every successful sign-in, signed with the fixed secret above, and expires after 7 days.

End-to-end:

1. `POST /auth/login`, `POST /auth/verify-2fa`, `POST /auth/google`, or `POST /auth/reset-password` calls `jwt.sign({ userId }, JWT_SECRET, { expiresIn: '7d' })` on success, producing a fresh token for that session.
2. The Flutter client stores it (see Token Storage below) and attaches it as `Authorization: Bearer <token>` on every subsequent request.
3. `authenticateToken` (see Backend Middleware below) verifies the signature and expiry against that same `JWT_SECRET`, loads the user, and checks `isActive` on every protected route.
4. On expiry or an `isActive: false` account, verification fails, the server answers `401`/`403`, and the client signs the user out. If the server cannot be reached at all, the client keeps the stored session and works from cached data until it can validate again.

The secret is meant to be constant; the tokens are what's generated and rotated, once per login.

### Registration and Login

Passwords are hashed with **bcryptjs** (12 salt rounds) before being stored. Plain-text passwords never touch the database.

New accounts must verify their email before they can log in. Registration emails a 6-digit OTP (5-minute expiry) via the Gmail REST API (see [DEPLOYMENT.md](DEPLOYMENT.md)); the account stays `isEmailVerified: false` until `POST /auth/verify-email` succeeds. Accounts created before this system existed are auto-verified the next time they log in successfully with a password, rather than being locked out.

Once the email is verified, login behaves as follows:

- If the account has **two-factor authentication** enabled (`twoFactorEnabled: true`), the server emails a second 6-digit OTP (10-minute expiry) and responds with `requiresTwoFactor: true` instead of a token. The JWT is only issued after `POST /auth/verify-2fa` succeeds.
- Otherwise the server immediately returns a signed **JSON Web Token** (JWT) with a 7-day expiry (`expiresIn: '7d'`). The JWT payload contains only `{ userId }` – no sensitive user data.

**Google Sign-In** (`POST /auth/google`) has no Passport dependency. On Android and iOS the app obtains a Google ID token through the `google_sign_in` package. On web it uses a full-page redirect that returns the ID token in the URL fragment, which the app removes from the address bar immediately and exchanges at the backend. The backend verifies the token server-side against Google's `tokeninfo` endpoint and, when `GOOGLE_CLIENT_ID` is set (one ID or a comma-separated list), checks the `aud` claim against it before issuing a Momentum JWT. An existing account with 2FA enabled gets the same emailed-code challenge as a password login. Accounts created via email/password have a `password` field; the login controller checks for its absence and returns an appropriate error if a user tries to log in with a password on a Google-only account.

**Password reset.** `POST /auth/forgot-password` emails a 6-digit code (10-minute expiry, one request per 60 seconds). `POST /auth/reset-password` verifies the code, stores the new bcrypt hash, and returns a fresh JWT, so a successful reset signs the user in. Google-only accounts are told to use Google Sign-In.

**Password change.** While signed in, `POST /users/request-password-change` checks the current password and emails a code; `POST /users/confirm-password-change` verifies it and applies the new password.

**Account deletion.** `POST /users/request-account-deletion` emails a code (10-minute expiry); `POST /users/confirm-account-deletion` deactivates the account (`isActive: false`). It is a soft delete: the authentication middleware rejects deactivated accounts, so any token that is still valid stops working immediately.

### Token Storage

| Platform | Storage mechanism |
| ---------- | ------------------ |
| Android | Android Keystore via `flutter_secure_storage` |
| iOS | iOS Keychain via `flutter_secure_storage` |
| Web | The `flutter_secure_storage` web implementation (WebCrypto-backed browser storage). Weaker than the native Keychain/Keystore, so serve the site over HTTPS only |
| Desktop | OS credential store via `flutter_secure_storage` |

Tokens are never written to `SharedPreferences`. The offline cache (tasks, teams, history, and dashboard stats) lives in `SharedPreferences` but holds no credentials, and it is cleared on logout.

### Token Validation

Every protected route passes through `authenticateToken` (`backend/src/middleware/authMiddleware.ts`), which verifies the JWT signature and expiry, loads the full `User` document, and rejects the request if the account has since been deactivated (`isActive: false`) — this closes the gap where a soft-deleted account's still-valid token could otherwise keep authenticating for the remainder of its 7-day lifetime.

On every app launch, `SplashPage` additionally calls `GET /auth/validate`, which runs through the same middleware. Only an explicit `401` or `403` (invalid, expired, or deactivated-account token) triggers a full logout and clears all stored credentials. If the server is unreachable or answers with a 5xx status, the session is kept and the app opens on cached data, because those responses don't prove the token is bad.

### Token Rotation

There is no refresh token mechanism. When a token expires after 7 days, the user is redirected to the login page. Changing `JWT_SECRET` on the server invalidates all existing tokens immediately (useful for incident response).

---

## Authorisation

### Backend Middleware

Every protected route passes through `authenticateToken` (`backend/src/middleware/authMiddleware.ts`). This middleware:

1. Extracts the `Authorization: Bearer <token>` header.
2. Verifies the JWT signature with `JWT_SECRET`.
3. Fetches the `User` document and attaches it to `req.user` and `req.userId`.
4. Rejects the request if the account has been deactivated (`isActive: false`).

If any step fails, the request is rejected with `401` or `403` before reaching the controller.

The middleware only authenticates. Role-based checks are plain functions in `backend/src/helpers/taskHelpers.ts` (task create, edit, delete) and inline checks in `backend/src/controllers/teamController.ts` (invite, settings, role changes, removal), called from the controllers on every request.

### Task Permissions

| Action | Who can perform it |
| -------- | -------------------- |
| Create task | Any authenticated user (personal); team owner or admin (team task) |
| Edit task | Team owner / admin, or the user who created the task (`assignedBy`) |
| Delete task | Team owner / admin, or the user who created the task |
| Complete task | Personal task: its assignee. Team task: any member of the team |
| View team tasks | Any member of the team sees every task in it |

These checks run server-side on every request. The frontend enforces the same rules via `TeamPermissions` and `PermissionHelper` for a consistent UI, but server-side enforcement is the authoritative gate.

### Team Permissions

| Role | Can create tasks | Can edit/delete tasks | Can invite members | Can change settings | Can delete team |
| ------ | :-: | :-: | :-: | :-: | :-: |
| owner | ✓ | ✓ (all) | ✓ | ✓ | ✓ |
| admin | ✓ | ✓ (all) | ✓ | ✓ | ✗ |
| member | ✗ | ✗ | ✗ (unless `allowMemberInvite`) | ✗ | ✗ |

Members can view every task in their team and complete any of them.

### Invite ID Privacy

User search (`GET /users/search` and `GET /users/invite/:inviteId`) only returns active users where `isPublic: true`. The `inviteId` and `name` are always included in results (they are the minimum required to send an invitation). The response also carries each user's `email`, `bio`, and `profileVisibility` flags; the Flutter client hides email and bio unless the matching flag is enabled, but the server does not redact those fields yet. Treat `showEmail` and `showBio` as display preferences until server-side redaction is added.

---

## Input Validation

All controller inputs are validated before touching the database:

- `name` fields are trimmed and checked for empty strings.
- `email` is lowercased and trimmed; format validation is applied at registration.
- `password` minimum length is enforced at registration, password reset, and password change (6 characters).
- Enum values (`priority`, `role`, `assignmentType`, `status`) are validated by Mongoose schema enums.
- Update endpoints build their changes from explicit field whitelists (task updates, team settings, profile fields, and `profileVisibility` keys), so clients cannot overwrite system fields such as `assignedBy`, `completedDays`, `isArchived`, or `team`.
- MongoDB ObjectId parameters (`:teamId`, `:taskId`, etc.) are implicitly validated by Mongoose's `findById` – invalid IDs cause a `CastError`.
- User-supplied search text (`GET /users/search`) has regex metacharacters escaped before being used in a MongoDB query, preventing ReDoS via crafted search terms.

---

## Data Protection

### Passwords

Stored as bcrypt hashes with 12 rounds. All profile endpoints explicitly exclude the `password` field from responses.

### One-Time Codes

Verification, 2FA, password reset, password change, and account deletion codes are stored on the user document in fields that Mongoose excludes from queries by default (`select: false`), and they are cleared after successful use. Codes expire after 5 minutes (email verification) or 10 minutes (everything else).

### JWT Secret

The `JWT_SECRET` environment variable must be a long, random string. Generate one with:

```bash
openssl rand -hex 32
```

Never commit this value to source control. On Render, set it as an environment variable in the dashboard.

### Email Credentials

`GMAIL_CLIENT_SECRET` and `GMAIL_REFRESH_TOKEN` grant send access to the mailbox the codes are sent from. Keep them in environment variables only, and rotate them if they are ever exposed.

### FCM Tokens

A user can have several registered device tokens. The app re-registers its token on each start, which refreshes `lastUsed`. Tokens that Firebase reports as invalid or unregistered are removed automatically after a failed send. There is currently no cap on tokens per user and no age-based pruning; see [PERFORMANCE.md](PERFORMANCE.md) for a suggested cleanup job.

### MongoDB

- Use MongoDB Atlas with TLS enabled (the default for Atlas connection strings).
- Restrict database user permissions to the specific database – avoid using the Atlas admin user in production.
- Whitelist only necessary IPs, or use VPC peering for production deployments.

---

## CORS

The server reads allowed origins from the `ALLOWED_ORIGINS` environment variable (comma-separated list). If `ALLOWED_ORIGINS` is not set, the server defaults to `*` (all origins allowed). Set this variable explicitly in production to restrict access to your known frontend domains.

To update allowed origins, add or edit the `ALLOWED_ORIGINS` variable in your hosting environment – no code change is required.

Credentials (`credentials: true`) are enabled so the browser can send the `Authorization` header cross-origin.

---

## Recommendations for Production Self-Hosting

1. **Use HTTPS everywhere.** Render provides TLS automatically. For self-hosted servers, use Let's Encrypt via Caddy or Nginx.
2. **Set `NODE_ENV=production`** so Express and its dependencies run in production mode. The global error handler never returns stack traces to clients.
3. **Set `ALLOWED_ORIGINS`** to a comma-separated list of your frontend domains instead of relying on the `*` default.
4. **Set `GOOGLE_CLIENT_ID`** to the OAuth client ID(s) your apps use, so only Google tokens issued for your application are accepted.
5. **Use a strong, unique `JWT_SECRET`.** Rotate it if you suspect it has been compromised (this logs out all users).
6. **Restrict MongoDB network access** to the server's IP only.
7. **Keep dependencies updated.** Run `npm audit` and `flutter pub outdated` regularly.
8. **Add rate limiting** to `/auth/login`, `/auth/register`, and every code-verification endpoint (`/auth/verify-email`, `/auth/verify-2fa`, `/auth/reset-password`, `/users/confirm-password-change`, `/users/confirm-account-deletion`) using `express-rate-limit`. This is not currently implemented, and six-digit codes have no attempt cap today.
9. **Protect or remove `/manual-cleanup`.** It is currently unauthenticated, so anyone who can reach the server can trigger the cleanup job. Require a secret header or an authenticated admin, or disable it in production.
10. **Store the Firebase service account as an environment variable**, not a file on disk, especially on platforms with ephemeral filesystems (Render, Heroku).

---

## Reporting a Security Vulnerability

Please do not open a public GitHub issue for security vulnerabilities. Contact the maintainer directly via GitHub's private security advisory feature or email. Include a description of the issue, steps to reproduce, and potential impact. You will receive a response within 48 hours.
