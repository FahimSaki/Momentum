import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// True only where the `home_widget` plugin has a native implementation.
///
/// home_widget ships Android and iOS code only. On Linux, Windows, macOS
/// and web every call into it throws MissingPluginException, so anything
/// that touches HomeWidget must be gated on this.
bool get supportsHomeWidget {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
