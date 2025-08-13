import 'package:flutter/material.dart';
import 'package:momentum/components/drawer_tile.dart';
import 'package:momentum/services/auth_service.dart';
import 'package:momentum/pages/settings_page.dart';
import 'package:momentum/theme/theme_provider.dart';
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

    if (shouldLogout == true) {
      try {
        // Clear stored authentication data
        await AuthService.logout();

        if (context.mounted) {
          // Navigate to login page and clear all previous routes
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error during logout: $e'),
              backgroundColor: Colors.red,
            ),
          );
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
              child: Center(
                child: Image.asset(
                  isLightMode
                      ? 'assets/images/momentum_app_logo_light.png'
                      : 'assets/images/momentum_app_logo_dark.png',
                  width: 170,
                  height: 164,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image not found
                    return Container(
                      width: 170,
                      height: 164,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(85),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        size: 80,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    );
                  },
                ),
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
              onTap: () {
                Navigator.pop(context); // Close drawer first
                _handleLogout(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
