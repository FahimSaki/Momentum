# Troubleshooting Guide

Common issues and solutions for Momentum development and deployment.

## Quick Diagnostics

### Health Check Commands

```bash
# Backend health
curl http://localhost:10000/health
# Should return: {"status":"ok"}

# Flutter doctor
flutter doctor -v
# Check for any issues with Flutter setup

# Database connection
mongo mongodb://localhost:27017/momentum
# Should connect without errors

# Check running processes
lsof -i :10000  # Backend port
lsof -i :27017  # MongoDB port
```

---

## Development Issues

### Flutter Setup Problems

**❌ Problem**: `flutter: command not found`

**✅ Solution**:

```bash
# Add Flutter to PATH
export PATH="$PATH:/path/to/flutter/bin"

# Make permanent (Linux/Mac)
echo 'export PATH="$PATH:/path/to/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# Verify
flutter --version
```

**❌ Problem**: `Flutter SDK not found` in VS Code

**✅ Solution**:

1. Open VS Code settings (Cmd/Ctrl + ,)
2. Search for "flutter sdk"
3. Set "Dart: Flutter Sdk Path" to your Flutter installation
4. Restart VS Code

**❌ Problem**: Android licenses not accepted

**✅ Solution**:

```bash
flutter doctor --android-licenses
# Accept all licenses by typing 'y'
```

### Backend Startup Issues

**❌ Problem**: `Error: Cannot find module 'dotenv'`

**✅ Solution**:

```bash
cd backend
rm -rf node_modules package-lock.json
npm install
```

**❌ Problem**: `MongooseError: The`uri`parameter is required`

**✅ Solution**:

```bash
# Check if .env file exists
ls -la backend/.env

# Create from example if missing
cp backend/.env.example backend/.env

# Edit with your MongoDB URI
nano backend/.env
```

**❌ Problem**: `Error: listen EADDRINUSE: address already in use :::10000`

**✅ Solution**:

```bash
# Find and kill process using port 10000
lsof -ti:10000 | xargs kill -9

# Or change port in .env
echo "PORT=3001" >> backend/.env
```

**❌ Problem**: `JWT_SECRET is required`

**✅ Solution**:

```bash
# Generate secure JWT secret
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Add to .env file
echo "JWT_SECRET=your_generated_secret_here" >> backend/.env
```

### Database Connection Issues

**❌ Problem**: `MongoServerError: Authentication failed`

**✅ Solution**:

```bash
# For local MongoDB (no auth by default)
MONGODB_URI=mongodb://localhost:27017/momentum

# For MongoDB with authentication
MONGODB_URI=mongodb://username:password@localhost:27017/momentum

# For MongoDB Atlas
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/momentum
```

**❌ Problem**: `MongooseError: buffering timed out after 10000ms`

**✅ Solution**:

```bash
# Check if MongoDB is running
sudo systemctl status mongod  # Linux
brew services list | grep mongo  # Mac

# Start MongoDB
sudo systemctl start mongod  # Linux
brew services start mongodb-community  # Mac

# Check connection
mongo --eval "db.adminCommand('ping')"
```

**❌ Problem**: MongoDB Atlas connection issues

**✅ Solution**:

1. **Check IP Whitelist**:
   - Go to MongoDB Atlas → Network Access
   - Add current IP or use `0.0.0.0/0` for development

2. **Verify Connection String**:

   ```bash
   # Format should be:
   mongodb+srv://username:password@cluster.mongodb.net/momentum?retryWrites=true&w=majority
   ```

3. **Test Connection**:

   ```bash
   # Use mongosh (modern MongoDB shell)
   mongosh "mongodb+srv://username:password@cluster.mongodb.net/momentum"
   ```

---

## Mobile Development Issues

### Android Issues

**❌ Problem**: `Gradle sync failed` or `Android license status unknown`

**✅ Solution**:

```bash
# Accept all Android licenses
flutter doctor --android-licenses

# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --debug
```

