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

  // 🔧 ENHANCED: Create task with full team support

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

      // Build request body more carefully
      final Map<String, dynamic> requestBody = {
        'name': name,
        'userId': userId, // Include userId for backend compatibility
      };

      // Only add non-null, non-empty values
      if (description != null && description.trim().isNotEmpty) {
        requestBody['description'] = description.trim();
      }

      if (assignedTo != null && assignedTo.isNotEmpty) {
        requestBody['assignedTo'] = assignedTo;
      }

      // 🔧 FIX: Only include teamId if it's not null and not empty
      if (teamId != null && teamId.isNotEmpty) {
        requestBody['teamId'] = teamId;
      }

      requestBody['priority'] = priority;
      requestBody['assignmentType'] = assignmentType;

      if (dueDate != null) {
        requestBody['dueDate'] = dueDate.toIso8601String();
      }

      if (tags != null && tags.isNotEmpty) {
        requestBody['tags'] = tags;
      }

      _logger.d('Request body: ${json.encode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/tasks'),
            headers: _headers,
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      _logger.i('Response status: ${response.statusCode}');
      _logger.d('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // 🔧 FIX: Handle different response formats more robustly
        Task task;

        if (data is Map<String, dynamic>) {
          if (data.containsKey('task')) {
            // Response format: { "message": "...", "task": {...} }
            task = Task.fromJson(data['task']);
          } else {
            // Response format: { task data directly }
            task = Task.fromJson(data);
          }
        } else if (data is List && data.isNotEmpty) {
          // Response format: [{ task data }]
          task = Task.fromJson(data[0]);
        } else {
          throw Exception('Unexpected response format from server');
        }

        _logger.i('Task created successfully: ${task.id}');
        return task;
      } else {
        // Enhanced error handling
        String errorMessage = 'Server error: ${response.statusCode}';

        try {
          final errorData = json.decode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          _logger.w('Could not parse error response: $e');
        }

        _logger.e('Task creation failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error in TaskService.createTask',
        error: e,
        stackTrace: stackTrace,
      );

      // 🔧 FIX: Better error categorization
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timed out - please try again');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error - check your connection');
      } else if (e.toString().contains('FormatException')) {
        throw Exception('Invalid server response');
      } else if (e.toString().contains('type ') &&
          e.toString().contains('is not a subtype')) {
        throw Exception('Data parsing error - please try again');
      }

      rethrow;
    }
  }

  // Get user tasks (both personal and team)
  Future<List<Task>> getUserTasks({String? teamId, String? type}) async {
    try {
      final queryParams = <String, String>{
        'userId': userId,
        if (teamId != null) 'teamId': teamId,
        if (type != null) 'type': type,
      };

      final uri = Uri.parse(
        '$apiBaseUrl/tasks/user',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final tasks = data.map((task) => Task.fromJson(task)).toList();
        _logger.i('Loaded ${tasks.length} user tasks');
        return tasks;
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
      final queryParams = {'status': status};
      final uri = Uri.parse(
        '$apiBaseUrl/tasks/team/$teamId',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final tasks = data.map((task) => Task.fromJson(task)).toList();
        _logger.i('Loaded ${tasks.length} team tasks');
        return tasks;
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
        Uri.parse('$apiBaseUrl/tasks/$taskId/complete'),
        headers: _headers,
        body: json.encode({'isCompleted': isCompleted}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final taskData = responseData['task'] ?? responseData;
        return Task.fromJson(taskData);
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
        Uri.parse('$apiBaseUrl/tasks/$taskId'),
        headers: _headers,
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final taskData = responseData['task'] ?? responseData;
        return Task.fromJson(taskData);
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
        Uri.parse('$apiBaseUrl/tasks/$taskId'),
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
      final queryParams = <String, String>{
        'userId': userId,
        if (teamId != null) 'teamId': teamId,
      };

      final uri = Uri.parse(
        '$apiBaseUrl/tasks/history',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final List<DateTime> allCompletions = [];

        _logger.i('Fetched ${data.length} task history records');

        for (final historyItem in data) {
          final List<dynamic> completedDays =
              historyItem['completedDays'] ?? [];
          for (final day in completedDays) {
            try {
              allCompletions.add(DateTime.parse(day).toLocal());
            } catch (e) {
              _logger.w('Failed to parse date: $day', error: e);
            }
          }
        }

        _logger.i(
          'Total historical completions loaded: ${allCompletions.length}',
        );
        return allCompletions;
      } else {
        _logger.w(
          'Error fetching task history (non-critical): ${response.statusCode}',
        );
        return []; // Return empty list on error
      }
    } catch (e, stackTrace) {
      _logger.w(
        'Error fetching task history (non-critical)',
        error: e,
        stackTrace: stackTrace,
      );
      return []; // Return empty list on error
    }
  }

  // Get dashboard stats
  Future<Map<String, int>> getDashboardStats({String? teamId}) async {
    try {
      final queryParams = <String, String>{
        if (teamId != null) 'teamId': teamId,
      };

      final uri = Uri.parse(
        '$apiBaseUrl/tasks/stats',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'totalTasks': (data['totalTasks'] ?? 0) as int,
          'completedToday': (data['completedToday'] ?? 0) as int,
          'overdueTasks': (data['overdueTasks'] ?? 0) as int,
          'upcomingTasks': (data['upcomingTasks'] ?? 0) as int,
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
