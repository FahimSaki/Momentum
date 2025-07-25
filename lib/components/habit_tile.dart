import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:habit_tracker/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class HabitTile extends StatelessWidget {
  final String text;
  final bool isCompleted;
  final Function(bool?)? onChanged;
  final void Function(BuildContext)? editHabit;
  final void Function(BuildContext)? deleteHabit;

  const HabitTile({
    super.key,
    required this.isCompleted,
    required this.text,
    required this.onChanged,
    required this.editHabit,
    required this.deleteHabit,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLightMode = !themeProvider.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          children: [
            // Edit button
            CustomSlidableAction(
              onPressed: editHabit,
              backgroundColor:
                  isLightMode ? Colors.grey.shade600 : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
              child: const FaIcon(FontAwesomeIcons.penToSquare,
                  color: Colors.white),
            ),

            // Delete button
            SlidableAction(
              onPressed: deleteHabit,
              backgroundColor: Colors.red,
              icon: Icons.delete,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () {
            if (onChanged != null) {
              onChanged!(!isCompleted);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isCompleted
                  ? (isLightMode ? Colors.green : Colors.teal)
                  : Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                if (!isCompleted)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  )
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: ListTile(
              title: Text(
                text,
                style: TextStyle(
                  color: isCompleted
                      ? Colors.white
                      : Theme.of(context).colorScheme.inversePrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              leading: Checkbox(
                activeColor: isLightMode ? Colors.green : Colors.teal,
                value: isCompleted,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
