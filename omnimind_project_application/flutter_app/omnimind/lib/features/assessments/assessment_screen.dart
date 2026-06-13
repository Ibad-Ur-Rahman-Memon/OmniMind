// lib/features/assessments/assessment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/providers/app_providers.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _C {
  static const bg          = Color(0xFF07090F);
  static const surface     = Color(0xFF0F1520);
  static const card        = Color(0xFF131B2E);
  static const cardBorder  = Color(0xFF1C2B45);
  static const primary     = Color(0xFF7C6FF7);
  static const accent      = Color(0xFF06D6A0);
  static const accentGold  = Color(0xFFFFD166);
  static const riskLow     = Color(0xFF4CAF50);
  static const riskModerate= Color(0xFFFF9800);
  static const riskHigh    = Color(0xFFF44336);
  static const textSub     = Color(0xFF6B7A99);
  static const textPrimary = Color(0xFFE8EAF6);

  static const grad1 = [Color(0xFF7C6FF7), Color(0xFF4F46E5)];
  static const grad2 = [Color(0xFF06D6A0), Color(0xFF118AB2)];
  static const grad3 = [Color(0xFFFF6B6B), Color(0xFFFF9A3C)];
  static const grad4 = [Color(0xFFFFD166), Color(0xFFFF9A3C)];
}

class _SeverityBand {
  final int min, max;
  final String label, hex, interpretation;
  const _SeverityBand(this.min, this.max, this.label, this.hex, this.interpretation);
}