**❌ Problem**: `ADB device unauthorized`

**✅ Solution**:

1. On device: Enable Developer Options → USB Debugging
2. Disconnect and reconnect USB
3. Accept RSA key fingerprint on device
4. Run: `adb devices` to verify

**❌ Problem**: Network requests fail on Android (cleartext HTTP)

**✅ Solution**:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application
    android:usesCleartextTraffic="true"
    ... >
```

**❌ Problem**: App crashes on Android release build

**✅ Solution**:

```bash
# Build with debug info
flutter build apk --release --split-debug-info=build/debug-info

# Check logs
adb logcat | grep flutter
```

### iOS Issues (macOS only)

**❌ Problem**: `CocoaPods not found`

**✅ Solution**:

```bash
# Install CocoaPods
sudo gem install cocoapods

# If permission issues
sudo gem install -n /usr/local/bin cocoapods

# Update pods
cd ios && pod install
```

**❌ Problem**: iOS Simulator not found

**✅ Solution**:

```bash
# List available simulators
xcrun simctl list devices

# Open iOS Simulator
open -a Simulator

# Create simulator if none exist
xcrun simctl create "iPhone 14" "iPhone 14" "iOS-16-0"
```

**❌ Problem**: `error: Signing for "Runner" requires a development team`

**✅ Solution**:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner in navigator
3. Go to Signing & Capabilities
4. Select a development team or use automatic signing

### Web Development Issues

**❌ Problem**: Web app not loading or white screen

**✅ Solution**:

```bash
# Enable web support (if not enabled)
flutter config --enable-web

# Clean and rebuild
flutter clean
flutter pub get
flutter build web

# Check for JavaScript errors in browser dev tools
```

**❌ Problem**: CORS errors when accessing backend from web

**✅ Solution**:

```javascript
// backend/index.js - Update CORS configuration
app.use(cors({
    origin: [
        'http://localhost:3000',  // Flutter web dev
        'https://your-frontend-domain.com'  // Production web
    ],
    credentials: true
}));
```

**❌ Problem**: `XMLHttpRequest error` in web

**✅ Solution**:

```dart
// Update API base URL for web
const String apiBaseUrl = kIsWeb
    ? 'https://your-backend-url.com'  // Use HTTPS for web
    : 'http://localhost:10000';
```

---

## Authentication Issues

**❌ Problem**: Login always returns "Invalid credentials"

**✅ Solution**:

```bash
# Check if user exists in database
mongo momentum
db.users.findOne({email: "test@example.com"})

# Check password hashing in registration
console.log('Password hash length:', hashedPassword.length);
// Should be ~60 characters for bcrypt
```

**❌ Problem**: JWT token not being sent with requests

**✅ Solution**:

```dart
// Verify token is stored
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('jwt_token');
print('Stored token: $token');

// Check headers in API requests
Map<String, String> get _headers => {
  'Authorization': 'Bearer $jwtToken',
  'Content-Type': 'application/json',
};
```

**❌ Problem**: "Token expired" errors

**✅ Solution**:

```dart
// Implement token refresh logic
static Future<bool> validateToken() async {
  try {
    // Test with a simple authenticated endpoint
    final response = await http.get(
      Uri.parse('$apiBaseUrl/auth/validate'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 401) {
      await logout(); // Clear invalid token
      return false;
    }
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}
```

**❌ Problem**: Session lost after app restart

**✅ Solution**:

```dart
// Use FlutterSecureStorage for sensitive data
final storage = FlutterSecureStorage();

// Store token securely
await storage.write(key: 'jwt_token', value: token);

// Read token on app start
final token = await storage.read(key: 'jwt_token');
```

---

## API & Networking Issues

**❌ Problem**: API requests timeout or fail intermittently

**✅ Solution**:

```dart
// Add timeout and retry logic
Future<http.Response> apiRequest(String url, {Map<String, dynamic>? body}) async {
  int retries = 3;
  
  for (int i = 0; i < retries; i++) {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return response;
      }
    } catch (e) {
      if (i == retries - 1) rethrow; // Last attempt
      await Future.delayed(Duration(seconds: 2 * (i + 1))); // Exponential backoff
    }
  }
  throw Exception('Request failed after $retries attempts');
}
```

**❌ Problem**: Backend returns 500 errors randomly

**✅ Solution**:

```bash
# Check backend logs
pm2 logs momentum-backend --lines 50

