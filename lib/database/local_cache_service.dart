import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';

/// Caches the last-known state of tasks, teams, historical completions,
/// and dashboard stats to disk so the app has something to show when
/// there's no connection. The backend is always the source of truth —
/// every key here gets overwritten the moment a fresh load succeeds.
class LocalCacheService {
  final Logger _logger = Logger();

  static const _tasksPrefix = 'cache_tasks_';
  static const _historyPrefix = 'cache_history_';
  static const _statsPrefix = 'cache_stats_';
  static const _teamsKey = 'cache_teams';

  String _scope(String? teamId) => teamId ?? 'personal';

  // ── Tasks ──────────────────────────────────────────────────────────────

  Future<void> saveTasks(String? teamId, List<Task> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_tasksPrefix${_scope(teamId)}',
        jsonEncode(tasks.map((t) => t.toJson()).toList()),
      );
    } catch (e, st) {
      _logger.w('Failed to cache tasks', error: e, stackTrace: st);
    }
  }

  Future<List<Task>> loadTasks(String? teamId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_tasksPrefix${_scope(teamId)}');
      if (raw == null || raw.isEmpty) return [];
      final List data = jsonDecode(raw);
      return data.map((j) => Task.fromJson(j)).toList();
    } catch (e, st) {
      _logger.w('Failed to load cached tasks', error: e, stackTrace: st);
      return [];
    }
  }

  // ── Teams ──────────────────────────────────────────────────────────────

  Future<void> saveTeams(List<Team> teams) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _teamsKey,
        jsonEncode(teams.map((t) => t.toJson()).toList()),
      );
    } catch (e, st) {
      _logger.w('Failed to cache teams', error: e, stackTrace: st);
    }
  }

  Future<List<Team>> loadTeams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_teamsKey);
      if (raw == null || raw.isEmpty) return [];
      final List data = jsonDecode(raw);
      return data.map((j) => Team.fromJson(j)).toList();
    } catch (e, st) {
      _logger.w('Failed to load cached teams', error: e, stackTrace: st);
      return [];
    }
  }

  // ── Historical completions ────────────────────────────────────────────

  Future<void> saveHistoricalCompletions(
    String? teamId,
    List<DateTime> dates,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_historyPrefix${_scope(teamId)}',
        jsonEncode(dates.map((d) => d.toIso8601String()).toList()),
      );
    } catch (e, st) {
      _logger.w(
        'Failed to cache historical completions',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<List<DateTime>> loadHistoricalCompletions(String? teamId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_historyPrefix${_scope(teamId)}');
      if (raw == null || raw.isEmpty) return [];
      final List data = jsonDecode(raw);
      return data.map((d) => DateTime.parse(d).toLocal()).toList();
    } catch (e, st) {
      _logger.w(
        'Failed to load cached historical completions',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // ── Dashboard stats ───────────────────────────────────────────────────

  Future<void> saveDashboardStats(
    String? teamId,
    Map<String, int> stats,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_statsPrefix${_scope(teamId)}',
        jsonEncode(stats),
      );
    } catch (e, st) {
      _logger.w('Failed to cache dashboard stats', error: e, stackTrace: st);
    }
  }

  Future<Map<String, int>?> loadDashboardStats(String? teamId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_statsPrefix${_scope(teamId)}');
      if (raw == null || raw.isEmpty) return null;
      final Map data = jsonDecode(raw);
      return data.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (e, st) {
      _logger.w(
        'Failed to load cached dashboard stats',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────

  /// Clears every cache key this service owns. Call on logout so the next
  /// account signed in on this device doesn't briefly see stale data.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (k) =>
            k.startsWith(_tasksPrefix) ||
            k.startsWith(_historyPrefix) ||
            k.startsWith(_statsPrefix) ||
            k == _teamsKey,
      );
      for (final key in keys.toList()) {
        await prefs.remove(key);
      }
    } catch (e, st) {
      _logger.w('Failed to clear cache', error: e, stackTrace: st);
    }
  }
}
