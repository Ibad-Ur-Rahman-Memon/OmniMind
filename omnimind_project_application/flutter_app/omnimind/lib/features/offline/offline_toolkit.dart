// lib/features/offline/offline_toolkit.dart
import 'package:flutter/material.dart';

class OfflineToolkitScreen extends StatelessWidget {
  const OfflineToolkitScreen({super.key});

  static const _breathingSteps = [
    '1. Sit comfortably and close your eyes.',
    '2. Breathe IN through nose for 4 counts.',
    '3. HOLD your breath for 7 counts.',
    '4. Breathe OUT through mouth for 8 counts.',
    '5. Repeat this cycle 4 times.',
    '6. Notice how your body feels calmer.',
  ];

  static const _groundingSteps = [
    '👁 Name 5 things you can SEE right now.',
    '✋ Notice 4 things you can FEEL/TOUCH.',
    '👂 Identify 3 things you can HEAR.',
    '👃 Notice 2 things you can SMELL.',
    '👅 Notice 1 thing you can TASTE.',
    '✅ Take one slow breath. You are safe.',
  ];

  static const _crisisNumbers = [
    {
      'country': 'Pakistan',
      'name': 'Umang Helpline',
      'number': '0317-4288665',
      'emoji': '🇵🇰',
    },
    {
      'country': 'Pakistan',
      'name': 'Rozan Counseling',
      'number': '051-2890505',
      'emoji': '🇵🇰',
    },
    {
      'country': 'Emergency',
      'name': 'Pakistan Emergency',
      'number': '115',
      'emoji': '🚨',
    },
    {
      'country': 'USA',
      'name': '988 Crisis Lifeline',
      'number': '988',
      'emoji': '🇺🇸',
    },
    {
      'country': 'UK',
      'name': 'Samaritans',
      'number': '116 123',
      'emoji': '🇬🇧',
    },
  ];

  static const _motivationalQuotes = [
    'You are stronger than you think.',
    'This feeling will pass. Hold on.',
    'You deserve support and kindness.',
    'Asking for help is brave.',
    'One breath at a time.',
    'You matter to the people around you.',
    'It is okay to not be okay.',
    'Small steps still move you forward.',
    'You have survived every hard day so far.',
    'Your mental health is worth fighting for.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0B4F6C),
                      Color(0xFF01BAEF),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          '🛡 Offline Toolkit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Works without internet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Crisis numbers
                _buildSection(
                  '🆘 Crisis Helplines',
                  'Available 24/7 — free to call',
                  _buildCrisisNumbers(),
                ),
                const SizedBox(height: 16),
                // 4-7-8 breathing
                _buildSection(
                  '💨 4-7-8 Breathing Exercise',
                  'Calms anxiety in 2 minutes',
                  _buildStepList(
                      _breathingSteps, const Color(0xFF00C9A7)),
                ),
                const SizedBox(height: 16),
                // Grounding 54321
                _buildSection(
                  '⚓ 5-4-3-2-1 Grounding',
                  'Anchors you to the present',
                  _buildStepList(
                      _groundingSteps, const Color(0xFF5B5FEF)),
                ),
                const SizedBox(height: 16),
                // Motivational quotes
                _buildSection(
                  '💪 Motivational Reminders',
                  'Read these when you feel low',
                  _buildQuotesList(),
                ),
                const SizedBox(height: 16),
                // Warning signs
                _buildSection(
                  '⚠️ When to Seek Help',
                  'Signs that need attention',
                  _buildWarningSigns(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String subtitle, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            color: Color(0xFF1C2B45),
            height: 1,
          ),
          content,
        ],
      ),
    );
  }

  Widget _buildCrisisNumbers() {
    return Column(
      children: _crisisNumbers.map((n) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Text(
                n['emoji']!,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n['name']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      n['country']!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C9A7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF00C9A7).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  n['number']!,
                  style: const TextStyle(
                    color: Color(0xFF00C9A7),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepList(List<String> steps, Color color) {
    return Column(
      children: steps
          .asMap()
          .entries
          .map((e) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildQuotesList() {
    return Column(
      children: _motivationalQuotes
          .map((q) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        q,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildWarningSigns() {
    final signs = [
      ['😔', 'Feeling hopeless for 2+ weeks'],
      ['😴', 'Unable to sleep or sleeping too much'],
      ['🍽', 'Significant changes in appetite'],
      ['💭', 'Intrusive or scary thoughts'],
      ['👥', 'Withdrawing from all social contact'],
      ['⚠️', 'Thoughts of self-harm or suicide'],
    ];

    return Column(
      children: signs
          .map((s) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Text(
                      s[0],
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s[1],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

