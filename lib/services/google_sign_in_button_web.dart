import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Renders Google's own "Sign in with Google" button. This is the only
/// way to get a real, signed idToken back on web — GoogleSignIn().signIn()
/// is a deprecated fallback that can never populate idToken (see
/// auth_service.dart for why).
///
/// Configured as close as Google's branding rules allow to the outlined
/// "Continue with Google" button used on mobile: bordered, rectangular
Widget buildGoogleSignInButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    theme: web.GSIButtonTheme.outline,
    shape: web.GSIButtonShape.rectangular,
    size: web.GSIButtonSize.large,
    text: web.GSIButtonText.continueWith,
    logoAlignment: web.GSIButtonLogoAlignment.left,
    minimumWidth: 320.0,
  ),
);
