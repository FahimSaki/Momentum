import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:momentum/models/pending_task_create.dart';

/// Persists personal-task creations that failed because the device was
/// offline. Team tasks are never queued here — they need server-side
/// membership/permission checks that can't be done offline.
class SyncQueueService {
  final Logger _logger = Logger();
  static const _key = 'sync_queue_pending_task_creates';

  Future<List<PendingTaskCreate>> getPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final List data = jsonDecode(raw);
      return data.map((j) => PendingTaskCreate.fromJson(j)).toList();
    } catch (e, st) {
      _logger.w('Failed to read sync queue', error: e, stackTrace: st);
      return [];
    }
  }

  Future<void> enqueue(PendingTaskCreate operation) async {
    try {
      final ops = await getPending();
      ops.add(operation);
      await _save(ops);
    } catch (e, st) {
      _logger.w('Failed to enqueue sync operation', error: e, stackTrace: st);
    }
  }

  Future<void> remove(String localId) async {
    try {
      final ops = await getPending();
      ops.removeWhere((o) => o.localId == localId);
      await _save(ops);
    } catch (e, st) {
      _logger.w('Failed to remove sync operation', error: e, stackTrace: st);
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e, st) {
      _logger.w('Failed to clear sync queue', error: e, stackTrace: st);
    }
  }

  Future<void> _save(List<PendingTaskCreate> ops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(ops.map((o) => o.toJson()).toList()),
    );
  }
}
