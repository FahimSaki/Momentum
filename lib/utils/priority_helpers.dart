import 'package:flutter/material.dart';

/// Priority colours, shared by the task tile chip and the creation dialog so a
/// priority looks the same everywhere.
class PriorityHelpers {
  PriorityHelpers._();

  static const _colors = <String, Color>{
    'low': Color(0xFF22C55E),
    'medium': Color(0xFFF59E0B),
    'high': Color(0xFFF97316),
    'urgent': Color(0xFFE53E3E),
  };

  static Color color(String priority) =>
      _colors[priority.toLowerCase()] ?? Colors.grey;
}
