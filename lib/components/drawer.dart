import 'package:flutter/material.dart';
import 'package:momentum/components/drawer_tile.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/services/auth_service.dart';
import 'package:momentum/pages/settings_page.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:momentum/pages/user_profile_page.dart';

final Logger _logger = Logger();

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  void _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      try {
        final db = Provider.of<TaskDatabase>(context, listen: false);

        // Close the drawer first.
        Navigator.of(context).pop();

        // Finish clearing the local session before showing the login page.
        // Previously this navigated immediately and let logout continue in
        // the background. If the user signed back in quickly, that delayed
        // logout could delete the freshly-persisted token or clear the newly
        // initialized TaskDatabase, causing authenticated calls like GET
        // /tasks to be sent without a usable access token after relogin.
        await AuthService.instance.logout();
        await db.clearData();

        if (!context.mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } catch (e) {
        _logger.e('Logout navigation error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLightMode = !themeProvider.isDarkMode;

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Theme(
              data: Theme.of(context).copyWith(
                dividerTheme: const DividerThemeData(color: Colors.transparent),
              ),
              child: DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use available height to scale image and text
                    final double availableHeight = constraints.maxHeight;
                    final double imageHeight = availableHeight * 0.6;
                    final double textHeight = availableHeight * 0.2;

                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Responsive Image
                          SizedBox(
                            height: imageHeight,
                            child: Image.asset(
                              isLightMode
                                  ? 'assets/images/momentum_app_logo_main.png'
                                  : 'assets/images/momentum_app_logo_main.png',
                              fit: BoxFit.contain, // maintain aspect ratio
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Responsive Text
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Momentum',
                              style: TextStyle(
                                fontSize: textHeight,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(
                                  context,
                                ).colorScheme.inversePrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 25.0),
            // Home Tile
            DrawerTile(
              title: 'Home',
              leading: const Icon(Icons.home),
              onTap: () => Navigator.pop(context),
            ),

            // Settings Tile
            DrawerTile(
              title: 'Settings',
              leading: const Icon(Icons.settings),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),

            // User Profile Tile
            DrawerTile(
              title: 'My Profile',
              leading: const Icon(Icons.account_circle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfilePage(),
                  ),
                );
              },
            ),

            const Spacer(),

            // Logout Tile
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: DrawerTile(
                title: 'Logout',
                leading: const Icon(Icons.logout),
                onTap: () => _handleLogout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
