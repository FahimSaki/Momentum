import 'package:flutter/material.dart';

class AppBreakpoints {
  const AppBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

class AppWidths {
  const AppWidths._();

  static const double authForm = 420;
  static const double simpleForm = 600;
  static const double content = 900;
  static const double wideContent = 1100;
}

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppWidths.content,
    this.padding = const EdgeInsets.all(16),
    this.scrollable = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final constrainedChild = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    if (!scrollable) {
      return Padding(padding: padding, child: constrainedChild);
    }

    return SingleChildScrollView(padding: padding, child: constrainedChild);
  }
}
