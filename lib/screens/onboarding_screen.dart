import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'main_navigation_screen.dart'; // adjust path if needed

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

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
    return Scaffold(
      body: Container(
        // Subtle warm gradient background
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
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "TU World Map",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6D4C41), // Brighter brown
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.red.withOpacity(0.2),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // PageView
              Expanded(
                child: ScrollConfiguration(
                  behavior: AppScrollBehavior(),
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        if (event.scrollDelta.dy > 0) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        } else if (event.scrollDelta.dy < 0) {
                          _controller.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      }
                    },
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
                              // Warm icon with glow effect
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(
                                        0xFFEF5350,
                                      ).withOpacity(0.2), // Red glow
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  page.icon,
                                  size: 80,
                                  color: const Color(0xFFD32F2F), // Red
                                ),
                              ),
                              const SizedBox(height: 32),

                              Text(
                                page.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3E2723), // Very dark brown
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),

                              Text(
                                page.description,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF5D4037), // Dark warm brown
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),

                              if (page.showButton) ...[
                                const SizedBox(height: 32),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const MainNavigationScreen(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFFD32F2F,
                                    ), // Red
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    elevation: 4,
                                    shadowColor: Colors.red.withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text(
                                    "Acknowledge",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
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
                ),
              ),

              // Page indicators with warm colors
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
                            ? const Color(0xFFD32F2F) // Red
                            : const Color(
                                0xFFFFCDD2,
                              ).withOpacity(0.5), // Light red
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _currentPage == index
                            ? [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
