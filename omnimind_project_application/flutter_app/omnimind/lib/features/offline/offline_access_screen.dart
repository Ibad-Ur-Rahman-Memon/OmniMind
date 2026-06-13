import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OfflineAccessScreen extends StatelessWidget {
  const OfflineAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emergency Toolkit',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF44336).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF44336).withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🆘', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text(
                      'If you are in crisis right now',
                      style: TextStyle(
                        color: Color(0xFFF44336),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _crisisButton(
                  context,
                  '🇵🇰 Umang Pakistan',
                  '0317-4288665',
                ),
                const SizedBox(height: 8),
                _crisisButton(
                  context,
                  '🚨 Emergency Pakistan',
                  '115',
                ),
                const SizedBox(height: 8),
                _crisisButton(
                  context,
                  '🇺🇸 USA Crisis Line',
                  '988',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildCard(
            '💨 4-7-8 Breathing',
            'Do this right now to calm down',
            const Color(0xFF00C9A7),
            Column(
              children: [
                '1. Breathe IN through nose — 4 counts',
                '2. HOLD your breath — 7 counts',
                '3. Breathe OUT through mouth — 8 counts',
                '4. Repeat this 4 times',
                '5. Notice your body getting calmer',
              ]
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: Color(0xFF00C9A7),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          _buildCard(
            '⚓ 5-4-3-2-1 Grounding',
            'Brings you back to the present',
            const Color(0xFF5B5FEF),
            Column(
              children: [
                '👁  5 things you can SEE',
                '✋  4 things you can FEEL',
                '👂  3 things you can HEAR',
                '👃  2 things you can SMELL',
                '👅  1 thing you can TASTE',
              ]
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Text(
                        s,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          _buildCard(
            '💙 Remember',
            'You are not alone',
            const Color(0xFF5B5FEF),
            Column(
              children: [
                'You are stronger than you think.',
                'This feeling will pass. Hold on.',
                'You have survived every difficult day so far.',
                'Asking for help is brave and right.',
                'You matter to the people around you.',
              ]
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          const Text(
                            '✨',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s,
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
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.07),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.wifi_rounded,
                  color: Color(0xFF5B5FEF),
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Want full AI support?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connect to internet and sign in to chat with Dr. Mira, complete assessments, and track your progress.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF5B5FEF),
                          Color(0xFF8B8FF5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Go to Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    String title,
    String subtitle,
    Color color,
    Widget content,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
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
          Divider(
            color: Colors.white.withOpacity(0.07),
            height: 1,
          ),
          content,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _crisisButton(
    BuildContext context,
    String label,
    String number,
  ) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('tel:$number');
        try {
          await launchUrl(uri);
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF44336).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF44336).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    number,
                    style: const TextStyle(
                      color: Color(0xFFF44336),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.call_rounded,
              color: Color(0xFFF44336),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