# Common causes and fixes:
# 1. Database connection pool exhausted
# 2. Unhandled async errors
# 3. Memory leaks

# Monitor memory usage
pm2 monit

# Restart if needed
pm2 restart momentum-backend
```

**❌ Problem**: Tasks not syncing between devices

**✅ Solution**:

```dart
// Check TimerService polling
class TimerService {
  Timer? _pollingTimer;
  
  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        await onPollingTick();
      } catch (e) {
        _logger.e('Polling error: $e');
        // Don't stop polling on errors
      }
    });
  }
}

// Verify TaskDatabase refresh
Future<void> _refreshData() async {
  try {
    await Future.wait([
      _loadTasks(),
      _loadNotifications(),
      _loadPendingInvitations(),
    ]);
    await updateWidget();
    notifyListeners(); // Ensure UI updates
  } catch (e) {
    _logger.e('Error refreshing data: $e');
  }
}
```

**❌ Problem**: Firebase notifications not working

**✅ Solution**:

```bash
# Check Firebase service account file
ls -la backend/momentum-api-fcm-*.json
# File should exist and be readable

# Verify environment variable
echo $FIREBASE_SERVICE_ACCOUNT_PATH

# Check notification service initialization
tail -f backend/logs/combined.log | grep firebase
```

---

## Data & State Management Issues

**❌ Problem**: UI not updating after API calls

**✅ Solution**:

```dart
// Ensure notifyListeners() is called
class TaskDatabase extends ChangeNotifier {
  Future<void> createTask(...) async {
    try {
      final task = await _taskService.createTask(...);
      currentTasks.add(task);
      _organizeTasksByType();
      notifyListeners(); // ✅ Critical for UI updates
    } catch (e) {
      // Handle error
    }
  }
}

