import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

class TimerService {
  Timer? _pollingTimer;
  Timer? _midnightTimer;
  bool _isTicking = false;
  final Future<void> Function() onPollingTick;
  final Future<void> Function() onMidnightCleanup;

  TimerService({required this.onPollingTick, required this.onMidnightCleanup});

  void startPolling() {
    if (kIsWeb) return;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      // Skip this tick if the previous one is still running (e.g. the
      // backend was slow to wake up right after reconnecting). Two ticks
      // overlapping meant two independent refresh cycles could both try to
      // flush the same queued offline task at once.
      if (_isTicking) return;
      _isTicking = true;
      try {
        await onPollingTick();
      } finally {
        _isTicking = false;
      }
    });
  }

  void scheduleMidnightCleanup() {
    if (kIsWeb) return;

    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now);

    _midnightTimer = Timer(duration, () async {
      await onMidnightCleanup();
      scheduleMidnightCleanup();
    });
  }

  void dispose() {
    _pollingTimer?.cancel();
    _midnightTimer?.cancel();
  }
}
