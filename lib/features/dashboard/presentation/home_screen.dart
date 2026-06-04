import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/secure_storage_service.dart';
import '../../journal/presentation/diary_screen.dart';
import '../../fitness/presentation/gym_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'navigation_state.dart';
import '../../auth/presentation/auth_provider.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final startingBalance = ref.watch(startingBalanceProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final auth = ref.watch(authProvider);
    final email = auth.email ?? '';
    String displayName = 'User';
    if (auth.username != null && auth.username!.isNotEmpty) {
      displayName = auth.username!;
    } else if (email.isNotEmpty) {
      if (email.contains('@')) {
        final prefix = email.split('@')[0];
        if (prefix.isNotEmpty) {
          displayName = prefix[0].toUpperCase() + prefix.substring(1);
        }
      }
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00E6FF))),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            data: (txsList) {
              double totalIncome = 0.0;
              double totalExpense = 0.0;

              for (final tx in txsList) {
                if (tx.isExpense) {
                  totalExpense += tx.amount;
                } else {
                  totalIncome += tx.amount;
                }
              }

              final double currentBalance = startingBalance + totalIncome - totalExpense;

              return RefreshIndicator(
                color: const Color(0xFF00E6FF),
                backgroundColor: const Color(0xFF131326),
                onRefresh: () async {
                  await ref.read(startingBalanceProvider.notifier).loadStartingBalance();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premium Greeting Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome Back,',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.white60,
                                    ),
                              ),
                              Text(
                                displayName,
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                      color: Colors.white,
                                    ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.circleUser, size: 28, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SettingsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Premium Daily Quote Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.glassCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FaIcon(FontAwesomeIcons.quoteLeft, color: Color(0xFF00E6FF), size: 18),
                            const SizedBox(height: 8),
                            Text(
                              'Your self-development is the best investment you can make.',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            const Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                '- AI Assistant',
                                style: TextStyle(color: Color(0xFF8F88FF), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Main Features Quick access grid
                      Text(
                        'Quick Access Modules',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 16),

                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.4,
                        children: [
                          _buildQuickCard(
                            context,
                            title: 'Gym Tracker',
                            subtitle: 'Log workouts',
                            icon: FontAwesomeIcons.dumbbell,
                            color: const Color(0xFF00E676),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const GymScreen()),
                              );
                            },
                          ),
                          _buildQuickCard(
                            context,
                            title: 'Daily Diary',
                            subtitle: 'AI Sentiment',
                            icon: FontAwesomeIcons.bookOpen,
                            color: const Color(0xFF6C63FF),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const DiaryScreen()),
                              );
                            },
                          ),
                          _buildQuickCard(
                            context,
                            title: 'My Calendar',
                            subtitle: 'Events & Meetings',
                            icon: FontAwesomeIcons.calendarDays,
                            color: const Color(0xFF00E6FF),
                            onTap: () {
                              ref.read(navigationIndexProvider.notifier).state = 1;
                            },
                          ),
                          _buildQuickCard(
                            context,
                            title: 'Task Board',
                            subtitle: 'Habits & Checklists',
                            icon: FontAwesomeIcons.listCheck,
                            color: const Color(0xFFFF8A00),
                            onTap: () {
                              ref.read(navigationIndexProvider.notifier).state = 2;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Interactive Balance Overview Card
                      InkWell(
                        onTap: () {
                          ref.read(navigationIndexProvider.notifier).state = 3;
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: AppTheme.glassCardDecoration(
                            borderClr: const Color(0xFF00E6FF).withAlpha(40),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'ACCOUNT BALANCE',
                                    style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5),
                                  ),
                                  const FaIcon(FontAwesomeIcons.wallet, color: Color(0xFF00E6FF), size: 16),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₹ ${currentBalance.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.arrow_upward, color: Color(0xFF00E676), size: 16),
                                  Text(' ₹${totalIncome.toStringAsFixed(0)} Income', style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.arrow_downward, color: Color(0xFFFF5252), size: 16),
                                  Text(' ₹${totalExpense.toStringAsFixed(0)} Expense', style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FaIcon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
