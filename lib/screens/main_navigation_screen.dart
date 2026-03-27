import 'package:expense_tracker/screens/home/dashboard_screen.dart';
import 'package:expense_tracker/screens/family/family_screen.dart';
import 'package:expense_tracker/screens/group/groups_screen.dart';
import 'package:expense_tracker/screens/analytics/analytics_screen.dart';
import 'package:expense_tracker/screens/profile/profile_screen.dart';
import 'package:flutter/material.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const FamilyScreen(),
    const GroupsScreen(),
    const AnalyticsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.family_restroom_rounded), label: 'Family'),
          NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
