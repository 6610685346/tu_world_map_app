import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:tu_world_map_app/services/search_history_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _autoSaveRecent = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF5), // Warm cream background
        elevation: 0,
        toolbarHeight: 90,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6D4C41), // Warm brown
              ),
            ),
            Text(
              'Customize your experience',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF5D4037), // Dark warm brown
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFFBF5), // Almost white with warm hint
              const Color(0xFFFFF8F0), // Very light cream
              const Color(0xFFFFF3E8), // Subtle warm white
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Preferences Section
              _buildSectionTitle('App Preferences'),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: 'Receive updates and alerts',
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.location_on,
                  title: 'Location Access',
                  subtitle: 'Allow app to access your location',
                  value: _locationEnabled,
                  onChanged: (value) {
                    setState(() {
                      _locationEnabled = value;
                    });
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.history,
                  title: 'Auto-save Recent',
                  subtitle: 'Automatically save visited locations',
                  value: _autoSaveRecent,
                  onChanged: (value) {
                    setState(() {
                      _autoSaveRecent = value;
                    });
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // Data Management Section
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
                    () {
                      // Clear recent locations logic would go here
                      // For now, just show a snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Recent locations cleared'),
                          backgroundColor: Color(0xFFD32F2F),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
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
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Favorites cleared'),
                          backgroundColor: Color(0xFFD32F2F),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.search_off,
                  title: 'Clear Search History',
                  subtitle: 'Remove all search history',
                  onTap: () => _showClearDialog(
                    context,
                    'Clear Search History',
                    'Are you sure you want to clear all search history?',
                    () {
                      SearchHistoryService().clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Search history cleared'),
                          backgroundColor: Color(0xFFD32F2F),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // Appearance Section
              _buildSectionTitle('Appearance'),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildActionTile(
                  icon: Icons.palette,
                  title: 'Theme',
                  subtitle: 'Warm & Cozy (Default)',
                  trailing: Icon(
                    CupertinoIcons.chevron_right,
                    color: Color(0xFF8D6E63),
                    size: 20,
                  ),
                  onTap: () {
                    // Theme selection would go here
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.text_fields,
                  title: 'Text Size',
                  subtitle: 'Medium',
                  trailing: Icon(
                    CupertinoIcons.chevron_right,
                    color: Color(0xFF8D6E63),
                    size: 20,
                  ),
                  onTap: () {
                    // Text size setting would go here
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // About Section
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
                  trailing: Icon(
                    CupertinoIcons.chevron_right,
                    color: Color(0xFF8D6E63),
                    size: 20,
                  ),
                  onTap: () {
                    // Navigate to terms of service
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  trailing: Icon(
                    CupertinoIcons.chevron_right,
                    color: Color(0xFF8D6E63),
                    size: 20,
                  ),
                  onTap: () {
                    // Navigate to privacy policy
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.code,
                  title: 'Open Source Licenses',
                  subtitle: 'View third-party licenses',
                  trailing: Icon(
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

              // Footer
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.school,
                      size: 48,
                      color: Color(0xFFD32F2F).withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TU World Map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
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
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3E2723), // Very dark brown
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      color: Colors.white.withOpacity(0.9),
      elevation: 2,
      shadowColor: Colors.red.withOpacity(0.1),
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
          color: Color(0xFFD32F2F).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Color(0xFFD32F2F), size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF3E2723),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Color(0xFFD32F2F),
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
          color: Color(0xFFD32F2F).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Color(0xFFD32F2F), size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF3E2723),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
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
      color: Color(0xFF5D4037).withOpacity(0.1),
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
          backgroundColor: Color(0xFFFFFBF5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Color(0xFF3E2723),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(message, style: TextStyle(color: Color(0xFF5D4037))),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(color: Color(0xFF8D6E63))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Clear'),
            ),
          ],
        );
      },
    );
  }
}
