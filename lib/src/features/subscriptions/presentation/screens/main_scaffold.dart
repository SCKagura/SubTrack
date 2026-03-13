import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:subtrack/src/features/authentication/data/user_profile_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/data_migration_service.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/dashboard_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/subscription_list_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/history_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/calendar_screen.dart';
import 'package:subtrack/src/features/settings/presentation/settings_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/analytics_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/family_members_screen.dart';
import 'package:subtrack/src/features/authentication/presentation/profile_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0; // Default to Dashboard (index 0)

  List<Widget> get _pages => [
    const DashboardScreen(),
    const SubscriptionListScreen(),
    const AnalyticsScreen(),
    const CalendarScreen(),
    const FamilyMembersScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Trigger migration check after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRunMigration();
    });
  }

  Future<void> _checkAndRunMigration() async {
    try {
      final service = DataMigrationService();
      if (await service.needsMigration()) {
        await service.migrate();
      }
    } catch (e) {
      debugPrint('Migration error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SubTrack'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final userAsync = ref.watch(userProfileProvider);
              final supabaseUser = Supabase.instance.client.auth.currentUser;
              final photoUrl =
                  supabaseUser?.userMetadata?['avatar_url'] as String?;

              return userAsync.when(
                data: (profile) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            profile.displayName ?? profile.email.split('@')[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            profile.email,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        backgroundColor: const Color(0xFFC67C00),
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(
                                (profile.displayName?.isNotEmpty == true
                                        ? profile.displayName![0]
                                        : profile.email.isNotEmpty
                                        ? profile.email[0]
                                        : 'U')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: SafeArea(child: _pages[_currentIndex]),
      ),
      drawer: NavigationDrawer(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          Navigator.pop(context); // Close drawer
        },
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Text('เมนู', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: Text('แดชบอร์ด'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.list),
            label: Text('การสมัครสมาชิก'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: Text('วิเคราะห์'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: Text('ปฏิทิน'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: Text('ครอบครัว'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.history),
            label: Text('ประวัติ'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('โปรไฟล์'),
          ),
        ],
      ),
    );
  }
}
