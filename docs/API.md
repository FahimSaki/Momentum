# API Documentation

Complete REST API reference for Momentum backend.

**Base URL**: `https://your-domain.com` or `http://localhost:10000`

## Authentication

All protected endpoints require JWT authentication via `Authorization` header:

```http
Authorization: Bearer <jwt_token>
```

Get JWT tokens from login/register endpoints.

---

## Authentication Endpoints

### Register User

Create a new user account.

**Endpoint**: `POST /auth/register`

**Request Body**:

```json
{
  "name": "John Doe",
  "email": "john@example.com", 
  "password": "securepassword123"
}
```

**Response** (201):

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "60d5ecb54b4f8a2d3c8e9f1a",
    "name": "John Doe",
    "email": "john@example.com",
    "avatar": null,
    "bio": null,
    "timezone": "UTC",
    "teams": [],
    "notificationSettings": {
      "email": true,
      "push": true,
      "inApp": true,
      "taskAssigned": true,
      "taskCompleted": true,
      "teamInvitations": true,
      "dailyReminder": false
    },
    "isActive": true,
    "lastLoginAt": "2023-12-07T10:30:00.000Z",
    "createdAt": "2023-12-07T10:30:00.000Z",
    "updatedAt": "2023-12-07T10:30:00.000Z"
  },
  "message": "Registration successful"
}
```

**Errors**:

- `400`: Missing required fields or validation errors
- `400`: Email already exists

### Login User

Authenticate existing user.

**Endpoint**: `POST /auth/login`

**Request Body**:

```json
{
  "email": "john@example.com",
  "password": "securepassword123"
}
```

**Response** (200):

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "60d5ecb54b4f8a2d3c8e9f1a",
    "name": "John Doe",
    "email": "john@example.com",
    // ... other user fields
  },
  "message": "Login successful"
}
```

**Errors**:

- `400`: Missing email or password
- `401`: Invalid credentials
- `401`: User registered with Google (use Google login)

### Logout User

**Endpoint**: `POST /auth/logout`  
**Authentication**: Required

**Response** (200):

```json
{
  "message": "Left team successfully"
}
```

### Delete Team

**Endpoint**: `DELETE /teams/:teamId`

**Response** (200):

```json
{
  "message": "Team deleted successfully"
}
```

---

## Notification Endpoints

All notification endpoints require authentication.

### Get User Notifications

**Endpoint**: `GET /notifications`

**Query Parameters**:

- `limit` (optional): Number of notifications to return (default: 50)
- `offset` (optional): Number of notifications to skip (default: 0)
- `unreadOnly` (optional): Return only unread notifications (default: false)

**Response** (200):

```json
[
  {
    "_id": "60d5ecb54b4f8a2d3c8e9f20",
    "recipient": {
      "_id": "60d5ecb54b4f8a2d3c8e9f1a",
      "name": "John Doe",
      "email": "john@example.com"
    },
    "sender": {
      "_id": "60d5ecb54b4f8a2d3c8e9f1f",
      "name": "Jane Smith",
      "email": "jane@example.com"
    },
    "team": {
      "_id": "60d5ecb54b4f8a2d3c8e9f1b",
      "name": "Development Team"
    },
    "task": {
      "_id": "60d5ecb54b4f8a2d3c8e9f1c",
      "name": "Complete API documentation"
    },
    "type": "task_assigned",
    "title": "New Task Assigned",
    "message": "Jane Smith assigned you a task: \"Complete API documentation\"",
    "data": {
      "type": "task_assigned",
      "taskId": "60d5ecb54b4f8a2d3c8e9f1c",
      "taskName": "Complete API documentation",
      "assignerName": "Jane Smith",
      "teamId": "60d5ecb54b4f8a2d3c8e9f1b",
      "dueDate": "2023-12-15T23:59:59.000Z",
      "priority": "high"
    },
    "isRead": false,
    "readAt": null,
    "createdAt": "2023-12-07T10:30:00.000Z"
  }
]
```

### Mark Notification as Read

**Endpoint**: `PUT /notifications/:notificationId/read`

**Response** (200):

```json
{
  "message": "Notification marked as read",
  "notification": {
    // ... notification object with isRead: true and readAt timestamp
  }
}
```

### Mark All Notifications as Read

**Endpoint**: `PUT /notifications/read-all`

**Response** (200):

