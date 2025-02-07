import 'package:flutter/material.dart';

class HabitTile extends StatelessWidget {
  final String text;
  final bool isCompleted;
  final Function(bool?) onChanged;

  const HabitTile({
    super.key,
    required this.isCompleted,
    required this.text,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green
            : Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 25),
      child: ListTile(
        title: Text(text),
        leading: Checkbox(
          activeColor: Colors.green,
          value: isCompleted,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
