import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:habit_tracker/services/realtime_service.dart';

final _logger = Logger();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      _logger.d('Background task started: $taskName');

      if (taskName == 'syncHabits') {
        await Supabase.initialize(
          url: const String.fromEnvironment('SUPABASE_URL'),
          ***REMOVED*** const String.fromEnvironment('SUPABASE_ANON_KEY'),
        );

        final realtimeService = RealtimeService();
        await realtimeService.init();

        _logger.d('Background sync completed successfully');
        return true;
      }

      _logger.w('Unknown task: $taskName');
      return false;
    } catch (e, stack) {
      _logger.e('Background task error', error: e, stackTrace: stack);
      return false;
    }
  });
}
