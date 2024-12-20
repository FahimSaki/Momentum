import 'package:flutter/material.dart';

// light mode
ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    surface: Colors.grey.shade300,
    primary: Colors.grey.shade500,
    secondary: Colors.grey.shade200,
    tertiary: Colors.white,
    inversePrimary: Colors.grey.shade900,
  ),
);

// dark mode

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    // surface: const Color.fromARGB(255, 24, 24, 24),
    surface: Colors.grey.shade900,
    // primary: const Color.fromARGB(255, 34, 34, 34),
    primary: Colors.grey.shade600,
    // secondary: const Color.fromARGB(255, 49, 49, 49),
    secondary: Colors.grey.shade700,
    tertiary: Colors.grey.shade800,
    inversePrimary: Colors.grey.shade300,
  ),
);
