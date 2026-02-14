import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    // Print to console in debug mode for visibility
    if (kDebugMode) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    }
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Map App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialRoute: '/',
      home: const OnboardingScreen(),
    );
  }
}
