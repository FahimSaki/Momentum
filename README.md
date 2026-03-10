# Momentum

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/images/momentum_app_logo_main.png">
    <source media="(prefers-color-scheme: light)" srcset="assets/images/momentum_app_logo_main.png">
    <img src="assets/images/momentum_app_logo_main.png" width="120" alt="Momentum Logo"/>
  </picture>
</p>

<p align="center">
  <strong>Smart daily task manager with dynamic scheduling & seamless team collaboration</strong>
</p>

<p align="center">
  A full-stack task tracking application for team and personal use built with Flutter (frontend) and Node.js/Express (backend).<br>
  Designed for both users and developers who want a self-hosted, customizable productivity solution.
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="docs/INSTALLATION.md">Installation</a> •
  <a href="docs/API.md">API Docs</a> •
  <a href="docs/ARCHITECTURE.md">Architecture</a> •
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

---

## Quick Start

Get Momentum running in under 5 minutes:

```bash
# Clone the repository
git clone <repository-url>
cd momentum

# Backend setup
cd backend
npm install
cp .env.example .env  # Configure your environment
npm run dev

# Frontend setup (new terminal)
cd ../
flutter pub get
flutter run
```

> **Need detailed setup?** See the [Installation Guide](docs/INSTALLATION.md)

## Key Features

### For Users

- **Cross-platform**: Android, iOS, Web, Desktop with platform-specific optimizations
- **Progressive Analytics**: 39-day growing activity heatmap with historical data preservation
- **Team Collaboration**: Real-time invitations, role-based permissions, team task assignment
- **Smart Notifications**: Firebase FCM push notifications + in-app notifications
- **Background Sync**: Automatic 10-second polling with offline capability
- **Home Screen Widgets**: Android home screen widget with activity visualization
- **Intelligent Cleanup**: Automated daily cleanup (12:05 AM UTC) with complete data preservation

### For Developers  

- **Self-hosted**: Complete control over data, deployment, and customization
- **Production Ready**: Automated cleanup, proper error handling, monitoring endpoints
- **Clean Architecture**: Service-layer separation, Provider state management, proper abstractions
- **Security First**: JWT with secure storage, input validation, bcrypt hashing
- **Developer Experience**: Hot reload, comprehensive logging, structured error responses
- **Extensible**: Well-documented APIs, clear separation of concerns, modular design

## Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Frontend** | Flutter 3.9+ | Cross-platform UI with Provider state management |
| **Backend** | Node.js + Express | RESTful API with automated cleanup scheduler |
| **Database** | MongoDB + Mongoose | Document storage with intelligent indexing |
| **Authentication** | JWT + bcrypt | Secure auth with FlutterSecureStorage |
| **Notifications** | Firebase FCM | Cross-platform push notifications |
| **Background Services** | WorkManager + BackgroundService | Real-time sync and widget updates |
| **Analytics** | Flutter Heatmap Calendar | Progressive 39-day activity visualization |

## Documentation

| Document | Description |
|----------|-------------|
| [Installation Guide](docs/INSTALLATION.md) | Complete setup for development & production |
| [Architecture](docs/ARCHITECTURE.md) | System design, data flow, and technical decisions |
| [API Reference](docs/API.md) | Endpoint documentation with examples |
| [Deployment](docs/DEPLOYMENT.md) | Self-hosting, VPS, cloud deployment options |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [Performance](docs/PERFORMANCE.md) | Optimization tips and monitoring |
| [Security](docs/SECURITY.md) | Security features and best practices |

## Contributing

We welcome contributions! Whether it's bug fixes, features, or documentation improvements.

- **[Contributing Guide](CONTRIBUTING.md)** - Development workflow, coding standards
- **[Issue Tracker](../../issues)** - Report bugs or request features  
- **[Discussions](../../discussions)** - Ask questions, share ideas

### Development Setup

```bash
# Fork the repo, then clone your fork
git clone https://github.com/YOUR_USERNAME/momentum.git

# Follow the installation guide
cd momentum && cat docs/INSTALLATION.md

# Create a feature branch
git checkout -b feature/your-feature-name

# Make changes, commit, and push
# Open a Pull Request with a clear description
```

## Why Momentum?

- **Own Your Data** - Self-hosted, no vendor lock-in
- **Purpose-Built** - Specifically designed for development teams
- **Security First** - JWT auth, input validation, secure defaults
- **API-First** - Everything accessible via REST API
- **Scalable** - Handles individual users to large teams
- **Extensible** - Clean architecture for custom integrations

## License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0) with additional terms under section 7**.  
> See the [LICENSE](LICENSE) file for more details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/fahimsaki">Fahim Saki</a>
</p>
