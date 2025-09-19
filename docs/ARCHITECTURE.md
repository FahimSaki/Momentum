# Architecture Guide

System design, data flow, and technical decisions for Momentum.

## System Overview

Momentum follows a **client-server architecture** with clean separation between frontend and backend concerns.

```
┌─────────────────┐    HTTP/REST     ┌─────────────────┐    MongoDB     ┌─────────────────┐
│                 │ ◄─────────────► │                 │ ◄────────────► │                 │
│  Flutter Client │                 │  Node.js Server │                │   MongoDB       │
│                 │                 │                 │                │   Database      │
└─────────────────┘                 └─────────────────┘                └─────────────────┘
        │                                   │                                   │
        ▼                                   ▼                                   ▼
┌─────────────────┐                 ┌─────────────────┐                ┌─────────────────┐
│ • State Mgmt    │                 │ • JWT Auth      │                │ • Users         │
│ • Local Storage │                 │ • RESTful API   │                │ • Tasks         │
│ • Push Notifications             │ • Data Validation│               │ • Teams         │
│ • Background Services           │ • Automated Cleanup              │ • Notifications │
└─────────────────┘                 └─────────────────┘                └─────────────────┘
```

## Design Principles

### 1. **Separation of Concerns**

- **Frontend**: UI, user interactions, local state
- **Backend**: Business logic, data persistence, authentication
- **Database**: Data storage and relationships

### 2. **API-First Design**

- All functionality accessible via REST API
- Enables future integrations and multiple clients
- Clear contracts between frontend and backend

### 3. **Security by Design**

- JWT authentication with secure defaults
- Input validation and sanitization
- CORS protection with whitelisting
- Password hashing with bcrypt

### 4. **Scalability Considerations**

- Stateless backend design
- Efficient database queries with proper indexing  
- Background job processing
- Modular service architecture

### 5. **Developer Experience**

- Clear error messages and logging
- Comprehensive documentation
- Hot reload in development
- Automated testing support

## Frontend Architecture

### Technology Stack

- **Framework**: Flutter 3.x (Dart)
- **State Management**: Provider pattern
- **Navigation**: Named routes with route guards
- **HTTP Client**: http package with retry logic
- **Local Storage**: SharedPreferences + FlutterSecureStorage
- **Background Services**: WorkManager + BackgroundService

### Directory Structure

```
lib/
├── components/          # Reusable UI components
│   ├── task_tile.dart
│   ├── animated_task_tile.dart
│   └── success_feedback.dart
├── pages/              # Screen-level widgets
│   ├── home_page.dart
│   ├── login_page.dart
│   └── team_details_page.dart
├── models/             # Data models
│   ├── task.dart
│   ├── user.dart
│   └── team.dart
├── services/           # Business logic & API calls
│   ├── auth_service.dart
│   ├── task_service.dart
│   └── team_service.dart
├── database/           # State management
│   ├── task_database.dart
│   └── timer_service.dart
├── constants/          # App constants
│   └── api_base_url.dart
├── theme/             # UI theming
│   ├── theme.dart
│   └── theme_provider.dart
└── util/              # Helper functions
    └── task_util.dart
```

### State Management Flow

```
┌─────────────────┐    User Action    ┌─────────────────┐
│                 │ ──────────────────►│                 │
│   UI Components │                   │ TaskDatabase    │
│                 │ ◄──────────────────│ (Provider)      │
└─────────────────┘   State Changes   └─────────────────┘
                                              │
                                              ▼
                                      ┌─────────────────┐
                                      │   API Services  │
                                      │ • TaskService   │
                                      │ • TeamService   │
                                      │ • AuthService   │
                                      └─────────────────┘
                                              │
                                              ▼
                                      ┌─────────────────┐
                                      │  Backend API    │
                                      └─────────────────┘
```

### Key Components

**TaskDatabase (Main State Controller)**:

- Manages all application state
- Coordinates API calls
- Handles data synchronization
- Manages background services

**Service Layer**:

- **AuthService**: Authentication & token management
- **TaskService**: Task CRUD operations
- **TeamService**: Team management
- **NotificationService**: Push notifications

**UI Layer**:

- Reactive widgets using Provider
- Custom components for consistency
- Theme management for dark/light modes

## 🔧 Backend Architecture

### Technology Stack

- **Runtime**: Node.js 16+
- **Framework**: Express.js
- **Database**: MongoDB with Mongoose ODM
- **Authentication**: JWT tokens
- **Password Hashing**: bcryptjs
- **Scheduling**: node-cron
- **Push Notifications**: Firebase Admin SDK

### Directory Structure

```
backend/
├── controllers/        # Request handlers
│   ├── authController.js
│   ├── taskController.js
│   ├── teamController.js
│   └── notificationController.js
├── models/            # Database schemas
│   ├── User.js
│   ├── Task.js
│   ├── Team.js
│   └── Notification.js
├── services/          # Business logic
│   ├── notificationService.js
│   ├── cleanupScheduler.js
│   └── schedulerService.js
├── middleware/        # Request middleware
│   └── middle_auth.js
├── routes/           # API routes
│   ├── auth.js
│   ├── task.js
│   ├── team.js
│   └── notification.js
└── index.js          # Application entry point
```

