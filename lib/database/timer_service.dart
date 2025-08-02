import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

class TimerService {
  Timer? _pollingTimer;
  Timer? _midnightTimer;
  final Future<void> Function() onPollingTick;
  final Future<void> Function() onMidnightCleanup;

  TimerService({
    required this.onPollingTick,
    required this.onMidnightCleanup,
  });

  void startPolling() {
    if (kIsWeb) return;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await onPollingTick();
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
