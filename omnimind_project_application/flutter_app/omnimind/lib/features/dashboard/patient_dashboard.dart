import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_providers.dart';

class PatientDashboard extends StatelessWidget {
  final ValueChanged<int>? onNavigateBottomNav;

  const PatientDashboard({super.key, this.onNavigateBottomNav});

  int _days(DateTime? dt) {
    if (dt == null) return 1;
    return DateTime.now().difference(dt).inDays + 1;
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final prog = context.watch<ProgressProvider>();
    final user = auth.user;

    final name = user?.name ?? 'Friend';

    final greeting = _greeting();
    final messages = prog.progress?.turnCount ?? 0;
    final exercises = prog.progress?.exercisesDone.length ?? 0;
    final days = _days(user?.createdAt);

    final emotionCounts = prog.progress?.emotionCounts;

    return RefreshIndicator(
      color: const Color(0xFF5B5FEF),
      backgroundColor: const Color(0xFF07090F),
      onRefresh: () async {
        final chat = context.read<ChatProvider>();
        final sessionId = chat.sessionId;
        if (sessionId != null) {
          await prog.refresh(sessionId);
        }
      },
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          children: [
            _buildHeader(
              greeting: greeting,
              name: name,
              messages: messages,
              exercises: exercises,
              days: days,
            ),
            const SizedBox(height: 16),
            _buildMoodSelector(),
            const SizedBox(height: 16),
            _buildQuoteCard(),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 16),
            _buildEmotionTrends(emotionCounts),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String greeting,
    required String name,
    required int messages,
    required int exercises,
    required int days,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A4E),
            Color(0xFF2D1B69),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $name',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statPill('Messages', '$messages'),
              const SizedBox(width: 10),
              _statPill('Exercises', '$exercises'),
              const SizedBox(width: 10),
              _statPill('Days', '$days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How are you feeling?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moodOption('😔', 'Rough'),
              _moodOption('😟', 'Low'),
              _moodOption('😐', 'Okay'),
              _moodOption('🙂', 'Good'),
              _moodOption('😊', 'Great'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moodOption(String emoji, String label) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuoteCard() {
    final quotes = [
      "You don't have to control your thoughts.\nYou just have to stop letting them control you.",
      'Mental health is not a destination,\nbut a process.',
      "It's okay to not be okay.",
      'Healing is not linear.\nBe patient with yourself.',
      'The bravest thing you can do\nis ask for help.',
    ];

    final quote = quotes[DateTime.now().day % quotes.length];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF00897B)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text(
            '💚',
            style: TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quote,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.6,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    const glass = Color(0xFF0F172A);
    const border = Color(0x33FFFFFF);
    const textPrimary = Color(0xFFF1F5F9);
    const textSecondary = Color(0xFFCBD5E1);

    final actions = [
      {
        'title': 'Chat with Dr. Mira',
        'subtitle': 'Start session',
        'from': const Color(0xFF4455FF),
        'to': const Color(0xFF7A6CFF),
        'glow': const Color(0xFF7A6CFF),
        'navIndex': 1,
      },
      {
        'title': 'Breathe',
        'subtitle': 'Calm exercise',
        'from': const Color(0xFF2EAD9B),
        'to': const Color(0xFF66CDBB),
        'glow': const Color(0xFF4EC7B4),
        'navIndex': 3,
      },
      {
        'title': 'Assess',
        'subtitle': 'Check scores',
        'from': const Color(0xFFFFBE7A),
        'to': const Color(0xFFFFC85A),
        'glow': const Color(0xFFFFC85A),
        'navIndex': 2,
      },
      {
        'title': 'Journal',
        'subtitle': 'Write thoughts',
        'from': const Color(0xFFCB7E9C),
        'to': const Color(0xFFDA8CAA),
        'glow': const Color(0xFFDA8CAA),
        'navIndex': 4,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: actions.map((a) {
            final title = a['title'] as String;
            final subtitle = a['subtitle'] as String;
            final from = a['from'] as Color;
            final to = a['to'] as Color;
            final glow = a['glow'] as Color;
            final navIndex = a['navIndex'] as int;

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onNavigateBottomNav?.call(navIndex),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: glass,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: glow.withOpacity(0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            colors: [
                              from.withOpacity(0.22),
                              to.withOpacity(0.16),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -22,
                      right: -22,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: glow.withOpacity(0.18),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: textSecondary.withOpacity(0.90),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmotionTrends(Map<String, dynamic>? emotionCounts) {
    if (emotionCounts == null || emotionCounts.isEmpty) {
      return _trendCard(
        title: 'Emotion Trends',
        child: const Text(
          'No data yet.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    final entries = emotionCounts.entries
        .where((e) => e.value is num)
        .map((e) => MapEntry(e.key, e.value as num))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = entries.take(5).toList();
    final maxVal = top.map((e) => e.value).fold<num>(0, (p, e) => e > p ? e : p);

    return _trendCard(
      title: 'Emotion Trends',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: top.map((e) {
          final ratio = maxVal <= 0 ? 0.0 : (e.value / maxVal).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.key,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 10,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.10),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: c.maxWidth * ratio,
                            height: 10,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF5B5FEF), Color(0xFF00C9A7)],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _trendCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

