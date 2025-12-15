// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Appearance Card
            _buildSectionCard(
              context,
              title: "Appearance",
              subtitle: "Customize the app's visual appearance",
              icon: Icons.palette_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Dark Mode",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle:
                      const Text("Use dark theme for better night viewing"),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  value: themeProvider.isDark,
                  onChanged: (val) {
                    themeProvider.setDarkMode(val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Color Vision Settings Card
            _buildSectionCard(
              context,
              title: "Color Vision Settings",
              subtitle:
                  "Customize color correction based on your vision type",
              icon: Icons.visibility_outlined,
              children: [
                const SizedBox(height: 12),
                const Text("Color Vision Deficiency Type",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CvdType>(
                      isExpanded: true,
                      value: themeProvider.cvdType,
                      onChanged: (CvdType? newValue) {
                        if (newValue != null) {
                          themeProvider.setCvdType(newValue);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                            value: CvdType.none, child: Text("None")),
                        DropdownMenuItem(
                            value: CvdType.protanopia,
                            child: Text("Protanopia (Red-Green)")),
                        DropdownMenuItem(
                            value: CvdType.deuteranopia,
                            child: Text("Deuteranopia (Red-Green)")),
                        DropdownMenuItem(
                            value: CvdType.tritanopia,
                            child: Text("Tritanopia (Blue-Yellow)")),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getCvdDescription(themeProvider.cvdType),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Accessibility Card
            _buildSectionCard(
              context,
              title: "Accessibility",
              subtitle: "Audio and visual accessibility options",
              icon: Icons.volume_up_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Audio Alerts",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Play sound when colors are detected"),
                  value: themeProvider.audioAlerts,
                  onChanged: (val) {
                    themeProvider.setAudioAlerts(val);
                  },
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text("Font Size",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildDropdown(
                  context,
                  value: themeProvider.fontSize,
                  items: ["Small", "Medium", "Large"],
                  onChanged: (val) => themeProvider.setFontSize(val!),
                ),
                const SizedBox(height: 16),
                const Text("Contrast Mode",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildDropdown(
                  context,
                  value: themeProvider.contrastMode,
                  items: ["Normal Contrast", "High Contrast"],
                  onChanged: (val) => themeProvider.setContrastMode(val!),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Account Card
            _buildSectionCard(
              context,
              title: "Account",
              subtitle: "Manage your COLAID account",
              children: [
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    // Sign out logic
                    UserService().clearUserData();
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/', (route) => false);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Sign Out"),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // About Card
            _buildSectionCard(
              context,
              title: "About COLAID",
              children: [
                const SizedBox(height: 12),
                const Text(
                  "COLAID is an assistive technology app designed to help individuals with Color Vision Deficiency (CVD) navigate the world more easily using real-time color correction and smart detection.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text("Version 1.0.0",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Text("Built with accessibility and user experience in mind",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 24),

            // Reset Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                   themeProvider.resetToDefaults();
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Settings reset to default")),
                   );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC143C), // Crimson red
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Reset to Default Settings"),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context,
      {required String title,
      String? subtitle,
      IconData? icon,
      required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                 if (icon != null) ...[
                   Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                   const SizedBox(width: 8),
                 ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (children.isNotEmpty) const SizedBox(height: 8), // Header spacing
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(BuildContext context,
      {required String value,
      required List<String> items,
      required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
         border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getCvdDescription(CvdType type) {
    switch (type) {
      case CvdType.protanopia:
        return "Difficulty distinguishing red and green colors (missing L-cones)";
      case CvdType.deuteranopia:
        return "Difficulty distinguishing red and green colors (missing M-cones)";
      case CvdType.tritanopia:
        return "Difficulty distinguishing blue and yellow colors (missing S-cones)";
      case CvdType.none:
        return "Standard color vision";
    }
  }
}
