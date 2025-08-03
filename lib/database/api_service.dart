// File: lib/services/habit_api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:habit_tracker/constants/api_base_url.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:logger/logger.dart';

class HabitApiService {
  final Logger _logger = Logger();
  final String jwtToken;
  final String userId;

  HabitApiService({required this.jwtToken, required this.userId});

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      };

  Future<List<Habit>> fetchHabits() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/habits/assigned?userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((habit) => Habit.fromJson(habit)).toList();
      } else {
        _logger.e('Error fetching habits: ${response.body}');
        throw Exception('Failed to fetch habits');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching habits', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<DateTime>> fetchHistoricalCompletions() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/habit-history?userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final List<DateTime> allCompletions = [];

        for (final historyItem in data) {
          final List<dynamic> completedDays =
              historyItem['completedDays'] ?? [];
          for (final day in completedDays) {
            allCompletions.add(DateTime.parse(day));
          }
        }

        return allCompletions;
      } else {
        _logger
            .w('Error fetching habit history (non-critical): ${response.body}');
        return []; // Return empty list if history endpoint fails
      }
    } catch (e, stackTrace) {
      _logger.w('Error fetching habit history (non-critical)',
          error: e, stackTrace: stackTrace);
      return []; // Return empty list on error
    }
  }

  Future<void> createHabit(String habitName) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/habits'),
        headers: _headers,
        body: json.encode({'name': habitName, 'userId': userId}),
      );
      if (response.statusCode != 200) {
        _logger.e('Error adding habit: ${response.body}');
        throw Exception('Failed to create habit');
      }
    } catch (e, stackTrace) {
      _logger.e('Error adding habit', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateHabit(String id, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/habits/$id'),
        headers: _headers,
        body: json.encode(updates),
      );
      if (response.statusCode != 200) {
        _logger.e('Error updating habit: ${response.body}');
        throw Exception('Failed to update habit');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating habit', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/habits/$id'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode != 200) {
        _logger.e('Error deleting habit: ${response.body}');
        throw Exception('Failed to delete habit');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting habit', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> removeYesterdayCompletions() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/habits/remove-yesterday-completions'),
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

  Future<void> deleteCompletedHabits() async {
    try {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final response = await http.delete(
        Uri.parse(
            '$apiBaseUrl/habits/completed?before=${yesterday.toIso8601String()}&userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode != 200) {
        _logger.e('Error deleting completed habits: ${response.body}');
        throw Exception('Failed to delete completed habits');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting completed habits',
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