// Use Consumer widgets properly
Consumer<TaskDatabase>(
  builder: (context, db, child) {
    return ListView.builder(
      itemCount: db.activeTasks.length,
      itemBuilder: (context, index) => TaskTile(task: db.activeTasks[index]),
    );
  },
)
```

**❌ Problem**: Heatmap showing incorrect data

**✅ Solution**:

```dart
// Verify date handling in task_util.dart
Map<DateTime, int> prepareMapDatasets(
  List<Task> tasks, 
  List<DateTime> historicalCompletions,
) {
  final Map<DateTime, int> heatMapData = {};

  // Process current tasks - ensure local time conversion
  for (final task in tasks) {
    for (final utcDate in task.completedDays) {
      final localDate = utcDate.toLocal();
      final localMidnight = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
      );
      
      heatMapData.update(
        localMidnight,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  // Process historical data
  for (final utcDate in historicalCompletions) {
    final localDate = utcDate.toLocal();
    final localMidnight = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
    
    heatMapData.update(
      localMidnight,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  return heatMapData;
}
```

**❌ Problem**: Task completion state inconsistent

**✅ Solution**:

```dart
// Check task completion logic in Task model
bool isCompletedToday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Verify task is archived AND has completion for today
  if (!isArchived) return false;

  return completedDays.any((completedDate) {
    final localDate = completedDate.toLocal();
    final completedDay = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
    return completedDay.isAtSameMomentAs(today);
  });
}

// Ensure backend completion endpoint is working
Future<Task> completeTask(String taskId, bool isCompleted) async {
  final requestBody = {
    'userId': userId,
    'isCompleted': isCompleted,
    'completedAt': DateTime.now().toIso8601String(),
  };

  final response = await http.put(
    Uri.parse('$apiBaseUrl/tasks/$taskId/complete'),
    headers: _headers,
    body: json.encode(requestBody),
  );
  
  if (response.statusCode != 200) {
    throw Exception('Failed to complete task: ${response.body}');
  }
  
  return Task.fromJson(json.decode(response.body)['task']);
}
```

---

## Home Widget Issues

**❌ Problem**: Android home widget not updating

**✅ Solution**:

```dart
// Check widget update service
class WidgetService {
  Future<void> updateWidgetWithHistoricalData(
    List<DateTime> historicalCompletions,
    List<Task> currentTasks,
  ) async {
    if (kIsWeb) return; // Widget only works on mobile
    
    try {
      final List<String> widgetData = [];
      final now = DateTime.now();

      // Generate 35 days of data
      for (int i = 0; i < 35; i++) {
        final date = now.subtract(Duration(days: 34 - i));
        int completedCount = 0;

        // Count current task completions
        for (final task in currentTasks) {
          completedCount += task.completedDays.where((completion) {
            final local = completion.toLocal();
            return local.year == date.year &&
                   local.month == date.month &&
                   local.day == date.day;
          }).length;
        }

        // Count historical completions
        completedCount += historicalCompletions.where((completion) {
          final local = completion.toLocal();
          return local.year == date.year &&
                 local.month == date.month &&
                 local.day == date.day;
        }).length;

        widgetData.add(completedCount.toString());
      }

      await HomeWidget.saveWidgetData('heatmap_data', widgetData.join(','));
      await HomeWidget.updateWidget(
        name: 'MomentumHomeWidget',
        androidName: 'MomentumHomeWidget',
      );
      
      _logger.i('Widget updated with ${widgetData.length} data points');
    } catch (e, stackTrace) {
      _logger.e('Error updating widget', error: e, stackTrace: stackTrace);
    }
  }
}
```

**❌ Problem**: Widget shows old data

**✅ Solution**:

```bash
# Check Android manifest permissions
# android/app/src/main/AndroidManifest.xml
<uses-permission android:name="android.permission.UPDATE_APP_WIDGET" />

# Verify widget provider configuration
# android/app/src/main/res/xml/home_widget.xml should exist

# Force widget update
adb shell am broadcast -a android.appwidget.action.APPWIDGET_UPDATE
```

---

## Background Services Issues

**❌ Problem**: Background polling not working

**✅ Solution**:

```dart
// Check TimerService initialization
class TaskDatabase extends ChangeNotifier {
  TimerService? _timerService;
  
  Future<void> initialize({required String jwt, required String userId}) async {
    // ... other initialization
    
    if (!kIsWeb) {
      _initializeTimerService();
    }
  }
  
  void _initializeTimerService() {
    _timerService = TimerService(
      onPollingTick: () async => await _refreshData(),
      onMidnightCleanup: () async => await _handleMidnightCleanup(),
    );
  }
  
  void _startPolling() {
    if (kIsWeb) {
      _logger.w('Polling disabled on web to reduce CPU load');
      return;
    }
    _timerService?.startPolling();
  }
}
```

**❌ Problem**: Midnight cleanup not running

**✅ Solution**:

```bash
# Backend - check cleanup scheduler
tail -f backend/logs/combined.log | grep cleanup

# Verify cron schedule in cleanupScheduler.js
# Should run at 12:05 AM UTC daily
cron.schedule('5 0 * * *', async () => {
  console.log(`⏰ Scheduled cleanup triggered at: ${new Date().toISOString()}`);
  await runDailyCleanup();
}, {
  scheduled: true,
  timezone: "UTC"
});

# Manual cleanup test
curl -X POST http://localhost:10000/manual-cleanup
```

---

## Deployment Issues

### Render.com Deployment

**❌ Problem**: Build fails on Render

**✅ Solution**:

```bash
# Check build logs in Render dashboard

# Common issues:
# 1. Node version mismatch - add .nvmrc file
echo "18" > backend/.nvmrc

# 2. Missing environment variables
# Add in Render dashboard: MONGODB_URI, JWT_SECRET, NODE_ENV=production

# 3. Build command incorrect
# Build Command: npm install
# Start Command: npm start
```

**❌ Problem**: Backend starts but API calls fail

**✅ Solution**:

```javascript
// Check CORS configuration for production
app.use(cors({
    origin: function (origin, callback) {
        const allowedOrigins = [
            'https://momentum-beryl-nine.vercel.app', // Production frontend
            'http://localhost:3000', // Local development
        ];
        
        if (!origin || allowedOrigins.includes(origin) || origin.endsWith('.vercel.app')) {
            callback(null, true);
        } else {
            console.warn(`CORS blocked origin: ${origin}`);
            callback(null, false);
        }
    },
    credentials: true,
}));
```

### MongoDB Atlas Issues

**❌ Problem**: Connection string authentication fails

**✅ Solution**:

```bash
# Correct format for MongoDB Atlas
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/momentum?retryWrites=true&w=majority

# Common mistakes:
# 1. Username/password not URL encoded
# 2. Database name missing
# 3. Special characters in password not escaped

# Test connection
node -e "
const mongoose = require('mongoose');
mongoose.connect('your_connection_string')
  .then(() => console.log('Connected!'))
  .catch(err => console.error('Error:', err));
"
```

### Vercel Frontend Deployment

**❌ Problem**: Flutter web build fails on Vercel

**✅ Solution**:

```bash
# Build locally first to check for issues
flutter build web --release --web-renderer html

# Create vercel.json for proper routing
{
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        }
      ]
    }
  ]
}
```

---

## Debugging Tools & Tips

### Flutter Debugging

```bash
# Debug mode with detailed logging
flutter run --debug --verbose

