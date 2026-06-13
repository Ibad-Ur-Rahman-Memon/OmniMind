// lib/features/gamification/gamification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationService {
  final _db = FirebaseFirestore.instance;

  // ── Streak tracking ──────────────────

  Future<void> recordDailyLogin(String userId) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('gamification')
        .doc('streaks')
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int currentStreak = 1;
    int longestStreak = 1;
    DateTime? lastLogin;

    if (doc.exists) {
      final data = doc.data()!;
      currentStreak = data['currentStreak'] as int? ?? 1;
      longestStreak = data['longestStreak'] as int? ?? 1;
      final lastTs = data['lastLogin'];
      if (lastTs is String) {
        lastLogin = DateTime.tryParse(lastTs);
      }
    }

    if (lastLogin != null) {
      final lastDate = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
      final diff = today.difference(lastDate).inDays;

      if (diff == 1) {
        // Consecutive day
        currentStreak++;
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
      } else if (diff == 0) {
        // Same day — no change
        return;
      } else {
        // Streak broken
        currentStreak = 1;
      }
    }

    await _db
        .collection('users')
        .doc(userId)
        .collection('gamification')
        .doc('streaks')
        .set(
      {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastLogin': today.toIso8601String(),
        'totalDays': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    // Check if streak milestone reached
    await _checkStreakBadges(userId, currentStreak);
  }

  Future<Map<String, dynamic>> getStreakData(String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('gamification')
          .doc('streaks')
          .get();
      if (!doc.exists) {
        return {
          'currentStreak': 0,
          'longestStreak': 0,
          'totalDays': 0,
        };
      }
      return doc.data()!;
    } catch (e) {
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'totalDays': 0,
      };
    }
  }

  // ── Points system ────────────────────

  Future<void> addPoints(String userId, int points, String reason) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('gamification')
        .doc('points')
        .set(
      {
        'total': FieldValue.increment(points),
        'history': FieldValue.arrayUnion([
          {
            'points': points,
            'reason': reason,
            'date': DateTime.now().toIso8601String(),
          }
        ]),
      },
      SetOptions(merge: true),
    );
  }

  Future<int> getTotalPoints(String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('gamification')
          .doc('points')
          .get();
      return doc.data()?['total'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Badge system ─────────────────────

  static const badges = {
    'first_chat': {
      'name': 'First Steps',
      'desc': 'Sent your first message',
      'emoji': '💬',
      'points': 10,
    },
    'streak_3': {
      'name': '3-Day Streak',
      'desc': 'Used app 3 days in a row',
      'emoji': '🔥',
      'points': 20,
    },
    'streak_7': {
      'name': 'Week Warrior',
      'desc': 'Used app 7 days in a row',
      'emoji': '⚡',
      'points': 50,
    },
    'streak_30': {
      'name': 'Monthly Champion',
      'desc': 'Used app 30 days in a row',
      'emoji': '🏆',
      'points': 200,
    },
    'first_exercise': {
      'name': 'Deep Breather',
      'desc': 'Completed first exercise',
      'emoji': '🧘',
      'points': 15,
    },
    'exercise_5': {
      'name': 'Wellness Warrior',
      'desc': 'Completed 5 exercises',
      'emoji': '💪',
      'points': 40,
    },
    'exercise_10': {
      'name': 'Zen Master',
      'desc': 'Completed 10 exercises',
      'emoji': '🌟',
      'points': 80,
    },
    'assessment_done': {
      'name': 'Self-Aware',
      'desc': 'Completed all assessments',
      'emoji': '📊',
      'points': 30,
    },
    'diary_7': {
      'name': 'Journaling Journey',
      'desc': 'Wrote 7 diary entries',
      'emoji': '📓',
      'points': 35,
    },
    'sessions_10': {
      'name': 'Committed',
      'desc': 'Had 10 chat sessions',
      'emoji': '🎯',
      'points': 60,
    },
  };

  Future<void> unlockBadge(String userId, String badgeId) async {
    final badge = badges[badgeId];
    if (badge == null) return;

    // Check if already unlocked
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('gamification')
        .doc('badges')
        .get();

    final unlocked = List<String>.from(doc.data()?['unlocked'] ?? []);

    if (unlocked.contains(badgeId)) return;

    // Unlock badge
    await _db
        .collection('users')
        .doc(userId)
        .collection('gamification')
        .doc('badges')
        .set(
      {
        'unlocked': FieldValue.arrayUnion([badgeId]),
        'history': FieldValue.arrayUnion([
          {
            'badgeId': badgeId,
            'name': badge['name'],
            'date': DateTime.now().toIso8601String(),
          }
        ]),
      },
      SetOptions(merge: true),
    );

    // Add points for badge
    await addPoints(userId, badge['points'] as int, 'Badge: ${badge['name']}');
  }

  Future<List<String>> getUnlockedBadges(String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('gamification')
          .doc('badges')
          .get();
      return List<String>.from(doc.data()?['unlocked'] ?? []);
    } catch (_) {
      return [];
    }
  }

  // ── Badge check helpers ──────────────

  Future<void> _checkStreakBadges(String userId, int streak) async {
    if (streak >= 3) {
      await unlockBadge(userId, 'streak_3');
    }
    if (streak >= 7) {
      await unlockBadge(userId, 'streak_7');
    }
    if (streak >= 30) {
      await unlockBadge(userId, 'streak_30');
    }
  }

  Future<void> onExerciseCompleted(String userId, int totalExercises) async {
    await addPoints(userId, 10, 'Exercise completed');
    if (totalExercises == 1) {
      await unlockBadge(userId, 'first_exercise');
    }
    if (totalExercises >= 5) {
      await unlockBadge(userId, 'exercise_5');
    }
    if (totalExercises >= 10) {
      await unlockBadge(userId, 'exercise_10');
    }
  }

  Future<void> onFirstChat(String userId) async {
    await unlockBadge(userId, 'first_chat');
    await addPoints(userId, 10, 'First chat message');
  }

  Future<void> onAssessmentComplete(String userId) async {
    await unlockBadge(userId, 'assessment_done');
    await addPoints(userId, 30, 'Completed assessments');
  }
}

