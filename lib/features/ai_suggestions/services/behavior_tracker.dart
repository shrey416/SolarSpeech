import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks user interactions with suggestions and learns which suggestion types
/// are most useful in each context. Uses a Bayesian scoring approach that
/// self-trains over time based on click-through vs dismiss rates.
class BehaviorTracker {
  static const _prefsKey = 'ai_suggestion_behavior';
  static const _navHistoryKey = 'ai_nav_history';
  static const _maxHistory = 50;

  /// Record format: { "contextKey": { "shown": int, "clicked": int } }
  static Future<void> recordImpression(
      String contextKey, String suggestionId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = _loadData(prefs);
    final key = '${contextKey}__$suggestionId';
    final entry = data[key] ?? {'shown': 0, 'clicked': 0};
    entry['shown'] = (entry['shown'] as int) + 1;
    data[key] = entry;
    await prefs.setString(_prefsKey, jsonEncode(data));
  }

  static Future<void> recordClick(
      String contextKey, String suggestionId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = _loadData(prefs);
    final key = '${contextKey}__$suggestionId';
    final entry = data[key] ?? {'shown': 1, 'clicked': 0};
    entry['clicked'] = (entry['clicked'] as int) + 1;
    data[key] = entry;
    await prefs.setString(_prefsKey, jsonEncode(data));
  }

  static Future<void> recordDismiss(
      String contextKey, String suggestionId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = _loadData(prefs);
    final key = '${contextKey}__$suggestionId';
    final entry = data[key] ?? {'shown': 1, 'clicked': 0};
    // Dismissal increases shown count without clicking, lowering score
    entry['shown'] = (entry['shown'] as int) + 1;
    data[key] = entry;
    await prefs.setString(_prefsKey, jsonEncode(data));
  }

  /// Returns a score between 0.0 and 1.0 based on historical click-through
  /// rate. Uses Laplace smoothing (add-1) to avoid cold-start issues.
  static Future<double> getScore(
      String contextKey, String suggestionId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = _loadData(prefs);
    final key = '${contextKey}__$suggestionId';
    final entry = data[key];
    if (entry == null) return 0.5; // neutral prior for unseen suggestions
    final shown = (entry['shown'] as int) + 2; // Laplace smoothing
    final clicked = (entry['clicked'] as int) + 1;
    return clicked / shown;
  }

  /// Track navigation history for pattern detection
  static Future<void> recordNavigation(String route) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_navHistoryKey) ?? [];
    history.add('${DateTime.now().toIso8601String()}|$route');
    if (history.length > _maxHistory) {
      history.removeRange(0, history.length - _maxHistory);
    }
    await prefs.setStringList(_navHistoryKey, history);
  }

  /// Get recent navigation history as (timestamp, route) pairs
  static Future<List<(DateTime, String)>> getNavHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_navHistoryKey) ?? [];
    return history.map((entry) {
      final parts = entry.split('|');
      return (DateTime.parse(parts[0]), parts.sublist(1).join('|'));
    }).toList();
  }

  /// Check if user has visited a specific route recently
  static Future<bool> hasVisitedRecently(
      String route, Duration window) async {
    final history = await getNavHistory();
    final cutoff = DateTime.now().subtract(window);
    return history
        .any((entry) => entry.$2 == route && entry.$1.isAfter(cutoff));
  }

  static Map<String, dynamic> _loadData(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }
}
