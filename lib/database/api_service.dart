import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:momentum/constants/api_base_url.dart';
import 'package:momentum/models/task.dart';
import 'package:logger/logger.dart';

class TaskApiService {
  final Logger _logger = Logger();
  final String jwtToken;

  TaskApiService({required this.jwtToken});

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  };

  // ─────────────────────────────────────────────
  // GET TASKS (replaces /assigned + /user)
  // ─────────────────────────────────────────────
  Future<List<Task>> fetchTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/tasks'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((task) => Task.fromJson(task)).toList();
      } else {
        _logger.e('Error fetching tasks: ${response.body}');
        throw Exception('Failed to fetch tasks');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching tasks', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // HISTORY
  // ─────────────────────────────────────────────
  Future<List<DateTime>> fetchHistoricalCompletions() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/tasks/history'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final List<DateTime> allCompletions = [];

        for (final historyItem in data) {
          final List<dynamic> completedDays =
              historyItem['completedDays'] ?? [];

          for (final day in completedDays) {
            try {
              allCompletions.add(DateTime.parse(day).toLocal());
            } catch (_) {}
          }
        }

        return allCompletions;
      } else {
        _logger.w('Task history failed: ${response.body}');
        return [];
      }
    } catch (e) {
      _logger.w('Task history error', error: e);
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // CREATE TASK (NO userId anymore)
  // ─────────────────────────────────────────────
  Future<void> createTask(String taskName) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/tasks'),
        headers: _headers,
        body: json.encode({'name': taskName}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create task');
      }
    } catch (e) {
      _logger.e('Create task error', error: e);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // UPDATE TASK
  // ─────────────────────────────────────────────
  Future<void> updateTask(String id, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/tasks/$id'),
        headers: _headers,
        body: json.encode(updates),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update task');
      }
    } catch (e) {
      _logger.e('Update task error', error: e);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // DELETE TASK
  // ─────────────────────────────────────────────
  Future<void> deleteTask(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/tasks/$id'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete task');
      }
    } catch (e) {
      _logger.e('Delete task error', error: e);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // COMPLETE TASK (NEW: PATCH route)
  // ─────────────────────────────────────────────
  Future<void> completeTask(String id) async {
    try {
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/tasks/$id/complete'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to complete task');
      }
    } catch (e) {
      _logger.e('Complete task error', error: e);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // REMOVE UNUSED ENDPOINTS (NOT IN TS BACKEND)
  // ─────────────────────────────────────────────
  // ❌ removed:
  // - removeYesterdayCompletions
  // - deleteCompletedTasks
}
