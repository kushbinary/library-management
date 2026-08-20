import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'members_screen.dart';
import 'settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MembersScreen(),
    const Scaffold(body: Center(child: Text("Reports (Coming Soon)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = isDark ? const Color(0xFF0F172A) : Colors.white; // match deep navy
    final activeColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA);
    final inactiveColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBgColor,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: activeColor,
          unselectedItemColor: inactiveColor,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), activeIcon: Icon(Icons.dashboard_rounded, size: 28), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), activeIcon: Icon(Icons.people_alt_rounded, size: 28), label: 'Members'),
            BottomNavigationBarItem(icon: Icon(Icons.insert_chart_rounded), activeIcon: Icon(Icons.insert_chart_rounded, size: 28), label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), activeIcon: Icon(Icons.settings_rounded, size: 28), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
