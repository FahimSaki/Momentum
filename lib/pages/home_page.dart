import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:momentum/blocs/notification_cubit.dart';
import 'package:momentum/blocs/session_cubit.dart';
import 'package:momentum/blocs/task_cubit.dart';
import 'package:momentum/blocs/task_state.dart';
import 'package:momentum/components/drawer.dart';
import 'package:momentum/components/dashboard_stats.dart';
import 'package:momentum/components/quick_invite_widget.dart';
import 'package:momentum/components/responsive_layout.dart';
import 'package:momentum/components/task_creation_dialog.dart';
import 'package:momentum/components/task_list.dart';
import 'package:momentum/components/task_map.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/pages/notifications_page.dart';
import 'package:momentum/pages/team_selection_page.dart';
import 'package:momentum/services/auth_service.dart';
import 'package:momentum/services/initialization_service.dart';
import 'package:momentum/utils/date_helpers.dart';

// Was TaskDatabase.currentUserRoleInSelectedTeam / .canCurrentUserCreateTasks.
// Plain functions since selectedTeam (TaskCubit) and userId (SessionCubit)
// live on two different cubits — same exact logic either way.
String? _currentUserRole(Team? selectedTeam, String? userId) {
  if (selectedTeam == null || userId == null) return null;
  final member = selectedTeam.getMember(userId);
  if (member != null) return member.role;
  if (selectedTeam.isOwner(userId)) return 'owner';
  return null;
}

bool _canCreateTasks(Team? selectedTeam, String? userId) {
  if (selectedTeam == null) return true;
  final role = _currentUserRole(selectedTeam, userId);
  return role == 'owner' || role == 'admin';
}

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final taskCubit = context.read<TaskCubit>();
      InitializationService.registerTaskCubit(taskCubit);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _ensureInitialized() async {
    final taskCubit = context.read<TaskCubit>();
    if (taskCubit.state.isInitialized || _initializationFailed) return;

    setState(() => _isInitializing = true);
    try {
      final authData = await AuthService.instance.getStoredAuthData();
      if (authData != null && mounted) {
        final tokenStatus = await AuthService.instance.validateToken();
        if (tokenStatus == TokenStatus.valid && mounted) {
          await taskCubit.initializeSession(
            jwt: authData['token'],
            userId: authData['userId'],
          );
        } else {
          if (mounted) {
            await AuthService.instance.logout();
            if (mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (r) => false);
            }
          }
          return;
        }
      } else {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _initializationFailed = true);
        await AuthService.instance.logout();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        }
        return;
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
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

        if (!state.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (r) => false);
            }
          });
          return const SizedBox.shrink();
        }

        final userId = context.watch<SessionCubit>().state.userId;
        final showFab = _canCreateTasks(state.selectedTeam, userId);

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: _buildAppBar(context, state),
          drawer: const MyDrawer(),
          floatingActionButton: showFab
              ? FloatingActionButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const TaskCreationDialog(),
                  ),
                  child: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.onTertiary,
                  ),
                )
              : null,
          body: Column(
            children: [
              if (state.isOffline) const _OfflineBanner(),
              _TabBar(controller: _tabController),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _DashboardTab(
                      onViewAllTasks: () => _tabController.animateTo(1),
                    ),
                    const TaskList(),
                    const _AnalyticsTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, TaskState state) {
    final unreadCount = context.watch<NotificationCubit>().state.unreadCount;
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeamSelectionPage()),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.selectedTeam != null ? Icons.group : Icons.person,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              state.selectedTeam?.name ?? 'Personal',
              style: const TextStyle(fontSize: 18),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              ),
            ),
            if (unreadCount > 0)
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
                    '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 8),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.swap_horiz),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeamSelectionPage()),
          ),
        ),
      ],
    );
  }
}

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 14,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 6),
          Text(
            'Offline — showing your last synced data',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        tabs: const [
          Tab(text: 'Dashboard'),
          Tab(text: 'Tasks'),
          Tab(text: 'Analytics'),
        ],
      ),
    );
  }
}