```json
{
  "message": "5 notifications marked as read"
}
```

### Update FCM Token

**Endpoint**: `POST /notifications/fcm-token`

**Request Body**:

```json
{
  "token": "fcm_token_string_here",
  "platform": "android"
}
```

**Response** (200):

```json
{
  "message": "FCM token updated successfully",
  "result": {
    "success": true
  }
}
```

---

## Utility Endpoints

### Health Check

**Endpoint**: `GET /health`

**Response** (200):

```json
{
  "status": "ok"
}
```

### Wake Up Server

Used by external services to keep the server active.

**Endpoint**: `GET /wake-up`

**Response** (200):

```json
{
  "message": "Server is awake",
  "timestamp": "2023-12-07T10:30:00.000Z",
  "uptime": 3600.5
}
```

### Manual Cleanup

Trigger manual cleanup of archived tasks.

**Endpoint**: `POST /manual-cleanup`

**Response** (200):

```json
{
  "message": "Manual cleanup completed successfully",
  "timestamp": "2023-12-07T10:30:00.000Z",
  "duration": "1250ms",
  "triggered_by": "external_cron"
}
```

---

## Data Models

### User Object

```json
{
  "_id": "60d5ecb54b4f8a2d3c8e9f1a",
  "email": "john@example.com",
  "name": "John Doe",
  "avatar": "https://example.com/avatar.jpg",
  "bio": "Full-stack developer",
  "timezone": "America/New_York",
  "teams": ["60d5ecb54b4f8a2d3c8e9f1b"],
  "notificationSettings": {
    "email": true,
    "push": true,
    "inApp": true,
    "taskAssigned": true,
    "taskCompleted": true,
    "teamInvitations": true,
    "dailyReminder": false
  },
  "fcmTokens": [{
    "token": "fcm_token_string",
    "platform": "android",
    "lastUsed": "2023-12-07T10:30:00.000Z"
  }],
  "isActive": true,
  "lastLoginAt": "2023-12-07T10:30:00.000Z",
  "createdAt": "2023-12-07T10:30:00.000Z",
  "updatedAt": "2023-12-07T10:30:00.000Z"
}
```

### Task Object

```json
{
  "_id": "60d5ecb54b4f8a2d3c8e9f1c",
  "name": "Complete API documentation",
  "description": "Write comprehensive API docs",
  "assignedTo": [/* User objects */],
  "assignedBy": {/* User object */},
  "team": {/* Team object */},
  "priority": "high",
  "dueDate": "2023-12-15T23:59:59.000Z",
  "tags": ["documentation", "urgent"],
  "completedDays": ["2023-12-07T00:00:00.000Z"],
  "completedBy": [{
    "user": {/* User object */},
    "completedAt": "2023-12-07T10:30:00.000Z"
  }],
  "lastCompletedDate": "2023-12-07T00:00:00.000Z",
  "isArchived": true,
  "archivedAt": "2023-12-07T10:30:00.000Z",
  "isTeamTask": true,
  "assignmentType": "individual",
  "recurrence": {
    "isRecurring": false,
    "pattern": "daily",
    "interval": 1
  },
  "createdAt": "2023-12-07T10:30:00.000Z",
  "updatedAt": "2023-12-07T10:30:00.000Z"
}
```

### Team Object

```json
{
  "_id": "60d5ecb54b4f8a2d3c8e9f1b",
  "name": "Development Team",
  "description": "Frontend and backend development",
  "owner": {/* User object */},
  "members": [{
    "user": {/* User object */},
    "role": "owner",
    "joinedAt": "2023-12-07T10:30:00.000Z",
    "invitedBy": {/* User object */}
  }],
  "settings": {
    "allowMemberInvite": false,
    "taskAutoDelete": true,
    "notificationSettings": {
      "taskAssigned": true,
      "taskCompleted": true,
      "memberJoined": true
    }
  },
  "isActive": true,
  "createdAt": "2023-12-07T10:30:00.000Z",
  "updatedAt": "2023-12-07T10:30:00.000Z"
}
```

---

## Error Responses

### Standard Error Format

```json
{
  "message": "Error description",
  "error": "Detailed error message (development only)",
  "errors": ["Array of validation errors (if applicable)"]
}
```

### Common HTTP Status Codes

