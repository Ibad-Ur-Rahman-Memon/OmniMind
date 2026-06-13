// lib/core/providers/app_providers.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/groq_llm_service.dart';

import '../../features/gamification/gamification_service.dart';



const _uuid = Uuid();

// ── Auth Provider ─────────────────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  AppUser? _user;
  bool _loading = false;
  String? _error;

  AppUser? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isDoctor => _user?.isDoctor ?? false;

  Future<void> initAuth() async {
    _loading = true; notifyListeners();
    try {
      await _authService.init();
      _user = await _authService.getCurrentAppUser();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false; notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _user = await _authService.signUp(
          email: email, password: password, name: name, role: role);
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e.toString());
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      debugPrint('🔐 Attempting sign-in for: $email');
      _user = await _authService.signIn(email: email, password: password);
      debugPrint('✅ Sign-in SUCCESS: ${_user?.email} (${_user?.role})');
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Sign-in error: $e (${e.runtimeType})');
      _error = _friendlyError(e.toString());
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  String _friendlyError(String e) {
    if (e == 'user-not-found')      return 'No account found with this email.';
    if (e == 'wrong-password')      return 'Incorrect password.';
    if (e == 'invalid-email')       return 'Please enter a valid email address.';
    if (e == 'user-disabled')       return 'This account has been disabled.';
    if (e == 'too-many-requests')   return 'Too many failed attempts. Try again later.';
    if (e == 'email-already-in-use')return 'Email already registered.';
    if (e == 'weak-password')       return 'Password must be at least 6 characters.';
    final raw = e.toLowerCase();
    if (raw.contains('network') || raw.contains('timeout')) {
      return 'Network error. Check your connection.';
    }
    return 'Sign-in failed. Please check your credentials.';
  }

  void clearError() { _error = null; notifyListeners(); }
}

// ── Chat Provider ─────────────────────────────────────────────────────────────

enum ChatStatus { idle, loading, error }

class ChatProvider extends ChangeNotifier {
  final _api = ApiService();
  final _firestore = FirestoreService();

  // Called after each successful AI reply is received
  // so UI can refresh dependent screens (e.g., assessments).
  VoidCallback? onMessageReceived;

  // IMPORTANT:
  // Do NOT call GroqLLMService directly from the Flutter app.
  // The backend server (Python) owns the Groq API key + LLM calls.

  // Prevent concurrent sendMessage calls.
  // On Flutter Web, Firestore writes can backlog and cause later
  // backend calls to time out / appear stuck after a few messages.
  bool _sendInFlight = false;

  List<ChatMessage> _messages = [];
  ChatStatus _status = ChatStatus.idle;
  String? _error;
  String? _sessionId;
  ExerciseSuggestion? _pendingExercise;
  bool _isConnected = true;

  // Backend availability is determined by the Python API being reachable.
  // (We still keep this flag lightweight so UI logic doesn't block.)
  bool _backendReady = true;





  List<ChatMessage> get messages => _messages;
  ChatStatus get status => _status;
  String? get error => _error;
  String? get sessionId => _sessionId;
  ExerciseSuggestion? get pendingExercise => _pendingExercise;
  bool get isConnected => _isConnected;
  bool get isLoading => _status == ChatStatus.loading;
  // Always considered connected; backend calls are handled per-request.
  bool get backendReady => _backendReady;


  // ── Initialize ─────────────────────────────────────────────────────────────

  Future<void> init(String userId) async {
    // No backend calls — everything local
    _isConnected = true;
    _backendReady = true;

    // Generate session ID locally
    _sessionId = const Uuid().v4();

    // Try to restore previous session ID
    // from Firestore for continuity
    try {
      final saved = await _firestore.getSessionId(userId);
      if (saved != null && saved.isNotEmpty) {
        _sessionId = saved;
      } else {
        // Save new local session ID
        await _firestore.saveSessionId(userId, _sessionId!);
      }
    } catch (_) {
      // Firestore unavailable — use local ID
    }

    // Load chat history from Firestore
    try {
      _messages = await _firestore.getChatHistoryOnce(userId);
    } catch (_) {
      _messages = [];
    }

    notifyListeners();
  }

  // ── Restore assessments (optional — only if Python backend is running) ────

