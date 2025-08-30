import 'package:flutter/material.dart';
import 'package:momentum/database/task_database.dart';
import 'package:provider/provider.dart';

class DashboardStats extends StatelessWidget {
  const DashboardStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedTaskDatabase>(
      builder: (context, db, _) {
        return FutureBuilder<Map<String, int>>(
          future: db.getDashboardStats(),
          builder: (context, snapshot) {
            final stats =
                snapshot.data ??
                {
                  'totalTasks': 0,
                  'completedToday': 0,
                  'overdueTasks': 0,
                  'upcomingTasks': 0,
                };

            return Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Active',
                    value: '${stats['totalTasks']}',
                    icon: Icons.assignment,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Completed',
                    value: '${stats['completedToday']}',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Overdue',
                    value: '${stats['overdueTasks']}',
                    icon: Icons.warning,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Upcoming',
                    value: '${stats['upcomingTasks']}',
                    icon: Icons.schedule,
                    color: Colors.orange,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