// ── Clinical assessment definitions (PHQ-9, GAD-7, PSS-10, SPIN) ─────────────
final List<_AssessmentDef> _assessmentDefs = [
  _AssessmentDef(
    name: 'PHQ-9', fullName: 'Patient Health Questionnaire-9',
    domain: 'Depression', maxScore: 27,
    questions: [
      'Little interest or pleasure in doing things?',
      'Feeling down, depressed, or hopeless?',
      'Trouble falling/staying asleep, or sleeping too much?',
      'Feeling tired or having little energy?',
      'Poor appetite or overeating?',
      'Feeling bad about yourself — or that you are a failure?',
      'Trouble concentrating on things?',
      'Moving/speaking slowly, or being fidgety/restless?',
      'Thoughts that you would be better off dead?',
    ],
    options: List.filled(9, ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    scores: List.filled(9, [0, 1, 2, 3]),
    bands: const [
      _SeverityBand(0,  4,  'Minimal',           '#4CAF50', 'Minimal depressive symptoms. Self-monitoring and healthy lifestyle recommended.'),
      _SeverityBand(5,  9,  'Mild',               '#8BC34A', 'Mild depression. Watchful waiting and supportive counseling recommended.'),
      _SeverityBand(10, 14, 'Moderate',           '#FFC107', 'Moderate depression. CBT or structured therapy is recommended.'),
      _SeverityBand(15, 19, 'Moderately Severe',  '#FF9800', 'Active treatment with pharmacotherapy and/or psychotherapy recommended.'),
      _SeverityBand(20, 27, 'Severe',             '#F44336', 'Severe depression. Immediate professional evaluation required.'),
    ],
  ),
  _AssessmentDef(
    name: 'GAD-7', fullName: 'Generalized Anxiety Disorder-7',
    domain: 'Anxiety', maxScore: 21,
    questions: [
      'Feeling nervous, anxious, or on edge?',
      'Not being able to stop or control worrying?',
      'Worrying too much about different things?',
      'Trouble relaxing?',
      'Being so restless it is hard to sit still?',
      'Becoming easily annoyed or irritable?',
      'Feeling afraid as if something awful might happen?',
    ],
    options: List.filled(7, ['Not at all', 'Several days', 'More than half the days', 'Nearly every day']),
    scores: List.filled(7, [0, 1, 2, 3]),
    bands: const [
      _SeverityBand(0,  4,  'Minimal',  '#4CAF50', 'Minimal anxiety. Self-care and monitoring appropriate.'),
      _SeverityBand(5,  9,  'Mild',     '#8BC34A', 'Mild anxiety. Relaxation techniques and monitoring recommended.'),
      _SeverityBand(10, 14, 'Moderate', '#FFC107', 'Moderate anxiety. CBT or structured therapy recommended.'),
      _SeverityBand(15, 21, 'Severe',   '#F44336', 'Severe anxiety. Immediate professional evaluation required.'),
    ],
  ),
  _AssessmentDef(
    name: 'PSS-10', fullName: 'Perceived Stress Scale-10',
    domain: 'Stress', maxScore: 40,
    questions: [
      'Upset because of something that happened unexpectedly?',
      'Unable to control the important things in your life?',
      'Felt nervous and stressed?',
      'Felt confident about your ability to handle problems? (R)',
      'Things were going your way? (R)',
      'Unable to cope with all the things you had to do?',
      'Able to control irritations in your life? (R)',
      'Felt on top of things? (R)',
      'Angered because of things outside your control?',
      'Difficulties piling up so high you cannot overcome them?',
    ],
    options: List.filled(10, ['Never', 'Almost never', 'Sometimes', 'Fairly often', 'Very often']),
    scores: [
      [0, 1, 2, 3, 4], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4],
      [4, 3, 2, 1, 0], // reversed
      [4, 3, 2, 1, 0], // reversed
      [0, 1, 2, 3, 4],
      [4, 3, 2, 1, 0], // reversed
      [4, 3, 2, 1, 0], // reversed
      [0, 1, 2, 3, 4], [0, 1, 2, 3, 4],
    ],
    bands: const [
      _SeverityBand(0,  13, 'Low Stress',      '#4CAF50', 'Perceived stress is low. Maintain healthy coping strategies.'),
      _SeverityBand(14, 26, 'Moderate Stress',  '#FFC107', 'Moderate stress. Stress management techniques recommended.'),
      _SeverityBand(27, 40, 'High Stress',      '#F44336', 'High perceived stress. Professional support strongly recommended.'),
    ],
  ),
  _AssessmentDef(
    name: 'SPIN', fullName: 'Social Phobia Inventory',
    domain: 'Social Anxiety', maxScore: 68,
    questions: [
      'Fear of people in authority?',
      'Embarrassment causes me to avoid doing things or speaking to people?',
      'Troubled by blushing in front of people?',
      'Avoid talking to people I don\'t know?',
      'Being criticized scares me a lot?',
      'Avoid doing things because I fear others will notice?',
      'Talking with people I don\'t know well?',
      'Would do anything to avoid being criticized?',
      'Heart palpitations when around other people?',
      'Avoid giving speeches or talks?',
      'Avoid going to parties?',
      'Would go out of my way to avoid meeting new people?',
      'Uncomfortable sweating when around people when anxious?',
      'Afraid when meeting people for the first time?',
      'Embarrassment or looking stupid — among worst fears?',
      'Avoid speaking to authority figures?',
      'Trembling or shaking in front of others?',
    ],
    options: List.filled(17, ['Not at all', 'A little bit', 'Somewhat', 'Very much', 'Extremely']),
    scores: List.filled(17, [0, 1, 2, 3, 4]),
    bands: const [
      _SeverityBand(0,  20, 'No Phobia',       '#4CAF50', 'No significant social anxiety detected.'),
      _SeverityBand(21, 30, 'Mild',             '#8BC34A', 'Mild social phobia. Psychoeducation and gradual exposure recommended.'),
      _SeverityBand(31, 40, 'Moderate',         '#FFC107', 'Moderate social phobia. CBT with exposure therapy recommended.'),
      _SeverityBand(41, 50, 'Severe',           '#FF9800', 'Severe social phobia. Structured therapy and medication consideration.'),
      _SeverityBand(51, 68, 'Very Severe',      '#F44336', 'Very severe social phobia. Urgent professional evaluation required.'),
    ],
  ),
];

int _maxScoreFor(String name) {
  final n = name.toUpperCase();
  if (n.contains('PHQ'))  return 27;
  if (n.contains('GAD'))  return 21;
  if (n.contains('PSS'))  return 40;
  if (n.contains('SPIN')) return 68;
  return 100;
}

