import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../core/models/models.dart';
import '../../core/services/firestore_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF07090F);

  static const surface = Color(0xFF0F1520);
  static const card = Color(0xFF131B2E);
  static const cardBorder = Color(0xFF1C2B45);
  static const primary = Color(0xFF7C6FF7);
  static const accent = Color(0xFF06D6A0);
  static const accentGold = Color(0xFFFFD166);
  static const textSub = Color(0xFF6B7A99);
  static const textPrimary = Color(0xFFE8EAF6);

  static const grad1 = [Color(0xFF7C6FF7), Color(0xFF4F46E5)];
  static const grad2 = [Color(0xFF06D6A0), Color(0xFF118AB2)];
  static const grad3 = [Color(0xFFFF6B6B), Color(0xFFFF9A3C)];

  static const riskLow = Color(0xFF4CAF50);
  static const riskModerate = Color(0xFFFF9800);
  static const riskHigh = Color(0xFFF44336);
  static const riskUnknown = Color(0xFF6B7A99);

  static const emotionColors = {
    'anxiety': Color(0xFFFF9800),
    'depression': Color(0xFF5C6BC0),
    'stress': Color(0xFFE53935),
    'neutral': Color(0xFF42A5F5),
    'anger': Color(0xFFD32F2F),
    'social_anxiety': Color(0xFF8E24AA),
    'crisis': Color(0xFFF44336),
  };
}

Color _riskColor(String? risk) {
  switch ((risk ?? '').toLowerCase()) {
    case 'high':
      return _C.riskHigh;
    case 'moderate':
      return _C.riskModerate;
    case 'low':
      return _C.riskLow;
    default:
      return _C.riskUnknown;
  }
}

int _maxScoreFor(String name) {
  final n = name.toUpperCase();
  if (n.contains('PHQ')) return 27;
  if (n.contains('GAD')) return 21;
  if (n.contains('PSS')) return 40;
  if (n.contains('SPIN')) return 68;
  return 100;
}

