import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../calendar/presentation/calendar_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../../budget/presentation/budget_screen.dart';
import '../../fitness/presentation/gym_screen.dart';
import '../../journal/presentation/diary_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../auth/presentation/auth_provider.dart';
import 'home_screen.dart';
import 'navigation_state.dart';

class NavigationShell extends ConsumerWidget {
  const NavigationShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationIndexProvider);

    final List<Widget> screens = [
      const HomeScreen(),
      const CalendarScreen(),
      const TasksScreen(),
      const BudgetScreen(),
    ];

    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: const Color(0xFF22223F).withAlpha(100), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            ref.read(navigationIndexProvider.notifier).state = index;
          },
          backgroundColor: const Color(0xFF0A0A14),
          selectedItemColor: const Color(0xFF00E6FF),
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.house, size: 18),
              activeIcon: FaIcon(FontAwesomeIcons.house, size: 20),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.calendar, size: 18),
              activeIcon: FaIcon(FontAwesomeIcons.calendar, size: 20),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.listCheck, size: 18),
              activeIcon: FaIcon(FontAwesomeIcons.listCheck, size: 20),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.wallet, size: 18),
              activeIcon: FaIcon(FontAwesomeIcons.wallet, size: 20),
              label: 'Budget',
            ),
          ],
        ),
      ),
    );
  }
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: const Color(0xFF0E0E1B),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E0E1B), Color(0xFF07070F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'ease ash',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                  ),
                  const Text(
                    'Personal Self-Development',
                    style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              context,
              title: 'Dashboard Home',
              icon: FontAwesomeIcons.house,
              onTap: () {
                ref.read(navigationIndexProvider.notifier).state = 0;
                Navigator.pop(context);
              },
            ),
            _buildDrawerItem(
              context,
              title: 'Gym Log Tracker',
              icon: FontAwesomeIcons.dumbbell,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GymScreen()));
              },
            ),
            _buildDrawerItem(
              context,
              title: 'Daily Diary & Journal',
              icon: FontAwesomeIcons.bookOpen,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DiaryScreen()));
              },
            ),
            const Divider(color: Color(0xFF22223F)),
            _buildDrawerItem(
              context,
              title: 'App Settings',
              icon: FontAwesomeIcons.gear,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              },
            ),
            _buildDrawerItem(
              context,
              title: 'Log Out',
              icon: FontAwesomeIcons.rightFromBracket,
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
              },
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final displayColor = color ?? const Color(0xFF00E6FF);
    return ListTile(
      leading: FaIcon(icon, color: displayColor, size: 18),
      title: Text(
        title,
        style: TextStyle(color: color ?? Colors.white, fontSize: 16),
      ),
      onTap: onTap,
    );
  }
}
