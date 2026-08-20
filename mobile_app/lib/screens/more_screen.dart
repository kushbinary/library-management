import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.insert_chart_rounded),
            title: const Text('Reports & Analytics'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text('Settings'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
    );
  }
}
