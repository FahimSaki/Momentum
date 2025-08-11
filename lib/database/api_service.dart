import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:momentum/constants/api_base_url.dart';
import 'package:momentum/models/task.dart';
import 'package:logger/logger.dart';

class TaskApiService {
  final Logger _logger = Logger();
  final String jwtToken;
  final String userId;

  TaskApiService({required this.jwtToken, required this.userId});

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      };

  Future<List<Task>> fetchTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/tasks/assigned?userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
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

  Future<List<DateTime>> fetchHistoricalCompletions() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/tasks/history?userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final List<DateTime> allCompletions = [];

        _logger.i('Fetched ${data.length} task history records');

        for (final historyItem in data) {
          final List<dynamic> completedDays =
              historyItem['completedDays'] ?? [];
          _logger.d(
              'Processing history item: ${historyItem['taskName']} with ${completedDays.length} completions');

          for (final day in completedDays) {
            try {
              allCompletions.add(DateTime.parse(day));
            } catch (e) {
              _logger.w('Failed to parse date: $day', error: e);
            }
          }
        }

        _logger
            .i('Total historical completions loaded: ${allCompletions.length}');
        return allCompletions;
      } else {
        _logger.w(
            'Error fetching task history (non-critical): ${response.statusCode} - ${response.body}');
        return []; // Return empty list if history endpoint fails
      }
    } catch (e, stackTrace) {
      _logger.w('Error fetching task history (non-critical)',
          error: e, stackTrace: stackTrace);
      return []; // Return empty list on error
    }
  }

  Future<void> createTask(String taskName) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/tasks'),
        headers: _headers,
        body: json.encode({'name': taskName, 'userId': userId}),
      );
      if (response.statusCode != 200) {
        _logger.e('Error adding task: ${response.body}');
        throw Exception('Failed to create task');
      }
    } catch (e, stackTrace) {
      _logger.e('Error adding task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateTask(String id, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/tasks/$id'),
        headers: _headers,
        body: json.encode(updates),
      );
      if (response.statusCode != 200) {
        _logger.e('Error updating task: ${response.body}');
        throw Exception('Failed to update task');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/tasks/$id'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode != 200) {
        _logger.e('Error deleting task: ${response.body}');
        throw Exception('Failed to delete task');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> removeYesterdayCompletions() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/tasks/remove-yesterday-completions'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        _logger.e('Error removing yesterday completions: ${response.body}');
        throw Exception('Failed to remove yesterday completions');
      }
    } catch (e, stackTrace) {
      _logger.e('Error removing yesterday completions',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteCompletedTasks() async {
    try {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);

      _logger
          .i('Deleting completed tasks before: ${yesterday.toIso8601String()}');

      final response = await http.delete(
        Uri.parse(
            '$apiBaseUrl/tasks/completed?before=${yesterday.toIso8601String()}&userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _logger
            .i('Delete completed tasks response: ${responseData['message']}');
      } else {
        _logger.e(
            'Error deleting completed tasks: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to delete completed tasks');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting completed tasks',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<DateTime?> getFirstLaunchDate() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/app_settings/first_launch_date?userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DateTime.parse(data['first_launch_date']);
      }
    } catch (e) {
      _logger.e('Error getting first launch date', error: e);
    }
    return null;
  }

  Future<void> setFirstLaunchDate(DateTime date) async {
    try {
      await http.post(
        Uri.parse('$apiBaseUrl/app_settings/first_launch_date'),
        headers: _headers,
        body: json.encode(
            {'first_launch_date': date.toIso8601String(), 'userId': userId}),
      );
    } catch (e) {
      _logger.e('Error setting first launch date', error: e);
    }
  }
}
