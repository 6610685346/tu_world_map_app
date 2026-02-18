import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6D4C41)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Terms of Service',
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
                'TU World Map — Terms of Service',
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
                '1. Acceptance of Terms',
                'By downloading, installing, or using the TU World Map application ("App"), '
                    'you agree to be bound by these Terms of Service. If you do not agree to '
                    'these terms, please do not use the App.',
              ),
              _buildSection(
                '2. Description of Service',
                'TU World Map is a campus navigation application designed for Thammasat University. '
                    'The App provides interactive maps, building information, location search, '
                    'and navigation features to help users explore the university campus.',
              ),
              _buildSection(
                '3. User Accounts & Data',
                'The App stores your preferences, recent locations, and favorite locations locally '
                    'on your device. We do not require user registration or collect personal '
                    'information beyond what is necessary for the App to function.',
              ),
              _buildSection(
                '4. Permitted Use',
                'You may use the App for personal, non-commercial purposes related to navigating '
                    'and exploring Thammasat University campus. You agree not to:\n\n'
                    '• Reverse engineer, decompile, or disassemble the App\n'
                    '• Use the App for any unlawful purpose\n'
                    '• Attempt to gain unauthorized access to any portion of the App\n'
                    '• Redistribute or republish the App without permission',
              ),
              _buildSection(
                '5. Location Services',
                'The App may request access to your device\'s location services to provide '
                    'navigation and location-based features. You can enable or disable location '
                    'access at any time through the App settings or your device settings.',
              ),
              _buildSection(
                '6. Disclaimer of Warranties',
                'The App is provided "as is" without warranties of any kind, either express or '
                    'implied. We do not guarantee the accuracy of map data, building information, '
                    'or navigation routes. The App is intended as a supplementary navigation aid '
                    'and should not be relied upon as the sole means of navigation.',
              ),
              _buildSection(
                '7. Limitation of Liability',
                'To the maximum extent permitted by applicable law, the developers of TU World Map '
                    'shall not be liable for any indirect, incidental, special, consequential, or '
                    'punitive damages arising from your use of the App.',
              ),
              _buildSection(
                '8. Changes to Terms',
                'We reserve the right to modify these Terms of Service at any time. Continued use '
                    'of the App after any changes constitutes your acceptance of the new terms.',
              ),
              _buildSection(
                '9. Contact',
                'If you have any questions about these Terms of Service, please contact the '
                    'development team at the Faculty of Engineering, Thammasat University.',
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
