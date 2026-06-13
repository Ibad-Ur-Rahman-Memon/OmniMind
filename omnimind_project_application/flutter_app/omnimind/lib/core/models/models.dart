// lib/core/models/models.dart
// Central data models for OmniMind
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Auth Models ────────────────────────────────────────────────────────────────

enum UserRole { patient, doctor }

class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String? assignedDoctorId;  // for patients
  final String? photoUrl;
  final String? risk;              // 'low' | 'moderate' | 'high' | 'unknown'
  final String? riskLevel; // written by GroqLLMService to users/{uid}.riskLevel

  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.assignedDoctorId,
    this.photoUrl,
    this.risk,
    this.riskLevel,
    required this.createdAt,
  });


  bool get isDoctor => role == UserRole.doctor;
  bool get isPatient => role == UserRole.patient;

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    uid: map['uid'] ?? '',
    email: map['email'] ?? '',
    name: map['name'] ?? '',
    role: map['role'] == 'doctor' ? UserRole.doctor : UserRole.patient,
    assignedDoctorId: map['assignedDoctorId'],
    photoUrl: map['photoUrl'],
    risk: map['risk'] ?? map['overallRisk'],
    riskLevel: map['riskLevel'] as String?,

    createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'name': name,
    'role': role == UserRole.doctor ? 'doctor' : 'patient',
    'assignedDoctorId': assignedDoctorId,
    'photoUrl': photoUrl,
    'risk': risk,
    'riskLevel': riskLevel,
    'createdAt': createdAt.toIso8601String(),
  };


  AppUser copyWith({String? name, String? assignedDoctorId, String? photoUrl, String? risk, String? riskLevel}) => AppUser(
    uid: uid, email: email,
    name: name ?? this.name,
    role: role,
    assignedDoctorId: assignedDoctorId ?? this.assignedDoctorId,
    photoUrl: photoUrl ?? this.photoUrl,
    risk: risk ?? this.risk,
    riskLevel: riskLevel ?? this.riskLevel,
    createdAt: createdAt,
  );
}


// ── Chat Models ────────────────────────────────────────────────────────────

enum MessageRole { user, assistant, system }
enum MessageStatus { sending, sent, error }

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final String emotion;
  final MessageStatus status;
  final bool crisisDetected;
  final ExerciseSuggestion? exerciseSuggestion;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.emotion = 'neutral',
    this.status = MessageStatus.sent,
    this.crisisDetected = false,
    this.exerciseSuggestion,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] ?? '',
    content: map['content'] ?? '',
    role: map['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
    timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    emotion: map['emotion'] ?? 'neutral',
    status: MessageStatus.sent,
    crisisDetected: map['crisisDetected'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'content': content,
    'role': role == MessageRole.user ? 'user' : 'assistant',
    'timestamp': timestamp.toIso8601String(),
    'emotion': emotion,
    'crisisDetected': crisisDetected,
  };
}

// ── Exercise Models ────────────────────────────────────────────────────────

class ExerciseSuggestion {
  final String id;
  final String name;
  final String tagline;
  final int durationMin;
  final String introMessage;
  final List<String> steps;
  final String postPrompt;

  const ExerciseSuggestion({
    required this.id,
    required this.name,
    required this.tagline,
    required this.durationMin,
    required this.introMessage,
    required this.steps,
    required this.postPrompt,
  });

  factory ExerciseSuggestion.fromMap(Map<String, dynamic> map) => ExerciseSuggestion(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    tagline: map['tagline'] ?? '',
    durationMin: map['duration_min'] ?? 5,
    introMessage: map['intro_message'] ?? '',
    steps: List<String>.from(map['steps'] ?? []),
    postPrompt: map['post_prompt'] ?? '',
  );
}

class ExerciseRecord {
  final String exerciseId;
  final String exerciseName;
  final DateTime completedAt;
  final String sessionId;

  const ExerciseRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.completedAt,
    required this.sessionId,
  });

  factory ExerciseRecord.fromMap(Map<String, dynamic> map) => ExerciseRecord(
    exerciseId: map['exerciseId'] ?? '',
    exerciseName: map['exerciseName'] ?? '',
    completedAt: DateTime.tryParse(map['completedAt'] ?? '') ?? DateTime.now(),
    sessionId: map['sessionId'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'completedAt': completedAt.toIso8601String(),
    'sessionId': sessionId,
  };
}

// ── Assessment Models ────────────────────────────────────────────────────────

class AssessmentQuestion {
  final String id;
  final String text;
  final List<String> options;
  final List<int> scores;
  final int? answeredScore;
  final String? answeredLabel;

  const AssessmentQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.scores,
    this.answeredScore,
    this.answeredLabel,
  });

  factory AssessmentQuestion.fromMap(Map<String, dynamic> map) => AssessmentQuestion(
    id: map['id'] ?? '',
    text: map['text'] ?? '',
    options: List<String>.from(map['options'] ?? []),
    scores: List<int>.from(map['scores'] ?? []),
    answeredScore: map['answered_score'],
    answeredLabel: map['answered_label'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'options': options,
    'scores': scores,
    'answered_score': answeredScore,
    'answered_label': answeredLabel,
  };
}

class Assessment {
  final String name;
  final String fullName;
  final String domain;
  final int score;
  final int answered;
  final int totalQuestions;
  final double completionPct;
  final String severity;
  final String severityColor;
  final String interpretation;
  final List<AssessmentQuestion> questions;
  final List<int>? itemScores; // Individual question scores for detailed analysis

  const Assessment({
    required this.name,
    required this.fullName,
    required this.domain,
    required this.score,
    required this.answered,
    required this.totalQuestions,
    required this.completionPct,
    required this.severity,
    required this.severityColor,
    required this.interpretation,
    required this.questions,
    this.itemScores,
  });

