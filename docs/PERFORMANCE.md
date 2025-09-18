# Performance Guide

Optimization strategies, monitoring techniques, and performance best practices for Momentum.

## Performance Overview

Momentum is designed for optimal performance across all platforms with intelligent optimizations:

- **Frontend**: Reactive UI updates, efficient state management, background processing
- **Backend**: Automated cleanup, connection pooling, optimized database queries
- **Database**: Strategic indexing, data archiving, intelligent cleanup scheduling
- **Mobile**: Background sync, widget optimization, memory management

---

## Frontend Performance

### Flutter Performance Optimization

**Widget Optimization**:

```dart

// Use ValueNotifier for localized updates
class TaskCounter extends StatefulWidget {
  @override
  State<TaskCounter> createState() => _TaskCounterState();
}

class _TaskCounterState extends State<TaskCounter> {
  late ValueNotifier<int> _counter;
  
  @override
  void initState() {
    super.initState();
    _counter = ValueNotifier<int>(0);
  }
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _counter,
      builder: (context, count, child) {
        return Text('Tasks: $count');
      },
    );
  }
  
  @override
  void dispose() {
    _counter.dispose();
    super.dispose();
  }
}
```

**ListView Optimization**:

```dart
// Use ListView.builder for large lists
ListView.builder(
  itemCount: tasks.length,
  itemBuilder: (context, index) {
    final task = tasks[index];
    return TaskTile(
      key: ValueKey(task.id), // Stable keys for performance
      task: task,
    );
  },
)

// Implement pull-to-refresh efficiently
RefreshIndicator(
  onRefresh: () async {
    // Debounce refresh requests
    if (_isRefreshing) return;
    _isRefreshing = true;
    
    try {
      await db.refreshData();
    } finally {
      _isRefreshing = false;
    }
  },
  child: ListView.builder(...),
)
```

### State Management Optimization

**Provider Pattern Efficiency**:

```dart
// Use Consumer only where data is needed
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Momentum')),
      body: Column(
        children: [
          // Static widget - no Consumer needed
          const DashboardHeader(),
          
          // Dynamic content - use Consumer
          Expanded(
            child: Consumer<TaskDatabase>(
              builder: (context, db, child) {
                return ListView.builder(
                  itemCount: db.activeTasks.length,
                  itemBuilder: (context, index) => TaskTile(
                    task: db.activeTasks[index],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Use Selector for specific properties
Selector<TaskDatabase, int>(
  selector: (context, db) => db.activeTasks.length,
  builder: (context, taskCount, child) {
    return Text('Active Tasks: $taskCount');
  },
)
```

### Memory Management

**Disposal Pattern**:

```dart
// Proper resource disposal
class TaskCreationDialog extends StatefulWidget {
  @override
  State<TaskCreationDialog> createState() => _TaskCreationDialogState();
}

class _TaskCreationDialogState extends State<TaskCreationDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  StreamSubscription? _subscription;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _subscription?.cancel();
    super.dispose();
  }
}
```

**Image and Asset Optimization**:

```dart
// Efficient image loading
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  
  const UserAvatar({super.key, this.avatarUrl});
  
  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null) {
      return const CircleAvatar(
        child: Icon(Icons.person),
      );
    }
    
    return CircleAvatar(
      backgroundImage: NetworkImage(avatarUrl!),
      onBackgroundImageError: (exception, stackTrace) {
        // Handle image load errors gracefully
        debugPrint('Avatar load error: $exception');
      },
    );
  }
}
```

### Background Processing

**Efficient Background Sync**:

```dart
// database/timer_service.dart - Optimized polling
class TimerService {
  Timer? _pollingTimer;
  bool _isPolling = false;
  
  void startPolling() {
    if (kIsWeb || _isPolling) return;
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isPolling) return; // Prevent overlapping requests
      
      _isPolling = true;
      try {
        await onPollingTick();
      } catch (e) {
        // Log error but continue polling
        debugPrint('Polling error: $e');
      } finally {
        _isPolling = false;
      }
    });
  }
  
  void dispose() {
    _pollingTimer?.cancel();
    _isPolling = false;
  }
}
```

**Widget Update Optimization**:

```dart
// database/widget_service.dart - Efficient widget updates
class WidgetService {
  DateTime? _lastUpdate;
  
  Future<void> updateWidgetWithHistoricalData(
    List<DateTime> historicalCompletions,
    List<Task> currentTasks,
  ) async {
    if (kIsWeb) return;
    
    // Throttle widget updates (max once per minute)
    final now = DateTime.now();
    if (_lastUpdate != null && 
        now.difference(_lastUpdate!).inMinutes < 1) {
      return;
    }
    
    try {
      _lastUpdate = now;
      
      // Efficient data processing
      final widgetData = _generateWidgetData(historicalCompletions, currentTasks);
      
      await HomeWidget.saveWidgetData('heatmap_data', widgetData.join(','));
      await HomeWidget.updateWidget(
        name: 'MomentumHomeWidget',
        androidName: 'MomentumHomeWidget',
      );
      
      _logger.i('Widget updated efficiently');
    } catch (e, stackTrace) {
      _logger.e('Widget update error', error: e, stackTrace: stackTrace);
    }
  }
  
  List<String> _generateWidgetData(
    List<DateTime> historical, 
    List<Task> tasks,
  ) {
    final List<String> widgetData = [];
    final now = DateTime.now();
    
    // Pre-compute date ranges for efficiency
    final dayCompletions = <DateTime, int>{};
    
    // Process historical data
    for (final completion in historical) {
      final day = _dateOnly(completion.toLocal());
      dayCompletions[day] = (dayCompletions[day] ?? 0) + 1;
    }
    
    // Process current task data
    for (final task in tasks) {
      for (final completion in task.completedDays) {
        final day = _dateOnly(completion.toLocal());
        dayCompletions[day] = (dayCompletions[day] ?? 0) + 1;
      }
    }
    
    // Generate 35 days of data efficiently
    for (int i = 0; i < 35; i++) {
      final date = now.subtract(Duration(days: 34 - i));
      final day = _dateOnly(date);
      widgetData.add((dayCompletions[day] ?? 0).toString());
    }
    
    return widgetData;
  }
  
  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
```

---

## Backend Performance

### Node.js Optimization

**Connection Pooling**:

```javascript
// backend/index.js - MongoDB connection optimization
import mongoose from 'mongoose';

mongoose.connect(process.env.MONGODB_URI, {
  // Connection pool settings
  maxPoolSize: 10, // Maintain up to 10 socket connections
  serverSelectionTimeoutMS: 5000, // Keep trying to send operations for 5 seconds
  socketTimeoutMS: 45000, // Close sockets after 45 seconds of inactivity
  
  // Performance optimizations
  bufferMaxEntries: 0, // Disable mongoose buffering
  bufferCommands: false, // Disable mongoose buffering
});

// Handle connection events
mongoose.connection.on('connected', () => {
  console.log('✅ MongoDB connected with optimized settings');
});

mongoose.connection.on('error', (err) => {
  console.error('❌ MongoDB connection error:', err);
});
```

**Request Optimization**:

```javascript
// backend/controllers/taskController.js - Optimized queries
export const getUserTasks = async (req, res) => {
  try {
    const { userId, teamId, type = 'all' } = req.query;
    const requesterId = req.userId;

    // Build efficient query with indexes
    let query = {};
    
    if (type === 'personal') {
      query = {
        assignedTo: userId || requesterId,
        team: { $exists: false }
      };
    } else if (type === 'team' && teamId) {
      query = {
        team: teamId,
        assignedTo: userId || requesterId
      };
    } else {
      query = {
        assignedTo: userId || requesterId
      };
    }

    // Optimized query with selective population
    const tasks = await Task.find(query)
      .populate('assignedTo', 'name email avatar') // Only needed fields
      .populate('assignedBy', 'name email avatar')
      .populate('team', 'name')
      .populate({
        path: 'completedBy.user',
        select: 'name email avatar'
      })
      .sort({ createdAt: -1 })
      .lean(); // Use lean() for read-only operations

    res.json(tasks);
  } catch (err) {
    console.error('Get user tasks error:', err);
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};
```

**Caching Strategy**:

```javascript
// backend/middleware/cache.js
import NodeCache from 'node-cache';

const cache = new NodeCache({
  stdTTL: 300, // 5 minutes default TTL
  checkperiod: 60, // Check for expired keys every minute
});

export const cacheMiddleware = (duration = 300) => {
  return (req, res, next) => {
    // Only cache GET requests
    if (req.method !== 'GET') {
      return next();
    }
    
    const key = `${req.originalUrl}_${req.userId}`;
    const cached = cache.get(key);
    
    if (cached) {
      console.log(`📦 Cache hit: ${key}`);
      return res.json(cached);
    }
    
    // Override res.json to cache response
    const originalJson = res.json;
    res.json = function(data) {
      if (res.statusCode === 200) {
        cache.set(key, data, duration);
        console.log(`💾 Cached: ${key}`);
      }
      return originalJson.call(this, data);
    };
    
    next();
  };
};

// Usage
app.get('/tasks/stats', cacheMiddleware(60), getDashboardStats); // Cache for 1 minute
```