### Request Flow

```
┌─────────────────┐    HTTP Request    ┌─────────────────┐
│                 │ ──────────────────►│                 │
│   Client App    │                   │ Express Router  │
│                 │ ◄──────────────────│                 │
└─────────────────┘    HTTP Response   └─────────────────┘
                                               │
                                               ▼
                                       ┌─────────────────┐
                                       │   Middleware    │
                                       │ • CORS          │
                                       │ • Auth          │
                                       │ • Validation    │
                                       └─────────────────┘
                                               │
                                               ▼
                                       ┌─────────────────┐
                                       │   Controllers   │
                                       │ • Route Logic   │
                                       │ • Input Validation│
                                       │ • Error Handling │
                                       └─────────────────┘
                                               │
                                               ▼
                                       ┌─────────────────┐
                                       │    Services     │
                                       │ • Business Logic│
                                       │ • External APIs │
                                       │ • Background Jobs│
                                       └─────────────────┘
                                               │
                                               ▼
                                       ┌─────────────────┐
                                       │    Models       │
                                       │ • Data Access   │
                                       │ • Validation    │
                                       │ • Relationships │
                                       └─────────────────┘
```

### Key Design Patterns

**Controller Pattern**:

- Thin controllers focused on HTTP concerns
- Delegate business logic to services
- Standardized error handling

**Service Layer Pattern**:

- Business logic separated from HTTP concerns
- Reusable across different controllers
- Easier to test and maintain

**Repository Pattern** (via Mongoose):

- Data access abstraction
- Consistent query interface
- Built-in validation and relationships

## Database Design

### Schema Overview

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│      Users      │         │      Teams      │         │      Tasks      │
├─────────────────┤         ├─────────────────┤         ├─────────────────┤
│ _id (ObjectId)  │◄───────►│ _id (ObjectId)  │◄───────►│ _id (ObjectId)  │
│ email (String)  │         │ name (String)   │         │ name (String)   │
│ password (Hash) │         │ owner (ObjectId)│         │ assignedTo[]    │
│ name (String)   │         │ members[]       │         │ assignedBy      │
│ avatar (String) │         │ settings        │         │ team (ObjectId) │
│ teams[]         │         │ isActive        │         │ completedDays[] │
│ notifications   │         │ createdAt       │         │ isArchived      │
│ fcmTokens[]     │         │ updatedAt       │         │ priority        │
│ isActive        │         └─────────────────┘         │ dueDate         │
│ createdAt       │                                     │ createdAt       │
│ updatedAt       │                                     │ updatedAt       │
└─────────────────┘                                     └─────────────────┘
        │                                                       │
        ▼                                                       ▼
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│ Notifications   │         │ TeamInvitations │         │  TaskHistory    │
├─────────────────┤         ├─────────────────┤         ├─────────────────┤
│ _id (ObjectId)  │         │ _id (ObjectId)  │         │ _id (ObjectId)  │
│ recipient       │         │ team (ObjectId) │         │ userId          │
│ sender          │         │ inviter         │         │ taskName        │
│ type (String)   │         │ invitee         │         │ completedDays[] │
│ title (String)  │         │ email           │         │ teamId          │
│ message         │         │ role (String)   │         │ createdAt       │
│ isRead          │         │ status          │         │ updatedAt       │
│ createdAt       │         │ expiresAt       │         └─────────────────┘
│ updatedAt       │         │ createdAt       │
└─────────────────┘         └─────────────────┘
```

### Key Relationships

**User ↔ Team**: Many-to-Many

- Users can be members of multiple teams
- Teams have multiple users with different roles

**User ↔ Task**: Many-to-Many (assignedTo)

- Users can be assigned multiple tasks
- Tasks can be assigned to multiple users

**Team ↔ Task**: One-to-Many

- Teams can have multiple tasks
- Tasks belong to one team (or none for personal tasks)

**Task → TaskHistory**: One-to-Many

- When tasks are deleted, completion data is preserved
- Historical data used for analytics

### Indexing Strategy

```javascript
// Users
{ email: 1 }                    // Login queries
{ teams: 1 }                    // Team membership queries

// Tasks
{ assignedTo: 1 }               // User's tasks
{ team: 1, isArchived: 1 }      // Team task queries
{ dueDate: 1 }                  // Due date filtering
{ isArchived: 1, archivedAt: 1 } // Cleanup queries

// Teams
{ 'members.user': 1 }           // Member lookup
{ owner: 1 }                    // Owner queries

// Notifications
{ recipient: 1, isRead: 1 }     // User notifications
{ recipient: 1, createdAt: -1 } // Recent notifications

