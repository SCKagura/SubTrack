import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/dashboard_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/subscription_list_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/category_management_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/history_screen.dart';
import 'package:subtrack/src/features/settings/presentation/settings_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/calendar_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 2; // Default to Dashboard (index 2)

  final _pages = [
    const SubscriptionListScreen(),
    const CalendarScreen(),
    const DashboardScreen(),
    const HistoryScreen(),
    const CategoryManagementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SubTrack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list), label: 'List'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, size: 32),
            label: 'Dashboard',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
        ],
      ),
    );
  }
}
