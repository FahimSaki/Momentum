# Momentum

<p align="center">
  <img src="assets/images/momentum_app_logo_main.png" width="120" alt="Momentum Logo"/>
</p>

<p align="center">
  <strong>Smart daily task manager with dynamic scheduling & seamless team collaboration</strong>
</p>

<p align="center">
  A full-stack task tracking application for team and personal productivity, built with Flutter and Node.js/Express.
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> •
  <a href="docs/INSTALLATION.md">Installation</a> •
  <a href="docs/API.md">API Docs</a> •
  <a href="docs/ARCHITECTURE.md">Architecture</a> •
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

---

## Overview

Momentum is a cross-platform productivity app that helps individuals and teams track daily tasks, visualize activity over time, and collaborate with role-based permissions. Tasks are automatically archived at midnight and their completion history is preserved indefinitely for analytics.

## Features

### Task Management

- Create personal or team tasks with priority levels (low, medium, high, urgent), due dates, and descriptions
- Complete and un-complete tasks; completion is tracked per user per day
- Tasks completed today appear in a "Completed" section; active tasks appear separately
- At midnight (12:05 AM UTC), completed tasks are archived and their history is saved to `TaskHistory`
- Slide-to-reveal edit and delete actions on each task tile

### Team Collaboration

- Create teams and invite members via email, username search, or a unique Invite ID
- Role system: **owner**, **admin**, and **member** with distinct permissions
  - Owners and admins can create, edit, and delete tasks
  - Members can only complete tasks assigned to them
- Pending invitations appear in the Notifications page; accept or decline in one tap
- Team tasks show which team they belong to and can be filtered per team

### Analytics

- 39-day progressive activity heatmap that grows from your first recorded completion
- Dashboard stats: active tasks, completed today, overdue, and upcoming
- Productivity insights: current streak, completions this week, daily average

### Notifications

- Firebase Cloud Messaging (FCM) push notifications for task assignments, completions, and team invitations
- In-app notification centre with unread badge counts
- Mark individual or all notifications as read

### Android Home Screen Widget

- Shows up to 5 tasks with their completion status
- Displays the currently selected team name
- Refresh and add-task shortcuts from the widget

### Background & Sync

- 10-second polling timer keeps tasks up to date while the app is open
- Midnight cleanup timer resets archived tasks at the start of each new day
- Automatic widget refresh after every task change

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter 3.41+, Dart, Provider |
| Backend | Node.js 24 LTS, Express 4 |
| Database | MongoDB 8, Mongoose 8 |
| Auth | JWT (7-day expiry), bcryptjs, FlutterSecureStorage |
| Notifications | Firebase Admin SDK, Firebase Messaging |
| Background | WorkManager, flutter_background_service |
| Widget | home_widget 0.9, Android AppWidgetProvider |
| Analytics | flutter_heatmap_calendar |

## Quick Start

```bash
# 1. Clone
git clone https://github.com/FahimSaki/Momentum.git
cd momentum

# 2. Backend
cd backend
npm install
cp .env.example .env      # fill in MONGODB_URI, JWT_SECRET, PORT
npm run dev               # starts on port 10000

# 3. Flutter (new terminal)
cd ..
flutter pub get
flutter run
```

> For detailed environment setup, Firebase configuration, and production deployment see [docs/INSTALLATION.md](docs/INSTALLATION.md).

## Documentation

| File | Contents |
|------|---------|
| [docs/INSTALLATION.md](docs/INSTALLATION.md) | Dev and production setup, environment variables, Firebase config |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, data flow, state management |
| [docs/API.md](docs/API.md) | All REST endpoints with request/response examples |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Railway, VPS, Docker deployment instructions |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common errors and fixes |
| [docs/SECURITY.md](docs/SECURITY.md) | Auth model, permissions, secure storage |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for coding standards, branch naming, commit format, and the pull-request checklist.

## License

GNU Affero General Public License v3.0 with additional attribution terms. See [LICENSE](LICENSE).

---

<p align="center">Made by <a href="https://github.com/FahimSaki">Fahim Saki</a></p>
