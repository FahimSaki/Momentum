import 'package:flutter/material.dart';
import 'package:momentum/blocs/task_cubit.dart';
import 'package:momentum/components/drawer_tile.dart';
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
        final taskCubit = context.read<TaskCubit>();

        Navigator.of(context).pop();

        await AuthService.instance.logout();
        await taskCubit.clearData();

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
                    final double availableHeight = constraints.maxHeight;
                    final double imageHeight = availableHeight * 0.6;
                    final double textHeight = availableHeight * 0.2;

                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: imageHeight,
                            child: Image.asset(
                              isLightMode
                                  ? 'assets/images/momentum_app_logo_main.png'
                                  : 'assets/images/momentum_app_logo_main.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
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
            DrawerTile(
              title: 'Home',
              leading: const Icon(Icons.home),
              onTap: () => Navigator.pop(context),
            ),

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
