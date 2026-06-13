/// risk_engine.dart — Unified risk assessment engine for mental health assessments
///
/// Implements clinical risk detection, combined risk scoring, and safety layers
/// for PHQ-9, GAD-7, PSS-10, and SPIN assessments.
library;

import '../models/models.dart';

class RiskEngine {
  /// Calculate risk level based on assessment scores
  ///
  /// Returns: 'low' | 'moderate' | 'high' | 'critical' | 'unknown'
  static String calculateRiskLevel(List<Assessment> assessments) {
    int phq = 0, gad = 0, pss = 0, spin = 0;
    int phqItem9 = 0; // Self-harm item from PHQ-9

    for (final a in assessments) {
      final name = a.name.toUpperCase();
      final score = a.score;
      
      if (name.contains('PHQ')) {
        phq = score;
        // Extract PHQ-9 item 9 (self-harm) if available
        if (a.questions.length >= 9) {
          final q9 = a.questions[8]; // 0-indexed
          phqItem9 = q9.answeredScore != null && q9.answeredScore! > 0 ? 1 : 0;
        }
      } else if (name.contains('GAD')) {
        gad = score;
      } else if (name.contains('PSS')) {
        pss = score;
      } else if (name.contains('SPIN')) {
        spin = score;
      }
    }

    // Check for crisis first (self-harm)
    if (phqItem9 > 0) {
      return 'critical';
    }

    // Check for high risk
    if (phq >= 15 || gad >= 15 || pss >= 27) {
      return 'high';
    }

    // Check for moderate risk
    if (phq >= 10 || gad >= 10 || pss >= 14 || spin >= 21) {
      return 'moderate';
    }

    // Check for low risk
    if (phq >= 5 || gad >= 5 || pss >= 7) {
      return 'low';
    }

    // All scores are 0 or very minimal
    if (phq == 0 && gad == 0 && pss == 0 && spin == 0) {
      return 'unknown';
    }

    return 'low';
  }

  /// Get specific risk flags for UI display and alerts
  static Map<String, bool> getRiskFlags(List<Assessment> assessments) {
    int phq = 0, gad = 0, pss = 0, spin = 0;
    int phqItem9 = 0; // Self-harm item from PHQ-9

    for (final a in assessments) {
      final name = a.name.toUpperCase();
      final score = a.score;
      
      if (name.contains('PHQ')) {
        phq = score;
        // Extract PHQ-9 item 9 (self-harm) if available
        if (a.questions.length >= 9) {
          final q9 = a.questions[8]; // 0-indexed
          phqItem9 = q9.answeredScore != null && q9.answeredScore! > 0 ? 1 : 0;
        }
      } else if (name.contains('GAD')) {
        gad = score;
      } else if (name.contains('PSS')) {
        pss = score;
      } else if (name.contains('SPIN')) {
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

  /// Calculate combined risk score (0-100) using weighted formula
  ///
  /// Formula: (PHQ-9 * 0.4) + (GAD-7 * 0.3) + (PSS-10 * 0.2) + (SPIN * 0.1)
  /// Normalized to 0-100 scale
  static double calculateCombinedRiskScore(List<Assessment> assessments) {
    int phq = 0, gad = 0, pss = 0, spin = 0;

    for (final a in assessments) {
      final name = a.name.toUpperCase();
      final score = a.score;
      
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

    // Max possible scores for each assessment
    const maxPhq = 27;
    const maxGad = 21;
    const maxPss = 40;
    const maxSpin = 68;

    // Normalize each score to 0-1 range (handle division by zero)
    final normPhq = maxPhq > 0 ? phq / maxPhq : 0.0;
    final normGad = maxGad > 0 ? gad / maxGad : 0.0;
    final normPss = maxPss > 0 ? pss / maxPss : 0.0;
    final normSpin = maxSpin > 0 ? spin / maxSpin : 0.0;

    // Weighted sum
    final weightedSum = (normPhq * 0.4) + (normGad * 0.3) + (normPss * 0.2) + (normSpin * 0.1);

    // Convert to 0-100 scale and clamp
    return (weightedSum * 100).clamp(0.0, 100.0);
  }

  /// Get clinical interpretation for risk level
  static String getRiskInterpretation(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'critical':
        return 'CRISIS ALERT: Self-harm indicators detected. Immediate professional intervention required.';
      case 'high':
        return 'High clinical risk detected. Professional evaluation strongly recommended.';
      case 'moderate':
        return 'Moderate risk indicators present. Consider professional consultation.';
      case 'low':
        return 'Low risk detected. Continue monitoring and self-care practices.';
      case 'unknown':
        return 'Insufficient data for risk assessment. Continue engagement with assessments.';
      default:
        return 'Risk level not recognized.';
    }
  }

  /// Get color for risk level UI
  static int getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'critical':
        return 0xFFFF0000; // Bright red
      case 'high':
        return 0xFFF44336; // Red
      case 'moderate':
        return 0xFFFF9800; // Orange
      case 'low':
        return 0xFF4CAF50; // Green
      case 'unknown':
      default:
        return 0xFF6B7A99; // Gray
    }
  }

  /// Check if any crisis indicators are present
  static bool hasCrisisIndicators(List<Assessment> assessments) {
    for (final a in assessments) {
      if (a.name.toUpperCase().contains('PHQ') && a.questions.length >= 9) {
        final q9 = a.questions[8]; // PHQ-9 item 9
        if (q9.answeredScore != null && q9.answeredScore! > 0) {
          return true;
        }
      }
    }
    return false;
  }
}