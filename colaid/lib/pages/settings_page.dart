// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import 'eyewear_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🌗 Background gradient (same as Login / Home)
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFEFF6FF),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Appearance Card
              _buildSectionCard(
                context,
                isDark: isDark,
                title: "Appearance",
                subtitle: "Customize the app's visual appearance",
                icon: Icons.palette_outlined,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Dark Mode",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      "Use dark theme for better night viewing",
                    ),
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
                isDark: isDark,
                title: "Color Vision Settings",
                subtitle:
                    "Customize color correction based on your vision type",
                icon: Icons.visibility_outlined,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    "Color Vision Deficiency Type",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
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
                            value: CvdType.none,
                            child: Text("None"),
                          ),
                          DropdownMenuItem(
                            value: CvdType.protanopia,
                            child: Text("Protanopia (Red-Green)"),
                          ),
                          DropdownMenuItem(
                            value: CvdType.deuteranopia,
                            child: Text("Deuteranopia (Red-Green)"),
                          ),
                          DropdownMenuItem(
                            value: CvdType.tritanopia,
                            child: Text("Tritanopia (Blue-Yellow)"),
                          ),
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
                isDark: isDark,
                title: "Accessibility",
                subtitle: "Audio and visual accessibility options",
                icon: Icons.volume_up_outlined,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Audio Alerts",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle:
                        const Text("Play sound when colors are detected"),
                    value: themeProvider.audioAlerts,
                    onChanged: (val) {
                      themeProvider.setAudioAlerts(val);
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    "Font Size",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    context,
                    value: themeProvider.fontSize,
                    items: ["Small", "Medium", "Large"],
                    onChanged: (val) => themeProvider.setFontSize(val!),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Contrast Mode",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    context,
                    value: themeProvider.contrastMode,
                    items: ["Normal Contrast", "High Contrast"],
                    onChanged: (val) =>
                        themeProvider.setContrastMode(val!),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Account Card
              _buildSectionCard(
                context,
                isDark: isDark,
                title: "Account",
                subtitle: "Manage your COLAID account",
                children: [
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      UserService().clearUserData();
                      Provider.of<ThemeProvider>(
                        context,
                        listen: false,
                      ).refresh();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text("Sign Out"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      foregroundColor: const Color(0xFFDC143C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: UserService().userEmail == 'Guest'
                        ? null
                        : () => _showChangePasswordDialog(context),
                    icon: const Icon(Icons.lock_reset),
                    label: Text(
                      UserService().userEmail == 'Guest'
                          ? "Change Password (Not available for guests)"
                          : "Change Password",
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showDeleteAccountDialog(context),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Delete Account"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

             _buildSectionCard(
  context,
  isDark: isDark,
  title: "Eyewear Connection",
  subtitle: "Connect to your COLAID glasses",
  icon: Icons.bluetooth,
  children: [
    const SizedBox(height: 12),
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EyewearPage(),
            ),
          );
        },
        icon: Icon(
          Icons.bluetooth_audio,
          color: isDark ? Colors.black : Colors.white,
        ),
        label: Text(
          "Manage Connection",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.black : Colors.white,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          backgroundColor:
              isDark ? Colors.white : const Color(0xFF1E293B),
          side: BorderSide(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
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
                      const SnackBar(
                        content: Text("Settings reset to default"),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                    foregroundColor:
                        isDark ? Colors.black : Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("Reset to Default Settings"),
                ),
              ),
              const SizedBox(height: 24),

              // About
              _buildSectionCard(
                context,
                isDark: isDark,
                title: "About COLAID",
                children: const [
                  SizedBox(height: 12),
                  Text(
                    "COLAID is an assistive technology app designed to help individuals with Color Vision Deficiency (CVD).",
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Version 1.0.0",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Built with accessibility and user experience in mind",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required bool isDark,
    required String title,
    String? subtitle,
    IconData? icon,
    required List<Widget> children,
  }) {
    return Card(
      color: isDark ? const Color(0xFF020617) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (children.isNotEmpty) const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
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
  void _showChangePasswordDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool loading = false;

    /// Validates password strength and returns error message if invalid
    String? validatePassword(String? value) {
      if (value == null || value.isEmpty) {
        return 'Password is required';
      }

      final List<String> errors = [];

      // Check minimum length
      if (value.length < 8) {
        errors.add('• At least 8 characters');
      }

      // Check for uppercase letter
      if (!RegExp(r'[A-Z]').hasMatch(value)) {
        errors.add('• At least one uppercase letter (A-Z)');
      }

      // Check for lowercase letter
      if (!RegExp(r'[a-z]').hasMatch(value)) {
        errors.add('• At least one lowercase letter (a-z)');
      }

      // Check for digit
      if (!RegExp(r'[0-9]').hasMatch(value)) {
        errors.add('• At least one number (0-9)');
      }

      // Check for special character
      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]').hasMatch(value)) {
        errors.add('• At least one special character (!@#\$%^&*...)');
      }

      // Check for common weak passwords
      final commonWeakPasswords = [
        '12345678',
        '123456789',
        '1234567890',
        'password',
        'password1',
        'qwerty12',
        'qwertyui',
        'abcdefgh',
        'abc12345',
        '11111111',
        '00000000',
        'aaaaaaaa',
        'password123',
        'admin123',
        'letmein1',
      ];
      if (commonWeakPasswords.contains(value.toLowerCase())) {
        errors.add('• Password is too common, choose a stronger one');
      }

      // Check for repeating characters
      if (RegExp(r'^(.)\1+$').hasMatch(value)) {
        errors.add('• Password cannot be all the same character');
      }

      if (errors.isNotEmpty) {
        return 'Password must contain:\n${errors.join('\n')}';
      }

      return null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Change Password"),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "New Password",
                        helperText:
                            'Must include uppercase, lowercase, number & special character',
                        helperMaxLines: 2,
                        errorMaxLines: 6,
                      ),
                      validator: validatePassword,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Confirm Password",
                      ),
                      validator: (value) {
                        if (value != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }

                          final newPass = passwordController.text;

                          setState(() => loading = true);

                          try {
                            final cookie = UserService().authCookie;
                            final headers = {
                              'Content-Type': 'application/json',
                              if (cookie != null) 'Cookie': cookie,
                            };

                            final response = await http.post(
                              Uri.parse(
                                "${dotenv.env['API_URL']}/reset-password",
                              ),
                              headers: headers,
                              body: jsonEncode({'new_password': newPass}),
                            );

                            setState(() => loading = false);

                            if (response.statusCode == 200) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Password updated! Please login again.",
                                    ),
                                  ),
                                );
                                // Optional: Logout user to force re-login
                                UserService().clearUserData();
                                if (context.mounted) {
                                  Provider.of<ThemeProvider>(
                                    context,
                                    listen: false,
                                  ).refresh();
                                }
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/',
                                  (route) => false,
                                );
                              }
                            } else {
                              if (context.mounted) {
                                final msg =
                                    jsonDecode(response.body)['error'] ??
                                    'Update failed';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $msg")),
                                );
                              }
                            }
                          } catch (e) {
                            setState(() => loading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Delete Account"),
              content: const Text(
                "Are you sure you want to delete your account? This action cannot be undone.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setState(() => loading = true);

                          try {
                            final cookie = UserService().authCookie;
                            final headers = {
                              'Content-Type': 'application/json',
                              if (cookie != null) 'Cookie': cookie,
                            };

                            final response = await http.post(
                              Uri.parse(
                                "${dotenv.env['API_URL']}/delete-account",
                              ),
                              headers: headers,
                            );

                            setState(() => loading = false);

                            if (response.statusCode == 200) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                UserService().clearUserData();
                                if (context.mounted) {
                                  Provider.of<ThemeProvider>(
                                    context,
                                    listen: false,
                                  ).refresh();
                                }
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/',
                                  (route) => false,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Account deleted successfully",
                                    ),
                                  ),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                final msg =
                                    jsonDecode(response.body)['error'] ??
                                    'Deletion failed';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $msg")),
                                );
                              }
                            }
                          } catch (e) {
                            setState(() => loading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          }
                        },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Delete"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
