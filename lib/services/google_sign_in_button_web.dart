import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Renders Google's own "Sign in with Google" button. This is the only
/// way to get a real, signed idToken back on web — GoogleSignIn().signIn()
/// is a deprecated fallback that can never populate idToken (see
/// auth_service.dart for why).
Widget buildGoogleSignInButton() => web.renderButton();
