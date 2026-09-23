import 'package:flutter/material.dart';
import 'package:momentum/theme/theme.dart';

/// The 80x80 rounded icon badge used at the top of single-purpose auth
/// flows (email verification, forgot/reset password, 2FA). Previously
/// copy-pasted with only the icon changing across four pages.
class AuthIconBadge extends StatelessWidget {
  final IconData icon;

  const AuthIconBadge({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: kIndigo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(icon, size: 40, color: kIndigo),
    );
  }
}
