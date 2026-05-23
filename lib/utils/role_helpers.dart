import 'package:flutter/material.dart';

/// Role colours, gradients, icons, labels, and descriptions used across
/// TeamHomePage, TeamSettingsPage, and TeamDetailsPage.
class RoleHelpers {
  RoleHelpers._();

  static Color color(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFF8B5CF6);
      case 'admin':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  static List<Color> gradient(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return [const Color(0xFF7C3AED), const Color(0xFF9D4EDD)];
      case 'admin':
        return [const Color(0xFFD97706), const Color(0xFFF59E0B)];
      default:
        return [const Color(0xFF2563EB), const Color(0xFF3B82F6)];
    }
  }

  static IconData icon(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Icons.star_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  static String displayName(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      default:
        return 'Member';
    }
  }

  static String description(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Full control over team, settings, members, and tasks';
      case 'admin':
        return 'Can create, edit, delete tasks and invite members';
      default:
        return 'Can view and complete tasks assigned to you';
    }
  }
}

/// Compact coloured pill showing a member role.
class RoleBadge extends StatelessWidget {
  final String role;
  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final color = RoleHelpers.color(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
