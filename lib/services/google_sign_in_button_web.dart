import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Custom "Continue with Google" button matching login_page.dart's mobile
/// OutlinedButton, with the real GIS button stacked on top — invisible, but
/// still the element that actually receives the click and drives sign-in
/// (a plain custom button can't call authenticate() on web; see auth_service.dart).
///
/// Note: opacity must be a small non-zero value, not exactly 0.0. Flutter web
/// drops platform views (which is what Google's real button is) from hit
/// testing entirely at opacity 0.0 — invisible AND unclickable. A near-zero
/// value like 0.01 stays visually imperceptible while keeping it interactive.
Widget buildGoogleSignInButton() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : 320.0;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return SizedBox(
        height: 50,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _FakeGoogleButton(isDark: isDark),
            Positioned.fill(
              child: Opacity(
                opacity: 0.01,
                child: web.renderButton(
                  configuration: web.GSIButtonConfiguration(
                    theme: web.GSIButtonTheme.outline,
                    shape: web.GSIButtonShape.rectangular,
                    size: web.GSIButtonSize.large,
                    text: web.GSIButtonText.continueWith,
                    logoAlignment: web.GSIButtonLogoAlignment.left,
                    minimumWidth: width,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _FakeGoogleButton extends StatelessWidget {
  final bool isDark;
  const _FakeGoogleButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed:
          () {}, // visual only — the real button on top handles the click
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(
          color: isDark ? const Color(0xFF3D3B5C) : const Color(0xFFDDD6FE),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                'G',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Continue with Google', style: TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
