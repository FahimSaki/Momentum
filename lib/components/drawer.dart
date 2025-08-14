import 'package:flutter/material.dart';
import 'package:momentum/components/drawer_tile.dart';
import 'package:momentum/services/auth_service.dart';
import 'package:momentum/pages/settings_page.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:momentum/database/task_database.dart';
import 'package:provider/provider.dart';

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
        // 🔧 FIXED: Close the drawer first
        Navigator.of(context).pop();

        // 🔧 FIXED: Navigate IMMEDIATELY to prevent HomePage from rebuilding
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false, // This removes all previous routes
        );

        // 🔧 FIXED: Clear data AFTER navigation to prevent loading state
        final taskDatabase = Provider.of<TaskDatabase>(context, listen: false);
        taskDatabase.clearData();

        // 🔧 FIXED: Perform logout after navigation to prevent any UI updates
        await AuthService.logout();
      } catch (e) {
        print('Logout error: $e');

        // 🔧 IMPROVED: If there's any error, force navigation anyway
        if (context.mounted) {
          try {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          } catch (navError) {
            // If navigation fails, show error and try alternative approach
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Logout error. Please restart the app.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Restart',
                  textColor: Colors.white,
                  onPressed: () {
                    // Force restart by clearing everything and going to splash
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/splash',
                      (route) => false,
                    );
                  },
                ),
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLightMode = !themeProvider.isDarkMode;

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Header
          Theme(
            data: Theme.of(context).copyWith(
              dividerTheme: const DividerThemeData(color: Colors.transparent),
            ),
            child: DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Use available height to scale image and text
                  final double availableHeight = constraints.maxHeight;
                  final double imageHeight =
                      availableHeight * 0.6; // 60% for image
                  final double textHeight =
                      availableHeight * 0.2; // 20% for text

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
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).colorScheme.inversePrimary,
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
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),

          const Spacer(), // pushes the Logout tile to the bottom

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
    );
  }
}
