import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:momentum/theme/theme.dart';

class ThemeProvider with ChangeNotifier {
  // initially theme is light mode
  ThemeData _themeData = lightMode;

  // getter method to access the theme from main.dart ThemeProvider
  ThemeData get themeData => _themeData;

  // getter method if dark mode is on
  bool get isDarkMode => _themeData == darkMode;

  ThemeProvider() {
    _loadTheme();
  }

  // load the saved theme from shared preferences
  Future<void> _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDark = prefs.getBool('isDarkMode') ?? false;
    _themeData = isDark ? darkMode : lightMode;
    notifyListeners();
  }

  // save the theme to shared preferences
  Future<void> _saveTheme(bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDarkMode);
  }

  // setter method to set the new theme
  set themeData(ThemeData themeData) {
    _themeData = themeData;
    _saveTheme(_themeData == darkMode);
    notifyListeners();
  }

  // toggle theme switch method
  void toggleTheme() {
    if (_themeData == lightMode) {
      themeData = darkMode;
    } else {
      themeData = lightMode;
    }
  }
}