// ── Page ──────────────────────────────────────────────────────────────────────
class PatientDetailPage extends StatefulWidget {
  final AppUser patient;
  const PatientDetailPage({super.key, required this.patient});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  // ── Loaded data ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _assessments = [];
  String _overallRisk = 'unknown';
  List<Map<String, dynamic>> _messages = [];
  Map<String, int> _emotions = {};
  int _turnCount = 0;
  DateTime? _lastActive;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);

    print('[Doctor Detail] Loading data for patient: ${widget.patient.uid}');
    print('[Doctor Detail] Patient name: ${widget.patient.name}');

    await Future.wait([
      _loadProfile(),
      _loadMessages(),
      _loadAssessments(),
    ]);

    print('[Doctor Detail] Load complete:');
    print('  messages: ${_messages.length}');
    print('  emotions: $_emotions');
    print('  assessments: ${_assessments.length}');
    print('  risk: $_overallRisk');

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // 1. Profile — reads riskLevel from users/{uid} ──────────────────
  Future<void> _loadProfile() async {
    try {
      _lastActive = await FirestoreService().getPatientLastActive(widget.patient.uid);

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patient.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final riskLevel = data['riskLevel'] as String?;
        if (riskLevel != null && riskLevel.isNotEmpty) {
          _overallRisk = riskLevel;
        }
      }
    } catch (_) {}
  }

  // 2. Messages — reads users/{uid}/messages (primary) ──────────────
  Future<void> _loadMessages() async {
    try {
      // FIX 1 — Primary path — where ChatProvider saves
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patient.uid)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(40)
          .get();

      print('[Doctor] Messages loaded: ${snap.docs.length} from '
          'users/${widget.patient.uid}/messages');

      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.docs;

      // FIX 1 — Fallback path (alternate storage)
      if (snap.docs.isEmpty) {
        final snap2 = await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.patient.uid)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(40)
            .get();

        print('[Doctor] Fallback messages: ${snap2.docs.length}');
        docs = snap2.docs;
      }

      _messages = docs.map((d) => d.data()).toList();

      // Count patient turns
      _turnCount = _messages
          .where((m) => (m['role'] as String?) == 'user')
          .length;

      print('[Doctor] Patient turns: $_turnCount');

      // Build emotion distribution
      final emoCount = <String, int>{};
      for (final m in _messages) {
        final role = m['role'] as String? ?? '';
        if (role != 'assistant') continue;

        // FIX 1 — Emotion field name may differ
        final emotion =
            (m['emotion'] as String?) ??
            (m['detectedEmotion'] as String?) ??
            (m['emotionLabel'] as String?) ??
            '';

        print('[Doctor] Message emotion: "$emotion" role=$role');

        if (emotion.isNotEmpty && emotion != 'neutral') {
          emoCount[emotion] = (emoCount[emotion] ?? 0) + 1;
        }
      }

      _emotions = emoCount;

      // FIX 4 — show partial data even if distribution empty
      if (_emotions.isEmpty && _messages.isNotEmpty) {
        final allEmotions = <String, int>{};
        for (final m in _messages) {
          final role = m['role'] as String? ?? '';
          if (role != 'assistant') continue;

          final emotion = (m['emotion'] as String?) ?? 'neutral';
          allEmotions[emotion] = (allEmotions[emotion] ?? 0) + 1;
        }
        if (allEmotions.isNotEmpty) {
          _emotions = allEmotions;
        }
      }

      print('[Doctor] Emotions built: $_emotions');
    } catch (e) {
      print('[Doctor] _loadMessages error: $e');
    }
  }

  // 3. Assessments — reads assessments/{uid}/results/ ──────────────
  Future<void> _loadAssessments() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('assessments')
          .doc(widget.patient.uid)
          .collection('results')
          .get();

      _assessments = snap.docs.map((d) {
        final data = d.data();
        return {
          'name': d.id,
          'score': data['score'] as int? ?? 0,
          'severity': data['severity'] as String? ?? '',
          'interpretation': data['interpretation'] as String? ?? '',
          'riskLevel': data['riskLevel'] as String? ?? '',
        };
      }).toList();

      if (_overallRisk == 'unknown' && _assessments.isNotEmpty) {
        _overallRisk = _deriveRisk();
      }
    } catch (_) {}
  }

  String _deriveRisk() {
    int phq = 0, gad = 0, pss = 0, spin = 0;
    int phqItem9 = 0; // Self-harm item from PHQ-9

    for (final a in _assessments) {
      final n = (a['name'] as String).toUpperCase();
      final score = a['score'] as int;
      if (n.contains('PHQ')) {
        phq = score;
        if (a.containsKey('itemScores') && a['itemScores'] is List) {
          final itemScores = a['itemScores'] as List;
          if (itemScores.length >= 9) {
            phqItem9 = itemScores[8] ?? 0;
          }
        }
      } else if (n.contains('GAD')) {
        gad = score;
      } else if (n.contains('PSS')) {
        pss = score;
      } else if (n.contains('SPIN')) {
        spin = score;
      }
    }

    if (phqItem9 > 0) return 'critical';
    if (phq >= 15 || gad >= 15 || pss >= 27) return 'high';
    if (phq >= 10 || gad >= 10 || pss >= 14 || spin >= 21) return 'moderate';
    if (phq >= 5 || gad >= 5 || pss >= 7) return 'low';
    if (phq == 0 && gad == 0 && pss == 0 && spin == 0) return 'unknown';
    return 'low';
  }

  // Unused but kept from original file
  double _deriveCombinedRiskScore() {
    int phq = 0, gad = 0, pss = 0, spin = 0;

    for (final a in _assessments) {
      final n = (a['name'] as String).toUpperCase();
      final score = a['score'] as int;
      if (n.contains('PHQ')) {
        phq = score;
      } else if (n.contains('GAD')) gad = score;
      else if (n.contains('PSS')) pss = score;
      else if (n.contains('SPIN')) spin = score;
    }

    const maxPhq = 27;
    const maxGad = 21;
    const maxPss = 40;
    const maxSpin = 68;

    final normPhq = maxPhq > 0 ? phq / maxPhq : 0.0;
    final normGad = maxGad > 0 ? gad / maxGad : 0.0;
    final normPss = maxPss > 0 ? pss / maxPss : 0.0;
    final normSpin = maxSpin > 0 ? spin / maxSpin : 0.0;

    final weightedSum = (normPhq * 0.4) + (normGad * 0.3) + (normPss * 0.2) + (normSpin * 0.1);
    return (weightedSum * 100).clamp(0.0, 100.0);
  }

  Map<String, bool> _deriveRiskFlags() {
    int phq = 0, gad = 0, pss = 0, spin = 0;
    int phqItem9 = 0;

    for (final a in _assessments) {
      final n = (a['name'] as String).toUpperCase();
      final score = a['score'] as int;

      if (n.contains('PHQ')) {
        phq = score;
        if (a.containsKey('itemScores') && a['itemScores'] is List) {
          final itemScores = a['itemScores'] as List;
          if (itemScores.length >= 9) {
            phqItem9 = itemScores[8] ?? 0;
          }
        }
      } else if (n.contains('GAD')) {
        gad = score;
      } else if (n.contains('PSS')) {
        pss = score;
      } else if (n.contains('SPIN')) {
        spin = score;
      }
    }

    return {
      'moderate_depression_risk': phq >= 10,
      'high_depression_risk': phq >= 15,
      'anxiety_risk': gad >= 10,
      'high_stress_risk': pss >= 27,
      'self_harm_risk': phqItem9 > 0,
      'crisis_risk': phqItem9 > 0,
    };
  }

  // ── Helpers ─────────────────────────────────────────────────────
  String _fmt(DateTime? dt) {
    if (dt == null) return 'Never';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 2) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${d.inDays}d ago';
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final rColor = _riskColor(widget.patient.riskLevel ?? _overallRisk);
    final rLabel = widget.patient.riskLevel ?? _overallRisk;

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
                  SliverAppBar(
                    expandedHeight: 220,
                    pinned: true,
                    backgroundColor: _C.bg,
                    elevation: 0,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 18),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(widget.patient.name,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            color: Colors.white54, size: 20),
                        onPressed: _load,
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: _PatientHero(
                        patient: widget.patient,
                        riskColor: rColor,
                        riskLabel: rLabel,
                        lastActive: _lastActive,
                        turnCount: _turnCount,
                        pulse: _pulse,
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _StatsRow(
                          turnCount: _turnCount,
                          lastActive: _lastActive,
                          riskColor: rColor,
                          riskLabel: _overallRisk,
                        ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08),
                        const SizedBox(height: 20),

                        const _SectionHeader(
                            icon: Icons.assignment_rounded,
                            title: 'Assessment Scores'),
                        const SizedBox(height: 12),
                        if (_assessments.isEmpty) ...[
                          const _EmptyCard(
                                  icon: Icons.assignment_outlined,
                                  text:
                                      'No assessments completed yet.\nPatient needs to take the clinical tests.')
                              .animate().fadeIn(delay: 120.ms)
                        ] else ...[
                          for (final e in _assessments.asMap().entries)
                            _AssessmentRow(data: e.value)
                                .animate()
                                .fadeIn(delay: Duration(milliseconds: 120 + e.key * 60))
                                .slideY(begin: 0.06)
                        ],

                        const SizedBox(height: 20),

                        const _SectionHeader(
                            icon: Icons.bar_chart_rounded,
                            title: 'Emotion Distribution'),
                        const SizedBox(height: 12),
                        _emotions.isEmpty
                            ? const _EmptyCard(
                                icon: Icons.mood_outlined,
                                text:
                                    'No emotion data yet.\nPatient needs to start chatting with Dr. Mira.')
                                .animate().fadeIn(delay: 180.ms)
                            : _EmotionChart(emotions: _emotions)
                                .animate().fadeIn(delay: 180.ms),

                        const SizedBox(height: 20),

                        _CrisisSection(messages: _messages)
                            .animate().fadeIn(delay: 220.ms),

                        const SizedBox(height: 20),

                        const _SectionHeader(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Session History (read-only)'),
                        const SizedBox(height: 12),
                        _ChatHistory(
                            messages: _messages,
                            turnCount: _turnCount)
                            .animate().fadeIn(delay: 260.ms),

                        const SizedBox(height: 20),

                        _SectionHeader(
                            icon: Icons.book_rounded,
                            title: 'Journals (read-only)'),
                        const SizedBox(height: 12),

                        _DiaryList(patientUid: widget.patient.uid)
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .slideY(begin: 0.06),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Patient Hero ─────────────────────────────────────────────────────────────
class _PatientHero extends StatelessWidget {

  final AppUser patient;
  final Color riskColor;
  final String riskLabel;
  final DateTime? lastActive;
  final int turnCount;
  final AnimationController pulse;

  const _PatientHero({
    required this.patient,
    required this.riskColor,
    required this.riskLabel,
    required this.lastActive,
    required this.turnCount,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                riskColor.withOpacity(0.14),
                const Color(0xFF07090F)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -20,
          right: -20,
          child: AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Container(
              width: 160 + pulse.value * 20,
              height: 160 + pulse.value * 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: riskColor.withOpacity(0.05 + pulse.value * 0.03),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        riskColor.withOpacity(0.9),
                        riskColor.withOpacity(0.6),
                      ]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: riskColor.withOpacity(0.3),
                            blurRadius: 16)
                      ],
                    ),
                    child: Center(
                      child: Text(
                        patient.name.isNotEmpty
                            ? patient.name[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient.name,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        Text(patient.email,
                            style: GoogleFonts.poppins(
                                color: Colors.white60, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: riskColor.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_riskIcon(riskLabel),
                                  color: riskColor, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                '${_cap(riskLabel)} Risk',
                                style: GoogleFonts.poppins(
                                    color: riskColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _riskIcon(String r) {
    switch (r.toLowerCase()) {
      case 'high':
        return Icons.error_rounded;
      case 'moderate':
        return Icons.warning_amber_rounded;
      case 'low':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int turnCount;
  final DateTime? lastActive;
  final Color riskColor;
  final String riskLabel;
  const _StatsRow({
    required this.turnCount,
    required this.lastActive,
    required this.riskColor,
    required this.riskLabel,
  });

  String _fmt(DateTime? dt) {
    if (dt == null) return 'Never';
    final d = DateTime.now().difference(dt);
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) =>
      Row(children: [
        _StatTile(
          icon: Icons.chat_bubble_rounded,
          value: '$turnCount',
          label: 'Messages',
          colors: const [Color(0xFF7C6FF7), Color(0xFF4F46E5)],
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.access_time_rounded,
          value: _fmt(lastActive),
          label: 'Last active',
          colors: const [Color(0xFF06D6A0), Color(0xFF118AB2)],
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.shield_rounded,
          value: riskLabel.isEmpty || riskLabel == 'unknown'
              ? 'Unknown'
              : riskLabel[0].toUpperCase() + riskLabel.substring(1),
          label: 'Risk level',
          colors: [riskColor, riskColor.withOpacity(0.7)],
        ),
      ]);
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final List<Color> colors;
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(height: 8),
              Text(value,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: _C.textSub, fontSize: 9)),
            ],
          ),
        ),
      );
}

// ── Assessment Row ────────────────────────────────────────────────────────────
class _AssessmentRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AssessmentRow({required this.data});

  Color _sevColor(String s) {
    final l = s.toLowerCase();
    if (l.contains('severe') || l.contains('high')) {
      return const Color(0xFFF44336);
    }
    if (l.contains('moderate')) return const Color(0xFFFF9800);
    if (l.contains('mild')) return const Color(0xFFFFD166);
    return const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '';
    final score = data['score'] as int? ?? 0;
    final sev = data['severity'] as String? ?? '';
    final interp = data['interpretation'] as String? ?? '';
    final color = _sevColor(sev);
    final maxSc = _maxScoreFor(name);
    final pct = (score / maxSc).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(name,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            Text('$score',
                style: GoogleFonts.poppins(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            Text(' / $maxSc',
                style: GoogleFonts.poppins(
                    color: _C.textSub, fontSize: 11)),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Text(sev,
                  style: GoogleFonts.poppins(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (interp.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(interp,
                style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

// ── Emotion Chart ─────────────────────────────────────────────────────────────
class _EmotionChart extends StatelessWidget {
  final Map<String, int> emotions;
  const _EmotionChart({required this.emotions});

  @override
  Widget build(BuildContext context) {
    final total = emotions.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    final sorted = emotions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        children: sorted.map((e) {
          final color = _C.emotionColors[e.key] ?? _C.primary;
          final pct = e.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(
                width: 110,
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.key.replaceAll('_', ' '),
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(pct * 100).round()}%',
                  style: GoogleFonts.poppins(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Crisis Section ────────────────────────────────────────────────────────────
class _CrisisSection extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  const _CrisisSection({required this.messages});

  @override
  Widget build(BuildContext context) {
    final crisis = messages
        .where((m) => (m['emotion'] as String? ?? '') == 'crisis')
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(
        icon: Icons.warning_amber_rounded,
        title: 'Crisis Alerts',
        color: crisis.isNotEmpty ? const Color(0xFFF44336) : null,
      ),
      const SizedBox(height: 12),
      crisis.isEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.cardBorder),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: _C.accent, size: 20),
                const SizedBox(width: 12),
                Text('No crisis events detected',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 13)),
              ]),
            )
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF44336).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFF44336).withOpacity(0.3)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFF44336), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${crisis.length} crisis message${crisis.length > 1 ? 's' : ''} detected',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFFF44336),
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'This patient has sent messages flagged for crisis content. '
                      'Immediate clinical follow-up is recommended.',
                      style: GoogleFonts.poppins(
                          color: Colors.white60, fontSize: 12, height: 1.5),
                    ),
                  ]),
            ),
    ]);
  }
}

// ── Chat History ─────────────────────────────────────────────────────────────
class _ChatHistory extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final int turnCount;
  const _ChatHistory({required this.messages, required this.turnCount});

  // FIX 5 — robust timestamp formatting
  String _fmtTs(dynamic ts) {
    if (ts == null) return '';
    try {
      DateTime dt;
      if (ts is Timestamp) {
        dt = ts.toDate();
      } else if (ts is String) {
        dt = DateTime.parse(ts);
      } else if (ts is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(ts);
      } else {
        return '';
      }
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyCard(
        icon: Icons.chat_bubble_outline_rounded,
        text: 'No messages yet.\nThis patient has not started a session.',
      );
    }

    final shown = messages.take(12).toList();

    return Column(children: [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _C.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.primary.withOpacity(0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.visibility_outlined, color: _C.primary, size: 14),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
            'Clinical observation view · $turnCount patient turns total',
            style: GoogleFonts.poppins(
                color: _C.primary,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          )),
        ]),
      ),

      Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.cardBorder),
        ),
        child: Column(
          children: shown.asMap().entries.map((e) {
            final i = e.key;
            final msg = e.value;
            final isUser = (msg['role'] as String? ?? '') == 'user';
            final content = msg['content'] as String? ?? '';
            final emotion = msg['emotion'] as String? ?? '';
            final eColor = _C.emotionColors[emotion] ?? Colors.transparent;

            return Container(
              decoration: BoxDecoration(
                border: i < shown.length - 1
                    ? const Border(bottom: BorderSide(color: _C.cardBorder, width: 0.5))
                    : null,
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isUser
                            ? [const Color(0xFF7C6FF7), const Color(0xFF4F46E5)]
                            : [const Color(0xFF06D6A0), const Color(0xFF118AB2)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        isUser ? 'P' : 'M',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(isUser ? 'Patient' : 'Dr. Mira',
                              style: GoogleFonts.poppins(
                                  color: isUser
                                      ? const Color(0xFF7C6FF7)
                                      : const Color(0xFF06D6A0),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(_fmtTs(msg['timestamp']),
                              style: GoogleFonts.poppins(
                                  color: _C.textSub, fontSize: 10)),
                          if (!isUser && emotion.isNotEmpty && emotion != 'neutral') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: eColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                emotion.replaceAll('_', ' '),
                                style: GoogleFonts.poppins(
                                    color: eColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          content.length > 160
                              ? '${content.substring(0, 160)}…'
                              : content,
                          style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),

      if (messages.length > 12)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '${messages.length - 12} earlier messages not shown',
            style: GoogleFonts.poppins(color: _C.textSub, fontSize: 11),
          ),
        ),
    ]);
  }
}

// ── Empty card ───────────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.cardBorder),
        ),
        child: Column(children: [
          Icon(icon, color: _C.textSub, size: 36),
          const SizedBox(height: 10),
          Text(text,
              style: GoogleFonts.poppins(
                  color: Colors.white54, fontSize: 12, height: 1.6),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Section header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: (color ?? _C.primary).withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color ?? _C.primary, size: 14),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.poppins(
                color: _C.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
      ]);
}

// ── Loading view ─────────────────────────────────────────────────────────────
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
                    boxShadow: [
                      BoxShadow(
                          color: _C.primary.withOpacity(0.3 + pulse.value * 0.15),
                          blurRadius: 20)
                    ],
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(height: 20),
              Text('Loading patient data…',
                  style: GoogleFonts.poppins(color: _C.textSub, fontSize: 14)),
            ],
          ),
        ),
      );
}