Color _hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

// ── _AssessmentDef class ─────────────────────────────────────────────────────
class _AssessmentDef {
  final String name;
  final String fullName;
  final String domain;
  final int maxScore;
  final List<String> questions;
  final List<List<String>> options;
  final List<List<int>> scores;
  final List<_SeverityBand> bands;

  const _AssessmentDef({
    required this.name,
    required this.fullName,
    required this.domain,
    required this.maxScore,
    required this.questions,
    required this.options,
    required this.scores,
    required this.bands,
  });

  String severity(int total) {
    for (final b in bands) {
      if (total >= b.min && total <= b.max) return b.label;
    }
    return bands.last.label;
  }

  String colorHex(int total) {
    for (final b in bands) {
      if (total >= b.min && total <= b.max) return b.hex;
    }
    return bands.last.hex;
  }

  String interpretation(int total) {
    for (final b in bands) {
      if (total >= b.min && total <= b.max) return b.interpretation;
    }
    return bands.last.interpretation;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});
  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen>
    with SingleTickerProviderStateMixin {
  // Saved results from Firestore: name → {score, severity, interpretation, ...}
  Map<String, Map<String, dynamic>> _results = {};
  bool _loading = true;
  String? _saveError;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    final chat = context.read<ChatProvider>();
    chat.onMessageReceived = () {
      if (mounted) {
        _load();
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    try {
      final chat = context.read<ChatProvider>();
      chat.onMessageReceived = null;
    } catch (_) {}
    _pulse.dispose();
    super.dispose();
  }

  // ── Load from Firestore ─────────────────────────────────────────────────────
  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      uid = FirebaseAuth.instance.currentUser?.uid;
    }
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('assessments')
          .doc(uid)
          .collection('results')
          .get();

      final results = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        results[doc.id] = doc.data();
      }

      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[Assessment] Load error: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load: $e'),
          backgroundColor: _C.riskHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── Save answer to Firestore with error handling ────────────────────────────
  Future<void> _saveAnswer(
      String assessmentName, int questionIndex, int score) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[Assessment] Save skipped: uid is null');
      if (mounted) {
        setState(() => _saveError = 'Not logged in. Please sign in again.');
      }
      return;
    }

    try {
      final def = _assessmentDefs.firstWhere((d) => d.name == assessmentName);

      final existing = Map<String, dynamic>.from(
          _results[assessmentName] ?? <String, dynamic>{});
      final answers = Map<String, int>.from(
          (existing['answers'] as Map?)?.cast<String, int>() ?? {});
      answers['q$questionIndex'] = score;

      // Recalculate total score
      int total = 0;
      for (int i = 0; i < def.questions.length; i++) {
        total += answers['q$i'] ?? 0;
      }

      final sev    = def.severity(total);
      final interp = def.interpretation(total);
      final risk   = _riskFromSeverity(sev);

      final data = <String, dynamic>{
        'assessmentName': assessmentName,
        'score':          total,
        'severity':       sev,
        'interpretation': interp,
        'answers':        answers,
        'riskLevel':      risk,
        'completedAt':    FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('assessments')
          .doc(uid)
          .collection('results')
          .doc(assessmentName)
          .set(data).timeout(const Duration(seconds: 10));

      // Update user doc for doctor dashboard
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastAssessment':         assessmentName,
        'lastAssessmentSeverity': sev,
        'lastAssessmentScore':    total,
        'riskLevel':              risk,
        'lastAssessmentAt':       FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      // Update local state
      if (mounted) {
        final displayData = Map<String, dynamic>.from(data);
        displayData.remove('completedAt');
        setState(() {
          _results[assessmentName] = displayData;
          _saveError = null;
        });
      }
    } catch (e) {
      debugPrint('[Assessment] Save error: $e');
      if (mounted) {
        setState(() {
          _saveError = 'Failed to save: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: ${e.toString().substring(0, e.toString().length.clamp(0, 120))}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  String _riskFromSeverity(String sev) {
    final s = sev.toLowerCase();
    if (s.contains('severe') || s.contains('high') || s == 'very severe') {
      return 'high';
    }
    if (s.contains('moderate')) return 'moderate';
    return 'low';
  }

  // ── Overall risk from all results ─────────────────────────────────────────
  String get _displayRisk {
    int phq = 0, gad = 0, pss = 0, spin = 0;

    for (final a in _results.entries) {
      final n = a.key.toUpperCase();
      final score = (a.value['score'] as int?) ?? 0;

      if (n.contains('PHQ')) {
        phq = score;
      } else if (n.contains('GAD')) {
        gad = score;
      } else if (n.contains('PSS')) {
        pss = score;
      } else if (n.contains('SPIN')) {
        spin = score;
      }
    }

    if (phq >= 15 || gad >= 15 || pss >= 27) return 'high';
    if (phq >= 10 || gad >= 10 || pss >= 14 || spin >= 20) return 'moderate';
    if (phq >= 5 || gad >= 5 || pss >= 7 || spin >= 10) return 'low';
    if (phq + gad + pss + spin == 0) return 'unknown';
    return 'low';
  }

  @override
  Widget build(BuildContext context) {
    final overallRisk = _displayRisk;
    final doneCount   = _results.length;

    return Consumer<ChatProvider>(builder: (context, chat, _) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: _loading
            ? _LoadingView(pulse: _pulse)
            : RefreshIndicator(
                color: _C.primary,
                backgroundColor: _C.card,
                onRefresh: _load,
                child: CustomScrollView(
                  slivers: [
                    // ── Hero SliverAppBar ─────────────────────────────────
                    SliverAppBar(
                      expandedHeight: doneCount > 0 ? 280 : 240,
                      pinned: true,
                      stretch: true,
                      automaticallyImplyLeading: false,
                      backgroundColor: _C.bg,
                      elevation: 0,
                      toolbarHeight: 70,
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.parallax,
                        background: _HeroHeader(
                          risk: overallRisk,
                          done: doneCount,
                          total: _assessmentDefs.length,
                          results: _results,
                          pulse: _pulse,
                          onRefresh: _load,
                        ),
                      ),
                    ),

                    // ── Content ───────────────────────────────────────────
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([

                          // Error banner if save failed
                          if (_saveError != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _C.riskHigh.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _C.riskHigh.withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline,
                                    color: _C.riskHigh, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_saveError!,
                                      style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 12)),
                                ),
                              ]),
                            ),

                          // Auto-detect banner
                          _AutoDetectBanner()
                              .animate()
                              .fadeIn(delay: 100.ms)
                              .slideY(begin: 0.08),

                          const SizedBox(height: 20),

                          // Section header
                          _SectionHeader(
                              count: _assessmentDefs.length),
                          const SizedBox(height: 14),

                          // Assessment cards — one per test
                          ..._assessmentDefs.asMap().entries.map((e) {
                            final def    = e.value;
                            final saved  = _results[def.name];
                            return _AssessmentCard(
                              def:     def,
                              saved:   saved,
                              onAnswer: (qIdx, score) =>
                                  _saveAnswer(def.name, qIdx, score),
                            )
                                .animate()
                                .fadeIn(delay: Duration(
                                    milliseconds: 150 + e.key * 80))
                                .slideY(begin: 0.08);
                          }),

                          // Disclaimer
                          const SizedBox(height: 8),
                          _Disclaimer(),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      );
    });
  }
}

