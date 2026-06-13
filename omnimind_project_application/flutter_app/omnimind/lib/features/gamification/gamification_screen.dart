// lib/features/gamification/gamification_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_providers.dart';
import 'gamification_service.dart';

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen> {
  final _service = GamificationService();
  Map<String, dynamic> _streakData = {};
  List<String> _unlockedBadges = [];
  int _totalPoints = 0;
  bool _loading = true;
  DateTime? _lastUpdated;
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfReady());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfReady();
  }

  void _loadIfReady() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    if (_loadedUserId != user.uid) {
      _load(user.uid);
    }
  }

  Future<void> _load(String uid) async {
    setState(() {
      _loading = true;
    });

    // Initialize streaks document if it doesn't exist (first-time user)
    try {
      await _service.recordDailyLogin(uid);
    } catch (_) {
      // If it fails, continue; data fetch below will return defaults
    }

    final results = await Future.wait([
      _service.getStreakData(uid),
      _service.getUnlockedBadges(uid),
      _service.getTotalPoints(uid),
    ]);

    if (!mounted) return;

    setState(() {
      _streakData = results[0] as Map<String, dynamic>;
      _unlockedBadges = results[1] as List<String>;
      _totalPoints = results[2] as int;
      _loadedUserId = uid;
      _loading = false;
      _lastUpdated = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF5B5FEF)),
            )
          : CustomScrollView(slivers: [
              // Header
              SliverAppBar(
                expandedHeight: 160,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1A1A4E),
                          Color(0xFF2D1B69),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 8),
                          const Text(
                            'Your Progress',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$_totalPoints points',
                            style: const TextStyle(
                              color: Color.fromRGBO(255, 255, 255, 0.7),
                              fontSize: 14,
                            ),
                          ),
                          if (_lastUpdated != null)
                            Text(
                              'Updated ${_formatTimeAgo(_lastUpdated!)}',
                                style: const TextStyle(
                                  color: Color.fromRGBO(255, 255, 255, 0.5),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Streak card
                    _buildStreakCard(),
                    const SizedBox(height: 16),
                    // Points summary
                    _buildPointsCard(),
                    const SizedBox(height: 16),
                    // Badges grid
                    _buildBadgesSection(),
                  ]),
                ),
              ),
            ]),
    );
  }

  Widget _buildStreakCard() {
    final current = _streakData['currentStreak'] as int? ?? 0;
    final longest = _streakData['longestStreak'] as int? ?? 0;
    final total = _streakData['totalDays'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2D1B69),
            Color(0xFF1A1A4E),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(91, 95, 239, 0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('🔥', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              'Daily Streak',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _streakStat('$current', 'Current\nStreak', '🔥'),
              _streakStat('$longest', 'Longest\nStreak', '⚡'),
              _streakStat('$total', 'Total\nDays', '📅'),
            ],
          ),
          const SizedBox(height: 16),
          // Week dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (i) {
              final active = i < current % 7;
              return Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFFF9800)
                      : const Color.fromRGBO(255, 255, 255, 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _streakStat(String value, String label, String emoji) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color.fromRGBO(255, 255, 255, 0.6),
          fontSize: 10,
        ),
      ),
    ]);
  }

  Widget _buildPointsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.07)),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFD166),
                Color(0xFFFF9800),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              '⭐',
              style: TextStyle(fontSize: 26),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_totalPoints Points',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Keep chatting and completing exercises to earn more!',
                style: TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Badges',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: GamificationService.badges.entries.map((e) {
            final unlocked = _unlockedBadges.contains(e.key);
            final badge = e.value;
            return Container(
              decoration: BoxDecoration(
                color: unlocked
                    ? const Color(0xFF2D1B69)
                    : const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: unlocked
                      ? const Color(0xFF5B5FEF)
                      : const Color.fromRGBO(255, 255, 255, 0.07),
                ),
                boxShadow: unlocked
                    ? [
                        const BoxShadow(
                          color: Color.fromRGBO(91, 95, 239, 0.3),
                          blurRadius: 10,
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    badge['emoji'] as String,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    badge['name'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: unlocked ? Colors.white : Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!unlocked)
                    const Text(
                      '🔒',
                      style: TextStyle(fontSize: 10),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 5) {
      return 'just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final month = monthNames[date.month - 1];
      return '${date.day} $month';
    }
  }
}

