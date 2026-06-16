import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:momentum/components/responsive_layout.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Appearance section
            _buildSectionHeader(
              'Appearance',
              Icons.palette_rounded,
              const Color(0xFF8B5CF6),
              context,
            ),
            const SizedBox(height: 10),
            _buildCard(
              isDark: isDark,
              children: [
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode
                                  ? const Color(0xFF1A1929)
                                  : const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              themeProvider.isDarkMode
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              color: themeProvider.isDarkMode
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF6366F1),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 14),
                                Text(
                                  'Dark Mode',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.inversePrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  themeProvider.isDarkMode
                                      ? 'Deep space indigo theme'
                                      : 'Light lavender theme',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF9B99C8)
                                        : const Color(0xFF6B66A3),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: themeProvider.isDarkMode,
                            onChanged: (_) => themeProvider.toggleTheme(),
                            activeTrackColor: const Color(0xFF6366F1),
                            thumbColor: Colors.white,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // About section
            _buildSectionHeader(
              'About',
              Icons.info_rounded,
              const Color(0xFF3B82F6),
              context,
            ),
            const SizedBox(height: 10),
            _buildCard(
              isDark: isDark,
              children: [
                _buildInfoTile(
                  icon: Icons.apps_rounded,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Momentum',
                  subtitle: 'Version 0.9.1',
                  isDark: isDark,
                  context: context,
                ),
                _buildDivider(isDark),
                _buildInfoTile(
                  icon: Icons.code_rounded,
                  iconColor: const Color(0xFF22C55E),
                  title: 'Developer',
                  subtitle: 'Fahim Saki',
                  isDark: isDark,
                  context: context,
                ),
                _buildDivider(isDark),
                _buildInfoTile(
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'License',
                  subtitle: 'AGPL v3.0',
                  isDark: isDark,
                  context: context,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Theme preview
            _buildThemePreview(isDark),

            const SizedBox(height: 40),

            Center(
              child: Text(
                '℗ by Fahim Saki',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF5A587A)
                      : const Color(0xFFB0ADDB),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isDark ? const Color(0xFF9B99C8) : const Color(0xFF6B66A3),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1929) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2C44) : const Color(0xFFEDE9FE),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF9B99C8)
                        : const Color(0xFF6B66A3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 16,
      color: isDark ? const Color(0xFF2D2C44) : const Color(0xFFEDE9FE),
    );
  }

  Widget _buildThemePreview(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF1A1929), Color(0xFF2D2C44)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isDark ? 'Deep Space Theme' : 'Lavender Light Theme',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isDark
                ? 'Dark indigo tones with violet accents for comfortable night use.'
                : 'Soft lavender with indigo accents for a clean, focused experience.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _colorDot(const Color(0xFF6366F1), 'Brand'),
              const SizedBox(width: 8),
              _colorDot(const Color(0xFF22C55E), 'Success'),
              const SizedBox(width: 8),
              _colorDot(const Color(0xFFF59E0B), 'Warning'),
              const SizedBox(width: 8),
              _colorDot(const Color(0xFFE53E3E), 'Error'),
              const SizedBox(width: 8),
              _colorDot(const Color(0xFF3B82F6), 'Info'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colorDot(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
