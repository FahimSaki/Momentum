import 'package:flutter/widgets.dart';

/// Non-web platforms never render this — login_page.dart uses the custom
/// OutlinedButton there and calls AuthService.googleSignIn() directly.
/// This stub only exists so the conditional export below always resolves
/// to something on every platform.
Widget buildGoogleSignInButton() => const SizedBox.shrink();
