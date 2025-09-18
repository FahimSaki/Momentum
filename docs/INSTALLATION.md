# Installation Guide

Complete setup instructions for Momentum development and production environments.

## Prerequisites

### Required

- **Node.js** 16+ ([Download](https://nodejs.org/))
- **Flutter SDK** 3.9+ ([Install Guide](https://docs.flutter.dev/get-started/install))
- **MongoDB** ([Local](https://www.mongodb.com/docs/manual/installation/) or [Atlas](https://www.mongodb.com/cloud/atlas))
- **Git** ([Download](https://git-scm.com/downloads))

### Recommended

- **VS Code** with Flutter/Dart extensions
- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)
- **MongoDB Compass** (GUI for database management)

### System Requirements

- **RAM**: 8GB minimum, 16GB recommended (for Flutter development)
- **Storage**: 10GB free space (includes Flutter SDK, Android Studio)
- **OS**: Windows 10+, macOS 10.14+, or Ubuntu 18.04+
- **Network**: Stable internet connection for package downloads

## Quick Development Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd momentum
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Configure .env file (see Environment Variables section below)
# At minimum, set:
# - MONGODB_URI
# - JWT_SECRET

# Start development server
npm run dev
```

### 3. Frontend Setup

```bash
# From project root
flutter pub get

# Run on your preferred platform
flutter run                    # Default device
flutter run -d chrome         # Web
flutter run -d android        # Android
flutter run -d ios           # iOS (macOS only)
```

## Environment Variables

Create `backend/.env` with the following configuration:

```bash
# Database
MONGODB_URI=mongodb://localhost:27017/momentum
# Or MongoDB Atlas: mongodb+srv://username:password@cluster.mongodb.net/momentum

# Authentication
JWT_SECRET=your_super_secure_jwt_secret_minimum_32_characters

# Server
PORT=10000
NODE_ENV=development

# Firebase (Optional - for push notifications)
FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/firebase-service-account.json

# Cleanup Schedule (Optional)
CLEANUP_ENABLED=true
```

### Environment Variable Details

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `MONGODB_URI` | ✅ | MongoDB connection string | `mongodb://localhost:27017/momentum` |
| `JWT_SECRET` | ✅ | Secret for JWT token signing | `your_32_char_secret_key_here` |
| `PORT` | ❌ | Server port (default: 10000) | `10000` |
| `NODE_ENV` | ❌ | Environment mode | `development` or `production` |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | ❌ | Path to Firebase service account JSON | `/etc/secrets/firebase-key.json` |
| `CLEANUP_ENABLED` | ❌ | Enable automatic cleanup (default: true) | `true` or `false` |

## Database Setup

### Option A: Local MongoDB

1. **Install MongoDB**

   ```bash
   # Ubuntu/Debian
   sudo apt install mongodb
   
   # macOS (Homebrew)
   brew tap mongodb/brew && brew install mongodb-community
   
   # Windows: Download from mongodb.com
   ```

2. **Start MongoDB**

   ```bash
   # Linux/macOS
   sudo systemctl start mongodb
   # or
   brew services start mongodb/brew/mongodb-community
   
   # Windows: Start as service or run mongod.exe
   ```

3. **Verify Connection**

   ```bash
   mongo
   # Should connect to MongoDB shell
   ```

### Option B: MongoDB Atlas (Cloud)

1. **Create Account** at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas)

2. **Create Cluster**
   - Choose free tier (M0)
   - Select region closest to you
   - Create cluster (takes 5-10 minutes)

3. **Setup Access**
   - Add database user (Database Access → Add New User)
   - Whitelist IP (Network Access → Add IP → Allow Access from Anywhere for development)

4. **Get Connection String**
   - Connect → Connect Your Application
   - Copy connection string
   - Replace `<password>` with your database user password

## 🔧 Platform-Specific Setup

### Android Development

1. **Install Android Studio**
2. **Setup Android SDK** (through Android Studio)
3. **Create Virtual Device** or connect physical device
4. **Enable Developer Options** on physical device
5. **Run**: `flutter run -d android`

### iOS Development (macOS only)

1. **Install Xcode** from Mac App Store
2. **Setup iOS Simulator** (included with Xcode)
3. **Install CocoaPods**: `sudo gem install cocoapods`
4. **Run**: `flutter run -d ios`

### Web Development

1. **Enable Web Support**: `flutter config --enable-web`
2. **Run**: `flutter run -d chrome`

### Desktop Development (Optional)

1. **Enable Desktop Support**:

   ```bash
   flutter config --enable-windows-desktop  # Windows
   flutter config --enable-macos-desktop    # macOS  
   flutter config --enable-linux-desktop    # Linux
   ```

2. **Run**: `flutter run -d windows/macos/linux`

## Firebase Setup (Optional)

Firebase is used for push notifications. Skip this section if you don't need push notifications.

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project
3. Enable Cloud Messaging

### 2. Download Service Account

1. Project Settings → Service Accounts
2. Generate new private key
3. Download JSON file
4. Place in `backend/` directory
5. Update `FIREBASE_SERVICE_ACCOUNT_PATH` in `.env`

### 3. Configure Flutter App

1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Configure: `flutterfire configure`
4. Select your Firebase project
5. Commit generated files

## Verify Installation

### Backend Health Check

```bash
curl http://localhost:10000/health
# Should return: {"status":"ok"}
```

### Frontend Build Test

```bash
flutter doctor
# Should show no critical issues

flutter test
# Should run all tests successfully
```

### Database Connection Test

```bash
# In MongoDB shell
use momentum
db.users.find()
# Should connect without errors
```

## Common Issues

### Backend Issues

#### MongoDB Connection Failed

```bash
# Check if MongoDB is running
sudo systemctl status mongodb    # Linux
brew services list | grep mongo  # macOS

# Check connection string format
MONGODB_URI=mongodb://localhost:27017/momentum
```

#### JWT Secret Error

```bash
# Generate secure JWT secret
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

#### Port Already in Use

```bash
# Kill process using port 10000
lsof -ti:10000 | xargs kill -9
# Or change PORT in .env file
```

### Frontend Issues

#### Flutter Doctor Issues

```bash
flutter doctor --android-licenses  # Accept Android licenses
flutter clean && flutter pub get   # Clean and reinstall dependencies
```

#### Build Failures

```bash
# Clear Flutter caches
flutter clean
dart pub cache repair
flutter pub get

# Rebuild
flutter build apk --debug  # Android
flutter build web          # Web
```

**Check API Base URL Configuration**:

```dart
// lib/constants/api_base_url.dart
const String apiBaseUrl = kIsWeb
    ? 'https://mome***um.onrender.com' // Web
    : (kReleaseMode
          ? 'https://mome***um.onrender.com' // Mobile production
          : 'http://10.0.2.2:10000'); // Android emulator

// Use the dynamic function for complex setups
String getApiBaseUrl() {
  if (kIsWeb) {
    return 'https://mome***um.onrender.com';
  } else if (kDebugMode) {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:10000'; // Android emulator
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:10000'; // iOS simulator
    }
  }
  return 'https://mome***um.onrender.com'; // Production
}
```

## Development Workflow

### 1. Start Development Servers

```bash
# Terminal 1: Backend
cd backend && npm run dev

# Terminal 2: Frontend  
flutter run

# Terminal 3: MongoDB (if local)
mongod
```

### 2. Hot Reload

- **Flutter**: Save files for automatic hot reload
- **Backend**: nodemon automatically restarts on changes

### 3. Database Management

```bash
# MongoDB shell
mongo momentum

# View collections
show collections

# View users
db.users.find().pretty()

# View tasks
db.tasks.find().pretty()
```

## Production Build

### Backend

```bash
cd backend
npm run build  # If you have build script
npm start      # Production server
```

### Frontend

```bash
# Android APK
flutter build apk --release

# iOS (macOS only)
flutter build ios --release

# Web
flutter build web --release
```

## Next Steps

- Read the [Architecture Guide](ARCHITECTURE.md) to understand the system design
- Check the [API Documentation](API.md) for endpoint details
- See [Deployment Guide](DEPLOYMENT.md) for production hosting
- Visit [Troubleshooting](TROUBLESHOOTING.md) if you encounter issues

---

**Need Help?**

- [Report Issues](../../issues)
- [Ask Questions](../../discussions)
- [Read Contributing Guide](../CONTRIBUTING.md)
