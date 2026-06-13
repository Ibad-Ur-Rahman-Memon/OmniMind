// lib/features/exercises/exercises_library.dart

import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import 'exercise_popup.dart';

// ignore: unused_import


class ExercisesLibrary extends StatefulWidget {
  const ExercisesLibrary({super.key});

  @override
  State<ExercisesLibrary> createState() => _ExercisesLibraryState();
}

class _ExercisesLibraryState extends State<ExercisesLibrary> {
  List<ExerciseSuggestion> _exercises = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService().getExercises();
      setState(() {
        _exercises = list;
        _loading = false;
      });
    } catch (e) {
      // Backend unavailable - use built-in offline exercises
      setState(() {
        _loading = false;
        _error = null; // Don't show error, use offline exercises
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        centerTitle: false,
        title: const Text(
          'Mind Exercises',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary

              ),
            )
          : _error != null
              ? _buildError()
              : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Unable to Load Exercises',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Please check your backend connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.white.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 34,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final exercises =
        _exercises.isNotEmpty
            ? _exercises
            : _offlineExercises;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        24,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,

                Color(0xFF06B6D4),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Wellness',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Guided CBT exercises designed to reduce stress, anxiety, and overthinking.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.white.withOpacity(0.88),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        ...List.generate(
          exercises.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ExerciseCard(
              exercise: exercises[i],
            ),
          ),
        ),
      ],
    );
  }

  static final _offlineExercises = [
    const ExerciseSuggestion(
      id: 'breathing_478',
      name: '4-7-8 Breathing',
      tagline:
          'Activates your body\'s natural calm-down response',
      durationMin: 2,
      introMessage:
          'A breathing technique to calm your nervous system.',
      steps: [
        'Sit comfortably. Place one hand on your chest and one on your belly.',
        'Breathe in quietly through your nose for 4 counts.',
        'Hold your breath completely for 7 counts.',
        'Exhale fully through your mouth for 8 counts.',
        'Repeat for 4 cycles total.',
        'Breathe normally. Notice how your body feels.',
      ],
      postPrompt:
          'How did that feel? What did you notice?',
    ),

    const ExerciseSuggestion(
      id: 'grounding_54321',
      name: '5-4-3-2-1 Grounding',
      tagline:
          'Anchors you in the present moment',
      durationMin: 3,
      introMessage:
          'Uses your five senses as an anchor.',
      steps: [
        'Name 5 things you can SEE right now.',
        'Notice 4 things you can FEEL.',
        'Identify 3 things you can HEAR.',
        'Notice 2 things you can SMELL.',
        'Notice 1 thing you can TASTE.',
        'Take one slow breath. Notice how present you feel.',
      ],
      postPrompt:
          'How are you feeling now compared to before?',
    ),

    const ExerciseSuggestion(
      id: 'pmr',
      name: 'Progressive Muscle Relaxation',
      tagline:
          'Releases tension stored in your body',
      durationMin: 5,
      introMessage:
          'Tense and release each muscle group.',
      steps: [
        'Find a comfortable position. Close your eyes.',
        'FEET: Curl toes tightly for 5 seconds… release.',
        'CALVES: Tense for 5 seconds… release.',
        'THIGHS & STOMACH: Squeeze… release.',
        'HANDS & ARMS: Clench fists… open wide.',
        'SHOULDERS: Shrug up… drop completely.',
        'FACE: Scrunch muscles… release everything.',
        'Take 3 slow breaths. Scan your body.',
      ],
      postPrompt:
          'How does your body feel now?',
    ),
  ];
}

// NOTE: Ensure there is no leftover markdown backticks or stray text after this block.

class _ExerciseCard extends StatelessWidget {
  final ExerciseSuggestion exercise;

  const _ExerciseCard({
    required this.exercise,
  });

  static const _icons = {
    'breathing_478': (
      Icons.air_rounded,
      Color(0xFF06B6D4)
    ),

    'grounding_54321': (
      Icons.anchor_rounded,
      AppColors.primary

    ),

    'thought_record': (
      Icons.edit_note_rounded,
      Color(0xFFF59E0B)
    ),

    'behavioral_activation': (
      Icons.directions_walk_rounded,
      Color(0xFF10B981)
    ),

    'pmr': (
      Icons.spa_rounded,
      Color(0xFF8B5CF6)
    ),

    'worry_postponement': (
      Icons.schedule_rounded,
      Color(0xFFEC4899)
    ),
  };

  @override
  Widget build(BuildContext context) {
    final pair =
        _icons[exercise.id] ??
        (
      Icons.self_improvement_rounded,
          AppColors.primary
        );

    return InkWell(
      borderRadius: BorderRadius.circular(28),

      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              ExercisePopup(exercise: exercise),
        );
      },

      child: Container(
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),

          borderRadius:
              BorderRadius.circular(28),

          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
        ),

        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,

              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(20),

                color: pair.$2.withOpacity(0.14),
              ),

              child: Icon(
                pair.$1,
                color: pair.$2,
                size: 30,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    exercise.tagline,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color:
                          Colors.white.withOpacity(0.7),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),

                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(30),

                          color: Colors.white
                              .withOpacity(0.05),
                        ),

                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: Colors.white70,
                            ),

                            const SizedBox(width: 6),

                            Text(
                              '${exercise.durationMin} min',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),

                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(30),

                          color: Colors.white
                              .withOpacity(0.05),
                        ),

                        child: Row(
                          children: [
                            const Icon(
                              Icons.format_list_numbered,
                              size: 14,
                              color: Colors.white70,
                            ),

                            const SizedBox(width: 6),

                            Text(
                              '${exercise.steps.length} steps',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Container(
              height: 42,
              width: 42,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),

              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


