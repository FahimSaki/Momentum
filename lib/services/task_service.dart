// lib/services/task_service.dart - FIXED COMPLETION METHOD

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

  Future<Task> completeTask(String taskId, bool isCompleted) async {
    try {
      _logger.i(
        'Attempting to ${isCompleted ? 'complete' : 'uncomplete'} task: $taskId',
      );

      final requestBody = {
        'userId': userId,
        'isCompleted': isCompleted,
        'completedAt': DateTime.now()
            .toIso8601String(), // Send current timestamp
      };

      _logger.d('Task completion request body: ${json.encode(requestBody)}');

      final response = await http
          .put(
            Uri.parse('$apiBaseUrl/tasks/$taskId/complete'),
            headers: _headers,
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      _logger.i('Task completion response status: ${response.statusCode}');
      _logger.d('Task completion response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle different response formats from backend
        Map<String, dynamic> taskData;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('task')) {
            taskData = responseData['task'];
          } else if (responseData.containsKey('data')) {
            taskData = responseData['data'];
          } else {
            taskData = responseData;
          }
        } else {
          throw Exception('Unexpected response format from server');
        }

        final updatedTask = Task.fromJson(taskData);
        _logger.i(
          'Task ${isCompleted ? 'completed' : 'uncompleted'} successfully: ${updatedTask.id}',
        );
        return updatedTask;
      } else {
        String errorMessage =
            'Failed to ${isCompleted ? 'complete' : 'uncomplete'} task';

        try {
          final errorData = json.decode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          _logger.w('Could not parse error response: $e');
        }

        _logger.e('Task completion failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      _logger.e('Error completing task', error: e, stackTrace: stackTrace);

      // Better error handling
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timed out - please try again');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error - check your connection');
      }

      rethrow;
    }
  }

  // Get user tasks with better filtering
  Future<List<Task>> getUserTasks({String? teamId, String? type}) async {
    try {
      final queryParams = <String, String>{
        'userId': userId,
        if (teamId != null) 'teamId': teamId,
        if (type != null) 'type': type,
      };

      final uri = Uri.parse(
        '$apiBaseUrl/tasks/assigned',
      ).replace(queryParameters: queryParams);

      _logger.d('Fetching tasks from: $uri');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        // Handle different response formats
        List<dynamic> tasksData;
        if (responseBody is List) {
          tasksData = responseBody;
        } else if (responseBody is Map && responseBody.containsKey('tasks')) {
          tasksData = responseBody['tasks'] ?? [];
        } else if (responseBody is Map && responseBody.containsKey('data')) {
          tasksData = responseBody['data'] ?? [];
        } else {
          _logger.w('Unexpected response format: $responseBody');
          tasksData = [];
        }

        final tasks = tasksData.map((task) => Task.fromJson(task)).toList();
        _logger.i('Loaded ${tasks.length} user tasks');
        return tasks;
      } else {
        _logger.e(
          'Error fetching user tasks: ${response.statusCode} - ${response.body}',
        );
        throw Exception('Failed to fetch tasks: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching user tasks', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Keep all other methods from your original TaskService...
  // (createTask, getTeamTasks, updateTask, deleteTask, etc.)

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

      final Map<String, dynamic> requestBody = {'name': name, 'userId': userId};

      if (description != null && description.trim().isNotEmpty) {
        requestBody['description'] = description.trim();
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

        Task task;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('task')) {
            task = Task.fromJson(data['task']);
          } else {
            task = Task.fromJson(data);
          }
        } else if (data is List && data.isNotEmpty) {
          task = Task.fromJson(data[0]);
        } else {
          throw Exception('Unexpected response format from server');
        }

        _logger.i('Task created successfully: ${task.id}');
        return task;
      } else {
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

      if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timed out - please try again');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error - check your connection');
      } else if (e.toString().contains('FormatException')) {
        throw Exception('Invalid server response');
      }

      rethrow;
    }
  }

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