### Automated Cleanup Optimization

**Efficient Cleanup Process**:

```javascript
// services/cleanupScheduler.js - Optimized cleanup
const runDailyCleanup = async () => {
  const now = new Date();
  console.log('🧹 Starting optimized daily cleanup...');

  try {
    // Use aggregation pipeline for efficient operations
    const cleanupPipeline = [
      {
        $match: {
          isArchived: true,
          archivedAt: { $lt: new Date(now.getTime() - 24 * 60 * 60 * 1000) }
        }
      },
      {
        $project: {
          _id: 1,
          name: 1,
          assignedTo: 1,
          completedDays: 1,
          team: 1
        }
      }
    ];

    const tasksToProcess = await Task.aggregate(cleanupPipeline);
    
    console.log(`Found ${tasksToProcess.length} tasks for cleanup`);

    // Process in batches to avoid memory issues
    const batchSize = 50;
    let processedCount = 0;

    for (let i = 0; i < tasksToProcess.length; i += batchSize) {
      const batch = tasksToProcess.slice(i, i + batchSize);
      
      // Process batch in parallel
      await Promise.all(batch.map(async (task) => {
        try {
          await saveTaskToHistory(task);
          await Task.findByIdAndDelete(task._id);
          processedCount++;
        } catch (error) {
          console.error(`Error processing task ${task._id}:`, error);
        }
      }));

      // Add small delay between batches to prevent overwhelming the database
      if (i + batchSize < tasksToProcess.length) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }

    console.log(`✅ Processed ${processedCount} tasks in batches`);
    
    // Force garbage collection if available
    if (global.gc) {
      global.gc();
      console.log('🗑️ Garbage collection triggered');
    }

    return {
      processedTasks: processedCount,
      timestamp: new Date().toISOString(),
      batchSize: batchSize
    };

  } catch (error) {
    console.error('❌ Cleanup failed:', error);
    return {
      error: error.message,
      timestamp: new Date().toISOString(),
      status: 'failed'
    };
  }
};
```

**Memory Management**:

```javascript
// backend/index.js - Memory optimization
process.on('warning', (warning) => {
  console.warn('⚠️ Node.js Warning:', warning.name, warning.message);
  console.warn('Stack:', warning.stack);
});

// Monitor memory usage
setInterval(() => {
  const memUsage = process.memoryUsage();
  const used = Math.round(memUsage.heapUsed / 1024 / 1024);
  const total = Math.round(memUsage.heapTotal / 1024 / 1024);
  
  if (used > 200) { // Alert if using more than 200MB
    console.warn(`⚠️ High memory usage: ${used}MB / ${total}MB`);
  }
}, 60000); // Check every minute

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('📴 Received SIGTERM, shutting down gracefully...');
  
  // Close database connections
  await mongoose.connection.close();
  
  // Close HTTP server
  server.close(() => {
    console.log('✅ HTTP server closed');
    process.exit(0);
  });
});
```

---

## Database Performance

### MongoDB Optimization

**Strategic Indexing**:

```javascript
// backend/models/Task.js - Performance indexes
import mongoose from 'mongoose';

const taskSchema = new mongoose.Schema({
  name: { type: String, required: true },
  assignedTo: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  assignedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  team: { type: mongoose.Schema.Types.ObjectId, ref: 'Team' },
  priority: { type: String, enum: ['low', 'medium', 'high', 'urgent'], default: 'medium' },
  dueDate: { type: Date },
  completedDays: [{ type: Date }],
  isArchived: { type: Boolean, default: false },
  archivedAt: { type: Date },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// Performance indexes
taskSchema.index({ assignedTo: 1, isArchived: 1 }); // Primary query pattern
taskSchema.index({ team: 1, createdAt: -1 }); // Team tasks sorted by creation
taskSchema.index({ dueDate: 1 }); // Due date filtering
taskSchema.index({ isArchived: 1, archivedAt: 1 }); // Cleanup queries
taskSchema.index({ assignedBy: 1 }); // Tasks assigned by user

// Compound indexes for common query patterns
taskSchema.index({ assignedTo: 1, team: 1, isArchived: 1 }); // Team member tasks
taskSchema.index({ team: 1, isArchived: 1, createdAt: -1 }); // Active team tasks
```

**Query Optimization**:

```javascript
// backend/controllers/taskController.js - Optimized aggregations
export const getDashboardStats = async (req, res) => {
  try {
    const { teamId } = req.query;
    const userId = req.userId;

    // Use aggregation pipeline for efficient statistics
    const pipeline = [
      // Match user's tasks
      {
        $match: {
          assignedTo: new mongoose.Types.ObjectId(userId),
          ...(teamId && { team: new mongoose.Types.ObjectId(teamId) })
        }
      },
      // Calculate all stats in one query
      {
        $facet: {
          totalTasks: [
            { $match: { isArchived: false } },
            { $count: "count" }
          ],
          completedToday: [
            {
              $match: {
                completedDays: {
                  $elemMatch: {
                    $gte: new Date(new Date().setHours(0, 0, 0, 0)),
                    $lt: new Date(new Date().setHours(23, 59, 59, 999))
                  }
                }
              }
            },
            { $count: "count" }
          ],
          overdueTasks: [
            {
              $match: {
                dueDate: { $lt: new Date() },
                isArchived: false
              }
            },
            { $count: "count" }
          ],
          upcomingTasks: [
            {
              $match: {
                dueDate: {
                  $gte: new Date(),
                  $lte: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
                },
                isArchived: false
              }
            },
            { $count: "count" }
          ]
        }
      }
    ];

    const [result] = await Task.aggregate(pipeline);

    const stats = {
      totalTasks: result.totalTasks[0]?.count || 0,
      completedToday: result.completedToday[0]?.count || 0,
      overdueTasks: result.overdueTasks[0]?.count || 0,
      upcomingTasks: result.upcomingTasks[0]?.count || 0,
    };

    res.json(stats);
  } catch (err) {
    console.error('Dashboard stats error:', err);
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};
```

**Connection Optimization**:

```javascript
// backend/config/database.js
import mongoose from 'mongoose';

export const connectDatabase = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      // Connection pool optimization
      maxPoolSize: 10, // Maximum number of connections
      minPoolSize: 2,  // Minimum number of connections
      maxIdleTimeMS: 30000, // Close connections after 30 seconds of inactivity
      serverSelectionTimeoutMS: 5000, // How long to try selecting a server
      socketTimeoutMS: 45000, // How long to wait for a socket to remain inactive
      
      // Write concern optimization
      w: 'majority', // Wait for majority of replicas to acknowledge writes
      wtimeoutMS: 10000, // Timeout after 10 seconds
      
      // Read preference
      readPreference: 'primary', // Always read from primary for consistency
      
      // Compression
      compressors: ['zlib'], // Enable compression for network traffic
      
      // Buffering
      bufferMaxEntries: 0, // Disable buffering for immediate error feedback
      bufferCommands: false,
    });

    console.log(`✅ MongoDB connected: ${conn.connection.host}:${conn.connection.port}`);
    
    // Monitor connection events
    mongoose.connection.on('error', (err) => {
      console.error('❌ MongoDB connection error:', err);
    });

    mongoose.connection.on('disconnected', () => {
      console.warn('⚠️ MongoDB disconnected');
    });

    mongoose.connection.on('reconnected', () => {
      console.log('🔄 MongoDB reconnected');
    });

  } catch (error) {
    console.error('💥 Database connection failed:', error);
    process.exit(1);
  }
};
```

### Data Archiving Strategy

**Intelligent Data Lifecycle**:

```javascript
// services/dataLifecycleService.js
class DataLifecycleService {
  constructor() {
    this.batchSize = 100;
    this.retentionPolicies = {
      tasks: {
        activeRetention: 90, // Keep active tasks for 90 days max
        completedRetention: 30, // Archive completed tasks after 30 days
        historyRetention: 365 // Keep history for 1 year
      },
      notifications: {
        retention: 30 // Delete notifications after 30 days
      }
    };
  }

  async optimizeTaskData() {
    console.log('🔄 Starting data lifecycle optimization...');
    
    // Archive old completed tasks
    const oldCompletedTasks = await Task.find({
      isArchived: true,
      archivedAt: {
        $lt: new Date(Date.now() - this.retentionPolicies.tasks.completedRetention * 24 * 60 * 60 * 1000)
      }
    }).limit(this.batchSize);

    for (const task of oldCompletedTasks) {
      await this.archiveTaskToHistory(task);
      await Task.findByIdAndDelete(task._id);
    }

    console.log(`✅ Archived ${oldCompletedTasks.length} old completed tasks`);
    
    // Clean old history records
    const cutoffDate = new Date(Date.now() - this.retentionPolicies.tasks.historyRetention * 24 * 60 * 60 * 1000);
    const deletedHistory = await TaskHistory.deleteMany({
      createdAt: { $lt: cutoffDate }
    });

    console.log(`🗑️ Deleted ${deletedHistory.deletedCount} old history records`);

    return {
      archivedTasks: oldCompletedTasks.length,
      deletedHistory: deletedHistory.deletedCount,
      timestamp: new Date()
    };
  }

  async archiveTaskToHistory(task) {
    if (task.completedDays?.length > 0) {
      const assigneeIds = Array.isArray(task.assignedTo) ? task.assignedTo : [task.assignedTo];
      
      for (const assigneeId of assigneeIds) {
        const existingHistory = await TaskHistory.findOne({
          userId: assigneeId,
          taskName: task.name
        });

        if (existingHistory) {
          // Merge completion days
          const allDays = [...existingHistory.completedDays, ...task.completedDays];
          const uniqueDays = [...new Set(allDays.map(d => d.toISOString()))]
            .map(d => new Date(d));
          
          existingHistory.completedDays = uniqueDays;
          await existingHistory.save();
        } else {
          await TaskHistory.create({
            userId: assigneeId,
            completedDays: task.completedDays,
            taskName: task.name,
            teamId: task.team
          });
        }
      }
    }
  }
}

export default DataLifecycleService;
```

---

## Performance Monitoring

### Application Performance Monitoring

**Backend Metrics Collection**:

```javascript
// backend/middleware/metrics.js
import { performance } from 'perf_hooks';

class MetricsCollector {
  constructor() {
    this.metrics = {
      requests: { total: 0, errors: 0 },
      responses: { times: [], slowRequests: 0 },
      database: { queries: 0, slowQueries: 0 },
      memory: { samples: [] }
    };
  }

  requestMetrics() {
    return (req, res, next) => {
      const start = performance.now();
      
      // Track request
      this.metrics.requests.total++;
      
      res.on('finish', () => {
        const duration = performance.now() - start;
        
        // Record response time
        this.metrics.responses.times.push(duration);
        
        // Track slow requests (>1 second)
        if (duration > 1000) {
          this.metrics.responses.slowRequests++;
          console.warn(`🐌 Slow request: ${req.method} ${req.path} - ${duration.toFixed(2)}ms`);
        }
        
        // Track errors
        if (res.statusCode >= 400) {
          this.metrics.requests.errors++;
        }
        
        // Cleanup old response times (keep last 1000)
        if (this.metrics.responses.times.length > 1000) {
          this.metrics.responses.times = this.metrics.responses.times.slice(-1000);
        }
      });
      
      next();
    };
  }

  getMetrics() {
    const responseTimes = this.metrics.responses.times;
    const avgResponseTime = responseTimes.length > 0 
      ? responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length 
      : 0;
    
    return {
      requests: {
        total: this.metrics.requests.total,
        errors: this.metrics.requests.errors,
        errorRate: this.metrics.requests.total > 0 
          ? (this.metrics.requests.errors / this.metrics.requests.total * 100).toFixed(2) + '%'
          : '0%'
      },
      performance: {
        averageResponseTime: avgResponseTime.toFixed(2) + 'ms',
        slowRequests: this.metrics.responses.slowRequests,
        p95ResponseTime: this.calculatePercentile(responseTimes, 95).toFixed(2) + 'ms'
      },
      memory: {
        heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + 'MB',
        heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + 'MB'
      }
    };
  }

  calculatePercentile(arr, percentile) {
    if (arr.length === 0) return 0;
    const sorted = [...arr].sort((a, b) => a - b);
    const index = Math.ceil(percentile / 100 * sorted.length) - 1;
    return sorted[index];
  }
}

const metricsCollector = new MetricsCollector();

// Expose metrics endpoint
app.get('/metrics', (req, res) => {
  res.json(metricsCollector.getMetrics());
});

export default metricsCollector;
```

**Database Query Monitoring**:

```javascript
// backend/middleware/database-monitor.js
import mongoose from 'mongoose';

class DatabaseMonitor {
  constructor() {
    this.slowQueryThreshold = 100; // milliseconds
    this.queryStats = {
      total: 0,
      slow: 0,
      errors: 0
    };
  }

  init() {
    // Monitor all database operations
    mongoose.set('debug', (collectionName, methodName, query, doc) => {
      this.queryStats.total++;
      
      const start = Date.now();
      
      // Log slow queries in production
      if (process.env.NODE_ENV === 'production') {
        setTimeout(() => {
          const duration = Date.now() - start;
          if (duration > this.slowQueryThreshold) {
            this.queryStats.slow++;
            console.warn(`🐌 Slow query detected:`, {
              collection: collectionName,
              method: methodName,
              duration: `${duration}ms`,
              query: JSON.stringify(query)
            });
          }
        }, 0);
      }
    });

    // Monitor connection events
    mongoose.connection.on('error', (err) => {
      this.queryStats.errors++;
      console.error('Database error:', err);
    });
  }

  getStats() {
    return {
      queries: {
        total: this.queryStats.total,
        slow: this.queryStats.slow,
        errors: this.queryStats.errors,
        slowPercentage: this.queryStats.total > 0 
          ? (this.queryStats.slow / this.queryStats.total * 100).toFixed(2) + '%'
          : '0%'
      },
      connection: {
        state: mongoose.connection.readyState,
        host: mongoose.connection.host,
        port: mongoose.connection.port,
        name: mongoose.connection.name
      }
    };
  }
}

export const dbMonitor = new DatabaseMonitor();
```

### Flutter Performance Monitoring

**Widget Performance Tracking**:

```dart
// util/performance_tracker.dart
class PerformanceTracker {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, List<int>> _durations = {};
  
  static void startTimer(String operation) {
    _startTimes[operation] = DateTime.now();
  }
  
  static void endTimer(String operation) {
    final start = _startTimes[operation];
    if (start != null) {
      final duration = DateTime.now().difference(start).inMilliseconds;
      
      if (!_durations.containsKey(operation)) {
        _durations[operation] = [];
      }
      
      _durations[operation]!.add(duration);
      
      // Log slow operations (>500ms)
      if (duration > 500) {
        debugPrint('🐌 Slow operation: $operation took ${duration}ms');
      }
      
      // Keep only last 100 measurements
      if (_durations[operation]!.length > 100) {
        _durations[operation] = _durations[operation]!.sublist(50);
      }
      
      _startTimes.remove(operation);
    }
  }
  
  static Map<String, dynamic> getStats() {
    final Map<String, dynamic> stats = {};
    
    _durations.forEach((operation, durations) {
      if (durations.isNotEmpty) {
        final avg = durations.reduce((a, b) => a + b) / durations.length;
        final max = durations.reduce((a, b) => a > b ? a : b);
        
        stats[operation] = {
          'averageDuration': '${avg.toStringAsFixed(2)}ms',
          'maxDuration': '${max}ms',
          'sampleCount': durations.length,
        };
      }
    });
    
    return stats;
  }
}

// Usage in TaskDatabase
class TaskDatabase extends ChangeNotifier {
  Future<void> createTask(...) async {
    PerformanceTracker.startTimer('createTask');
    
    try {
      final task = await _taskService.createTask(...);
      currentTasks.add(task);
      notifyListeners();
      
      PerformanceTracker.endTimer('createTask');
      return task;
    } catch (e) {
      PerformanceTracker.endTimer('createTask');
      rethrow;
    }
  }
}
```

**Memory Usage Monitoring**:

```dart
// services/memory_monitor.dart
class MemoryMonitor {
  static Timer? _monitorTimer;
  static final List<Map<String, dynamic>> _samples = [];
  
  static void startMonitoring() {
    _monitorTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _collectMemorySample();
    });
  }
  
  static void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }
  
  static void _collectMemorySample() {
    // Note: Flutter doesn't provide direct memory APIs
    // This would integrate with platform channels for actual memory data
    final sample = {
      'timestamp': DateTime.now().toIso8601String(),
      'widgetCount': _getEstimatedWidgetCount(),
      'providerListeners': _getProviderListenerCount(),
    };
    
    _samples.add(sample);
    
    // Keep only last 60 samples (1 hour)
    if (_samples.length > 60) {
      _samples.removeRange(0, _samples.length - 60);
    }
    
    debugPrint('📊 Memory sample: ${sample.toString()}');
  }
  
  static int _getEstimatedWidgetCount() {
    // Rough estimate based on binding's element count
    return WidgetsBinding.instance.renderView.child?.debugDescribeChildren()?.length ?? 0;
  }
  
  static int _getProviderListenerCount() {
    // This would require custom Provider instrumentation
    return 0; // Placeholder
  }
  
  static List<Map<String, dynamic>> getSamples() {
    return List.from(_samples);
  }
}
```

### Performance Dashboard

**Metrics Endpoint**:

```javascript
// backend/routes/metrics.js
import express from 'express';
import { authenticateToken } from '../middleware/middle_auth.js';
import metricsCollector from '../middleware/metrics.js';
import { dbMonitor } from '../middleware/database-monitor.js';

const router = express.Router();

// Admin-only metrics endpoint
router.get('/performance', authenticateToken, async (req, res) => {
  // In production, you'd check if user is admin
  // if (!req.user.isAdmin) return res.status(403).json({message: 'Forbidden'});
  
  try {
    const metrics = {
      server: metricsCollector.getMetrics(),
      database: dbMonitor.getStats(),
      system: {
        uptime: process.uptime(),
        nodeVersion: process.version,
        platform: process.platform,
        arch: process.arch,
        memory: process.memoryUsage(),
        cpuUsage: process.cpuUsage()
      },
      cleanup: {
        lastRun: await getLastCleanupTime(),
        nextRun: await getNextCleanupTime()
      }
    };
    
    res.json(metrics);
  } catch (error) {
    res.status(500).json({ message: 'Metrics collection error', error: error.message });
  }
});

async function getLastCleanupTime() {
  // Implementation to get last cleanup timestamp
  // Could be stored in database or log files
  return new Date(); // Placeholder
}

async function getNextCleanupTime() {
  // Calculate next cleanup time (12:05 AM UTC)
  const now = new Date();
  const nextCleanup = new Date();
  nextCleanup.setUTCHours(0, 5, 0, 0); // 12:05 AM UTC
  
  if (nextCleanup <= now) {
    nextCleanup.setUTCDate(nextCleanup.getUTCDate() + 1);
  }
  
  return nextCleanup;
}

export default router;
```

---

## Performance Best Practices

### Frontend Best Practices

**State Management**:

```dart
// Use appropriate state management
// Provider for app-wide state
// ValueNotifier for local widget state
// setState for simple component state

// Minimize rebuilds
class TaskList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TaskDatabase>(
      builder: (context, db, child) {
        // Only rebuild when tasks change
        return ListView.builder(
          itemCount: db.activeTasks.length,
          itemBuilder: (context, index) => TaskTile(
            key: ValueKey(db.activeTasks[index].id),
            task: db.activeTasks[index],
          ),
        );
      },
    );
  }
}

// Use keys for list items
ListView.builder(
  itemBuilder: (context, index) => TaskTile(
    key: ValueKey(task.id), // Stable key for performance
    task: task,
  ),
)
```

**Async Operations**:

```dart
// Debounce rapid operations
class SearchBox extends StatefulWidget {
  @override
  _SearchBoxState createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  Timer? _debounceTimer;
  
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }
  
  void _performSearch(String query) {
    // Actual search logic
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

### Backend Best Practices

**Database Queries**:

```javascript
// Use lean() for read-only operations
const tasks = await Task.find(query).lean();

// Select only needed fields
const users = await User.find({}, 'name email avatar');

// Use aggregation for complex operations
const stats = await Task.aggregate([
  { $match: { assignedTo: userId } },
  { $group: { _id: '$priority', count: { $sum: 1 } } }
]);

// Implement pagination
const tasks = await Task.find(query)
  .skip(page * limit)
  .limit(limit)
  .sort({ createdAt: -1 });
```

**Error Handling**:

```javascript
// Implement circuit breaker pattern for external services
class CircuitBreaker {
  constructor(threshold = 5, timeout = 60000) {
    this.threshold = threshold;
    this.timeout = timeout;
    this.failureCount = 0;
    this.lastFailureTime = null;
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
  }
  
  async call(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.timeout) {
        this.state = 'HALF_OPEN';
      } else {
        throw new Error('Circuit breaker is OPEN');
      }
    }
    
    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }
  
  onSuccess() {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }
  
  onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    
    if (this.failureCount >= this.threshold) {
      this.state = 'OPEN';
    }
  }
}
```

---

## Performance Alerts

### Monitoring Thresholds

**Backend Alerts**:

```javascript
// backend/services/alertService.js
class AlertService {
  constructor() {
    this.thresholds = {
      responseTime: 1000, // ms
      errorRate: 5, // percentage
      memoryUsage: 512, // MB
      slowQueries: 10, // percentage
    };
    
    this.alertCooldown = 5 * 60 * 1000; // 5 minutes
    this.lastAlerts = {};
  }
  