// ── Collapsed title bar ───────────────────────────────────────────────────────
class _CollapsedTitle extends StatelessWidget {
  final VoidCallback onRefresh;
  const _CollapsedTitle({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(width: 16),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: _C.grad1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(Icons.assignment_rounded,
            color: Colors.white, size: 14),
      ),
      const SizedBox(width: 10),
      Text('Assessments',
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w600)),
      const Spacer(),
      IconButton(
        icon: const Icon(Icons.refresh_rounded,
            color: Colors.white54, size: 20),
        onPressed: onRefresh,
      ),
      const SizedBox(width: 4),
    ],
  );
}

// ── Hero Header ───────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final String risk;
  final int done, total;
  final Map<String, Map<String, dynamic>> results;
  final AnimationController pulse;
  final VoidCallback onRefresh;

  const _HeroHeader({
    required this.risk, required this.done,
    required this.total, required this.results,
    required this.pulse, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, label, subtitle, bgColors) = switch (risk) {
      'low'      => (_C.riskLow,     Icons.check_circle_rounded, 'LOW RISK',
          'Minimal concerns detected', [const Color(0xFF0A2A1A), const Color(0xFF07090F)]),
      'moderate' => (_C.riskModerate, Icons.warning_amber_rounded, 'MODERATE RISK',
          'Regular check-ins recommended', [const Color(0xFF2A1A00), const Color(0xFF07090F)]),
      'high'     => (_C.riskHigh,    Icons.error_rounded, 'HIGH RISK',
          'Please consult a professional', [const Color(0xFF2A0A0A), const Color(0xFF07090F)]),
      _          => (_C.textSub,     Icons.psychology_outlined, 'NOT ASSESSED',
          'Complete the tests below to begin', [const Color(0xFF0F0A2A), const Color(0xFF07090F)]),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bgColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(top: -30, right: -30,
          child: AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Container(
              width: 180 + pulse.value * 25,
              height: 180 + pulse.value * 25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.06 + pulse.value * 0.03),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: _C.grad1),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [BoxShadow(
                          color: _C.primary.withOpacity(0.3), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.assignment_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text('Mental Assessments',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onRefresh,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white54, size: 18),
                    ),
                  ),
                ]),

                const Spacer(),

                // Risk display
                Row(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.3)),
                      boxShadow: [BoxShadow(
                          color: color.withOpacity(0.2), blurRadius: 16)],
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overall Risk',
                          style: GoogleFonts.poppins(
                              color: Colors.white54, fontSize: 11,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(label,
                          style: GoogleFonts.poppins(
                              color: color, fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      Text(subtitle,
                          style: GoogleFonts.poppins(
                              color: Colors.white60, fontSize: 12)),
                    ],
                  )),
                  // Circular completion
                  Column(children: [
                    CircularPercentIndicator(
                      radius: 32,
                      lineWidth: 5,
                      percent: total == 0 ? 0 : done / total,
                      progressColor: color,
                      backgroundColor: color.withOpacity(0.15),
                      circularStrokeCap: CircularStrokeCap.round,
                      center: Text('$done/$total',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Text('done', style: GoogleFonts.poppins(
                        color: _C.textSub, fontSize: 10)),
                  ]),
                ]),

                // Score pills
                if (results.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: results.entries.map((e) {
                        final score = e.value['score'] as int? ?? 0;
                        final def   = _assessmentDefs.firstWhere(
                            (d) => d.name == e.key,
                            orElse: () => _assessmentDefs.first);
                        final c = _hexColor(def.colorHex(score));
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 6, height: 6,
                                decoration: BoxDecoration(
                                    color: c, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('${e.key} · $score',
                                style: GoogleFonts.poppins(
                                    color: c, fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final int count;
  const _SectionHeader({required this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 3, height: 18,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: _C.grad1,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: Text('Clinical Assessments',
          style: GoogleFonts.poppins(
              color: _C.textPrimary, fontSize: 15,
              fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
          maxLines: 1),
    ),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.primary.withOpacity(0.2)),
      ),
      child: Text('$count validated tests',
          style: GoogleFonts.poppins(
              color: _C.primary, fontSize: 10,
              fontWeight: FontWeight.w600)),
    ),
  ]);
}

// ── Auto-detect banner ────────────────────────────────────────────────────────
class _AutoDetectBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_C.primary.withOpacity(0.12), _C.primary.withOpacity(0.04)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _C.primary.withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: _C.grad1),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [BoxShadow(
              color: _C.primary.withOpacity(0.3), blurRadius: 8)],
        ),
        child: const Icon(Icons.verified_rounded,
            color: Colors.white, size: 15),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DSM-5 Validated Clinical Tools',
              style: GoogleFonts.poppins(
                  color: _C.primary, fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            'PHQ-9 · GAD-7 · PSS-10 · SPIN — the same tools used by '
            'mental health professionals worldwide. Results sync to your '
            'psychologist\'s dashboard.',
            style: GoogleFonts.poppins(
                color: _C.primary.withOpacity(0.7),
                fontSize: 11, height: 1.4),
          ),
        ],
      )),
    ]),
  );
}

