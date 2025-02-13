// import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/components/drawer_tile.dart';
import 'package:habit_tracker/pages/settings_page.dart';
import 'package:habit_tracker/theme/theme_provider.dart';
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
          // notes logo
          Theme(
            data: Theme.of(context).copyWith(
              dividerTheme: const DividerThemeData(color: Colors.transparent),
            ),
            child: DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface, // use your drawer background color
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
          // const Spacer(),

          // notes tile
          DrawerTile(
            title: 'Home',
            leading: const Icon(Icons.home),
            onTap: () => Navigator.pop(context),
          ),

          // settings tile
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
        ],
      ),
    );
  }
}
