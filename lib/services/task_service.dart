import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:momentum/constants/api_base_url.dart';
import 'package:momentum/models/task.dart';
import 'package:logger/logger.dart';

class TaskService {
  final Logger _logger = Logger();
  final String jwtToken;
  final String userId;

  TaskService({required this.jwtToken, required this.userId});

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  };

  // Fixed createTask method in TaskService class
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
      _logger.i(
        'TaskService.createTask called with: name=$name, teamId=$teamId',
      );

      // Build request body carefully
      final Map<String, dynamic> requestBody = {
        'name': name,
        'userId': userId, // Add userId to the request
      };

      // Only add non-null values to avoid backend issues
      if (description != null && description.isNotEmpty) {
        requestBody['description'] = description;
      }

      if (assignedTo != null && assignedTo.isNotEmpty) {
        requestBody['assignedTo'] = assignedTo;
      }

      if (teamId != null && teamId.isNotEmpty) {
        requestBody['teamId'] = teamId;
      }

      requestBody['priority'] = priority;
      requestBody['assignmentType'] = assignmentType;

      if (dueDate != null) {
        requestBody['dueDate'] = dueDate.toIso8601String();
      }

      if (tags != null) {
        requestBody['tags'] = tags;
      }

      _logger.i('Request body: ${json.encode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/tasks'), // Try the basic endpoint first
            headers: _headers,
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15)); // Add timeout

      _logger.i('Response status: ${response.statusCode}');
      _logger.i('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // Handle different response formats
        Task task;
        if (data['task'] != null) {
          task = Task.fromJson(data['task']);
        } else if (data is List && data.isNotEmpty) {
          task = Task.fromJson(data[0]);
        } else {
          task = Task.fromJson(data);
        }

        _logger.i('Task created successfully: ${task.id}');
        return task;
      } else {
        final errorBody = response.body;
        _logger.e('Task creation failed: ${response.statusCode} - $errorBody');

        // Try to parse error message from response
        try {
          final errorData = json.decode(errorBody);
          final errorMessage =
              errorData['message'] ??
              errorData['error'] ??
              'Unknown server error';
          throw Exception(errorMessage);
        } catch (_) {
          throw Exception('Server error: ${response.statusCode}');
        }
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error in TaskService.createTask',
        error: e,
        stackTrace: stackTrace,
      );

      if (e.toString().contains('TimeoutException')) {
        throw Exception(
          'Request timed out. Please check your connection and try again.',
        );
      } else if (e.toString().contains('SocketException')) {
        throw Exception(
          'Network error. Please check your internet connection.',
        );
      } else if (e.toString().contains('FormatException')) {
        throw Exception('Invalid server response. Please try again.');
      }

      rethrow;
    }
  }

  // Get user tasks (personal + team)
  Future<List<Task>> getUserTasks({String? teamId, String type = 'all'}) async {
    try {
      final queryParams = {
        'userId': userId,
        'type': type,
        if (teamId != null) 'teamId': teamId,
      };

      final uri = Uri.parse(
        '$apiBaseUrl/tasks-enhanced/user',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((task) => Task.fromJson(task)).toList();
      } else {
        _logger.e('Error fetching user tasks: ${response.body}');
        throw Exception('Failed to fetch tasks');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching user tasks', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Get team tasks
  Future<List<Task>> getTeamTasks(
    String teamId, {
    String status = 'active',
  }) async {
    try {
      final uri = Uri.parse(
        '$apiBaseUrl/tasks-enhanced/team/$teamId',
      ).replace(queryParameters: {'status': status});

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((task) => Task.fromJson(task)).toList();
      } else {
        _logger.e('Error fetching team tasks: ${response.body}');
        throw Exception('Failed to fetch team tasks');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching team tasks', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Complete/uncomplete task
  Future<Task> completeTask(String taskId, bool isCompleted) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/tasks-enhanced/$taskId/complete'),
        headers: _headers,
        body: json.encode({'isCompleted': isCompleted}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Task.fromJson(data['task']);
      } else {
        _logger.e('Error completing task: ${response.body}');
        throw Exception('Failed to complete task');
      }
    } catch (e, stackTrace) {
      _logger.e('Error completing task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Update task
  Future<Task> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/tasks-enhanced/$taskId'),
        headers: _headers,
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Task.fromJson(data['task']);
      } else {
        _logger.e('Error updating task: ${response.body}');
        throw Exception('Failed to update task');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Delete task
  Future<void> deleteTask(String taskId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/tasks-enhanced/$taskId'),
        headers: _headers,
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

  // Get task history
  Future<List<DateTime>> getTaskHistory({String? teamId}) async {
    try {
      final queryParams = {
        'userId': userId,
        if (teamId != null) 'teamId': teamId,
      };

      final uri = Uri.parse(
        '$apiBaseUrl/tasks-enhanced/history',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final List<DateTime> allCompletions = [];

        for (final historyItem in data) {
          final List<dynamic> completedDays =
              historyItem['completedDays'] ?? [];
          for (final day in completedDays) {
            try {
              allCompletions.add(DateTime.parse(day));
            } catch (e) {
              _logger.w('Failed to parse date: $day', error: e);
            }
          }
        }

        return allCompletions;
      } else {
        _logger.w(
          'Error fetching task history (non-critical): ${response.statusCode}',
        );
        return [];
      }
    } catch (e, stackTrace) {
      _logger.w(
        'Error fetching task history (non-critical)',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Get dashboard stats
  Future<Map<String, int>> getDashboardStats({String? teamId}) async {
    try {
      final queryParams = <String, String>{};
      if (teamId != null) queryParams['teamId'] = teamId;

      final uri = Uri.parse(
        '$apiBaseUrl/tasks-enhanced/stats',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'totalTasks': data['totalTasks'] ?? 0,
          'completedToday': data['completedToday'] ?? 0,
          'overdueTasks': data['overdueTasks'] ?? 0,
          'upcomingTasks': data['upcomingTasks'] ?? 0,
        };
      } else {
        _logger.e('Error fetching dashboard stats: ${response.body}');
        return {
          'totalTasks': 0,
          'completedToday': 0,
          'overdueTasks': 0,
          'upcomingTasks': 0,
        };
      }
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
