import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class AnimatedTaskTile extends StatefulWidget {
  final String text;
  final bool isCompleted;
  final Function(bool?)? onChanged;
  final void Function(BuildContext)? editTask;
  final void Function(BuildContext)? deleteTask;

  const AnimatedTaskTile({
    super.key,
    required this.isCompleted,
    required this.text,
    required this.onChanged,
    required this.editTask,
    required this.deleteTask,
  });

  @override
  State<AnimatedTaskTile> createState() => _AnimatedTaskTileState();
}

class _AnimatedTaskTileState extends State<AnimatedTaskTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1.5),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCompletion() async {
    if (!widget.isCompleted) {
      await _controller.forward();
      widget.onChanged?.call(true);
    } else {
      widget.onChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLightMode = !themeProvider.isDarkMode;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
          child: Slidable(
            endActionPane: ActionPane(
              motion: const StretchMotion(),
              children: [
                CustomSlidableAction(
                  onPressed: widget.editTask,
                  backgroundColor:
                      isLightMode ? Colors.grey.shade600 : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                  child: const FaIcon(FontAwesomeIcons.penToSquare,
                      color: Colors.white),
                ),
                SlidableAction(
                  onPressed: widget.deleteTask,
                  backgroundColor: Colors.red,
                  icon: Icons.delete,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: _handleCompletion,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isCompleted
                      ? (isLightMode ? Colors.green : Colors.teal)
                      : Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    if (!widget.isCompleted)
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
                    widget.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: widget.isCompleted
                          ? Colors.white
                          : Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                  leading: Checkbox(
                    activeColor: isLightMode ? Colors.green : Colors.teal,
                    value: widget.isCompleted,
                    onChanged: (_) => _handleCompletion(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
