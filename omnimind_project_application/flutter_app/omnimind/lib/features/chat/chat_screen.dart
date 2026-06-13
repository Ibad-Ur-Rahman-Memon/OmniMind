// lib/features/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/services/api_service.dart';

import '../exercises/exercise_popup.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _C {
  static const bg          = Color(0xFF07090F);
  static const surface     = Color(0xFF0F1520);
  static const card        = Color(0xFF131B2E);
  static const cardBorder  = Color(0xFF1C2B45);
  static const primary     = Color(0xFF7C6FF7);
  static const accent      = Color(0xFF06D6A0);
  static const textSub     = Color(0xFF6B7A99);

  static const emotionColors = {
    'anxiety':        Color(0xFFFF9800),
    'depression':     Color(0xFF5C6BC0),
    'stress':         Color(0xFFE53935),
    'neutral':        Color(0xFF42A5F5),
    'anger':          Color(0xFFD32F2F),
    'social_anxiety': Color(0xFF8E24AA),
    'crisis':         Color(0xFFF44336),
  };
  static const emotionEmojis = {
    'anxiety':        '😰',
    'depression':     '😔',
    'stress':         '😣',
    'neutral':        '😐',
    'anger':          '😠',
    'social_anxiety': '😟',
    'crisis':         '🆘',
  };
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller   = TextEditingController();
  final _scrollCtrl   = ScrollController();
  bool _showScrollBtn = false;
  int  _lastMsgCount  = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final atBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200;
    if (_showScrollBtn == atBottom) {
      setState(() => _showScrollBtn = !atBottom);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (animated) {
        _scrollCtrl.animateTo(max,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      } else {
        _scrollCtrl.jumpTo(max);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    HapticFeedback.lightImpact();

    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();

    await chat.sendMessage(text, auth.user!.uid);

    if (!mounted) return;

    if (chat.error != null && chat.error!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(chat.error!.split('\n').first),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
      chat.clearError();
    }

    _scrollToBottom();

    if (chat.pendingExercise != null) {
      _showExercise(chat.pendingExercise!);
      chat.clearPendingExercise();
    }
  }

  Future<void> _markExerciseComplete(ChatProvider chat, String exerciseId) async {
    final auth = context.read<AuthProvider>();
    final sessionId = chat.sessionId;

    if (sessionId == null || sessionId.isEmpty) return;

    // If ApiService is reachable, mark completion in backend.
    // Errors are non-fatal for the UX.
    try {
      await ApiService().markExerciseComplete(sessionId, exerciseId);
    } catch (_) {
      // ignore
    }
  }

  void _showExercise(ExerciseSuggestion ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExercisePopup(
        exercise: ex,
        onComplete: () async {
          final auth = context.read<AuthProvider>();
          final chat = context.read<ChatProvider>();

          await _markExerciseComplete(chat, ex.id);

          await chat.sendMessage(
            ex.postPrompt,
            auth.user!.uid,
            postExercise: true,
          );

          _scrollToBottom();
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();

    // Scroll to bottom whenever message count increases
    if (chat.messages.length != _lastMsgCount) {
      _lastMsgCount = chat.messages.length;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(animated: true));
    }

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _ChatAppBar(
          isLoading: chat.isLoading,
          onNewSession: () async {
            final ok = await _confirmNewSession();
            if (ok == true && mounted) {
              await chat.startNewSession(auth.user!.uid);
            }
          },
          onInfo: _showInfo,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                chat.messages.isEmpty
                    ? _WelcomeView()
                    : ListView.builder(
                        key: ValueKey(chat.messages.length),
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(
                            16, 12, 16, 16),
                        itemCount: chat.messages.length,
                        itemBuilder: (_, i) => _MessageBubble(
                          msg: chat.messages[i],
                          onExerciseTap: chat.messages[i]
                                      .exerciseSuggestion !=
                                  null
                              ? () => _showExercise(chat
                                  .messages[i].exerciseSuggestion!)
                              : null,
                        )
                            .animate()
                            .fadeIn(duration: 250.ms)
                            .slideY(begin: 0.06),
                      ),
                if (_showScrollBtn)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _scrollToBottom,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _C.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color:
                                    _C.primary.withOpacity(0.4),
                                blurRadius: 12)
                          ],
                        ),
                        child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 22),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _InputBar(
            controller: _controller,
            isLoading: chat.isLoading,
            onSend: chat.isLoading ? () {} : _send,
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmNewSession() => showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: _C.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _C.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: _C.primary, size: 26),
                  ),
                  const SizedBox(height: 16),
                  Text('New Session',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'Starting a new session resets the conversation. '
                    'Your history is saved.',
                    style: GoogleFonts.poppins(
                        color: _C.textSub, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(
                              color: Color(0xFF2E3A52)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                        ),
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: Text('Cancel',
                            style: GoogleFonts.poppins(
                                fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                        ),
                        onPressed: () =>
                            Navigator.pop(context, true),
                        child: Text('Start New',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ]),
          ),
        ),
      );

  void _showInfo() => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: _C.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF7C6FF7),
                          Color(0xFF4F46E5)
                        ]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                          Icons.psychology_rounded,
                          color: Colors.white,
                          size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('About Dr. Mira',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 16),
                  const _InfoRow(Icons.smart_toy_rounded,
                      'Powered by LLaMA 3 8B via Groq with '
                      'RAG-enhanced DSM-5-TR clinical knowledge'),
                  const SizedBox(height: 10),
                  const _InfoRow(Icons.psychology_outlined,
                      'Uses CBT techniques, mindfulness, and '
                      'evidence-based therapeutic interventions'),
                  const SizedBox(height: 10),
                  const _InfoRow(
                    Icons.warning_amber_rounded,
                    'Not a substitute for professional psychiatric '
                    'care. In emergencies, contact your crisis line.',
                    color: AppColors.emotionStress,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Got it',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
          ),
        ),
      );
}

