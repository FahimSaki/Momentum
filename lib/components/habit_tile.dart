import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
    return Slidable(
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          // * edit option
          CustomSlidableAction(
            onPressed: editHabit,
            backgroundColor: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
            child: const FaIcon(FontAwesomeIcons.penToSquare),
          ),

          // delete option
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
            // toggle completion status
            onChanged!(!isCompleted);
          }
        },
        child: Container(
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
        ),
      ),
    );
  }
}