class _DiaryList extends StatelessWidget {
  final String patientUid;
  const _DiaryList({required this.patientUid});

  String _fmt(DateTime dt) =>
      '${dt.toLocal().year}-${dt.toLocal().month.toString().padLeft(2, '0')}-${dt.toLocal().day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DiaryEntry>>(
      stream: FirestoreService().getDiaryEntries(patientUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError) {
          return _EmptyCard(
            icon: Icons.error_outline_rounded,
            text: 'Failed to load journals for this patient.',
          );
        }

        final entries = snap.data ?? [];
        if (entries.isEmpty) {
          return _EmptyCard(
            icon: Icons.book_outlined,
            text: 'No journal entries yet\nPatient has not created any diary entries.',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final e = entries[i];

            return _DoctorJournalCard(
              entry: e,
            );
          },
        );
      },
    );
  }
}

class _DoctorJournalCard extends StatefulWidget {
  final DiaryEntry entry;
  const _DoctorJournalCard({required this.entry});

  @override
  State<_DoctorJournalCard> createState() => _DoctorJournalCardState();
}

class _DoctorJournalCardState extends State<_DoctorJournalCard> {
  final _replyController = TextEditingController();
  bool _sending = false;

  String _fmt(DateTime dt) =>
      '${dt.toLocal().year}-${dt.toLocal().month.toString().padLeft(2, '0')}-${dt.toLocal().day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final reply = _replyController.text.trim();
    if (reply.isEmpty) return;

