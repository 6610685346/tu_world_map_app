import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF5),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(
            height: 1,
            thickness: 1,
            color: const Color(0xFF6D4C41).withValues(alpha: 0.1),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6D4C41)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6D4C41),
          ),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TU World Map — Privacy Policy',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: February 2026',
                style: TextStyle(fontSize: 13, color: Color(0xFF8D6E63)),
              ),
              const SizedBox(height: 20),
              _buildSection(
                '1. Introduction',
                'This Privacy Policy describes how TU World Map ("we", "us", or "the App") '
                    'collects, uses, and protects information when you use our campus navigation '
                    'application for Thammasat University.',
              ),
              _buildSection(
                '2. Information We Collect',
                'The App collects and stores the following information locally on your device:\n\n'
                    '• Recent locations you have viewed\n'
                    '• Favorite locations you have saved\n'
                    '• App preference settings (e.g., location access, auto-save)\n\n'
                    'This data is stored only on your device and is not transmitted to any '
                    'external servers.',
              ),
              _buildSection(
                '3. Location Data',
                'When you grant location permission, the App accesses your device\'s GPS to '
                    'provide navigation and show your current position on the map. Your location '
                    'data is used in real-time only and is not stored or shared with third parties. '
                    'You can revoke location access at any time through the App settings.',
              ),
              _buildSection(
                '4. How We Use Information',
                'The information collected is used solely to:\n\n'
                    '• Display your recent and favorite locations for quick access\n'
                    '• Remember your app preferences between sessions\n'
                    '• Provide navigation features from your current location\n'
                    '• Improve your overall experience using the App',
              ),
              _buildSection(
                '5. Data Storage & Security',
                'All user data is stored locally on your device using secure storage mechanisms '
                    'provided by the operating system. We do not transmit, sell, or share your '
                    'personal data with any third parties. You can clear all stored data at any '
                    'time through the Settings screen.',
              ),
              _buildSection(
                '6. Third-Party Services',
                'The App uses the following third-party services:\n\n'
                    '• OpenStreetMap — for map tile rendering\n'
                    '• OSRM — for route calculation\n\n'
                    'These services may have their own privacy policies. We encourage you to '
                    'review them.',
              ),
              _buildSection(
                '7. Children\'s Privacy',
                'The App is designed for general use by students, faculty, and visitors of '
                    'Thammasat University. We do not knowingly collect personal information from '
                    'children under the age of 13.',
              ),
              _buildSection(
                '8. Data Deletion',
                'You can delete your data at any time by:\n\n'
                    '• Using "Clear Recent Locations" in Settings\n'
                    '• Using "Clear Favorites" in Settings\n'
                    '• Uninstalling the App from your device\n\n'
                    'Uninstalling the App will remove all locally stored data.',
              ),
              _buildSection(
                '9. Changes to This Policy',
                'We may update this Privacy Policy from time to time. Any changes will be '
                    'reflected in the "Last updated" date at the top of this page.',
              ),
              _buildSection(
                '10. Contact Us',
                'If you have any questions or concerns about this Privacy Policy, please contact '
                    'the development team at the Faculty of Engineering, Thammasat University.',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF5D4037),
            ),
          ),
        ],
      ),
    );
  }
}