// ── Dashboard tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final VoidCallback onViewAllTasks;

  const _DashboardTab({required this.onViewAllTasks});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TaskCubit>().state;
    final taskCubit = context.read<TaskCubit>();
    final userId = context.watch<SessionCubit>().state.userId;

    return ResponsiveBody(
      child: RefreshIndicator(
        onRefresh: taskCubit.refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.selectedTeam != null
                          ? 'Team: ${state.selectedTeam!.name}'
                          : 'Personal Workspace',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _welcomeMessage(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.track_changes, size: 16),
                          label: Text('${state.activeTasks.length} active'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.done_all, size: 16),
                          label: Text(
                            '${state.completedTasks.length} completed',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (state.selectedTeam == null ||
                _canCreateTasks(state.selectedTeam, userId))
              const QuickInviteWidget(),
            if (state.selectedTeam == null ||
                _canCreateTasks(state.selectedTeam, userId))
              const SizedBox(height: 16),
            const DashboardStats(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                          onPressed: onViewAllTasks,
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...state.activeTasks
                        .take(3)
                        .map((task) => _TaskRow(task: task)),
                    if (state.activeTasks.isEmpty)
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
      ),
    );
  }

  String _welcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning! Ready to tackle your tasks?';
    if (hour < 17) return 'Good afternoon! Keep up the momentum!';
    return 'Good evening! Time to wrap up your day.';
  }
}

class _TaskRow extends StatefulWidget {
  final Task task;

  const _TaskRow({required this.task});

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _isToggling = false;

  Future<void> _toggle(bool complete) async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    try {
      final taskCubit = context.read<TaskCubit>();
      await taskCubit.completeTask(widget.task.id, complete);
      await taskCubit.refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(complete ? '✅ Task completed!' : '↩️ Task unmarked'),
            backgroundColor: complete ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isCompleted = task.isCompletedToday();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          leading: _isToggling
              ? const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Container(
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
              ? Text(DateHelpers.formatDueDate(task.dueDate!))
              : null,
          trailing: task.isPendingSync
              ? Icon(
                  Icons.cloud_off_rounded,
                  size: 18,
                  color: Colors.grey.shade500,
                )
              : task.isOverdue
              ? const Icon(Icons.warning, color: Colors.orange, size: 20)
              : task.isDueSoon
              ? const Icon(Icons.access_time, color: Colors.amber, size: 20)
              : null,
          onTap: _isToggling ? null : () => _toggle(!isCompleted),
        ),
      ),
    );
  }
}

// ── Analytics tab ─────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TaskCubit>().state;
    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HeatMapComponent(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Productivity Insights',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _InsightRow(
                    label: 'Streak',
                    value:
                        '${_streak(state.historicalCompletions, state.currentTasks)} days',
                    icon: Icons.local_fire_department,
                    color: Colors.orange,
                  ),
                  _InsightRow(
                    label: 'This Week',
                    value:
                        '${_thisWeek(state.historicalCompletions, state.currentTasks)} tasks',
                    icon: Icons.calendar_today,
                    color: Colors.blue,
                  ),
                  _InsightRow(
                    label: 'Average per Day',
                    value: _avgPerDay(
                      state.historicalCompletions,
                      state.currentTasks,
                    ).toStringAsFixed(1),
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _streak(List<DateTime> historical, List<Task> current) {
    final all = <DateTime>{};
    all.addAll(historical);
    for (final t in current) {
      all.addAll(t.completedDays);
    }
    if (all.isEmpty) return 0;
    final days =
        all
            .map((d) {
              final l = d.toLocal();
              return DateTime(l.year, l.month, l.day);
            })
            .toSet()
            .toList()
          ..sort();
    int streak = 0;
    final now = DateTime.now();
    var check = DateTime(now.year, now.month, now.day);
    if (!days.contains(check)) {
      check = check.subtract(const Duration(days: 1));
    }
    while (days.contains(check)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _thisWeek(List<DateTime> historical, List<Task> current) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    int count = 0;
    for (final d in historical) {
      final l = d.toLocal();
      if (!DateTime(l.year, l.month, l.day).isBefore(start)) count++;
    }
    for (final t in current) {
      for (final d in t.completedDays) {
        final l = d.toLocal();
        if (!DateTime(l.year, l.month, l.day).isBefore(start)) count++;
      }
    }
    return count;
  }

  double _avgPerDay(List<DateTime> historical, List<Task> current) {
    final all = [...historical, ...current.expand((t) => t.completedDays)];
    if (all.isEmpty) return 0;
    final earliest = all.reduce((a, b) => a.isBefore(b) ? a : b);
    final days = DateTime.now().difference(earliest).inDays + 1;
    return days > 0 ? all.length / days : 0;
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InsightRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
