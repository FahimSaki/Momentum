import 'package:flutter/material.dart';

const Color _kIndigo = Color(0xFF6366F1);
const Color _kIndigoDark = Color(0xFF818CF8);

// * light mode
ThemeData lightMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    surface: Color(0xFFF5F3FF),
    primary: Color(0xFFFFFFFF),
    secondary: Color(0xFFEDE9FE),
    tertiary: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFF1C1B3A),
    primaryContainer: Color(0xFF6366F1),
    secondaryContainer: Color(0xFFDDD6FE),
    onPrimary: Color(0xFF1C1B3A),
    onSecondary: Color(0xFF1C1B3A),
    onSurface: Color(0xFF1C1B3A),
    error: Color(0xFFE53E3E),
    onError: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF5F3FF),
    foregroundColor: Color(0xFF1C1B3A),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: Color(0xFF1C1B3A),
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFEDE9FE), width: 1),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _kIndigo,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _kIndigo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _kIndigo,
      side: const BorderSide(color: Color(0xFFDDD6FE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF5F3FF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDDD6FE)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDDD6FE)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kIndigo, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE53E3E)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: const TextStyle(color: Color(0xFF6B66A3)),
    hintStyle: const TextStyle(color: Color(0xFFB0ADDB)),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return const Color(0xFFBBB8D4);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _kIndigo;
      return const Color(0xFFEDE9FE);
    }),
    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _kIndigo;
      return Colors.transparent;
    }),
    checkColor: WidgetStateProperty.all(Colors.white),
    side: const BorderSide(color: Color(0xFFB0ADDB), width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: _kIndigo,
    foregroundColor: Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFFEDE9FE),
    thickness: 1,
    space: 1,
  ),
  listTileTheme: const ListTileThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: Color(0xFFF5F3FF),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topRight: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF1C1B3A),
    contentTextStyle: const TextStyle(color: Colors.white),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFEDE9FE),
    labelStyle: const TextStyle(color: Color(0xFF1C1B3A), fontSize: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    side: BorderSide.none,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: Colors.white,
    elevation: 8,
    shadowColor: const Color(0x1A6366F1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  expansionTileTheme: const ExpansionTileThemeData(
    backgroundColor: Colors.transparent,
    collapsedBackgroundColor: Colors.transparent,
    iconColor: Color(0xFF6366F1),
    collapsedIconColor: Color(0xFF6B66A3),
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: _kIndigo,
    unselectedLabelColor: Color(0xFF6B66A3),
    indicatorColor: _kIndigo,
    dividerColor: Color(0xFFEDE9FE),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: _kIndigo),
  scaffoldBackgroundColor: const Color(0xFFF5F3FF),
);

// * dark mode
ThemeData darkMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    surface: Color(0xFF0E0D1C),
    primary: Color(0xFF1A1929),
    secondary: Color(0xFF232236),
    tertiary: Color(0xFF2D2C44),
    inversePrimary: Color(0xFFE8E6FF),
    primaryContainer: Color(0xFF7C79F0),
    secondaryContainer: Color(0xFF2A2845),
    onPrimary: Color(0xFFE8E6FF),
    onSecondary: Color(0xFFE8E6FF),
    onSurface: Color(0xFFE8E6FF),
    error: Color(0xFFFC8181),
    onError: Color(0xFF1C1B3A),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0E0D1C),
    foregroundColor: Color(0xFFE8E6FF),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: Color(0xFFE8E6FF),
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF1A1929),
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF2D2C44), width: 1),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _kIndigoDark,
      foregroundColor: const Color(0xFF0E0D1C),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _kIndigoDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _kIndigoDark,
      side: const BorderSide(color: Color(0xFF3D3B5C)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF232236),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2D2C44)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2D2C44)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kIndigoDark, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFFC8181)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: const TextStyle(color: Color(0xFF9B99C8)),
    hintStyle: const TextStyle(color: Color(0xFF5A587A)),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return const Color(0xFF5A587A);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _kIndigoDark;
      return const Color(0xFF232236);
    }),
    trackOutlineColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.transparent;
      return const Color(0xFF3D3B5C);
    }),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _kIndigoDark;
      return Colors.transparent;
    }),
    checkColor: WidgetStateProperty.all(const Color(0xFF0E0D1C)),
    side: const BorderSide(color: Color(0xFF5A587A), width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF7C79F0),
    foregroundColor: Color(0xFF0E0D1C),
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFF2D2C44),
    thickness: 1,
    space: 1,
  ),
  listTileTheme: const ListTileThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: Color(0xFF0E0D1C),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topRight: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF2D2C44),
    contentTextStyle: const TextStyle(color: Color(0xFFE8E6FF)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFF232236),
    labelStyle: const TextStyle(color: Color(0xFFE8E6FF), fontSize: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    side: BorderSide.none,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: const Color(0xFF1A1929),
    elevation: 8,
    shadowColor: Colors.black45,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFF2D2C44)),
    ),
  ),
  expansionTileTheme: const ExpansionTileThemeData(
    backgroundColor: Colors.transparent,
    collapsedBackgroundColor: Colors.transparent,
    iconColor: Color(0xFF818CF8),
    collapsedIconColor: Color(0xFF9B99C8),
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: _kIndigoDark,
    unselectedLabelColor: Color(0xFF9B99C8),
    indicatorColor: _kIndigoDark,
    dividerColor: Color(0xFF2D2C44),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: _kIndigoDark),
  scaffoldBackgroundColor: const Color(0xFF0E0D1C),
);
