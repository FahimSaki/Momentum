import 'package:flutter/material.dart';
import 'package:momentum/components/drawer.dart';
import 'package:momentum/components/task_map.dart';
import 'package:momentum/components/task_list.dart';
import 'package:momentum/components/dashboard_stats.dart';
import 'package:momentum/components/task_creation_dialog.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/pages/team_selection_page.dart';
import 'package:momentum/pages/notifications_page.dart';
import 'package:momentum/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/components/quick_invite_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  bool _isInitializing = false;
  bool _initializationFailed = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ensureInitialized();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _ensureInitialized() async {
    final db = Provider.of<TaskDatabase>(context, listen: false);

    if (!db.isInitialized && !_initializationFailed) {
      setState(() {
        _isInitializing = true;
      });

      try {
        final authData = await AuthService.getStoredAuthData();

        if (authData != null && mounted) {
          final isValidToken = await AuthService.validateToken();

          if (isValidToken && mounted) {
            await db.initialize(
              jwt: authData['token'],
              userId: authData['userId'],
            );
          } else {
            if (mounted) {
              final navigator = Navigator.of(context);
              await AuthService.logout();
              navigator.pushNamedAndRemoveUntil('/login', (route) => false);
              return;
            }
          }
        } else {
          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
            return;
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _initializationFailed = true;
          });

          final navigator = Navigator.of(context);
          await AuthService.logout();
          navigator.pushNamedAndRemoveUntil('/login', (route) => false);
          return;
        }
      } finally {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskDatabase>(
      builder: (context, db, _) {
        if (_isInitializing) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your workspace...'),
                ],
              ),
            ),
          );
        }

        if (_initializationFailed) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Failed to load workspace. Please restart the app.'),
                ],
              ),
            ),
          );
        }

        if (!db.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            }
          });
          return const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: _buildAppBar(db),
          drawer: const MyDrawer(),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showTaskCreationDialog(),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            child: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          body: Column(
            children: [
              // Tab bar
              Container(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: const [
                    Tab(text: 'Dashboard'),
                    Tab(text: 'Tasks'),
                    Tab(text: 'Analytics'),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(db),
                    _buildTasksTab(db),
                    _buildAnalyticsTab(db),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(TaskDatabase db) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TeamSelectionPage()),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              db.selectedTeam != null ? Icons.group : Icons.person,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              db.selectedTeam?.name ?? 'Personal',
              style: const TextStyle(fontSize: 18),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
      actions: [
        // Notifications
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
            ),
            if (db.unreadNotificationCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Text(
                    '${db.unreadNotificationCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 8),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),

        // Team selector
        IconButton(
          icon: const Icon(Icons.swap_horiz),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TeamSelectionPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDashboardTab(TaskDatabase db) {
    return RefreshIndicator(
      onRefresh: () async {
        await db.refreshData();
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Welcome message
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    db.selectedTeam != null
                        ? 'Team: ${db.selectedTeam!.name}'
                        : 'Personal Workspace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getWelcomeMessage(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Invite Widget
          const QuickInviteWidget(),

          const SizedBox(height: 16),

          // Dashboard stats
          const DashboardStats(),

          const SizedBox(height: 16),

          // WITH COMPLETION FUNCTIONALITY
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Tasks',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () => _tabController.animateTo(1),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Use interactive task tiles instead of simple ListTiles
                  ...db.activeTasks
                      .take(3)
                      .map((task) => _buildInteractiveTaskTile(task, db)),

                  if (db.activeTasks.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No active tasks'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTaskTile(Task task, TaskDatabase db) {
    final isCompleted = task.isCompletedToday();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: GestureDetector(
            onTap: () => _handleTaskCompletion(task, db, !isCompleted),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? Colors.green : Colors.grey,
                  width: 2,
                ),
                color: isCompleted ? Colors.green : Colors.transparent,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
          title: Text(
            task.name,
            style: TextStyle(
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted
                  ? Colors.grey
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: task.team != null
              ? Text('Team: ${task.team!.name}')
              : task.dueDate != null
              ? Text(_formatDueDate(task.dueDate!))
              : null,
          trailing: task.isOverdue
              ? const Icon(Icons.warning, color: Colors.orange, size: 20)
              : task.isDueSoon
              ? const Icon(Icons.access_time, color: Colors.amber, size: 20)
              : null,

          onTap: () => _handleTaskCompletion(task, db, !isCompleted),
        ),
      ),
    );
  }

  //  Method to handle task completion in dashboard:
  Future<void> _handleTaskCompletion(
    Task task,
    TaskDatabase db,
    bool shouldComplete,
  ) async {
    try {
      await db.completeTask(task.id, shouldComplete);

      // Force refresh so DashboardStats updates right away
      await db.refreshData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldComplete ? '✅ Task completed!' : '↩️ Task unmarked',
          ),
          backgroundColor: shouldComplete ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Helper Method for due date formatting:
  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference == 0) return 'Due today';
    if (difference == 1) return 'Due tomorrow';
    if (difference == -1) return 'Due yesterday';
    if (difference < 0) return 'Overdue by ${-difference}d';
    if (difference <= 7) return 'Due in ${difference}d';

    return 'Due ${dueDate.month}/${dueDate.day}';
  }

  Widget _buildTasksTab(TaskDatabase db) {
    return const TaskList();
  }

  Widget _buildAnalyticsTab(TaskDatabase db) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const HeatMapComponent(),
        const SizedBox(height: 16),

        // Additional analytics
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productivity Insights',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _buildInsightTile(
                  'Streak',
                  '${_calculateCurrentStreak(db.historicalCompletions, db.currentTasks)} days',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                _buildInsightTile(
                  'This Week',
                  '${_getThisWeekCompletions(db.historicalCompletions, db.currentTasks)} tasks',
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildInsightTile(
                  'Average per Day',
                  _getAveragePerDay(
                    db.historicalCompletions,
                    db.currentTasks,
                  ).toStringAsFixed(1),
                  Icons.trending_up,
                  Colors.green,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getWelcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning! Ready to tackle your tasks?';
    if (hour < 17) return 'Good afternoon! Keep up the momentum!';
    return 'Good evening! Time to wrap up your day.';
  }

  // ANALYTICS METHODS

  int _calculateCurrentStreak(List<DateTime> historical, List<Task> current) {
    final allCompletions = <DateTime>{};

    allCompletions.addAll(historical);

    for (final task in current) {
      allCompletions.addAll(task.completedDays);
    }

    if (allCompletions.isEmpty) return 0;

    final sortedDates =
        allCompletions
            .map((d) {
              final local = d.toLocal();
              return DateTime(local.year, local.month, local.day);
            })
            .toSet()
            .toList()
          ..sort();

    int streak = 0;
    final today = DateTime.now();
    var checkDate = DateTime(today.year, today.month, today.day);

    if (!sortedDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (sortedDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  int _getThisWeekCompletions(List<DateTime> historical, List<Task> current) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    int count = 0;

    count += historical.where((date) {
      final local = date.toLocal();
      final dayOnly = DateTime(local.year, local.month, local.day);
      return dayOnly.isAfter(weekStartDate.subtract(const Duration(days: 1)));
    }).length;

    for (final task in current) {
      count += task.completedDays.where((date) {
        final local = date.toLocal();
        final dayOnly = DateTime(local.year, local.month, local.day);
        return dayOnly.isAfter(weekStartDate.subtract(const Duration(days: 1)));
      }).length;
    }

    return count;
  }

  double _getAveragePerDay(List<DateTime> historical, List<Task> current) {
    final allCompletions = <DateTime>[];
    allCompletions.addAll(historical);

    for (final task in current) {
      allCompletions.addAll(task.completedDays);
    }

    if (allCompletions.isEmpty) return 0.0;

    DateTime earliestDate = allCompletions.first;
    for (final date in allCompletions) {
      if (date.isBefore(earliestDate)) {
        earliestDate = date;
      }
    }

    final daysSinceStart = DateTime.now().difference(earliestDate).inDays + 1;

    if (daysSinceStart <= 0) return 0.0;

    return allCompletions.length / daysSinceStart;
  }

  void _showTaskCreationDialog() {
    showDialog(
      context: context,
      builder: (context) => const TaskCreationDialog(),
    );
  }
}
