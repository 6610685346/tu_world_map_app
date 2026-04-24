import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:tu_world_map_app/services/recent_location_service.dart';
import 'package:tu_world_map_app/services/favorite_service.dart';
import 'package:tu_world_map_app/services/settings_service.dart';
import 'package:tu_world_map_app/services/graph_loader.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    // Print to console in debug mode for visibility
    if (kDebugMode) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    }
  });

  // Load persisted data before running the app
  await RecentLocationService().loadFromPrefs();
  await FavoriteService().loadFromPrefs();
  await SettingsService().loadFromPrefs();

  // Kick off graph load in the background; NavigationService awaits it
  // lazily on first route request, so startup isn't blocked on this.
  unawaited(GraphLoader.ensureLoaded());

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
      home: SettingsService().firstLaunch ? const TUWorldMapOnboarding() : const MainNavigationScreen(),
    );
  }
}
