# Contributing to Momentum

Thank you for your interest in contributing! This document covers how to set up a development environment, coding standards, commit conventions, and the pull-request process.

---

## Table of Contents

1. [Ways to Contribute](#ways-to-contribute)
2. [Development Setup](#development-setup)
3. [Project Structure at a Glance](#project-structure-at-a-glance)
4. [Coding Standards](#coding-standards)
5. [Commit Conventions](#commit-conventions)
6. [Branch Naming](#branch-naming)
7. [Pull Request Process](#pull-request-process)
8. [Testing](#testing)
9. [Issue Guidelines](#issue-guidelines)
10. [Code of Conduct](#code-of-conduct)

---

## Ways to Contribute

- **Bug reports** – open an issue using the bug template
- **Feature requests** – open an issue with the feature template
- **Code** – fix a bug, implement a feature, or improve performance
- **Documentation** – improve clarity, fix typos, add missing content
- **Tests** – add unit or widget tests to increase coverage
- **Translations** – help localise the app

---

## Development Setup

### Prerequisites

| Tool | Minimum version |
|------|----------------|
| Flutter SDK | 3.41.0 |
| Dart SDK | 3.11.1 |
| Node.js | 20 LTS |
| MongoDB | 6+ (local) or Atlas |
| Android Studio / Xcode | Latest stable |

### 1 – Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/momentum.git
cd momentum
git remote add upstream https://github.com/FahimSaki/Momentum.git
```

### 2 – Backend

```bash
cd backend
npm install

# Create .env (never commit this file)
cp .env.example .env
```

Minimum `.env` contents:

```env
MONGODB_URI=mongodb://localhost:27017/momentum
JWT_SECRET=a-long-random-secret
PORT=10000
NODE_ENV=development
```

Optional (needed for push notifications):

```env
FIREBASE_SERVICE_ACCOUNT_PATH=./momentum-firebase-adminsdk.json
# OR
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
```

```bash
npm run dev   # nodemon, auto-restarts on save
```

### 3 – Flutter Frontend

```bash
cd ..          # back to project root
flutter pub get
```

The API base URL is resolved automatically by `lib/constants/api_base_url.dart`:

| Context | URL used |
|---------|---------|
| Android emulator (debug) | `http://10.0.2.2:10000` |
| iOS simulator (debug) | `http://127.0.0.1:10000` |
| Release / web | `https://momentum-production-f728.up.railway.app` |

To point at a different server, edit `api_base_url.dart` locally (do not commit personal URLs).

```bash
flutter run          # pick a connected device / emulator
flutter run -d chrome  # web
```

### 4 – Firebase (optional for local dev)

Push notifications and FCM token registration require a Firebase project. For local development you can skip Firebase setup – the app degrades gracefully (notifications are silently no-ops). If you want to test notifications:

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an Android app (`com.example.momentum`) and download `google-services.json` → `android/app/`
3. Add an iOS app and download `GoogleService-Info.plist` → `ios/Runner/`
4. Generate a service account key and set `FIREBASE_SERVICE_ACCOUNT_PATH` in the backend `.env`

---

## Coding Standards

### Dart / Flutter

- Run `flutter analyze` and resolve all issues before committing.
- Format with `dart format .` (enforced by CI).
- Use `Logger` from the `logger` package instead of `print`.
- All HTTP calls belong in `lib/services/`; widgets call `TaskDatabase` methods only.
- Dispose controllers, animation controllers, and timers in `dispose()`.
- Avoid `dynamic` types where a typed alternative exists.

```dart
//
Future<void> deleteTask(String taskId) async {
  try {
    await _taskService!.deleteTask(taskId);
    currentTasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  } catch (e, st) {
    logger.e('Error deleting task', error: e, stackTrace: st);
    rethrow;
  }
}

// Swallows errors, no logging, dynamic return
deleteTask(id) async {
  await _taskService.deleteTask(id);
}
```

### JavaScript / Node.js

- Use ES modules (`import`/`export`), async/await, and optional chaining.
- Wrap every async controller in try/catch; never let unhandled rejections crash the server.
- Return a clean error object: `{ message: '...' }` with an appropriate HTTP status.
- Log with `console.log` / `console.error` prefixed with an emoji for easy scanning (✅ ❌ ⚠️).
- Do not hardcode MongoDB IDs, secrets, or file paths – use environment variables.

```js
//
export const createTask = async (req, res) => {
  try {
    const { name } = req.body;
    if (!name?.trim()) return res.status(400).json({ message: 'Task name is required' });
    const task = await Task.create({ name: name.trim(), assignedBy: req.userId });
    res.status(201).json({ message: 'Task created', task });
  } catch (err) {
    console.error('createTask:', err);
    res.status(500).json({ message: 'Server error' });
  }
};
```

---

## Commit Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <short description>

[optional body]

[optional footer]
```

| Type | Use for |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no logic change |
| `refactor` | Restructuring without behaviour change |
| `test` | Adding or updating tests |
| `chore` | Dependencies, build scripts, CI config |
| `perf` | Performance improvement |

Examples:

```bash
git commit -m "feat(team): add Invite ID lookup when sending invitations"
git commit -m "fix(widget): correct SharedPreferences file name for home_widget 0.9"
git commit -m "docs: add INSTALLATION.md with Firebase setup steps"
git commit -m "refactor(task_database): split activeTasks and completedTasks getters"
```

---

## Branch Naming

```
feature/<short-description>      # new feature
bugfix/<short-description>       # bug fix
docs/<short-description>         # documentation
refactor/<short-description>     # refactoring
chore/<short-description>        # maintenance
```

Examples: `feature/google-oauth`, `bugfix/widget-empty-state`, `docs/api-endpoints`

---

## Pull Request Process

### Before Opening a PR

- [ ] `flutter analyze` passes with no errors
- [ ] `dart format . --set-exit-if-changed` passes
- [ ] `flutter test` passes
- [ ] Backend starts without errors (`npm run dev`)
- [ ] No secrets, personal URLs, or debug `print` statements in the diff
- [ ] Documentation updated if the change affects public API or user-facing behaviour

### PR Description Template

```markdown
## What does this PR do?
Short description.

## Type
- [ ] Bug fix
- [ ] New feature
- [ ] Refactor
- [ ] Documentation
- [ ] Breaking change

## How to test
Step-by-step instructions for reviewers.

## Screenshots (if UI change)
Before / After screenshots.

## Checklist
- [ ] `flutter analyze` passes
- [ ] Tests added / updated
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (for user-facing changes)
```

### Review Criteria

Reviewers look for: correctness, error handling, test coverage, adherence to the patterns in the codebase, and documentation.

---

## Testing

### Flutter

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run a single test file
flutter test test/unit_test.dart
```

Tests live in `test/`. Add unit tests for models and utilities in `test/unit_test.dart`; widget tests in `test/widget_test.dart`.

### Backend

There is no dedicated test runner configured yet. Manual testing against a local MongoDB instance is acceptable for now. Contributors adding backend tests are welcome to introduce Jest or Mocha.

---

## Issue Guidelines

### Bug Report

```markdown
**Description**
What went wrong?

**Steps to reproduce**
1. ...
2. ...

**Expected behaviour**
What should have happened?

**Environment**
- Platform: Android / iOS / Web / Desktop
- App version:
- Device / OS:

**Logs / screenshots**
Paste relevant logs or screenshots.
```

### Feature Request

```markdown
**Problem**
What problem does this solve?

**Proposed solution**
How should it work?

**Alternatives considered**
What else did you think about?
```

---

## Code of Conduct

- Be respectful and constructive in all interactions.
- Welcome contributors of all experience levels.
- Focus feedback on the code, not the person.
- Harassment of any kind will not be tolerated.

Questions? Open a [GitHub Discussion](../../discussions).
