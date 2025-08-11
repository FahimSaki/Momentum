import 'package:flutter/material.dart';
import 'package:momentum/components/drawer_tile.dart';
import 'package:momentum/pages/login_page.dart';
import 'package:momentum/pages/settings_page.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

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
                  height: 170,
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
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