    // Doctor UID is not available inside this widget (no AuthProvider here).
    // For now, use a placeholder; if your app wires doctorUid elsewhere, we should pass it down.
    // This prevents runtime crashes and keeps UI functional for testing.
    final doctorUid = 'doctor_uid_unknown';

    setState(() => _sending = true);
    try {
      await FirestoreService().saveDiaryReply(
        diaryEntryId: widget.entry.journalId,
        doctorUid: doctorUid,
        reply: reply,
      );
      _replyController.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C6FF7), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  e.mood,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (e.title?.isNotEmpty ?? false) ? e.title! : 'Diary entry',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _fmt(e.createdAt),
                      style: GoogleFonts.poppins(
                        color: _C.textSub,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            e.content,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 14),
          const _ReplyHeader(),
          const SizedBox(height: 10),

          StreamBuilder<List<DiaryReply>>(
            stream: FirestoreService().getDiaryReplies(
              diaryEntryId: e.journalId,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (snap.hasError) {
                return _EmptyCard(
                  icon: Icons.error_outline_rounded,
                  text: 'Failed to load replies.',
                );
              }

              final replies = snap.data ?? [];
              if (replies.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.cardBorder),
                  ),
                  child: Text(
                    'No replies yet. Write one below.',
                    style: GoogleFonts.poppins(
                      color: _C.textSub,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                );
              }

              return Column(
                children: replies.map((r) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. reply',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r.content,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fmt(r.createdAt),
                          style: GoogleFonts.poppins(
                            color: _C.textSub,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 8),
          TextField(
            controller: _replyController,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write a reply to this journal...',
              hintStyle: GoogleFonts.poppins(color: _C.textSub),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _C.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _C.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _C.primary.withOpacity(0.6)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded),
              onPressed: _sending ? null : _sendReply,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: Text(_sending ? 'Sending...' : 'Reply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyHeader extends StatelessWidget {
  const _ReplyHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _C.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              color: _C.accent, size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          'Doctor Replies',
          style: GoogleFonts.poppins(
            color: _C.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