  factory Assessment.fromMap(Map<String, dynamic> map) => Assessment(
    name: map['name'] ?? '',
    fullName: map['full_name'] ?? '',
    domain: map['domain'] ?? '',
    score: map['score'] ?? 0,
    answered: map['answered'] ?? 0,
    totalQuestions: map['total_questions'] ?? 0,
    completionPct: (map['completion_pct'] ?? 0.0).toDouble(),
    severity: map['severity'] ?? 'Minimal',
    severityColor: map['severity_color'] ?? '#4CAF50',
    interpretation: map['interpretation'] ?? '',
    questions: (map['questions'] as List? ?? [])
        .map((q) => AssessmentQuestion.fromMap(q as Map<String, dynamic>))
        .toList(),
    itemScores: map['item_scores'] != null
        ? List<int>.from(map['item_scores'] as List)
        : null,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'full_name': fullName,
    'domain': domain,
    'score': score,
    'answered': answered,
    'total_questions': totalQuestions,
    'completion_pct': completionPct,
    'severity': severity,
    'severity_color': severityColor,
    'interpretation': interpretation,
    'questions': questions.map((q) => q.toMap()).toList(),
    'item_scores': itemScores,
  };
}

// ── Progress Models ────────────────────────────────────────────────────────

class EmotionDataPoint {
  final int turn;
  final String emotion;
  final DateTime timestamp;

  const EmotionDataPoint({
    required this.turn,
    required this.emotion,
    required this.timestamp,
  });

  factory EmotionDataPoint.fromMap(Map<String, dynamic> map) => EmotionDataPoint(
    turn: map['turn'] ?? 0,
    emotion: map['emotion'] ?? 'neutral',
    timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
  );
}

class SessionProgress {
  final String sessionId;
  final int turnCount;
  final List<String> exercisesDone;
  final List<EmotionDataPoint> emotionHistory;
  final Map<String, int> emotionCounts;

  const SessionProgress({
    required this.sessionId,
    required this.turnCount,
    required this.exercisesDone,
    required this.emotionHistory,
    required this.emotionCounts,
  });

  factory SessionProgress.fromMap(Map<String, dynamic> map) => SessionProgress(
    sessionId: map['session_id'] ?? '',
    turnCount: map['turn_count'] ?? 0,
    exercisesDone: List<String>.from(map['exercises_done'] ?? []),
    emotionHistory: (map['emotion_history'] as List? ?? [])
        .map((e) => EmotionDataPoint.fromMap(e as Map<String, dynamic>))
        .toList(),
    emotionCounts: (map['emotion_counts'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v as int)),
  );
}

// ── Diary Models ────────────────────────────────────────────────────────────

class DiaryEntry {
  final String id;
  final String journalId;
  final String patientId;
  final String? doctorId;
  final String? title; // optional
  final String content;
  final String mood; // emoji-based
  final int moodScore; // 1-10
  final String riskLevel; // low|moderate|high|unknown
  final DateTime createdAt;
  final DateTime lastUpdated;

  const DiaryEntry({
    required this.id,
    required this.journalId,
    required this.patientId,
    this.doctorId,
    this.title,
    required this.content,
    required this.mood,
    required this.moodScore,
    required this.riskLevel,
    required this.createdAt,
    required this.lastUpdated,
  });


factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    // Support BOTH legacy and new schemas.
    final now = DateTime.now();

    DateTime parseTs(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? now;
      if (raw is DateTime) return raw;
      return now;
    }

    final createdAt = parseTs(map['createdAt']);
    final updatedAt = parseTs(map['updatedAt'] ?? map['lastUpdated']);

    // Legacy: stored under users/{uid}/diary with userId.
    final legacyUserId = (map['userId'] ?? map['patientId'])?.toString() ?? '';

    // New: top-level journals/{journalId}
    final patientId = (map['patientId'] ?? legacyUserId).toString();

    final journalId = (map['journalId'] ?? map['id'] ?? '').toString();

    return DiaryEntry(
      id: (map['id'] ?? map['journalId'] ?? map['journal_id'] ?? '').toString(),
      journalId: journalId,
      patientId: patientId,
      doctorId: map['doctorId']?.toString(),
      title: map['title']?.toString(),
      content: map['content'] ?? '',
      mood: map['mood'] ?? '😐',
      moodScore: (map['moodScore'] ?? map['mood_score'] ?? 5) is num
          ? (map['moodScore'] ?? map['mood_score']).toInt()
          : 5,
      riskLevel: (map['riskLevel'] ?? map['risk_level'] ?? 'unknown').toString(),
      createdAt: createdAt,
      lastUpdated: updatedAt,
    );
  }


Map<String, dynamic> toMap() => {
    'journalId': journalId,
    'id': id,
    'patientId': patientId,
    'doctorId': doctorId,
    'title': title,
    'content': content,
    'mood': mood,
    'moodScore': moodScore,
    'riskLevel': riskLevel,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(lastUpdated),
    'lastUpdated': Timestamp.fromDate(lastUpdated),
  };
}


// Diary Reply Model
class DiaryReply {
  final String id;
  final String diaryEntryId;
  final String doctorId;
  final String content;
  final DateTime createdAt;

  const DiaryReply({
    required this.id,
    required this.diaryEntryId,
    required this.doctorId,
    required this.content,
    required this.createdAt,
  });

  factory DiaryReply.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'];

    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return DiaryReply(
      id: map['id'] ?? '',
      diaryEntryId: map['diaryEntryId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      content: map['content'] ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'diaryEntryId': diaryEntryId,
    'doctorId': doctorId,
    'content': content,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}