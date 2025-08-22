# Momentum

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/images/momentum_app_logo_dark.png">
    <source media="(prefers-color-scheme: light)" srcset="assets/images/momentum_app_logo_light.png">
    <img src="assets/images/momentum_app_logo_dark.png" width="100" alt="Momentum Logo"/>
  </picture>
</p>

<p align="center">
A full-stack task tracking application built with Flutter (frontend) and Node.js/Express (backend).<br>
The app helps users track daily tasks with more focus and clarity.
</p>

## 🚀 Features

### Frontend (Flutter)

- **Cross-platform**: Works on Android, iOS, Web and Windows
- **User Authentication**: Email/password registration and login
- **Task Management**: Create, edit, delete, and complete tasks
- **Interactive UI**:
  - Animated task tiles with slide-to-edit/delete functionality
  - Expandable completed tasks section
  - Real-time completion tracking
- **Data Visualization**:
  - Heat map showing activity over time
  - Progressive calendar view (grows from first launch to 39-day window)
- **Theme Support**: Light and dark mode with persistent settings
- **Home Widget**: Android home screen widget showing activity heatmap
- **Background Services**: Real-time task synchronization
- **Notifications**: Local notifications for task updates

### Backend (Node.js/Express)

- **RESTful API**: Complete CRUD operations for tasks and users
- **JWT Authentication**: Secure token-based authentication
- **Data Preservation**: Historical task completion data is preserved even after deletion
- **Automatic Cleanup**:
  - Daily scheduled cleanup at 12:05 AM UTC
  - Archives completed tasks after completion day
  - Preserves all completion data in history collection
- **MongoDB Integration**: Efficient data storage and retrieval
- **CORS Support**: Configured for multiple deployment environments
- **Health Monitoring**: Health check endpoints and wake-up functionality

## 🛠️ Tech Stack

### Frontend

- **Framework**: Flutter 3.x
- **State Management**: Provider
- **Local Storage**: SharedPreferences
- **HTTP Client**: http package
- **UI Components**:
  - flutter_heatmap_calendar
  - flutter_slidable
  - font_awesome_flutter
- **Background Services**: flutter_background_service
- **Notifications**: flutter_local_notifications
- **Home Widget**: home_widget

### Backend

- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: MongoDB with Mongoose ODM
- **Authentication**: JWT (jsonwebtoken)
- **Password Hashing**: bcryptjs
- **Scheduling**: node-cron
- **CORS**: cors middleware

## 📱 Installation & Setup

### Prerequisites

- Flutter SDK (3.0+)
- Node.js (16+)
- MongoDB database
- Android Studio / VS Code
- Git

### Backend Setup

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd momentum/backend
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Environment Configuration**
   Create a `.env` file in the backend directory:

   ```env
   MONGODB_URI=mongodb://localhost:27017/momentum
   # Or use MongoDB Atlas: mongodb+srv://username:password@cluster.mongodb.net/momentum
   JWT_SECRET=your_super_secure_jwt_secret_here
   PORT=10000
   ```

4. **Start the server**

   ```bash
   # Development
   npm run dev
   
   # Production
   npm start
   ```

5. **Run the Flutter app**

   ```bash
   # Navigate to project root
   cd ../
   
   # Install Flutter dependencies
   flutter pub get
   
   # Run the app
   flutter run
   ```

## 📊 API Documentation

### Authentication Endpoints

- `POST /auth/register` - User registration
- `POST /auth/login` - User login

### Task Endpoints (Authenticated)

- `GET /tasks/assigned?userId={id}` - Get user's tasks
- `POST /tasks` - Create new task
- `PUT /tasks/{id}` - Update task
- `DELETE /tasks/{id}` - Delete task
- `GET /tasks/history?userId={id}` - Get task completion history
- `DELETE /tasks/completed?userId={id}&before={date}` - Delete completed tasks

### Utility Endpoints

- `GET /health` - Health check
- `GET /wake-up` - Wake up server (for scheduled services)
- `POST /manual-cleanup` - Trigger manual cleanup

## ⚙️ Key Features Explained

### Automatic Data Cleanup

The backend runs daily cleanup process :

1. **Archive** tasks completed before today
2. **Delete** archived tasks from previous days
3. **Preserve** all completion data in TaskHistory collection
4. **Clean** old completion days from active tasks

This ensures the database stays efficient while preserving all historical data for the heatmap.

### Heat Map Visualization

- Shows activity over the last 39 days (or since first launch)
- Combines current task data with preserved historical completions
- Progressive calendar that grows with user activity
- Color-coded intensity based on tasks completed per day

### Real-time Synchronization

- Background polling every 10 seconds (mobile only)
- Automatic task list updates
- Conflict resolution for concurrent edits
- Offline capability with sync on reconnect

## 🐛 Troubleshooting

### Common Issues

1. **CORS Errors**
   - Ensure your frontend URL is added to the CORS whitelist in `backend/index.js`

2. **Authentication Failures**
   - Check JWT secret consistency between frontend and backend
   - Verify MongoDB connection

3. **Database Connection Issues**
   - Confirm MongoDB URI format and credentials
   - Check network connectivity for MongoDB Atlas

4. **Build Errors**
   - Run `flutter clean` and `flutter pub get`
   - Check Flutter and Dart SDK versions

5. **Widget Not Updating (Android)**
   - Ensure home_widget permissions are granted
   - Check Android manifest configuration

## 📈 Performance Optimization

- **Backend**: Daily cleanup prevents database bloat
- **Frontend**: Efficient state management with Provider
- **Memory**: Automatic garbage collection after cleanup operations
- **Network**: Optimized API calls with proper error handling
- **UI**: Smooth animations with proper widget lifecycle management

## 🔒 Security Features

- JWT-based authentication with 7-day expiration
- Password hashing with bcrypt (10 rounds)
- CORS protection with whitelist
- Input validation and sanitization
- Secure HTTP headers

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b`)
3. Commit changes (`git commit -m`)
4. Push to branch (`git push origin feature/branch`)
5. Open a Pull Request

## 📄 License

> See the [LICENSE](LICENSE) file or visit [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) for more details.

---