  Future<void> _restoreAssessments(String userId) async {
    if (_sessionId == null || _messages.isEmpty) return;
    try {
      final messageList = _messages.map((m) => {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      }).toList();

      final uri = Uri.parse('${ApiService.baseUrl}/session/restore');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'session_id': _sessionId, 'messages': messageList}),
      ).timeout(const Duration(seconds: 5));
      debugPrint('Assessment scores restored from history');
    } catch (e) {
      debugPrint('Assessment restore skipped (backend not running): $e');
    }
  }

  Future<void> restoreAssessments() async {
    if (_sessionId == null || _messages.isEmpty) return;
    await _restoreAssessments('');
  }

    // ── Send Message ── Use Python backend (/chat) ─────────────────────────

  Future<void> sendMessage(
      String text, String userId,
      {bool postExercise = false}) async {
    if (text.trim().isEmpty) return;

    // Ensure session ID exists
    if (_sessionId == null) {
      _sessionId = const Uuid().v4();
      _firestore.saveSessionId(userId, _sessionId!)
          .catchError((_) {});
    }

    // Add user message immediately
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      content: text.trim(),
      role: MessageRole.user,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );
    _messages.add(userMsg);

    // Add typing placeholder immediately
    final placeholderId = const Uuid().v4();
    _messages.add(ChatMessage(
      id: placeholderId,
      content: '',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    ));

    _status = ChatStatus.loading;
    notifyListeners();

    // Save user message to Firestore
    _firestore.saveMessage(userId, userMsg)
        .catchError((_) {});

    try {
      // Check for crisis first (local keyword check)
      final isCrisis = _checkCrisis(text);

      String reply;
      String emotion;

      if (isCrisis) {
        reply = _getCrisisResponse();
        emotion = 'crisis';
      } else {
        // Try Python backend first (has RAG + assessment inference)
        bool backendUsed = false;
        try {
          final apiResp = await _api.sendMessage(
            message: text,
            sessionId: _sessionId ?? '',
            postExercise: postExercise,
          );

          reply = apiResp.reply;
          emotion = apiResp.emotion;
          backendUsed = true;

          // Save assessment scores from backend to Firestore
          if (apiResp.assessmentScores.isNotEmpty) {
            debugPrint('[Chat] Saving assessment scores from backend: ${apiResp.assessmentScores.keys.toList()}');
            _firestore.saveAssessmentScores(userId, apiResp.assessmentScores)
                .catchError((e) => debugPrint('[Chat] saveAssessmentScores error: $e'));
          }
        } catch (e) {
          // Backend unreachable — fall back to embedded Groq
          debugPrint('[Chat] Backend unavailable ($e), using Groq directly');
          final groq = GroqLLMService();
          final result = await groq.generate(
            userMessage: text,
            postExercise: postExercise,
          );
          reply = result.reply;
          emotion = result.emotion;
        }
      }

      // Replace placeholder with response
      final idx = _messages.indexWhere(
          (m) => m.id == placeholderId);
      final aiMsg = ChatMessage(
        id: const Uuid().v4(),
        content: reply,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        emotion: emotion,
        status: MessageStatus.sent,
        crisisDetected: isCrisis,
      );

      if (idx != -1) {
        _messages[idx] = aiMsg;
      } else {
        _messages.add(aiMsg);
      }

      // Save AI message to Firestore
      _firestore.saveMessage(userId, aiMsg)
          .catchError((_) {});

      _status = ChatStatus.idle;
      _error = null;

      onMessageReceived?.call();
    } catch (e) {
      _messages.removeWhere(
          (m) => m.id == placeholderId);
      _status = ChatStatus.error;
      _error = e.toString().contains('401')
          ? 'Invalid Groq API key. '
            'Check your .env file.'
          : e.toString().contains('429')
              ? 'Too many requests. '
                'Wait a moment and try again.'
              : 'Failed to get response. '
                'Please try again.';
    }

    notifyListeners();
  }

  // Crisis detection — no backend needed
  bool _checkCrisis(String text) {
    final lower = text.toLowerCase();
    final keywords = [
      'kill myself', 'end my life',
      'want to die', 'suicide',
      'better off dead', 'take my life',
      'harm myself', 'hurt myself',
    ];
    return keywords.any((k) => lower.contains(k));
  }

  String _getCrisisResponse() {
    return '''I'm deeply concerned about 
what you just shared. You are not alone.

Please reach out immediately:
- Pakistan: Umang: 0317-4288665
- Pakistan: Rozan: 051-2890505  
- Emergency: 115
- USA: 988 Suicide & Crisis Lifeline
- UK: Samaritans: 116 123

I'm still here for you. 
Whenever you're ready to talk, 
I'm listening. 💙''';
  }

  void clearPendingExercise() {
    _pendingExercise = null;
    notifyListeners();
  }

  Future<void> startNewSession(String userId) async {
    _sessionId = _uuid.v4(); // generate locally
    await _firestore.saveSessionId(userId, _sessionId!);
    _messages = [];

    _pendingExercise = null;

    // Reset assessment results in Firestore to 0 for new session
    try {
      await _firestore.resetAssessmentScores(userId);
    } catch (_) {
      // non-fatal
    }

    notifyListeners();
  }

  void clearError() { _error = null; notifyListeners(); }
}

// ── Theme Provider ────────────────────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;
  void toggle() { _isDark = !_isDark; notifyListeners(); }
  void setDark(bool v) { _isDark = v; notifyListeners(); }
}

// ── Progress Provider ─────────────────────────────────────────────────────────

class ProgressProvider extends ChangeNotifier {
  final _api = ApiService();
  SessionProgress? _progress;

  SessionProgress? get progress => _progress;

  Future<void> refresh(String sessionId) async {
    try {
      _progress = await _api.getProgress(sessionId);
      notifyListeners();
    } catch (e) {
      // Backend session can expire (Python in-memory sessions reset on restart).
      // Keep UI stable and make it obvious in logs.
      debugPrint('[ProgressProvider] refresh failed for sessionId=$sessionId: $e');
      _progress = _progress; // no-op (leave existing data)
    }
  }
}