| Status | Description | Common Causes |
|--------|-------------|---------------|
| `400` | Bad Request | Missing required fields, validation errors |
| `401` | Unauthorized | Invalid/expired token, missing authentication |
| `403` | Forbidden | Insufficient permissions |
| `404` | Not Found | Resource doesn't exist |
| `409` | Conflict | Duplicate resource (e.g., email already exists) |
| `422` | Unprocessable Entity | Invalid data format |
| `429` | Too Many Requests | Rate limiting (if implemented) |
| `500` | Internal Server Error | Server-side errors |

### Example Error Responses

**400 Bad Request**:

```json
{
  "message": "Validation error",
  "errors": [
    "Name is required for registration",
    "Password must be at least 6 characters long"
  ]
}
```

**401 Unauthorized**:

```json
{
  "message": "Invalid or expired token"
}
```

**403 Forbidden**:

```json
{
  "message": "You do not have permission to perform this action"
}
```

**404 Not Found**:

```json
{
  "message": "Task not found"
}
```

---

## Rate Limiting

Currently no rate limiting is implemented, but consider implementing it for production:

- **Authentication endpoints**: 5 requests per minute per IP
- **API endpoints**: 100 requests per minute per user
- **File uploads**: 10 requests per minute per user

---

## API Client Examples

### JavaScript (Fetch)

```javascript
// Login
const response = await fetch('http://localhost:10000/auth/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    email: 'john@example.com',
    password: 'password123'
  })
});
const data = await response.json();
const token = data.token;

// Create task
const taskResponse = await fetch('http://localhost:10000/tasks', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    name: 'New Task',
    description: 'Task description'
  })
});
```

### cURL

```bash
# Login
curl -X POST http://localhost:10000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"john@example.com","password":"password123"}'

# Create task (replace TOKEN with actual token)
curl -X POST http://localhost:10000/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"name":"New Task","description":"Task description"}'
```

### Dart/Flutter

```dart
// Login
final response = await http.post(
  Uri.parse('$apiBaseUrl/auth/login'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode({
    'email': 'john@example.com',
    'password': 'password123'
  }),
);
final data = json.decode(response.body);
final token = data['token'];

// Create task
final taskResponse = await http.post(
  Uri.parse('$apiBaseUrl/tasks'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json'
  },
  body: json.encode({
    'name': 'New Task',
    'description': 'Task description'
  }),
);
```

---

## Changelog

### API Version 1.0

- Initial API implementation
- Authentication endpoints
- Basic CRUD operations for tasks
- Team management
- Notification system

### Upcoming Features

- API versioning (`/api/v1/`, `/api/v2/`)
- GraphQL endpoint
- WebSocket support for real-time updates
- Bulk operations
- Advanced filtering and sorting
- File attachments for tasks

---

**Need Help?**

- [Report API Issues](../../issues)
- [API Questions](../../discussions)
- [Back to Main Docs](../README.md) "Logged out successfully"
}