// ── Info Row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoRow(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? _C.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    color: color != null
                        ? color!.withOpacity(0.9)
                        : Colors.white70,
                    fontSize: 12,
                    height: 1.5)),
          ),
        ],
      );
}

// ── Chat AppBar ───────────────────────────────────────────────────────────────
class _ChatAppBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onNewSession;
  final VoidCallback onInfo;
  const _ChatAppBar({
    required this.isLoading,
    required this.onNewSession,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(
            bottom: BorderSide(color: _C.cardBorder, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF7C6FF7),
                        Color(0xFF4F46E5)
                      ]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _C.primary.withOpacity(0.35),
                            blurRadius: 12)
                      ],
                    ),
                    child: Center(
                      child: Text('M',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _C.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _C.surface, width: 2),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scaleXY(
                            begin: 1.0,
                            end: 1.3,
                            duration: 1000.ms,
                            curve: Curves.easeInOut)
                        .then()
                        .scaleXY(
                            begin: 1.3,
                            end: 1.0,
                            duration: 1000.ms),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. Mira',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    Row(children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin:
                            const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: isLoading
                              ? AppColors.emotionAnxiety
                              : _C.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        isLoading ? 'Typing...' : 'Online',
                        style: GoogleFonts.poppins(
                            color: isLoading
                                ? AppColors.emotionAnxiety
                                : _C.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_comment_outlined,
                    color: Colors.white54, size: 20),
                tooltip: 'New Session',
                onPressed: onNewSession,
              ),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded,
                    color: Colors.white54, size: 20),
                tooltip: 'About',
                onPressed: onInfo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Welcome View ──────────────────────────────────────────────────────────────
