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
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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

    // Completion colors — vibrant emerald green (semantic: done = green)
    const Color completedLight = Color(0xFF10B981); // emerald-500
    const Color completedDark = Color(0xFF34D399); // emerald-400

    final completedColor = isLightMode ? completedLight : completedDark;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Slidable(
            endActionPane: ActionPane(
              motion: const StretchMotion(),
              children: [
                CustomSlidableAction(
                  onPressed: widget.editTask,
                  backgroundColor: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.penToSquare,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomSlidableAction(
                  onPressed: widget.deleteTask,
                  backgroundColor: const Color(0xFFE53E3E),
                  borderRadius: BorderRadius.circular(12),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_rounded, color: Colors.white, size: 18),
                      SizedBox(height: 4),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: _handleCompletion,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: widget.isCompleted
                      ? completedColor.withValues(
                          alpha: isLightMode ? 0.12 : 0.15,
                        )
                      : (isLightMode ? Colors.white : const Color(0xFF1A1929)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isCompleted
                        ? completedColor.withValues(alpha: 0.4)
                        : (isLightMode
                              ? const Color(0xFFEDE9FE)
                              : const Color(0xFF2D2C44)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (!widget.isCompleted)
                      BoxShadow(
                        color: isLightMode
                            ? const Color(0x0D6366F1)
                            : Colors.black.withValues(alpha: 0.15),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  leading: GestureDetector(
                    onTap: _handleCompletion,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isCompleted
                            ? completedColor
                            : Colors.transparent,
                        border: Border.all(
                          color: widget.isCompleted
                              ? completedColor
                              : (isLightMode
                                    ? const Color(0xFFB0ADDB)
                                    : const Color(0xFF5A587A)),
                          width: 2,
                        ),
                      ),
                      child: widget.isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                  title: Text(
                    widget.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: widget.isCompleted
                          ? completedColor
                          : Theme.of(context).colorScheme.inversePrimary,
                      decoration: widget.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: completedColor,
                    ),
                  ),
                  trailing: widget.isCompleted
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: completedColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Done',
                            style: TextStyle(
                              color: completedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
