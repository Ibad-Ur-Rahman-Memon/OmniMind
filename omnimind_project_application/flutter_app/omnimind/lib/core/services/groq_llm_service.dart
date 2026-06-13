import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;


/// Groq LLM integration.
///
/// Note: In this codebase, `emotion` is represented as a *String* (see
/// `ChatMessage.emotion`). This service therefore returns emotion strings.
class GroqLLMService {
  static String? groqApiKey;

  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  final List<Map<String, String>> _history = [];
  bool _configured = false;

  bool get isConfigured => _configured || (groqApiKey?.trim().isNotEmpty ?? false);

  void configure({required String apiKey}) {
    groqApiKey = apiKey;
    _configured = apiKey.trim().isNotEmpty;
  }

  void clearSession() => _history.clear();

  Future<void> loadHistory() async {
    // No-op: using in-memory history.
    _configured = (groqApiKey?.trim().isNotEmpty ?? false);
  }

  Future<GroqLLMResponse> generate({
    required String userMessage,
    required bool postExercise,
  }) async {
    final start = DateTime.now();

    if (!isConfigured) {
      return GroqLLMResponse(
        reply:
            'Groq is not configured. Add your GROQ API key to GroqLLMService.groqApiKey.',
        emotion: 'neutral',
        crisisDetected: false,
        latencyMs: DateTime.now().difference(start).inMilliseconds,
      );
    }

    _history.add({'role': 'user', 'content': userMessage});

    final messages = <Map<String, String>>[
      ..._buildSystemPrompt(postExercise),
      ..._history,
    ];

    final payload = {
      'model': 'llama-3.3-70b-versatile',
      'messages': messages,
      'temperature': 0.7,
      'stream': false,
      'response_format': {'type': 'json_object'},
    };

    try {
      final res = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${groqApiKey!.trim()}',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Groq error ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = (decoded['choices'] as List).cast<Map<String, dynamic>>();
      final message = choices.first['message'] as Map<String, dynamic>;
      final content = (message['content'] ?? '').toString();

      _history.add({'role': 'assistant', 'content': content});

      final parsed = _parseAssistantContent(content);
      return GroqLLMResponse(
        reply: parsed.reply,
        emotion: parsed.emotion,
        crisisDetected: parsed.crisisDetected,
        latencyMs: DateTime.now().difference(start).inMilliseconds,
      );
    } catch (e, st) {
      debugPrint('[GroqLLMService] generate failed: $e\n$st');
      return GroqLLMResponse(
        reply: 'Failed to get response from Groq. Please try again.',
        emotion: 'neutral',
        crisisDetected: false,
        latencyMs: DateTime.now().difference(start).inMilliseconds,
      );
    }
  }

  List<Map<String, String>> _buildSystemPrompt(bool postExercise) {
    return [
      {
        'role': 'system',
        'content': [
          'You are OmniMind, a supportive mental-health assistant.',
          'Return STRICT JSON with keys: reply (string), emotion (one of: neutral, happy, sad, angry, anxious, calm), crisisDetected (boolean).',
          'If the user shows self-harm or imminent crisis, set crisisDetected=true and keep reply supportive and non-judgmental.',
          if (postExercise)
            'The user is completing an exercise. Be encouraging, summarize progress, and suggest a small next step.'
          else
            'Do a brief reflection, validate feelings, and ask one relevant question.'
        ].join('\n'),
      }
    ];
  }

  _ParsedAssistant _parseAssistantContent(String content) {
    // Try strict JSON first.
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        final reply = decoded['reply']?.toString() ?? content;
        final emotion = (decoded['emotion'] ?? 'neutral').toString();
        final crisis = decoded['crisisDetected'];

        return _ParsedAssistant(
          reply: reply,
          emotion: _normalizeEmotion(emotion),
          crisisDetected: crisis is bool ? crisis : false,
        );
      }
    } catch (_) {
      // fall through to heuristics
    }

    // Heuristic fallback.
    final lower = content.toLowerCase();
    final crisis = lower.contains('suicide') ||
        lower.contains('self-harm') ||
        lower.contains('kill myself') ||
        lower.contains('hurt myself');

    var emotion = 'neutral';
    if (lower.contains('anxious') || lower.contains('anxiety')) {
      emotion = 'anxious';
    } else if (lower.contains('sad')) {
      emotion = 'sad';
    } else if (lower.contains('angry')) {
      emotion = 'angry';
    } else if (lower.contains('happy')) {
      emotion = 'happy';
    } else if (lower.contains('calm')) {
      emotion = 'calm';
    }

    return _ParsedAssistant(
      reply: content,
      emotion: emotion,
      crisisDetected: crisis,
    );
  }

  String _normalizeEmotion(String raw) {
    final key = raw.trim().toLowerCase();
    const allowed = {'neutral', 'happy', 'sad', 'angry', 'anxious', 'calm'};
    return allowed.contains(key) ? key : 'neutral';
  }
}

class GroqLLMResponse {
  final String reply;
  final String emotion;
  final bool crisisDetected;
  final int latencyMs;

  const GroqLLMResponse({
    required this.reply,
    required this.emotion,
    required this.crisisDetected,
    required this.latencyMs,
  });
}

class _ParsedAssistant {
  final String reply;
  final String emotion;
  final bool crisisDetected;

  _ParsedAssistant({
    required this.reply,
    required this.emotion,
    required this.crisisDetected,
  });
}

