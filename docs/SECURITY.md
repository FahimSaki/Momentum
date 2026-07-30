# Security

An overview of Momentum's authentication model, permission system, data protection practices, and guidance for secure self-hosting.

---

## Authentication

### Token Lifecycle

Two different things both get casually called "the JWT" — worth being precise about which is which:

- **`JWT_SECRET`** — the signing key, held only in the server's environment variables. It stays fixed by design: the same secret has to be present both when a token is signed and later when it's verified, or every previously issued token would suddenly fail validation. Rotating it is a deliberate, rare action (see Token Rotation below), not something that happens per request.
- **The token itself** — the string returned to the client after login. A new one is minted on every successful sign-in, signed with the fixed secret above, and expires after 7 days.

End-to-end:

1. `POST /auth/login`, `POST /auth/verify-2fa`, or `POST /auth/google` calls `jwt.sign({ userId }, JWT_SECRET, { expiresIn: '7d' })` on success, producing a fresh token for that session.
2. The Flutter client stores it (see Token Storage below) and attaches it as `Authorization: Bearer <token>` on every subsequent request.
3. `authenticateToken` (see Backend Middleware below) verifies the signature and expiry against that same `JWT_SECRET`, loads the user, and checks `isActive` on every protected route.
4. On expiry or an `isActive: false` account, verification fails, the client gets a `401`/`403`, and is logged out.

The secret is meant to be constant; the tokens are what's generated and rotated, once per login.

### Registration and Login

Passwords are hashed with **bcryptjs** (12 salt rounds) before being stored. Plain-text passwords never touch the database.

New accounts must verify their email before they can log in. Registration emails a 6-digit OTP (5-minute expiry) via the Gmail REST API (see [DEPLOYMENT.md](DEPLOYMENT.md)); the account stays `isEmailVerified: false` until `POST /auth/verify-email` succeeds. Accounts created before this system existed are auto-verified the next time they log in successfully with a password, rather than being locked out.

Once the email is verified, login behaves as follows:

- If the account has **two-factor authentication** enabled (`twoFactorEnabled: true`), the server emails a second 6-digit OTP (10-minute expiry) and responds with `requiresTwoFactor: true` instead of a token. The JWT is only issued after `POST /auth/verify-2fa` succeeds.
- Otherwise the server immediately returns a signed **JSON Web Token** (JWT) with a 7-day expiry (`expiresIn: '7d'`). The JWT payload contains only `{ userId }` – no sensitive user data.

**Google Sign-In is fully implemented** (`POST /auth/google`) — there's no Passport dependency involved. The Flutter app obtains a Google ID token via the `google_sign_in` package; the backend verifies it server-side against Google's `tokeninfo` endpoint (and checks the `aud` claim against `GOOGLE_CLIENT_ID` when that env var is set) before issuing a Momentum JWT. Accounts created via email/password have a `password` field; the login controller checks for its absence and returns an appropriate error if a user tries to log in with a password on a Google-only account.

### Token Storage

| Platform | Storage mechanism |
| ---------- | ------------------ |
| Android | Android Keystore via `flutter_secure_storage` |
| iOS | iOS Keychain via `flutter_secure_storage` |
| Web | In-memory only (`SharedPreferences` on web is not used for tokens) |
| Desktop | OS credential store via `flutter_secure_storage` |

Tokens are never stored in plain `SharedPreferences` or `localStorage`.

### Token Validation

Every protected route passes through `authenticateToken` (`backend/src/middleware/middle_auth.ts`), which verifies the JWT signature and expiry, loads the full `User` document, and rejects the request if the account has since been deactivated (`isActive: false`) — this closes the gap where a soft-deleted account's still-valid token could otherwise keep authenticating for the remainder of its 7-day lifetime.

On every app launch, `SplashPage` additionally calls `GET /auth/validate`, which runs through the same middleware. An invalid, expired, or deactivated-account token triggers a full logout and clears all stored credentials.

### Token Rotation

