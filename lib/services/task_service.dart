import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:momentum/constants/api_base_url.dart';
import 'package:momentum/models/task.dart';
import 'package:logger/logger.dart';

class TaskService {
  final Logger _logger = Logger();
  final String jwtToken;

  TaskService({required this.jwtToken});

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  };

  // ─────────────────────────────────────────────
  // COMPLETE / UNCOMPLETE TASK
  // ─────────────────────────────────────────────
  Future<Task> completeTask(String taskId, bool isCompleted) async {
    try {
      _logger.i(
        'Task ${isCompleted ? "complete" : "uncomplete"} request: $taskId',
      );

      final response = await http
          .patch(
            Uri.parse('$apiBaseUrl/tasks/$taskId/complete'),
            headers: _headers,
            body: json.encode({
              'isCompleted': isCompleted,
              'completedAt': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final taskData = (data is Map<String, dynamic>)
            ? (data['task'] ?? data['data'] ?? data)
            : data;

        final task = Task.fromJson(taskData);

        _logger.i('Task updated successfully: ${task.id}');
        return task;
      } else {
        _logger.e('Complete task failed: ${response.body}');
        throw Exception('Failed to update task');
      }
    } catch (e, stackTrace) {
      _logger.e('Error completing task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // GET USER TASKS (FIXED ROUTE)
  // ─────────────────────────────────────────────
  Future<List<Task>> getUserTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/tasks'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final List tasksData = (data is List)
            ? data
            : (data['tasks'] ?? data['data'] ?? []);

        return tasksData.map((t) => Task.fromJson(t)).toList();
      } else {
        _logger.e('Get tasks failed: ${response.body}');
        throw Exception('Failed to fetch tasks');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching tasks', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // CREATE TASK (NO userId anymore)
  // ─────────────────────────────────────────────
  Future<Task> createTask({
    required String name,
    String? description,
    List<String>? assignedTo,
    String? teamId,
    String priority = 'medium',
    DateTime? dueDate,
    List<String>? tags,
    String assignmentType = 'individual',
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'priority': priority,
        'assignmentType': assignmentType,
      };

      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }

      if (assignedTo != null && assignedTo.isNotEmpty) {
        body['assignedTo'] = assignedTo;
      }

      if (teamId != null && teamId.isNotEmpty) {
        body['teamId'] = teamId;
      }

      if (dueDate != null) {
        body['dueDate'] = dueDate.toIso8601String();
      }

      if (tags != null && tags.isNotEmpty) {
        body['tags'] = tags;
      }

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/tasks'),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        final taskData = (data is Map<String, dynamic>)
            ? (data['task'] ?? data)
            : data;

        return Task.fromJson(taskData);
      } else {
        _logger.e('Create task failed: ${response.body}');
        throw Exception('Failed to create task');
      }
    } catch (e, stackTrace) {
      _logger.e('Error creating task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // TEAM TASKS (UNCHANGED LOGIC, FIXED ROUTE ONLY)
  // ─────────────────────────────────────────────
  Future<List<Task>> getTeamTasks(String teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/tasks/team/$teamId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((t) => Task.fromJson(t)).toList();
      } else {
        throw Exception('Failed to fetch team tasks');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching team tasks', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // UPDATE TASK
  // ─────────────────────────────────────────────
  Future<Task> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/tasks/$taskId'),
        headers: _headers,
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final taskData = data['task'] ?? data;
        return Task.fromJson(taskData);
      } else {
        throw Exception('Failed to update task');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // DELETE TASK
  // ─────────────────────────────────────────────
  Future<void> deleteTask(String taskId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/tasks/$taskId'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete task');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // HISTORY (FIXED: NO userId)
  // ─────────────────────────────────────────────
  Future<List<DateTime>> getTaskHistory({String? teamId}) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/tasks/history');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final List<DateTime> results = [];

        for (final item in data) {
          final List days = item['completedDays'] ?? [];
          for (final d in days) {
            results.add(DateTime.parse(d).toLocal());
          }
        }

        return results;
      }

      return [];
    } catch (e, stackTrace) {
      _logger.e('Error fetching history', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // DASHBOARD STATS (FIXED ROUTE)
  // ─────────────────────────────────────────────
  Future<Map<String, int>> getDashboardStats({String? teamId}) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/tasks/dashboard-stats');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return {
          'totalTasks': data['totalTasks'] ?? 0,
          'completedToday': data['completedToday'] ?? 0,
          'overdueTasks': data['overdueTasks'] ?? 0,
          'upcomingTasks': data['upcomingTasks'] ?? 0,
        };
      }

      return {
        'totalTasks': 0,
        'completedToday': 0,
        'overdueTasks': 0,
        'upcomingTasks': 0,
      };
    } catch (e, stackTrace) {
      _logger.e(
        'Error fetching dashboard stats',
        error: e,
        stackTrace: stackTrace,
      );

      return {
        'totalTasks': 0,
        'completedToday': 0,
        'overdueTasks': 0,
        'upcomingTasks': 0,
      };
    }
  }
}
