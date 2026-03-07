import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/suggestion.dart';
import '../services/context_analyzer.dart';
import '../services/behavior_tracker.dart';
import '../services/crowd_navigation_service.dart';

// ── Current screen context ──
class _ScreenContextNotifier extends Notifier<ScreenContext?> {
  @override
  ScreenContext? build() => null;

  void update(String route, {Map<String, String> params = const {}}) {
    final name = _routeToName(route);
    state = ScreenContext(
      route: route,
      screenName: name,
      params: params,
      viewedAt: DateTime.now(),
    );
    // Record navigation for local behavior learning
    BehaviorTracker.recordNavigation(route);
    // Record transition for crowd-sourced suggestions (pgvector)
    CrowdNavigationService.recordTransition(
      toRoute: route,
      toScreen: name,
    );
  }

  String _routeToName(String route) {
    if (route == '/dashboard') return 'Dashboard';
    if (route == '/my-plants') return 'My Plants';
    if (route == '/inverters') return 'Inverters';
    if (route.contains('/inverters/')) return 'Inverter Detail';
    if (route.contains('/mfm/')) return 'MFM Detail';
    if (route.contains('/temp/')) return 'Temperature Detail';
    if (route.startsWith('/plants/')) return 'Plant Detail';
    if (route == '/slms') return 'SLMS Devices';
    if (route.startsWith('/slms/')) return 'SLMS Detail';
    if (route == '/sensors') return 'Sensors';
    if (route == '/alerts') return 'Alerts';
    if (route == '/exports') return 'Exports';
    return 'Unknown';
  }
}

final screenContextProvider =
    NotifierProvider<_ScreenContextNotifier, ScreenContext?>(
        _ScreenContextNotifier.new);

// ── Suggestions for current context ──
final suggestionsProvider = FutureProvider<List<AiSuggestion>>((ref) async {
  final ctx = ref.watch(screenContextProvider);
  if (ctx == null) return [];
  return ContextAnalyzer.analyze(ctx);
});

// ── Crowd-sourced "most users go here" suggestions ──
final crowdSuggestionsProvider =
    FutureProvider<List<AiSuggestion>>((ref) async {
  final ctx = ref.watch(screenContextProvider);
  if (ctx == null) return [];

  final crowdData =
      await CrowdNavigationService.getSuggestions(ctx.route);

  final suggestions = <AiSuggestion>[];
  final seenRoutes = <String>{};

  for (final cs in crowdData) {
    // Skip self-links and duplicates
    if (cs.toRoute == ctx.route) continue;
    if (seenRoutes.contains(cs.toRoute)) continue;
    seenRoutes.add(cs.toRoute);

    final pct = cs.percentage;
    final icon = _iconForRoute(cs.toRoute);

    final message = pct > 0
        ? '$pct% of users visit ${cs.toScreen} next'
        : 'Popular: users often visit ${cs.toScreen} from here';

    suggestions.add(AiSuggestion(
      id: 'crowd_${cs.toRoute.replaceAll("/", "_")}',
      message: message,
      route: cs.toRoute,
      type: SuggestionType.trending,
      priority: pct >= 50
          ? SuggestionPriority.high
          : pct >= 25
              ? SuggestionPriority.medium
              : SuggestionPriority.low,
      icon: icon,
      metadata: {
        'crowd_percentage': pct,
        'crowd_count': cs.transitionCount,
      },
    ));
  }
  return suggestions;
});

IconData _iconForRoute(String route) {
  if (route.contains('/dashboard')) return Icons.dashboard;
  if (route.contains('/inverters')) return Icons.electrical_services;
  if (route.contains('/sensors') ||
      route.contains('/mfm/') ||
      route.contains('/temp/')) return Icons.sensors;
  if (route.contains('/alerts')) return Icons.warning_amber;
  if (route.contains('/exports')) return Icons.file_download_outlined;
  if (route.contains('/slms')) return Icons.monitor;
  if (route.contains('/plants') || route.contains('/my-plants')) {
    return Icons.park_outlined;
  }
  return Icons.trending_up;
}

// ── Suggestion bar visibility ──
class _SuggestionBarNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void show() => state = true;
  void hide() => state = false;
  void toggle() => state = !state;
}

final suggestionBarVisibleProvider =
    NotifierProvider<_SuggestionBarNotifier, bool>(
        _SuggestionBarNotifier.new);