```

### Validate Token
Check if current token is valid.

**Endpoint**: `GET /auth/validate`  
**Authentication**: Required

**Response** (200):
```json
{
  "valid": true,
  "userId": "60d5ecb54b4f8a2d3c8e9f1a",
  "user": {
    "id": "60d5ecb54b4f8a2d3c8e9f1a",
    "name": "John Doe",
    "email": "john@example.com"
  }
}
```

---

## Task Endpoints

All task endpoints require authentication.

### Create Task

**Endpoint**: `POST /tasks`

**Request Body**:

```json
{
  "name": "Complete API documentation",
  "description": "Write comprehensive API docs for all endpoints",
  "assignedTo": ["60d5ecb54b4f8a2d3c8e9f1a"],
  "teamId": "60d5ecb54b4f8a2d3c8e9f1b",
  "priority": "high",
  "dueDate": "2023-12-15T23:59:59.000Z",
  "tags": ["documentation", "urgent"],
  "assignmentType": "individual"
}
```

**Response** (201):

```json
{
  "message": "Task created successfully",
  "task": {
    "_id": "60d5ecb54b4f8a2d3c8e9f1c",
    "name": "Complete API documentation",
    "description": "Write comprehensive API docs for all endpoints",
    "assignedTo": [{
      "_id": "60d5ecb54b4f8a2d3c8e9f1a",
      "name": "John Doe",
      "email": "john@example.com",
      "avatar": null
    }],
    "assignedBy": {
      "_id": "60d5ecb54b4f8a2d3c8e9f1a",
      "name": "John Doe",
      "email": "john@example.com"
    },
    "team": {
      "_id": "60d5ecb54b4f8a2d3c8e9f1b",
      "name": "Development Team"
    },
    "priority": "high",
    "dueDate": "2023-12-15T23:59:59.000Z",
    "tags": ["documentation", "urgent"],
    "completedDays": [],
    "completedBy": [],
    "lastCompletedDate": null,
    "isArchived": false,
    "archivedAt": null,
    "isTeamTask": true,
    "assignmentType": "individual",
    "createdAt": "2023-12-07T10:30:00.000Z",
    "updatedAt": "2023-12-07T10:30:00.000Z"
  }
}
```

### Get User Tasks

**Endpoint**: `GET /tasks/user` or `GET /tasks/assigned`

**Query Parameters**:

- `userId` (optional): User ID to get tasks for
- `teamId` (optional): Filter by team
- `type` (optional): `personal`, `team`, or `all`

**Response** (200):

```json
[
  {
    "_id": "60d5ecb54b4f8a2d3c8e9f1c",
    "name": "Complete API documentation",
    // ... full task object
  }
]
```

### Get Team Tasks

**Endpoint**: `GET /tasks/team/:teamId`

**Query Parameters**:

- `status` (optional): `active` or `archived`

**Response** (200):

```json
[
  {
    "_id": "60d5ecb54b4f8a2d3c8e9f1c",
    "name": "Complete API documentation",
    // ... full task object
  }
]
```

### Update Task

**Endpoint**: `PUT /tasks/:id`

**Request Body** (partial update):

```json
{
  "name": "Updated task name",
  "description": "Updated description",
  "priority": "medium",
  "dueDate": "2023-12-20T23:59:59.000Z"
}
```

**Response** (200):

```json
{
  "message": "Task updated successfully",
  "task": {
    // ... updated task object
  }
}
```

### Complete/Uncomplete Task

**Endpoint**: `PUT /tasks/:id/complete`

**Request Body**:

```json
{
  "isCompleted": true
}
```

**Response** (200):

```json
{
  "message": "Task completed successfully",
  "task": {
    "_id": "60d5ecb54b4f8a2d3c8e9f1c",
    // ... task with updated completion status
    "completedDays": ["2023-12-07T00:00:00.000Z"],
    "lastCompletedDate": "2023-12-07T00:00:00.000Z",
    "isArchived": true,
    "archivedAt": "2023-12-07T10:30:00.000Z",
    "completedBy": [{
      "user": {
        "_id": "60d5ecb54b4f8a2d3c8e9f1a",
        "name": "John Doe",
        "email": "john@example.com"
      },
      "completedAt": "2023-12-07T10:30:00.000Z"
    }]
  }
}
```

### Delete Task

**Endpoint**: `DELETE /tasks/:id`

**Response** (200):

```json
{
  "message": "Task deleted successfully and preserved in history"
}
```

### Get Task History

**Endpoint**: `GET /tasks/history`

**Query Parameters**:

- `userId` (optional): User ID to get history for
- `teamId` (optional): Team ID to get history for

**Response** (200):

```json
[
  {
    "_id": "60d5ecb54b4f8a2d3c8e9f1d",
    "userId": "60d5ecb54b4f8a2d3c8e9f1a",
    "taskName": "Completed Task Example",
    "completedDays": [
      "2023-12-06T00:00:00.000Z",
      "2023-12-05T00:00:00.000Z"
    ],
    "teamId": "60d5ecb54b4f8a2d3c8e9f1b",
    "createdAt": "2023-12-07T10:30:00.000Z",
    "updatedAt": "2023-12-07T10:30:00.000Z"
  }
]
```

### Get Dashboard Stats

**Endpoint**: `GET /tasks/stats`

**Query Parameters**:

- `teamId` (optional): Team ID to get stats for

**Response** (200):

```json
{
  "totalTasks": 25,
  "completedToday": 3,
  "overdueTasks": 2,
  "upcomingTasks": 8
}
```

---

## Team Endpoints

All team endpoints require authentication.

### Create Team

**Endpoint**: `POST /teams`

**Request Body**:

```json
{
  "name": "Development Team",
  "description": "Frontend and backend development team"
}
```

**Response** (201):

```json
{
  "message": "Team created successfully",
  "team": {
    "_id": "60d5ecb54b4f8a2d3c8e9f1b",
    "name": "Development Team",
    "description": "Frontend and backend development team",
    "owner": {
      "_id": "60d5ecb54b4f8a2d3c8e9f1a",
      "name": "John Doe",
      "email": "john@example.com",
      "avatar": null
    },
    "members": [{
      "user": {
        "_id": "60d5ecb54b4f8a2d3c8e9f1a",
        "name": "John Doe",
        "email": "john@example.com"
      },
      "role": "owner",
      "joinedAt": "2023-12-07T10:30:00.000Z",
      "invitedBy": null
    }],
    "settings": {
      "allowMemberInvite": false,
      "taskAutoDelete": true,
      "notificationSettings": {
        "taskAssigned": true,
        "taskCompleted": true,
        "memberJoined": true
      }
    },
    "isActive": true,
    "createdAt": "2023-12-07T10:30:00.000Z",
    "updatedAt": "2023-12-07T10:30:00.000Z"
  }
}
```

### Get User Teams

**Endpoint**: `GET /teams`

**Response** (200):

```json
[
  {
    "_id": "60d5ecb54b4f8a2d3c8e9f1b",
    "name": "Development Team",
    // ... full team object
  }
]
```

### Get Team Details

**Endpoint**: `GET /teams/:teamId`

**Response** (200):

```json
{
  "_id": "60d5ecb54b4f8a2d3c8e9f1b",
  "name": "Development Team",
  // ... full team object with all members and settings
}
```

### Invite User to Team

**Endpoint**: `POST /teams/:teamId/invite`

**Request Body**:

```json
{
  "email": "jane@example.com",
  "role": "member",
  "message": "Join our development team!"
}
```

**Response** (200):

```json
{
  "message": "Invitation sent successfully",
  "invitation": {
    "_id": "60d5ecb54b4f8a2d3c8e9f1e",
    "team": "60d5ecb54b4f8a2d3c8e9f1b",
    "inviter": "60d5ecb54b4f8a2d3c8e9f1a",
    "invitee": "60d5ecb54b4f8a2d3c8e9f1f",
    "email": "jane@example.com",
    "role": "member",
    "status": "pending",
    "expiresAt": "2023-12-14T10:30:00.000Z",
    "message": "Join our development team!",
    "createdAt": "2023-12-07T10:30:00.000Z"
  }
}
```

### Get Pending Invitations

**Endpoint**: `GET /teams/invitations/pending`

**Response** (200):

```json
[
  {
    "_id": "60d5ecb54b4f8a2d3c8e9f1e",
    "team": {
      "_id": "60d5ecb54b4f8a2d3c8e9f1b",
      "name": "Development Team",
      "description": "Frontend and backend development team"
    },
    "inviter": {
      "_id": "60d5ecb54b4f8a2d3c8e9f1a",
      "name": "John Doe",
      "email": "john@example.com"
    },
    "invitee": {
      "_id": "60d5ecb54b4f8a2d3c8e9f1f",
      "name": "Jane Smith",
      "email": "jane@example.com"
    },
    "email": "jane@example.com",
    "role": "member",
    "status": "pending",
    "expiresAt": "2023-12-14T10:30:00.000Z",
    "message": "Join our development team!",
    "createdAt": "2023-12-07T10:30:00.000Z"
  }
]
```

### Respond to Team Invitation

**Endpoint**: `PUT /teams/invitations/:invitationId/respond`

**Request Body**:

```json
{
  "response": "accepted"
}
```

*Values: `accepted` or `declined`*

**Response** (200):

```json
{
  "message": "Invitation accepted successfully",
  "invitation": {
    // ... updated invitation object with new status
  }
}
```

### Update Team Settings

**Endpoint**: `PUT /teams/:teamId/settings`

**Request Body**:

```json
{
  "settings": {
    "allowMemberInvite": true,
    "taskAutoDelete": false,
    "notificationSettings": {
      "taskAssigned": true,
      "taskCompleted": false,
      "memberJoined": true
    }
  }
}
```

### Remove Team Member

**Endpoint**: `DELETE /teams/:teamId/members/:memberId`

**Response** (200):

```json
{
  "message": "Member removed successfully"
}
```

### Leave Team

**Endpoint**: `POST /teams/:teamId/leave`

**Response** (200):

```json
{
  "message":
