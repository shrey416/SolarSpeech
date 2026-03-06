import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/suggestion.dart';
import '../services/context_analyzer.dart';
import '../services/behavior_tracker.dart';

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
    // Record navigation for behavior learning
    BehaviorTracker.recordNavigation(route);
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