class _WelcomeView extends StatelessWidget {
  static const _starters = [
    "I've been feeling anxious lately",
    "I'm having trouble sleeping",
    "I feel overwhelmed with everything",
    "I want to talk about my feelings",
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFF7C6FF7),
                  Color(0xFF4F46E5)
                ]),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                      color: _C.primary.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8))
                ],
              ),
              child: const Icon(Icons.psychology_rounded,
                  size: 46, color: Colors.white),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(
                    begin: const Offset(0.7, 0.7),
                    curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text('Hello, I\'m Dr. Mira',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700))
                .animate()
                .fadeIn(delay: 150.ms)
                .slideY(begin: 0.2),
            const SizedBox(height: 10),
            Text(
              'I\'m your AI mental health companion.\n'
              'Share what\'s on your mind — I\'m here to listen,\n'
              'support, and guide you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: _C.textSub, fontSize: 14, height: 1.65),
            )
                .animate()
                .fadeIn(delay: 250.ms)
                .slideY(begin: 0.2),
            const SizedBox(height: 32),
            Row(children: [
              const Expanded(
                  child:
                      Divider(color: _C.cardBorder, thickness: 1)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Start with',
                    style: GoogleFonts.poppins(
                        color: _C.textSub, fontSize: 11)),
              ),
              const Expanded(
                  child:
                      Divider(color: _C.cardBorder, thickness: 1)),
            ]).animate().fadeIn(delay: 350.ms),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _starters.asMap().entries.map((e) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context
                        .read<ChatProvider>()
                        .sendMessage(e.value,
                            context.read<AuthProvider>().user!.uid);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _C.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: _C.primary.withOpacity(0.3),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send_rounded,
                            size: 12,
                            color: _C.primary.withOpacity(0.7)),
                        const SizedBox(width: 7),
                        Text(e.value,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(
                        delay: Duration(
                            milliseconds: 400 + e.key * 80))
                    .slideY(begin: 0.15);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final VoidCallback? onExerciseTap;
  const _MessageBubble({required this.msg, this.onExerciseTap});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;

    if (msg.status == MessageStatus.sending && !isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _MiraAvatar(),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: _C.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                border: Border.all(color: _C.cardBorder),
              ),
              child: const _TypingDots(),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: msg.content));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Copied',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: _C.card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ));
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 12,
          left: isUser ? 52 : 0,
          right: isUser ? 0 : 52,
        ),
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              _MiraAvatar(),
              const SizedBox(width: 8)
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (msg.crisisDetected)
                    Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF44336)
                            .withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFF44336)
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.warning_amber_rounded,
                                size: 13,
                                color: Color(0xFFF44336)),
                            const SizedBox(width: 5),
                            Text('Crisis Support Activated',
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: const Color(
                                        0xFFF44336),
                                    fontWeight:
                                        FontWeight.w600)),
                          ]),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF7C6FF7),
                                Color(0xFF4F46E5)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isUser ? null : _C.card,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft:
                            Radius.circular(isUser ? 20 : 4),
                        bottomRight:
                            Radius.circular(isUser ? 4 : 20),
                      ),
                      border: isUser
                          ? null
                          : Border.all(color: _C.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: isUser
                              ? _C.primary.withOpacity(0.25)
                              : Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: MarkdownBody(
                      data: msg.content,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isUser
                              ? Colors.white
                              : Colors.white.withOpacity(0.88),
                          height: 1.55,
                        ),
                        strong: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: isUser
                              ? Colors.white
                              : _C.primary,
                        ),
                        em: GoogleFonts.poppins(
                          fontStyle: FontStyle.italic,
                          color: isUser
                              ? Colors.white70
                              : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                  if (msg.exerciseSuggestion != null)
                    GestureDetector(
                      onTap: onExerciseTap,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [
                                Color(0xFF06D6A0),
                                Color(0xFF118AB2)
                              ]),
                          borderRadius:
                              BorderRadius.circular(14),
                          // ── FIXED: always provide shadow ──
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF06D6A0)
                                    .withOpacity(0.3),
                                blurRadius: 10.0,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                  Icons.self_improvement_rounded,
                                  size: 16,
                                  color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                '${msg.exerciseSuggestion!.name} · '
                                '${msg.exerciseSuggestion!.durationMin} min',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: Colors.white70),
                            ]),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isUser &&
                            msg.emotion.isNotEmpty &&
                            msg.emotion != 'neutral') ...[
                          _EmotionTag(msg.emotion),
                          const SizedBox(width: 6),
                        ],
                        Text(_fmt(msg.timestamp),
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: _C.textSub)),
                        if (isUser) ...[
                          const SizedBox(width: 4),
                          Icon(
                            msg.status ==
                                    MessageStatus.sending
                                ? Icons.access_time_rounded
                                : Icons.done_all_rounded,
                            size: 12,
                            color: msg.status ==
                                    MessageStatus.sending
                                ? _C.textSub
                                : _C.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Mira Avatar ───────────────────────────────────────────────────────────────
class _MiraAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF7C6FF7), Color(0xFF4F46E5)]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: _C.primary.withOpacity(0.3),
                blurRadius: 8)
          ],
        ),
        child: Center(
          child: Text('M',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      );
}

// ── Emotion Tag ───────────────────────────────────────────────────────────────
class _EmotionTag extends StatelessWidget {
  final String emotion;
  const _EmotionTag(this.emotion);

  @override
  Widget build(BuildContext context) {
    final color = _C.emotionColors[emotion] ?? _C.primary;
    final emoji = _C.emotionEmojis[emotion] ?? '';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text('$emoji ${emotion.replaceAll('_', ' ')}',
          style: GoogleFonts.poppins(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Typing Dots ── FIXED: prevent reverse() after dispose ─────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      3,
      (_) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400)),
    );
    _anims = _ctrls
        .map((c) => Tween<double>(begin: 0, end: -7).animate(
            CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
    _loop();
  }

  // ── FIXED: check mounted before every controller call ─────────────────────
  void _loop() async {
    while (mounted) {
      for (int i = 0; i < 3; i++) {
        if (!mounted) return;
        await _ctrls[i].forward();
        if (!mounted) return;
        await _ctrls[i].reverse();
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 140));
      }
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 520));
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              width: 8,
              height: 8,
              margin:
                  const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _C.primary.withOpacity(0.6 + i * 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Input Bar ── FIXED: boxShadow never null (prevents blurRadius crash) ──────
class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });
  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _hasText && !widget.isLoading;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: _C.surface,
        border:
            Border(top: BorderSide(color: _C.cardBorder, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1520),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1C2B45)),
              ),
              child: TextField(
                controller: widget.controller,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 14),
                cursorColor: _C.primary,
                onSubmitted:
                    widget.isLoading ? null : (_) => widget.onSend(),
                decoration: InputDecoration(
                  hintText: 'Share how you\'re feeling…',
                  hintStyle: GoogleFonts.poppins(
                      color: _C.textSub, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F1520),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── FIXED: always provide boxShadow, use transparent color ─────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      colors: [Color(0xFF7C6FF7), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: active ? null : _C.card,
              shape: BoxShape.circle,
              border: Border.all(color: _C.cardBorder),
              // ── KEY FIX: shadow always present, color fades ───────────
              boxShadow: [
                BoxShadow(
                  color: active
                      ? _C.primary.withOpacity(0.4)
                      : Colors.transparent,
                  blurRadius: 12.0, // always non-negative
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: widget.isLoading ? null : widget.onSend,
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _C.primary.withOpacity(0.6)),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: active ? Colors.white : _C.textSub,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}