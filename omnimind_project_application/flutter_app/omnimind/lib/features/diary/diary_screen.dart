// lib/features/diary/diary_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../core/models/models.dart';
import '../../core/services/firestore_service.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/theme/app_theme.dart';

class _D {
  static const bg = Color(0xFF07090F);
  static const surface = Color(0xFF0F1520);
  static const card = Color(0xFF131B2E);
  static const cardBorder = Color(0xFF1C2B45);

  static const primary = AppColors.primary;
  static const accent = AppColors.accent;
  static const textSub = AppColors.lightTextSecondary;
}

const _uuid = Uuid();

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userId = auth.user?.uid ?? '';

    if (userId.isEmpty) {
      return const Scaffold(
        backgroundColor: _D.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _D.bg,
      resizeToAvoidBottomInset: false,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F1520),
            border: Border(bottom: BorderSide(color: Color(0xFF1C2B45))),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primary,
                          Color(0xFF4F46E5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.book_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Diary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<DiaryEntry>>(
        stream: FirestoreService().getDiaryEntries(userId),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load journals.',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return _EmptyDiary(
              onCreateFirstEntry: () => _showNewEntrySheet(context, userId),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _DiaryEntryCard(
              entry: entries[i],
              onDelete: () => FirestoreService()
                  .deleteDiaryEntry(entries[i].journalId),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewEntrySheet(context, userId),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New Journal'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showNewEntrySheet(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewJournalSheet(userId: userId),
    );
  }
}

class _EmptyDiary extends StatelessWidget {
  final VoidCallback onCreateFirstEntry;

  const _EmptyDiary({required this.onCreateFirstEntry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: _D.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _D.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.book_outlined,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'No diary entries yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first entry to track your mood and thoughts over time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _D.textSub,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
                onPressed: onCreateFirstEntry,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Create First Entry',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryEntryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onDelete;

  const _DiaryEntryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy • HH:mm');

    return Dismissible(
      key: Key(entry.journalId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.accent),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _D.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _D.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF4F46E5)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(entry.mood,
                        style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmt.format(entry.createdAt.toLocal()),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _D.textSub,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(10, (i) {
                            final active = i < entry.moodScore;
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.secondary
                                    : AppColors.secondary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entry.content,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.6,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 14),

              // Doctor replies (read-only on patient side)
              StreamBuilder<List<DiaryReply>>(
                stream: FirestoreService().getDiaryReplies(
                  diaryEntryId: entry.journalId,
                ),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: SizedBox(
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Could not load doctor reply.',
                        style: GoogleFonts.poppins(
                          color: _D.textSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  final replies = snap.data ?? [];
                  if (replies.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'No doctor reply yet.',
                        style: GoogleFonts.poppins(
                          color: _D.textSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctor reply',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...replies.map((r) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _D.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                DateFormat('MMM d, yyyy • HH:mm')
                                    .format(r.createdAt.toLocal()),
                                style: GoogleFonts.poppins(
                                  color: _D.textSub,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showNewJournalSheet(BuildContext context, {required String userId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NewJournalSheet(userId: userId),
  );
}

class NewJournalSheet extends StatefulWidget {
  final String userId;
  const NewJournalSheet({required this.userId});

  @override
  State<NewJournalSheet> createState() => _NewEntrySheetState();
}

class _NewEntrySheetState extends State<NewJournalSheet> {
  final _titleController = TextEditingController();
  final _controller = TextEditingController();
  String _mood = '😐';
  int _moodScore = 5;
  bool _saving = false;

  static const _moods = [
    ('😔', 'Very Bad', 1),
    ('😟', 'Bad', 3),
    ('😐', 'Okay', 5),
    ('🙂', 'Good', 7),
    ('😊', 'Great', 10),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _saving = true);

    // Title is optional for now; DiaryEntry model currently stores only content/mood.
    final _ = _titleController.text.trim();

final now = DateTime.now();
    final journalId = _uuid.v4();

    final entry = DiaryEntry(
      id: journalId,
      journalId: journalId,
      patientId: widget.userId,
      doctorId: null,
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      content: _controller.text.trim(),
      mood: _mood,
      moodScore: _moodScore,
      riskLevel: _moodScore <= 3
          ? 'high'
          : _moodScore <= 6
              ? 'moderate'
              : 'low',
      createdAt: now,
      lastUpdated: now,
    );

    await FirestoreService().saveDiaryEntry(entry);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Diary Entry',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  const Text('How are you feeling?',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  const Text('Title (optional)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Give your entry a short title...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _moods.map((m) => GestureDetector(
                      onTap: () => setState(() {
                        _mood = m.$1; _moodScore = m.$3;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _mood == m.$1
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: _mood == m.$1
                              ? Border.all(color: AppColors.primary)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(m.$1, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 2),
                            Text(m.$2,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _mood == m.$1
                                        ? AppColors.primary
                                        : AppColors.lightTextSecondary,
                                    fontWeight: _mood == m.$1
                                        ? FontWeight.w600 : null)),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('What\'s on your mind?',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText:
                          'Write freely about your thoughts, feelings, and experiences...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Entry'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
