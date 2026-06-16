import 'package:flutter/material.dart';

// ── Breakpoints ───────────────────────────────────────────────────────────────
class AppBreakpoints {
  const AppBreakpoints._();
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

// ── Max content widths ────────────────────────────────────────────────────────
class AppWidths {
  const AppWidths._();
  static const double authForm = 420;
  static const double simpleForm = 600;
  static const double content = 900;
  static const double wideContent = 1100;
}

// ── Screen size helpers ───────────────────────────────────────────────────────
bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppBreakpoints.mobile;

bool isTablet(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= AppBreakpoints.mobile && w < AppBreakpoints.desktop;
}

bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

// ── Responsive value helper ───────────────────────────────────────────────────
/// Returns the right value for the current screen size. [tablet] falls back to
/// [desktop] when omitted.
T responsiveValue<T>(
  BuildContext context, {
  required T mobile,
  T? tablet,
  required T desktop,
}) {
  if (isDesktop(context)) return desktop;
  if (isTablet(context)) return tablet ?? desktop;
  return mobile;
}

// ── ResponsiveBuilder ─────────────────────────────────────────────────────────
/// Renders a different widget tree based on screen width.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? desktop;
    return mobile;
  }
}

// ── ResponsiveCenter ──────────────────────────────────────────────────────────
/// Centres [child] and constrains its width to [maxWidth]. When [scrollable]
/// is true (the default) the whole thing is wrapped in a
/// [SingleChildScrollView]. Ideal for form pages such as login / register.
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding = padding.resolve(Directionality.of(context));
        final minHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - resolvedPadding.vertical)
                  .clamp(0.0, double.infinity)
                  .toDouble()
            : 0.0;

        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: constrainedChild,
          ),
        );
      },
    );
  }
}

// ── ResponsiveBody ────────────────────────────────────────────────────────────
/// Use as [Scaffold.body] when [child] is a self-scrolling widget such as a
/// [ListView], [RefreshIndicator], or a [Column] that contains an [Expanded].
///
/// The widget fills the available height (so scrolling and [Expanded] children
/// keep working) and centres its child horizontally up to [maxWidth].
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = AppWidths.content,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

// ── ResponsiveScrollView ──────────────────────────────────────────────────────
/// A [SingleChildScrollView] whose [children] are rendered in a centred,
/// max-width-constrained [Column]. Use for profile / settings pages where the
/// body is a vertical list of cards.
class ResponsiveScrollView extends StatelessWidget {
  const ResponsiveScrollView({
    super.key,
    required this.children,
    this.maxWidth = AppWidths.content,
    this.padding = const EdgeInsets.all(16),
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
  }
}