There is no refresh token mechanism. When a token expires after 7 days, the user is redirected to the login page. Changing `JWT_SECRET` on the server invalidates all existing tokens immediately (useful for incident response).

---

## Authorisation

### Backend Middleware

Every protected route passes through `authenticateToken` (`backend/src/middleware/middle_auth.ts`). This middleware:

1. Extracts the `Authorization: Bearer <token>` header.
2. Verifies the JWT signature with `JWT_SECRET`.
3. Fetches the `User` document and attaches it to `req.user` and `req.userId`.
4. Rejects the request if the account has been deactivated (`isActive: false`).

If any step fails, the request is rejected with `401` or `403` before reaching the controller.

### Task Permissions

Task creation, editing, and deletion are gated by helper functions in `backend/src/controllers/taskController.ts`:

| Action | Who can perform it |
| -------- | -------------------- |
| Create task | Any authenticated user (personal); team owner or admin (team task) |
| Edit task | Team owner / admin, or the user who created the task (`assignedBy`) |
| Delete task | Team owner / admin, or the user who created the task |
| Complete task | Only users in the task's `assignedTo` array |

These checks run server-side on every request. The frontend enforces the same rules via `TeamPermissions` and `PermissionHelper` for a consistent UI, but server-side enforcement is the authoritative gate.

### Team Permissions

| Role | Can create tasks | Can edit/delete tasks | Can invite members | Can change settings | Can delete team |
| ------ | :-: | :-: | :-: | :-: | :-: |
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
- `email` is lowercased and trimmed; format validation is applied at registration.
- `password` minimum length is enforced at registration (6 characters).
- Enum values (`priority`, `role`, `assignmentType`, `status`) are validated by Mongoose schema enums.
- `profileVisibility` keys are checked against a whitelist before being saved.
- MongoDB ObjectId parameters (`:teamId`, `:taskId`, etc.) are implicitly validated by Mongoose's `findById` – invalid IDs cause a `CastError`.
- User-supplied search text (`GET /users/search`) has regex metacharacters escaped before being used in a MongoDB query, preventing ReDoS via crafted search terms.

---

## Data Protection

### Passwords

Stored as bcrypt hashes with 12 rounds. All profile endpoints explicitly exclude the `password` field from responses.

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

The server reads allowed origins from the `ALLOWED_ORIGINS` environment variable (comma-separated list). If `ALLOWED_ORIGINS` is not set, the server defaults to `*` (all origins allowed). Set this variable explicitly in production to restrict access to your known frontend domains.

To update allowed origins, add or edit the `ALLOWED_ORIGINS` variable in your hosting environment – no code change is required.

Credentials (`credentials: true`) are enabled so the browser can send the `Authorization` header cross-origin.

---

## Recommendations for Production Self-Hosting

1. **Use HTTPS everywhere.** Render provides TLS automatically. For self-hosted servers, use Let's Encrypt via Caddy or Nginx.
2. **Set `NODE_ENV=production`.** This disables stack traces in API error responses.
3. **Set `ALLOWED_ORIGINS`** to a comma-separated list of your frontend domains instead of relying on the `*` default.
4. **Use a strong, unique `JWT_SECRET`.** Rotate it if you suspect it has been compromised (this logs out all users).
5. **Restrict MongoDB network access** to the server's IP only.
6. **Keep dependencies updated.** Run `npm audit` and `flutter pub outdated` regularly.
7. **Add rate limiting** to the auth endpoints (`/auth/login`, `/auth/register`) using `express-rate-limit` to prevent brute-force attacks. This is not currently implemented.
8. **Store Firebase service account as an environment variable**, not a file on disk, especially on platforms with ephemeral filesystems (Render, Heroku).

---

## Reporting a Security Vulnerability

Please do not open a public GitHub issue for security vulnerabilities. Contact the maintainer directly via GitHub's private security advisory feature or email. Include a description of the issue, steps to reproduce, and potential impact. You will receive a response within 48 hours.
