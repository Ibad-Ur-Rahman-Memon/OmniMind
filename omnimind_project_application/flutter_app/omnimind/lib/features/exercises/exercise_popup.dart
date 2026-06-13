import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/models/models.dart';

class ExercisePopup extends StatefulWidget {
  final ExerciseSuggestion exercise;
  final VoidCallback? onComplete;

  const ExercisePopup({
    super.key,
    required this.exercise,
    this.onComplete,
  });

  @override
  State<ExercisePopup> createState() => _ExercisePopupState();
}

class _ExercisePopupState extends State<ExercisePopup>
    with SingleTickerProviderStateMixin {
  int _step = -1; // -1 = intro
  late AnimationController _pageAnim;
  late Animation<double> _fadeAnim;
  bool _completed = false;

  static const _bg = Color(0xFF0B1120);
  static const _card = Color(0xFF131B2E);
  static const _teal = Color(0xFF00C9A7);
  static const _tealAccent2 = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();

    _pageAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnim = CurvedAnimation(
      parent: _pageAnim,
      curve: Curves.easeInOut,
    );

    _pageAnim.forward();
  }

  @override
  void dispose() {
    _pageAnim.dispose();
    super.dispose();
  }

  int get totalSteps => widget.exercise.steps.length;
  bool get isIntro => _step == -1;
  bool get isLastStep => _step == totalSteps - 1;

  Future<void> _next() async {
    await _pageAnim.reverse();

    setState(() {
      if (isIntro) {
        _step = 0;
      } else if (isLastStep) {
        _completed = true;
      } else {
        _step++;
      }
    });

    _pageAnim.forward();
  }

  Future<void> _prev() async {
    await _pageAnim.reverse();

    setState(() {
      _step = _step > 0 ? _step - 1 : -1;
    });

    _pageAnim.forward();
  }

  void _finish() {
    Navigator.of(context).pop();
    widget.onComplete?.call();
  }

  Color get _border => Colors.white.withOpacity(0.08);
  Color get _handleBar => Colors.white.withOpacity(0.2);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // App is always dark, but keep isDark fallback.
    final bg = isDark ? _bg : _bg;
    final card = isDark ? _card : _card;

    return Container(
      margin: const EdgeInsets.only(top: 70),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(34),
        ),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 14),
            width: 52,
            height: 5,
            decoration: BoxDecoration(
              color: _handleBar,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Expanded(
            child: _completed
                ? _buildCompleted(bg: bg)
                : _buildContent(bg: bg, card: card),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required Color bg,
    required Color card,
  }) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            /// ICON
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [_teal, _tealAccent2],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _teal.withOpacity(0.25),
                    blurRadius: 28,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                _getExerciseIcon(),
                size: 42,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 22),

            /// TITLE
            Text(
              widget.exercise.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),

            const SizedBox(height: 10),

            /// TAGLINE
            Text(
              widget.exercise.tagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 18),

            /// DURATION badge (teal)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _teal.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: _teal,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.exercise.durationMin} Minutes',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _teal,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            /// PROGRESS dots
            if (!isIntro) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  totalSteps,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _step ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: i <= _step
                          ? _teal
                          : Colors.white.withOpacity(0.2), // inactive dot
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Step ${_step + 1} of $totalSteps',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
            ],

            /// CONTENT BOX (dark card)
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: card, // Fix 1
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _border),
                ),
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: isIntro
                        ? widget.exercise.introMessage
                        : widget.exercise.steps[_step],
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        fontSize: 16,
                        height: 1.8,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                      strong: const TextStyle(
                        fontSize: 16,
                        color: _teal, // Fix 2
                        fontWeight: FontWeight.w700,
                        height: 1.8,
                      ),
                      em: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                        height: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// BUTTONS
            Row(
              children: [
                if (!isIntro)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _prev,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: Colors.white54, // Fix 3
                      ),
                      label: const Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                if (!isIntro) const SizedBox(width: 14),

                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_teal, _tealAccent2], // Fix 3
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isIntro
                                ? 'Start Exercise'
                                : isLastStep
                                    ? 'Complete'
                                    : 'Continue',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleted({required Color bg}) {
    return Container(
      width: double.infinity,
      color: bg, // Fix 4
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Trophy emoji container w/ gradient + glow
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_teal, _tealAccent2],
              ),
              boxShadow: [
                BoxShadow(
                  color: _teal.withOpacity(0.35),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '🏆',
                style: TextStyle(fontSize: 62),
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Exercise Complete!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white, // Fix 4
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Excellent work. Take a moment to notice how your body and mind feel now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.7,
              color: Colors.white.withOpacity(0.6), // Fix 4
            ),
          ),

          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF5B5FEF), Color(0xFF8B8FF5)], // Fix 4
                ),
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              child: ElevatedButton(
                onPressed: _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Return to Session',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getExerciseIcon() {
    switch (widget.exercise.id) {
      case 'breathing_478':
        return Icons.air_rounded;
      case 'grounding_54321':
        return Icons.anchor_rounded;
      case 'thought_record':
        return Icons.edit_note_rounded;
      case 'behavioral_activation':
        return Icons.directions_walk_rounded;
      case 'pmr':
        return Icons.spa_rounded;
      case 'worry_postponement':
        return Icons.schedule_rounded;
      default:
        return Icons.self_improvement_rounded;
    }
  }
}