// TaskHistory
{ userId: 1 }                   // User history
{ teamId: 1 }                   // Team history
```

## Security Architecture

### Authentication Flow

```
┌─────────────────┐    1. Login       ┌─────────────────┐
│                 │ ─────────────────►│                 │
│   Client App    │                   │  Auth Controller│
│                 │ ◄─────────────────│                 │
└─────────────────┘    2. JWT Token   └─────────────────┘
        │                                       │
        │ 3. Store Token                        │ 4. Hash Password
        │    (Secure Storage)                   │    (bcrypt)
        ▼                                       ▼
┌─────────────────┐                   ┌─────────────────┐
│ Local Storage   │                   │    Database     │
│ • JWT Token     │                   │ • User Record   │
│ • User Data     │                   │ • Hashed Pass   │
└─────────────────┘                   └─────────────────┘
        │
        │ 5. API Requests
        ▼
┌─────────────────┐    6. Validate    ┌─────────────────┐
│                 │ ─────────────────►│                 │
│  Protected API  │                   │ Auth Middleware │
│                 │ ◄─────────────────│                 │
└─────────────────┘    7. Allow/Deny  └─────────────────┘
```

### Security Measures

**Authentication**:

- JWT tokens with 7-day expiration
- Secure token storage (FlutterSecureStorage on mobile)
- Token validation on every protected request
- Automatic logout on token expiration

**Password Security**:

- bcrypt hashing with 12 rounds
- Minimum 6-character password requirement
- No password storage in plaintext anywhere

**API Security**:

- CORS with origin whitelisting
- Input validation and sanitization
- Rate limiting (recommended for production)
- Structured error messages (no sensitive data leakage)

**Data Protection**:

- No sensitive data in client-side logs
- Database connection string in environment variables
- JWT secret in environment variables

## Data Flow & State Management

### Task Creation Flow

```
1. User fills form → 2. TaskCreationDialog validates
                    ↓
8. UI updates ←────── 3. TaskDatabase.createTask()
                    ↓
7. Response handled← 4. TaskService.createTask()
                    ↓
6. Backend response← 5. HTTP POST /tasks
                    ↓
                    Backend Controller:
                    • Validates input
                    • Creates Task model
                    • Saves to MongoDB
                    • Sends notifications
                    • Returns task data
```

### Real-time Synchronization

```
┌─────────────────┐    Timer Service    ┌─────────────────┐
│                 │ ──────────────────► │                 │
│  Background     │     (10s interval)  │   API Polling   │
│  Service        │ ◄────────────────── │                 │
└─────────────────┘                     └─────────────────┘
        │                                       │
        ▼                                       ▼
┌─────────────────┐                     ┌─────────────────┐
│ TaskDatabase    │                     │  Data Refresh   │
│ • Update lists  │                     │ • Compare with  │
│ • Notify UI     │                     │   local state   │
│ • Handle conflicts                   │ • Resolve conflicts
└─────────────────┘                     └─────────────────┘
```

### Offline Handling

**Write Operations**:

- Show optimistic UI updates
- Queue failed requests for retry
- Show error feedback on persistent failures

**Read Operations**:

- Use cached data when offline
- Refresh when connection restored
- Show offline indicator

## Performance Considerations

### Database Optimization

**Query Optimization**:

- Use indexes for frequent queries
- Limit result sets with pagination
- Use projection to fetch only needed fields
- Aggregate complex queries server-side

**Data Cleanup**:

- Automated archival of old completed tasks
- Historical data preservation for analytics
- Regular cleanup of expired tokens/sessions

### Frontend Optimization

**State Management**:

- Provider for efficient rebuilds
- Local state for temporary UI state
- Debounced API calls for search/filter

**Background Services**:

- Efficient polling intervals (10s)
- Background sync only on mobile
- Widget updates for home screen

**Memory Management**:

- Dispose controllers and streams
- Lazy loading for large lists
- Image caching for avatars

### Network Optimization

**API Design**:

- RESTful endpoints with appropriate HTTP methods
- Batch operations where possible
- Compression for large responses

**Error Handling**:

- Exponential backoff for retries
- Circuit breaker pattern for external services
- Graceful degradation for non-critical features

## Future Architecture Considerations

### Scalability Improvements

**Backend**:

- Microservices architecture for larger scale
- Redis for caching and session storage
- Message queues for background processing
- Load balancing for multiple instances

**Database**:

- Read replicas for scaling reads
- Sharding for large datasets
- Connection pooling optimization

**Frontend**:

- State management with Redux/Riverpod for complex apps
- Code splitting for web builds
- Progressive Web App (PWA) features

### Feature Enhancements

**Real-time Features**:

- WebSocket connections for live updates
- Collaborative editing for task descriptions
- Live presence indicators

**Mobile Features**:

- Offline-first architecture with sync
- Native integrations (calendar, contacts)
- Advanced home screen widgets

**Analytics & Monitoring**:

- Application performance monitoring (APM)
- User analytics and feature usage tracking
- Error tracking and alerting

---

**Related Documentation**:

- [Installation Guide](INSTALLATION.md)
- [API Reference](API.md)
- [Deployment Guide](DEPLOYMENT.md)
