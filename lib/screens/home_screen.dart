import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Campus Map App',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),

          // 🗺️ MAIN BUTTON
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/map');
            },
            child: const Text('Open Campus Map'),
          ),

          const SizedBox(height: 15),

          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
            child: const Text('Search Location'),
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/favorite');
            },
            child: const Text('Favorite Places'),
          ),
        ],
      ),
    );
  }
}
