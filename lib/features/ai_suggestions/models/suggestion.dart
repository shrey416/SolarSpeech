import 'package:flutter/material.dart';

enum SuggestionType {
  navigation,
  anomaly,
  report,
  insight,
  comparison,
}

enum SuggestionPriority { low, medium, high, critical }

class AiSuggestion {
  final String id;
  final String message;
  final String? route;
  final SuggestionType type;
  final SuggestionPriority priority;
  final IconData icon;
  final Map<String, dynamic> metadata;

  const AiSuggestion({
    required this.id,
    required this.message,
    this.route,
    required this.type,
    this.priority = SuggestionPriority.medium,
    this.icon = Icons.lightbulb_outline,
    this.metadata = const {},
  });

  double get priorityWeight {
    switch (priority) {
      case SuggestionPriority.critical:
        return 4.0;
      case SuggestionPriority.high:
        return 3.0;
      case SuggestionPriority.medium:
        return 2.0;
      case SuggestionPriority.low:
        return 1.0;
    }
  }
}

class ScreenContext {
  final String route;
  final String screenName;
  final Map<String, String> params;
  final DateTime viewedAt;

  const ScreenContext({
    required this.route,
    required this.screenName,
    this.params = const {},
    required this.viewedAt,
  });
}
