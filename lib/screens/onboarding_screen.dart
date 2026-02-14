import 'package:flutter/material.dart';
import 'main_navigation_screen.dart'; // adjust path if needed

class TUWorldMapOnboarding extends StatefulWidget {
  const TUWorldMapOnboarding({super.key});

  @override
  State<TUWorldMapOnboarding> createState() => _TUWorldMapOnboardingState();
}

class _TUWorldMapOnboardingState extends State<TUWorldMapOnboarding> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardPage> pages = [
    _OnboardPage(
      icon: Icons.location_pin,
      title: "Welcome to TU World Map",
      description:
          "Navigate your campus with ease. Find buildings, facilities, and points of interest all in one place.",
    ),
    _OnboardPage(
      icon: Icons.navigation,
      title: "Real-time Navigation",
      description:
          "Get turn-by-turn directions to any location on campus. Never get lost on your way to class again.",
    ),
    _OnboardPage(
      icon: Icons.menu_book,
      title: "Discover Campus Life",
      description:
          "Explore dining halls, libraries, study spaces, and more. Everything you need is at your fingertips.",
      showButton: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "TU World Map",
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = pages[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          page.icon,
                          size: 80,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 32),

                        Text(
                          page.title,
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        Text(
                          page.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        if (page.showButton) ...[
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const MainNavigationScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text("Acknowledge"),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentPage == index ? 32 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String description;
  final bool showButton;

  _OnboardPage({
    required this.icon,
    required this.title,
    required this.description,
    this.showButton = false,
  });
}
