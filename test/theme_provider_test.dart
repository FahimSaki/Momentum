import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to light mode when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await pumpEventQueue();

    expect(provider.isDarkMode, isFalse);
  });

  test('restores a saved dark mode preference', () async {
    SharedPreferences.setMockInitialValues({'isDarkMode': true});
    final provider = ThemeProvider();
    await pumpEventQueue();

    expect(provider.isDarkMode, isTrue);
  });

  test(
    'toggleTheme flips the theme, notifies listeners and saves it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      await pumpEventQueue();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.toggleTheme();
      await pumpEventQueue();

      expect(provider.isDarkMode, isTrue);
      expect(notifications, 1);
      expect(
        (await SharedPreferences.getInstance()).getBool('isDarkMode'),
        isTrue,
      );

      provider.toggleTheme();
      await pumpEventQueue();

      expect(provider.isDarkMode, isFalse);
      expect(notifications, 2);
      expect(
        (await SharedPreferences.getInstance()).getBool('isDarkMode'),
        isFalse,
      );
    },
  );
}