  checkMetrics(metrics) {
    // Response time alert
    if (parseFloat(metrics.performance.averageResponseTime) > this.thresholds.responseTime) {
      this.sendAlert('HIGH_RESPONSE_TIME', {
        current: metrics.performance.averageResponseTime,
        threshold: this.thresholds.responseTime + 'ms'
      });
    }
    
    // Error rate alert
    const errorRate = parseFloat(metrics.requests.errorRate);
    if (errorRate > this.thresholds.errorRate) {
      this.sendAlert('HIGH_ERROR_RATE', {
        current: metrics.requests.errorRate,
        threshold: this.thresholds.errorRate + '%'
      });
    }
    
    // Memory usage alert
    const memoryUsage = parseInt(metrics.memory.heapUsed);
    if (memoryUsage > this.thresholds.memoryUsage) {
      this.sendAlert('HIGH_MEMORY_USAGE', {
        current: metrics.memory.heapUsed,
        threshold: this.thresholds.memoryUsage + 'MB'
      });
    }
  }
  
  sendAlert(type, data) {
    const now = Date.now();
    
    // Implement cooldown to prevent spam
    if (this.lastAlerts[type] && (now - this.lastAlerts[type]) < this.alertCooldown) {
      return;
    }
    
    console.error(`🚨 PERFORMANCE ALERT: ${type}`, data);
    
    // In production, send to monitoring service
    // await this.sendToSlack(type, data);
    // await this.sendEmail(type, data);
    
    this.lastAlerts[type] = now;
  }
}

export const alertService = new AlertService();
```

**Frontend Performance Monitoring**:

```dart
// util/performance_monitor.dart
class PerformanceMonitor {
  static const Duration _alertThreshold = Duration(milliseconds: 500);
  static const Duration _criticalThreshold = Duration(milliseconds: 1000);
  
  static void trackOperation(String operation, Future<T> Function() fn) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await fn();
    } finally {
      stopwatch.stop();
      
      if (stopwatch.elapsed > _criticalThreshold) {
        debugPrint('🚨 CRITICAL: $operation took ${stopwatch.elapsedMilliseconds}ms');
        _reportCriticalPerformance(operation, stopwatch.elapsed);
      } else if (stopwatch.elapsed > _alertThreshold) {
        debugPrint('⚠️ SLOW: $operation took ${stopwatch.elapsedMilliseconds}ms');
      }
    }
  }
  
  static void _reportCriticalPerformance(String operation, Duration duration) {
    // In production, report to analytics service
    // FirebasePerformance.instance.newTrace(operation)
    //   ..putAttribute('duration', duration.inMilliseconds.toString())
    //   ..start()
    //   ..stop();
  }
}

// Usage
Future<void> createTask() async {
  await PerformanceMonitor.trackOperation('createTask', () async {
    final task = await _taskService.createTask(...);
    currentTasks.add(task);
    notifyListeners();
  });
}
```

---

## Performance Optimization Checklist

### Frontend (Flutter)

- [ ] **Widgets**: Use const constructors where possible
- [ ] **Lists**: Implement ListView.builder for large lists
- [ ] **State**: Use Provider/Consumer efficiently
- [ ] **Images**: Implement caching and lazy loading
- [ ] **Memory**: Dispose controllers and streams properly
- [ ] **Background**: Optimize polling and sync intervals
- [ ] **Build**: Enable obfuscation and tree-shaking for release

### Backend (Node.js)

- [ ] **Database**: Implement proper indexing strategy
- [ ] **Queries**: Use lean() and field selection
- [ ] **Connection**: Configure connection pooling
- [ ] **Caching**: Implement response caching where appropriate
- [ ] **Memory**: Monitor and prevent memory leaks
- [ ] **Cleanup**: Optimize automated cleanup processes
- [ ] **Monitoring**: Set up performance monitoring and alerts

### Database (MongoDB)

- [ ] **Indexes**: Create compound indexes for common queries
- [ ] **Aggregation**: Use aggregation pipelines for complex operations
- [ ] **Archiving**: Implement data lifecycle management
- [ ] **Sharding**: Consider sharding for large datasets
- [ ] **Monitoring**: Enable profiling for slow queries
- [ ] **Connection**: Use connection pooling and read replicas

### Infrastructure

- [ ] **CDN**: Use CDN for static assets
- [ ] **Compression**: Enable gzip compression
- [ ] **Caching**: Implement Redis for session and cache storage
- [ ] **Load Balancing**: Use load balancers for high availability
- [ ] **Monitoring**: Set up APM and log aggregation
- [ ] **Scaling**: Implement horizontal scaling strategies

---

**Performance is an ongoing process**. Regular monitoring, profiling, and optimization ensure your Momentum deployment stays fast and responsive as it grows! 🚀

---

**Related Documentation**:

- [Architecture Guide](ARCHITECTURE.md)
- [Security Guide](SECURITY.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
