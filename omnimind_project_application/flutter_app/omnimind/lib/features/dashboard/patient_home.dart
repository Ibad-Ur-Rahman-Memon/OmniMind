// lib/features/dashboard/patient_home.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_providers.dart';
import '../../features/auth/login_screen.dart';
import 'patient_dashboard.dart';
import '../assessments/assessment_screen.dart';
import '../chat/chat_screen.dart';
import '../diary/diary_screen.dart';
import '../exercises/exercises_library.dart';
import '../gamification/gamification_screen.dart';


class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _FloatingNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final List<AnimationController> iconControllers;
  final ValueChanged<int> onTap;
  final VoidCallback onLogout;

  static const _primary = Color(0xFF7C6FF7);
  static const _navBg = Color(0xFF0E1525);
  static const _navBorder = Color(0xFF1C2B45);

  const _FloatingNav({
    required this.currentIndex,
    required this.items,
    required this.iconControllers,
    required this.onTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          // Use hardEdge to avoid tiny edge-glow artifacts on desktop/web.
          clipBehavior: Clip.hardEdge,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: _navBg.withOpacity(0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _navBorder, width: 1),
                boxShadow: [
                  // Keep a single shadow; avoid stacked/transparent shadows that can bleed on clipped edges.
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ...List.generate(items.length, (i) {
                    final item = items[i];
                    final selected = i == currentIndex;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: AnimatedBuilder(
                          animation: iconControllers[i],
                          builder: (_, __) {
                            final bounce = Curves.elasticOut.transform(
                              iconControllers[i].value,
                            );
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  clipBehavior: Clip.hardEdge,
                                  // Keep indicator geometry stable; animate opacity to prevent edge artifacts.
                                  height: 3,
                                  width: 20,
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: _primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 250),
                                    opacity: selected ? 1 : 0,
                                    child: const SizedBox.shrink(),
                                  ),
                                ),
                                Transform.scale(
                                  scale: selected ? 1.0 + bounce * 0.15 : 1.0,
                                  child: Icon(
                                    selected ? item.activeIcon : item.icon,
                                    size: selected ? 22 : 20,
                                    color: selected
                                        ? _primary
                                        : const Color(0xFF4A5568),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: GoogleFonts.poppins(
                                    fontSize: selected ? 10 : 9,
                                    fontWeight:
                                        selected ? FontWeight.w600 : FontWeight.w400,
                                    color: selected
                                        ? _primary
                                        : const Color(0xFF4A5568),
                                  ),
                                  child: Text(item.label),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  }),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onLogout,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded,
                                size: 19, color: Color(0xFF3A4560)),
                            const SizedBox(height: 3),
                            Text(
                              'Exit',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: const Color(0xFF3A4560),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<AnimationController> _iconControllers;

  static const _bg = Color(0xFF07090F);

  static const _navItems = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat'),
    _NavItem(Icons.assignment_outlined, Icons.assignment_rounded, 'Assess'),
    _NavItem(Icons.self_improvement_outlined, Icons.self_improvement_rounded, 'Exercises'),
    _NavItem(Icons.book_outlined, Icons.book_rounded, 'Diary'),
    _NavItem(Icons.emoji_events_rounded, Icons.emoji_events_outlined, 'Progress'),
  ];


  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(
      _navItems.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        context.read<ChatProvider>().init(auth.user!.uid);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    _iconControllers[index].forward(from: 0);
    setState(() => _currentIndex = index);
  }

  void _onNavigateFromHome(int index) {
    // Ensure quick actions can switch tabs.
    _onTabTap(index);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final pages = <Widget>[
      PatientDashboard(onNavigateBottomNav: _onNavigateFromHome),
      const ChatScreen(),
      const AssessmentScreen(),
      const ExercisesLibrary(),
      const DiaryScreen(),
      const GamificationScreen(),
    ];


    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      floatingActionButton: _currentIndex == 4
          ? FloatingActionButton.extended(
              onPressed: () {
                final auth = context.read<AuthProvider>();
                final userId = auth.user?.uid ?? '';
                if (userId.isEmpty) return;
                showNewJournalSheet(context, userId: userId);
              },
              icon: const Icon(Icons.edit_rounded),
              label: const Text('New Journal'),
              backgroundColor: const Color(0xFF7C6FF7),
              foregroundColor: Colors.white,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [

          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),
          IndexedStack(index: _currentIndex, children: pages),
        ],
      ),
      bottomNavigationBar: _FloatingNav(
        currentIndex: _currentIndex,
        items: _navItems,
        iconControllers: _iconControllers,
        onTap: _onTabTap,
        onLogout: _confirmLogout,
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.redAccent, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign Out',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to sign out?',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF2E3A52)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Sign Out',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}

