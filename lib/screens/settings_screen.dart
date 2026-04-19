import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tu_world_map_app/services/recent_location_service.dart';
import 'package:tu_world_map_app/services/favorite_service.dart';
import 'package:tu_world_map_app/services/settings_service.dart';
import 'package:tu_world_map_app/screens/terms_of_service_screen.dart';
import 'package:tu_world_map_app/screens/privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _autoSaveRecent;

  @override
  void initState() {
    super.initState();
    _autoSaveRecent = SettingsService().autoSaveRecent;
  }

  Future<void> _launchFeedbackUrl() async {
    final Uri url = Uri.parse('mailto:support@tuworldmap.com?subject=App%20Feedback');
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client to send feedback')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF5), 
        elevation: 0,
        toolbarHeight: 90,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6D4C41),
              ),
            ),
            Text(
              'Customize your experience',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFBF5),
              Color(0xFFFFF8F0),
              Color(0xFFFFF3E8),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('App Preferences'),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.history,
                  title: 'Auto-save Recent',
                  subtitle: 'Automatically save visited locations',
                  value: _autoSaveRecent,
                  onChanged: (value) {
                    setState(() {
                      _autoSaveRecent = value;
                    });
                    SettingsService().setAutoSaveRecent(value);
                  },
                ),
              ]),

              const SizedBox(height: 24),

              _buildSectionTitle('Data Management'),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildActionTile(
                  icon: Icons.delete_sweep,
                  title: 'Clear Recent Locations',
                  subtitle: 'Remove all recent location history',
                  onTap: () => _showClearDialog(
                    context,
                    'Clear Recent Locations',
                    'Are you sure you want to clear all recent locations?',
                    () async {
                      await RecentLocationService().clear();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recent locations cleared'),
                            backgroundColor: Color(0xFFD32F2F),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.favorite_border,
                  title: 'Clear Favorites',
                  subtitle: 'Remove all saved favorites',
                  onTap: () => _showClearDialog(
                    context,
                    'Clear Favorites',
                    'Are you sure you want to clear all favorites?',
                    () async {
                      await FavoriteService().clearAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Favorites cleared'),
                            backgroundColor: Color(0xFFD32F2F),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              _buildSectionTitle('Feedback'),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildActionTile(
                  icon: Icons.feedback_outlined,
                  title: 'Send Feedback',
                  subtitle: 'Help us improve TU World Map',
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    color: Color(0xFF8D6E63),
                    size: 20,
                  ),
                  onTap: _launchFeedbackUrl,
                ),
              ]),

              const SizedBox(height: 24),

              _buildSectionTitle('About'),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildActionTile(
                  icon: Icons.info_outline,
                  title: 'App Version',
                  subtitle: '1.0.0',
                  onTap: () {},
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.description,
                  title: 'Terms of Service',
                  subtitle: 'Read our terms and conditions',
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    color: Color(0xFF8D6E63),
                    size: 20,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TermsOfServiceScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    color: Color(0xFF8D6E63),
                    size: 20,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.code,
                  title: 'Open Source Licenses',
                  subtitle: 'View third-party licenses',
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    color: Color(0xFF8D6E63),
                    size: 20,
                  ),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'TU World Map',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
              ]),

              const SizedBox(height: 32),

              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.school,
                      size: 48,
                      color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'TU World Map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Explore Thammasat University with ease',
                      style: TextStyle(fontSize: 14, color: Color(0xFF5D4037)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3E2723), 
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      color: Colors.white.withValues(alpha: 0.9),
      elevation: 2,
      shadowColor: Colors.red.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFFD32F2F), size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF3E2723),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFFD32F2F),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFFD32F2F), size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF3E2723),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: 16,
      color: const Color(0xFF5D4037).withValues(alpha: 0.1),
    );
  }

  void _showClearDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFBF5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF3E2723),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(message, style: const TextStyle(color: Color(0xFF5D4037))),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8D6E63))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }
}