// ── Disclaimer ────────────────────────────────────────────────────────────────
class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded,
            color: Colors.white38, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'These assessments are clinically validated screening tools. '
            'Results are automatically shared with your assigned psychologist. '
            'They do not constitute a clinical diagnosis.',
            style: GoogleFonts.poppins(
                color: Colors.white38, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

// ── Assessment Card ───────────────────────────────────────────────────────────
class _AssessmentCard extends StatefulWidget {
  final _AssessmentDef def;
  final Map<String, dynamic>? saved;
  final void Function(int qIdx, int score) onAnswer;

  const _AssessmentCard({
    required this.def, required this.saved, required this.onAnswer});

  @override
  State<_AssessmentCard> createState() => _AssessmentCardState();
}

class _AssessmentCardState extends State<_AssessmentCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _sevColor(String sev) {
    final s = sev.toLowerCase();
    if (s.contains('severe') || s.contains('high') || s == 'very severe') {
      return _C.riskHigh;
    }
    if (s.contains('moderate')) return _C.riskModerate;
    if (s.contains('mild'))     return _C.accentGold;
    return _C.riskLow;
  }

  List<Color> _gradForDomain(String domain) {
    switch (domain.toLowerCase()) {
      case 'depression':    return [const Color(0xFF5C6BC0), const Color(0xFF3949AB)];
      case 'anxiety':       return [const Color(0xFFFF9800), const Color(0xFFF57C00)];
      case 'stress':        return _C.grad3;
      case 'social anxiety':return [const Color(0xFF8E24AA), const Color(0xFF6A1B9A)];
      default:              return _C.grad1;
    }
  }

  IconData _iconForDomain(String domain) {
    switch (domain.toLowerCase()) {
      case 'depression':    return Icons.cloud_outlined;
      case 'anxiety':       return Icons.air_rounded;
      case 'stress':        return Icons.whatshot_rounded;
      case 'social anxiety':return Icons.people_outline_rounded;
      default:              return Icons.psychology_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final def    = widget.def;
    final saved  = widget.saved;
    final score  = saved?['score']    as int?    ?? 0;
    final sev    = saved?['severity'] as String? ?? '';
    final interp = saved?['interpretation'] as String? ?? '';
    final savedAnswers = Map<String, int>.from(
        (saved?['answers'] as Map?)?.cast<String, int>() ?? {});

    final color  = sev.isNotEmpty ? _sevColor(sev) : _C.primary;
    final grad   = _gradForDomain(def.domain);
    final maxSc  = def.maxScore;
    final pct    = saved != null ? (score / maxSc).clamp(0.0, 1.0) : 0.0;
    final isDone = saved != null;
    final answeredCount = savedAnswers.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: _expanded ? color.withOpacity(0.45) : _C.cardBorder,
            width: _expanded ? 1.5 : 1),
        boxShadow: _expanded
            ? [BoxShadow(
                color: color.withOpacity(0.14),
                blurRadius: 20, offset: const Offset(0, 6))]
            : null,
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            setState(() => _expanded = !_expanded);
            _expanded ? _ctrl.forward() : _ctrl.reverse();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              // Left: fixed-width icon/circle
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularPercentIndicator(
                      radius: 32,
                      lineWidth: 4,
                      percent: pct,
                      progressColor: color,
                      backgroundColor: color.withOpacity(0.1),
                      circularStrokeCap: CircularStrokeCap.round,
                      center: const SizedBox.shrink(),
                    ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: grad),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: grad.first.withOpacity(0.35),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: Icon(
                        _iconForDomain(def.domain),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Center: expanded text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          def.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isDone && answeredCount == def.questions.length)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: _C.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      def.domain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _C.textSub,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      def.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _C.textSub.withOpacity(0.6),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (sev.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.25)),
                            ),
                            child: Text(
                              sev,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _C.textSub.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Not taken',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: _C.textSub,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$answeredCount/${def.questions.length} answered',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: _C.textSub,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right: score + dropdown arrow
              SizedBox(
                width: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isDone ? '$score' : '—',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: isDone ? color : _C.textSub,
                                height: 1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '/ $maxSc',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: _C.textSub,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _C.textSub,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),

        // ── Expanded ──────────────────────────────────────────────────────────
        SizeTransition(
          sizeFactor: _anim,
          child: Column(children: [
            Container(height: 1, color: _C.cardBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bar
                  if (isDone) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Score: $score / $maxSc',
                            style: GoogleFonts.poppins(
                                color: _C.textSub, fontSize: 11)),
                        Text('${(pct * 100).round()}% complete',
                            style: GoogleFonts.poppins(
                                color: color, fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 7,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Interpretation
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _C.cardBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _C.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                                Icons.info_outline_rounded,
                                color: _C.primary, size: 14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(interp,
                                style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 12, height: 1.6)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Questions header
                  Row(children: [
                    Text('Questions',
                        style: GoogleFonts.poppins(
                            color: _C.textPrimary, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _C.accent.withOpacity(0.25)),
                      ),
                      child: Text(
                        '$answeredCount / ${def.questions.length}',
                        style: GoogleFonts.poppins(
                            color: _C.accent, fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  // Questions
                  ...def.questions.asMap().entries.map((e) {
                    final i         = e.key;
                    final qText     = e.value;
                    final opts      = def.options[i];
                    final sc        = def.scores[i];
                    final answered  = savedAnswers['q$i'];

                    return _QuestionRow(
                      index:      i + 1,
                      text:       qText,
                      options:    opts,
                      scores:     sc,
                      answered:   answered,
                      onAnswer:   (score) => widget.onAnswer(i, score),
                    );
                  }),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Question Row ──────────────────────────────────────────────────────────────
class _QuestionRow extends StatelessWidget {
  final int index;
  final String text;
  final List<String> options;
  final List<int> scores;
  final int? answered;
  final void Function(int score) onAnswer;

  const _QuestionRow({
    required this.index, required this.text,
    required this.options, required this.scores,
    required this.answered, required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final isAnswered = answered != null;
    final answeredLabel = isAnswered
        ? options[scores.indexOf(answered!)]
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isAnswered ? _C.primary.withOpacity(0.06) : _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAnswered
              ? _C.primary.withOpacity(0.25)
              : _C.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Number badge
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: isAnswered
                      ? _C.primary.withOpacity(0.2)
                      : _C.cardBorder.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text('$index',
                    style: GoogleFonts.poppins(
                        color: isAnswered ? _C.primary : _C.textSub,
                        fontSize: 10, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w500, height: 1.4)),
              ),
              if (isAnswered)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 11, color: _C.primary),
                    const SizedBox(width: 4),
                    Text(answeredLabel ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: _C.primary,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: List.generate(options.length, (i) {
              final score    = scores[i];
              final selected = answered == score;
              return GestureDetector(
                onTap: () => onAnswer(score),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(colors: _C.grad1)
                        : null,
                    color: selected ? null : _C.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : _C.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: selected
                            ? _C.primary.withOpacity(0.3)
                            : Colors.transparent,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(options[i],
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: selected ? Colors.white : _C.textSub,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal)),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  final AnimationController pulse;
  const _LoadingView({required this.pulse});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _C.bg,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Container(
              width: 68 + pulse.value * 6,
              height: 68 + pulse.value * 6,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: _C.grad1),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(
                    color: _C.primary.withOpacity(0.3 + pulse.value * 0.15),
                    blurRadius: 20)],
              ),
              child: const Icon(Icons.assignment_rounded,
                  color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(height: 20),
          Text('Loading assessments…',
              style: GoogleFonts.poppins(
                  color: _C.textSub, fontSize: 14)),
        ],
      ),
    ),
  );
}