# Inspector for widget tree
flutter inspector

# Performance overlay
# Add to main.dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: true, // Add this
      // ... rest of app
    );
  }
}

# Check for memory leaks
flutter analyze --write=analysis.txt
```

### Backend Debugging

```bash
# Enable debug logging
export DEBUG=*
npm run dev

# MongoDB query profiling
mongo
use momentum
db.setProfilingLevel(2) // Profile all operations
db.system.profile.find().pretty()

# Check for slow queries
db.system.profile.find({millis: {$gt: 100}}).pretty()
```

### Network Debugging

```bash
# Monitor HTTP traffic
# Install Charles Proxy or mitmproxy

# Flutter network logging
import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

// In main()
HttpOverrides.global = MyHttpOverrides();
```

## 📞 Getting Additional Help

### When to Seek Help

1. **Searched existing issues**: Check [GitHub Issues](../../issues)
2. **Tried troubleshooting steps**: Followed relevant solutions above
3. **Isolated the problem**: Can reproduce consistently
4. **Gathered information**: Have logs, error messages, environment details

### How to Report Issues

**Provide Essential Information**:

```markdown
**Environment:**
- OS: [macOS 12.6, Ubuntu 20.04, Windows 11]
- Flutter: [flutter doctor -v output]
- Backend: Node.js version, npm version
- Database: MongoDB version/Atlas

**Steps to Reproduce:**
1. Specific steps
2. Expected vs actual behavior
3. Error messages or logs

**Relevant Code:**
- Include minimal code that reproduces the issue
- Remove sensitive information (API keys, passwords)

**Additional Context:**
- Recent changes made
- When the issue started
- Workarounds attempted
```

### Resources

- **Documentation**: [Main README](../README.md)
- **Architecture**: [Architecture Guide](ARCHITECTURE.md)
- **API Reference**: [API Documentation](API.md)
- **Deployment**: [Deployment Guide](DEPLOYMENT.md)
- **Community**: [GitHub Discussions](../../discussions)

---

**Still having issues?** Don't hesitate to [open an issue](../../issues/new) with detailed information. The community is here to help!
