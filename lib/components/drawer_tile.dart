import 'package:flutter/material.dart';

class DrawerTile extends StatelessWidget {
  final String title;
  final Widget leading;
  final void Function()? onTap;

  const DrawerTile({
    super.key,
    required this.title,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.secondary.withValues(alpha: 0.8),
              ),
            ),
            child: ListTile(
              minLeadingWidth: 24,
              title: Text(
                title,
                style: TextStyle(
                  color: colorScheme.inversePrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              leading: IconTheme(
                data: IconThemeData(color: colorScheme.primaryContainer),
                child: leading,
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
