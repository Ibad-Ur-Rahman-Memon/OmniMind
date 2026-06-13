// lib/core/services/firestore_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ── Assessments (chat-inferred + manual questionnaire) ──────────────
  Future<void> upsertAssessmentResult({
    required String userId,
    required String assessmentName,
    required int score,
    required String severity,
    required String interpretation,
    required Map<String, int> answers,
    required String riskLevel,
  }) async {
    await _db
        .collection('assessments')
        .doc(userId)
        .collection('results')
        .doc(assessmentName)
        .set({
      'assessmentName': assessmentName,
      'score': score,
      'severity': severity,
      'interpretation': interpretation,
      'answers': answers,
      'riskLevel': riskLevel,
      'completedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Save backend-inferred assessment scores returned by `/chat`.
  ///
  /// Expected input shape (per assessmentName):
  /// {
  ///   "score": int,
  ///   "severity": string,
  ///   "interpretation": string,
  ///   "answers": { "<questionId>": int, ... } (optional),
  ///   "riskLevel": string (optional)
  /// }
  Future<void> saveAssessmentScores(
    String userId,
    Map<String, dynamic> assessmentScores,
  ) async {
    if (assessmentScores.isEmpty) return;

    for (final entry in assessmentScores.entries) {
      final assessmentName = entry.key;
      final raw = entry.value;

      if (raw is! Map<String, dynamic>) continue;

      final score = (raw['score'] ?? 0) as num;
      final severity = (raw['severity'] ?? 'unknown').toString();
      final interpretation = (raw['interpretation'] ?? '').toString();
      final riskLevel = (raw['riskLevel'] ?? 'unknown').toString();

      final answersRaw = raw['answers'];
      final Map<String, int> answers = {};
      if (answersRaw is Map) {
        for (final aEntry in answersRaw.entries) {
          final k = aEntry.key.toString();
          final v = aEntry.value;
          if (v is num) answers[k] = v.toInt();
        }
      }

      await upsertAssessmentResult(
        userId: userId,
        assessmentName: assessmentName,
        score: score.toInt(),
        severity: severity,
        interpretation: interpretation,
        answers: answers,
        riskLevel: riskLevel,
      );
    }
  }

  /// Reset all assessment scores to 0 for a new session
  Future<void> resetAssessmentScores(String userId) async {
    try {
      final snapshot = await _db
          .collection('assessments')
          .doc(userId)
          .collection('results')
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.set({
          'score': 0,
          'severity': '',
          'interpretation': '',
          'answers': {},
          'riskLevel': 'unknown',
          'completedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }

      // Also reset user doc
      await _db.collection('users').doc(userId).update({
        'lastAssessment': '',
        'lastAssessmentSeverity': '',
        'lastAssessmentScore': 0,
        'riskLevel': 'unknown',
        'lastAssessmentAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[FirestoreService] resetAssessmentScores error: $e');
    }
  }

  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // ── Chat History ──────────────────────────────────────────────────────────

  Future<void> saveMessage(String userId, ChatMessage msg) async {
    await _db
        .collection('users').doc(userId)
        .collection('messages')
        .doc(msg.id)
        .set(msg.toMap());
  }

  Stream<List<ChatMessage>> getChatHistory(String userId) {
    return _db
        .collection('users').doc(userId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatMessage.fromMap(doc.data()))
            .toList());
  }

  Future<List<ChatMessage>> getChatHistoryOnce(String userId, {int limit = 100}) async {
    final snap = await _db
        .collection('users').doc(userId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(limit)
        .get();
    return snap.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList();
  }

  Future<void> clearChatHistory(String userId) async {
    final snap = await _db
        .collection('users').doc(userId)
        .collection('messages').get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

// ── Session state ─────────────────────────────────────────────────────────

  Future<void> saveSessionId(String userId, String sessionId) async {
    // Use set(..., merge: true) so the document is created if it doesn't exist yet.
    // This prevents: [cloud_firestore/not-found] No document to update users/{uid}
    await _db.collection('users').doc(userId).set({
      'currentSessionId': sessionId,
      'sessionUpdatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<String?> getSessionId(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['currentSessionId'] as String?;
  }

  // ── Exercise Records ──────────────────────────────────────────────────────

  Future<void> saveExerciseRecord(String userId, ExerciseRecord record) async {
    await _db
        .collection('users').doc(userId)
        .collection('exercises')
        .add(record.toMap());
  }

  Stream<List<ExerciseRecord>> getExerciseHistory(String userId) {
    return _db
        .collection('users').doc(userId)
        .collection('exercises')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ExerciseRecord.fromMap(doc.data()))
            .toList());
  }

  // ── Diary ─────────────────────────────────────────────────────────────────

Future<void> saveDiaryEntry(DiaryEntry entry) async {
    // New schema: journals/{journalId}
    await _db
        .collection('journals')
        .doc(entry.journalId)
        .set(entry.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteDiaryEntry(String journalId) async {
    await _db.collection('journals').doc(journalId).delete();
  }


  // ── Reset assessments for new session ──────────────────────────────
  Future<void> clearAssessmentResults(String userId) async {
    final snap = await _db
        .collection('assessments')
        .doc(userId)
        .collection('results')
        .get();

    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

Stream<List<DiaryEntry>> getDiaryEntries(String userId) {
    // Support BOTH schemas:
    // 1) New: journals/{journalId}
    // 2) Legacy: users/{uid}/diary/{journalId}
    //
    // We fetch both streams and then merge them in-memory.
    final newSchemaStream = _db
        .collection('journals')
        .where('patientId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DiaryEntry.fromMap({
                  ...doc.data(),
                  'journalId': doc.id,
                  'id': doc.id,
                }))
            .toList());

    final legacyStream = _db
        .collection('users')
        .doc(userId)
        .collection('diary')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DiaryEntry.fromMap({
                  ...doc.data(),
                  // legacy docs may not include patientId/journalId consistently
                  'patientId': userId,
                  'journalId': doc.id,
                  'id': doc.id,
                }))
            .toList());

    // Merge in-memory without StreamZip dependency.
    // We keep the latest value of each stream and emit merged results whenever either updates.
    return Stream<List<DiaryEntry>>.multi((multiController) {
      List<DiaryEntry> latestNew = const [];
      List<DiaryEntry> latestLegacy = const [];

      void emitMerged() {
        final merged = <DiaryEntry>[...latestNew, ...latestLegacy];
        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final seen = <String>{};
        final deduped = <DiaryEntry>[];
        for (final e in merged) {
          final key = e.id.isNotEmpty ? e.id : e.journalId;
          if (seen.add(key)) deduped.add(e);
        }

        multiController.add(deduped);
      }

      final sub1 = newSchemaStream.listen(
        (v) {
          latestNew = v;
          emitMerged();
        },
        onError: multiController.addError,
      );

      final sub2 = legacyStream.listen(
        (v) {
          latestLegacy = v;
          emitMerged();
        },
        onError: multiController.addError,
      );

      multiController.onCancel = () {
        sub1.cancel();
        sub2.cancel();
      };
    });
  }


  Future<void> saveDiaryReply({
    required String diaryEntryId,
    required String doctorUid,
    required String reply,
  }) async {
    final replyId = const Uuid().v4();
    final diaryReply = DiaryReply(
      id: replyId,
      diaryEntryId: diaryEntryId,
      doctorId: doctorUid,
      content: reply.trim(),
      createdAt: DateTime.now(),
    );

    // New schema: journals/{journalId}/replies/{replyId}
    await _db
        .collection('journals')
        .doc(diaryEntryId)
        .collection('replies')
        .doc(replyId)
        .set(diaryReply.toMap());
  }

  Stream<List<DiaryReply>> getDiaryReplies({
    required String diaryEntryId,
  }) {
    return _db
        .collection('journals')
        .doc(diaryEntryId)
        .collection('replies')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DiaryReply.fromMap(doc.data()))
            .toList());
  }


  // ── Progress snapshots (for doctor view) ─────────────────────────────────

  Future<void> saveProgressSnapshot(String userId, Map<String, dynamic> data) async {
    await _db
        .collection('users').doc(userId)
        .collection('progress')
        .add({
          ...data,
          'savedAt': DateTime.now().toIso8601String(),
        });
  }

  Stream<List<Map<String, dynamic>>> getProgressSnapshots(String userId) {
    return _db
        .collection('users').doc(userId)
        .collection('progress')
        .orderBy('savedAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  // ── Patient Risk ─────────────────────────────────────────────────────────

  Future<String> getPatientRiskLevel(String patientUid) async {
    try {
      // Step 1: Try riskLevel field on user document directly
      final userDoc = await _db.collection('users').doc(patientUid).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final rawRiskLevel = data['riskLevel'] as String?;
          if (rawRiskLevel != null) {
            final v = rawRiskLevel.trim();
            if (v.isNotEmpty && v.toLowerCase() != 'unknown') {
              return v.toLowerCase();
            }
          }
        }
      }

      // Step 2: Calculate from assessment scores stored in Firestore
      // (Doctor detail reads from: assessments/{uid}/results/*)
      final assessSnap = await _db
          .collection('assessments')
          .doc(patientUid)
          .collection('results')
          .get();


      if (assessSnap.docs.isNotEmpty) {
        int phq = 0, gad = 0, pss = 0, spin = 0;

        for (final doc in assessSnap.docs) {
          final name = doc.id.toUpperCase();
          final score = (doc.data()['score'] as int?) ?? 0;

          if (name.contains('PHQ')) {
            phq = score;
          } else if (name.contains('GAD')) {
            gad = score;
          } else if (name.contains('PSS')) {
            pss = score;
          } else if (name.contains('SPIN')) {
            spin = score;
          }
        }

        print('[Risk] $patientUid: PHQ=$phq GAD=$gad PSS=$pss SPIN=$spin');

        if (phq >= 15 || gad >= 15 || pss >= 27) return 'high';
        if (phq >= 10 || gad >= 10 || pss >= 14 || spin >= 20) {
          return 'moderate';
        }
        if (phq >= 5 || gad >= 5 || pss >= 7 || spin >= 10) {
          return 'low';
        }
        if (phq + gad + pss + spin > 0) {
          return 'low';
        }
      }

      return 'unknown';
    } catch (e) {
      print('[Risk] Error for $patientUid: $e');
      return 'unknown';
    }
  }

  // ── Patient Activity ─────────────────────────────────────────────────────

  Future<DateTime?> getPatientLastActive(String patientUid) async {
    // 1) Prefer sessionUpdatedAt from user doc
    final userDoc = await _db.collection('users').doc(patientUid).get();
    final raw = userDoc.data()?['sessionUpdatedAt'];

    DateTime? parsed;
    if (raw != null) {
      if (raw is Timestamp) {
        parsed = raw.toDate();
      } else if (raw is DateTime) {
        parsed = raw;
      } else if (raw is String) {
        // Handle ISO strings (and any accidental whitespace)
        parsed = DateTime.tryParse(raw.trim());
      }
    }

    // If it's valid, return immediately
    if (parsed != null) return parsed;

    // 2) Fallback to latest message timestamp
    final msgSnap = await _db
        .collection('users').doc(patientUid)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (msgSnap.docs.isNotEmpty) {
      final ts = ChatMessage.fromMap(msgSnap.docs.first.data()).timestamp;
      return ts;
    }

    return null;
  }


  Stream<DateTime?> streamPatientLastActive(String patientUid) {
    // Listen to user doc sessionUpdatedAt
    return _db.collection('users').doc(patientUid).snapshots().map((doc) {
      final sessionUpdatedAt = doc.data()?['sessionUpdatedAt'];
      if (sessionUpdatedAt is Timestamp) return sessionUpdatedAt.toDate();
      if (sessionUpdatedAt is String) return DateTime.tryParse(sessionUpdatedAt);
      return null;
    });
  }

  // ── Doctor notes ──────────────────────────────────────────────────────────

  Future<void> saveDoctorNote(
      String doctorUid, String patientUid, String note) async {
    await _db
        .collection('doctors')
        .doc(doctorUid)
        .collection('notes')
        .doc(patientUid)
        .collection('entries')
        .add({
      'note': note,
      'createdAt': DateTime.now().toIso8601String(),
      'doctorUid': doctorUid,
      'patientUid': patientUid,
    });
  }

  Stream<List<Map<String, dynamic>>> getDoctorNotes(
      String doctorUid, String patientUid) {
    return _db
        .collection('doctors')
        .doc(doctorUid)
        .collection('notes')
        .doc(patientUid)
        .collection('entries')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  // ── Doctor authority: remove patient ─────────────────────────────────────
  //
  // NOTE: Real authorization must be enforced by Firestore Security Rules.
  // This method performs the deletion of patient-related data in Firestore.
  Future<void> removePatientData(String patientUid) async {
    // Helper: delete a list of docs in batches (<= 500).
    Future<void> batchDelete(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
      const maxPerBatch = 500;
      for (var i = 0; i < docs.length; i += maxPerBatch) {
        final batch = _db.batch();
        final slice = docs.sublist(
          i,
          i + maxPerBatch > docs.length ? docs.length : i + maxPerBatch,
        );
        for (final d in slice) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }

    // 1) messages under users/{uid}/messages
    try {
      final snap = await _db
          .collection('users')
          .doc(patientUid)
          .collection('messages')
          .get();
      await batchDelete(snap.docs);
    } catch (_) {}

    // 2) assessments under assessments/{uid}/results/*
    try {
      final snap = await _db
          .collection('assessments')
          .doc(patientUid)
          .collection('results')
          .get();
      const maxPerBatch = 500;
      for (var i = 0; i < snap.docs.length; i += maxPerBatch) {
        final batch = _db.batch();
        final slice = snap.docs.sublist(
          i,
          i + maxPerBatch > snap.docs.length ? snap.docs.length : i + maxPerBatch,
        );
        for (final d in slice) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {}

    // 3) chats under chats/{uid}/messages/*
    try {
      final snap = await _db
          .collection('chats')
          .doc(patientUid)
          .collection('messages')
          .get();
      const maxPerBatch = 500;
      for (var i = 0; i < snap.docs.length; i += maxPerBatch) {
        final batch = _db.batch();
        final slice = snap.docs.sublist(
          i,
          i + maxPerBatch > snap.docs.length ? snap.docs.length : i + maxPerBatch,
        );
        for (final d in slice) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {}

    // 4) exercises under users/{uid}/exercises/*
    try {
      final snap = await _db
          .collection('users')
          .doc(patientUid)
          .collection('exercises')
          .get();
      await batchDelete(snap.docs);
    } catch (_) {}

    // 5) diary under users/{uid}/diary/*
    try {
      final snap = await _db
          .collection('users')
          .doc(patientUid)
          .collection('diary')
          .get();
      await batchDelete(snap.docs);
    } catch (_) {}

    // 6) progress under users/{uid}/progress/*
    try {
      final snap = await _db
          .collection('users')
          .doc(patientUid)
          .collection('progress')
          .get();
      await batchDelete(snap.docs);
    } catch (_) {}

    // 7) finally delete the user profile doc
    try {
      await _db.collection('users').doc(patientUid).delete();
    } catch (_) {}
  }
}
