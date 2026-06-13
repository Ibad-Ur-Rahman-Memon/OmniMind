// lib/core/services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
static String _defaultBaseUrl() => kIsWeb
       ? 'http://127.0.0.1:8000'
       : 'http://10.102.138.54:8000';

  // When running on Android emulator, the backend on your dev machine must be reachable.
  // 10.0.2.2 maps emulator localhost -> host machine localhost.
  // If API_BASE_URL is not set, fall back to emulator-friendly localhost.
  static String _emulatorFallbackBaseUrl() => 'http://10.0.2.2:8000';

  static const String _apiBaseUrlFromDefine =
      String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    // Priority: 1) dart-define, 2) .env file, 3) default
    if (_apiBaseUrlFromDefine.isNotEmpty) return _apiBaseUrlFromDefine;
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    return _defaultBaseUrl();
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ── Health ────────────────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      final r = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── FIXED: always return true — Groq is embedded, no warmup needed ────────
  Future<bool> waitForBackendReady() async {
    return true;
  }

  // ── Session ───────────────────────────────────────────────────────────────

  Future<String> createSession() async {
    try {
      final r = await _client
          .post(Uri.parse('$baseUrl/session/new'), headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        return (jsonDecode(r.body) as Map<String, dynamic>)['session_id']
            as String;
      }
    } catch (_) {}
    // If backend is not running, generate a local UUID
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  }

  // ── Chat (kept for backwards compat — ChatProvider now uses Groq directly) ─

  Future<ChatApiResponse> sendMessage({
    required String message,
    required String sessionId,
    bool postExercise = false,
  }) async {
    final body = jsonEncode({
      'message': message,
      'session_id': sessionId,
      'post_exercise': postExercise,
    });
    final r = await _client
        .post(Uri.parse('$baseUrl/chat'), headers: _headers, body: body)
        .timeout(const Duration(seconds: 60));
    if (r.statusCode == 200) {
      return ChatApiResponse.fromMap(jsonDecode(r.body));
    }
    throw ApiException('Chat failed: ${r.statusCode} — ${r.body}');
  }

  // ── Exercises ─────────────────────────────────────────────────────────────

  Future<List<ExerciseSuggestion>> getExercises() async {
    final r = await _client
        .get(Uri.parse('$baseUrl/exercises'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body);
      return (data['exercises'] as List)
          .map((e) =>
              ExerciseSuggestion.fromMap(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException('Failed to fetch exercises: ${r.statusCode}');
  }

  Future<void> markExerciseComplete(
      String sessionId, String exerciseId) async {
    try {
      await _client
          .post(
            Uri.parse('$baseUrl/exercise/complete'),
            headers: _headers,
            body: jsonEncode(
                {'session_id': sessionId, 'exercise_id': exerciseId}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ── Assessments ───────────────────────────────────────────────────────────

  Future<AssessmentStatusResponse> getAssessmentStatus(
      String sessionId) async {
    final r = await _client
        .get(
          Uri.parse('$baseUrl/assess/status')
              .replace(queryParameters: {'session_id': sessionId}),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      return AssessmentStatusResponse.fromMap(jsonDecode(r.body));
    }
    throw ApiException(
        'Failed to fetch assessments: ${r.statusCode}');
  }

  Future<void> submitAssessmentAnswer({
    required String sessionId,
    required String assessmentName,
    required String questionId,
    required int score,
  }) async {
    final body = jsonEncode({
      'session_id': sessionId,
      'assessment_name': assessmentName,
      'question_id': questionId,
      'score': score,
    });
    final r = await _client
        .post(Uri.parse('$baseUrl/assess/answer'),
            headers: _headers, body: body)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw ApiException(
          'Assessment submit failed: ${r.statusCode}');
    }
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  Future<SessionProgress> getProgress(String sessionId) async {
    final r = await _client
        .get(
          Uri.parse('$baseUrl/progress')
              .replace(queryParameters: {'session_id': sessionId}),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      return SessionProgress.fromMap(jsonDecode(r.body));
    }
    throw ApiException('Failed to fetch progress: ${r.statusCode}');
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> exportSession(
      String sessionId) async {
    final r = await _client
        .get(
          Uri.parse(
              '$baseUrl/session/export?session_id=$sessionId'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException('Export failed: ${r.statusCode}');
  }

  void dispose() => _client.close();
}

// ── Response Types ────────────────────────────────────────────────────────────

class CrisisRisk {
  final int riskLevel;
  final String category;
  final double confidence;
  final String rationale;

  const CrisisRisk({
    required this.riskLevel,
    required this.category,
    required this.confidence,
    required this.rationale,
  });

  factory CrisisRisk.fromMap(Map<String, dynamic> map) {
    return CrisisRisk(
      riskLevel: (map['risk_level'] ?? 0) as int,
      category: (map['category'] ?? 'none').toString(),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      rationale: (map['rationale'] ?? '').toString(),
    );
  }
}

class ChatApiResponse {
  final String sessionId;
  final String reply;
  final String emotion;
  final bool crisisDetected;

  /// DSM-5 structured crisis classification from backend `/chat`
  final CrisisRisk? crisisRisk;

  final ExerciseSuggestion? exerciseSuggestion;

  // Inferred assessment scores returned by backend `/chat`
  // (so Flutter can persist them to Firestore)
  final Map<String, dynamic> assessmentScores;

  final double latencyMs;
  final int turn;

  const ChatApiResponse({
    required this.sessionId,
    required this.reply,
    required this.emotion,
    required this.crisisDetected,
    this.crisisRisk,
    this.exerciseSuggestion,
    required this.assessmentScores,
    required this.latencyMs,
    required this.turn,
  });

  factory ChatApiResponse.fromMap(
    Map<String, dynamic> map,
  ) =>
      ChatApiResponse(
        sessionId: map['session_id'] ?? '',
        reply: map['reply'] ?? '',
        emotion: map['emotion'] ?? 'neutral',
        crisisDetected: map['crisis_detected'] ?? false,
        crisisRisk: map['crisis_risk'] != null
            ? CrisisRisk.fromMap(
                map['crisis_risk'] as Map<String, dynamic>,
              )
            : null,
        exerciseSuggestion: map['exercise_suggestion'] != null
            ? ExerciseSuggestion.fromMap(
                map['exercise_suggestion'] as Map<String, dynamic>,
              )
            : null,
        assessmentScores: Map<String, dynamic>.from(
          map['assessment_scores'] ?? {},
        ),
        latencyMs: (map['latency_ms'] ?? 0.0).toDouble(),
        turn: map['turn'] ?? 0,
      );
}

class AssessmentStatusResponse {
  final List<Assessment> assessments;
  final String overallRisk;
  final Map<String, bool> riskFlags;
  final double combinedRiskScore;

  const AssessmentStatusResponse({
    required this.assessments,
    required this.overallRisk,
    required this.riskFlags,
    required this.combinedRiskScore,
  });

  factory AssessmentStatusResponse.fromMap(
          Map<String, dynamic> map) =>
      AssessmentStatusResponse(
        assessments: (map['assessments'] as List? ?? [])
            .map((a) =>
                Assessment.fromMap(a as Map<String, dynamic>))
            .toList(),
        overallRisk: (map['overall_risk'] ??
                map['overallRisk'] ??
                'unknown')
            .toString()
            .toLowerCase()
            .trim(),
        riskFlags: (map['risk_flags'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as bool)),
        combinedRiskScore: (map['combined_risk_score'] as num? ?? 0.0).toDouble(),
      );
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}