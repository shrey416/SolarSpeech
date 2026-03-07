import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a crowd-sourced navigation suggestion based on what most users
/// do after visiting a particular page.
class CrowdSuggestion {
  final String toRoute;
  final String toScreen;
  final int transitionCount;
  final int percentage;
  final double similarityScore;
  final String source; // 'direct' or 'similar'

  const CrowdSuggestion({
    required this.toRoute,
    required this.toScreen,
    required this.transitionCount,
    required this.percentage,
    required this.similarityScore,
    required this.source,
  });

  factory CrowdSuggestion.fromJson(Map<String, dynamic> json) {
    return CrowdSuggestion(
      toRoute: json['to_route'] as String,
      toScreen: json['to_screen'] as String,
      transitionCount: json['transition_count'] as int? ?? 0,
      percentage: json['percentage'] as int? ?? 0,
      similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 0.5,
      source: json['source'] as String? ?? 'direct',
    );
  }
}

/// Service that tracks navigation patterns across all users and provides
/// crowd-sourced "what most users do next" suggestions via Supabase pgvector.
class CrowdNavigationService {
  static final _supabase = Supabase.instance.client;
  static String? _sessionId;
  static String? _lastRoute;
  static String? _lastScreen;

  /// Get or create a session ID for this app session
  static String get _currentSessionId {
    if (_sessionId != null) return _sessionId!;
    // Use auth user ID if logged in, otherwise generate a random hex string
    final userId = _supabase.auth.currentSession?.user.id;
    if (userId != null) {
      _sessionId = userId;
    } else {
      final rng = Random.secure();
      final bytes = List.generate(16, (_) => rng.nextInt(256));
      _sessionId = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
    return _sessionId!;
  }

  /// Record a page transition when the user navigates.
  /// Call this whenever the screen context changes.
  static Future<void> recordTransition({
    required String toRoute,
    required String toScreen,
  }) async {
    // Skip if this is the first page (no "from" yet)
    if (_lastRoute == null) {
      _lastRoute = toRoute;
      _lastScreen = toScreen;
      return;
    }

    // Skip self-transitions
    if (_lastRoute == toRoute) return;

    final fromRoute = _lastRoute!;
    final fromScreen = _lastScreen ?? 'Unknown';

    // Update last route before async call
    _lastRoute = toRoute;
    _lastScreen = toScreen;

    try {
      // Normalize dynamic routes for aggregation:
      // /plants/123/inverters/456 → /plants/:id/inverters/:id
      final normalizedFrom = _normalizeRoute(fromRoute);
      final normalizedTo = _normalizeRoute(toRoute);

      await _supabase.from('navigation_events').insert({
        'session_id': _currentSessionId,
        'from_route': normalizedFrom,
        'to_route': normalizedTo,
        'from_screen': fromScreen,
        'to_screen': toScreen,
      });

      // Fire-and-forget stats refresh
      _supabase.rpc('refresh_transition_stats').then((_) {}).catchError((e) {
        debugPrint('CrowdNav: Stats refresh warning: $e');
      });

      // Ensure route embeddings exist for dynamic routes
      _ensureRouteEmbedding(normalizedTo, toScreen);
    } catch (e) {
      debugPrint('CrowdNav: Failed to record transition: $e');
    }
  }

  /// Fetch crowd-based suggestions for the current route.
  /// Returns what most users navigate to after visiting this page.
  static Future<List<CrowdSuggestion>> getSuggestions(String route) async {
    try {
      final normalizedRoute = _normalizeRoute(route);

      // Query direct transition stats
      final directResult = await _supabase
          .rpc('get_crowd_suggestions', params: {
            'p_route': normalizedRoute,
            'p_limit': 5,
          })
          .select();

      final List<dynamic> directData = directResult as List<dynamic>? ?? [];

      // Compute percentages
      final totalCount = directData.fold<int>(
        0,
        (sum, row) => sum + ((row['transition_count'] as int?) ?? 0),
      );

      final suggestions = <CrowdSuggestion>[];
      final seenRoutes = <String>{};

      for (final row in directData) {
        final count = (row['transition_count'] as int?) ?? 0;
        final rawRoute = row['to_route'] as String;
        final screen = row['to_screen'] as String;

        // Convert normalized :id routes to navigable list pages
        final navigable = _toNavigableRoute(rawRoute);
        final navigableScreen = _toNavigableScreen(rawRoute, screen);

        // Skip duplicates (multiple :id routes may map to same list page)
        if (seenRoutes.contains(navigable)) continue;
        // Skip self-links
        if (navigable == route || navigable == normalizedRoute) continue;
        seenRoutes.add(navigable);

        suggestions.add(CrowdSuggestion(
          toRoute: navigable,
          toScreen: navigableScreen,
          transitionCount: count,
          percentage: totalCount > 0
              ? ((count / totalCount) * 100).round()
              : 0,
          similarityScore:
              (row['similarity_score'] as num?)?.toDouble() ?? 0.5,
          source: 'direct',
        ));
      }

      return suggestions;
    } catch (e) {
      debugPrint('CrowdNav: Failed to fetch suggestions: $e');
      return [];
    }
  }

  /// Convert normalized :id routes to navigable list pages.
  /// e.g. /plants/:id/inverters/:id → /inverters
  static String _toNavigableRoute(String route) {
    // Already navigable (no :id placeholder)
    if (!route.contains(':id')) return route;

    // Map detail patterns to their list counterparts
    if (route == '/plants/:id/inverters/:id') return '/inverters';
    if (route == '/plants/:id/mfm/:id') return '/sensors';
    if (route == '/plants/:id/temp/:id') return '/sensors';
    if (route == '/plants/:id') return '/my-plants';
    if (route == '/slms/:id') return '/slms';

    // Fallback: strip everything after first :id
    final idx = route.indexOf(':id');
    if (idx > 1) {
      final prefix = route.substring(0, idx - 1); // remove trailing /
      return prefix.isEmpty ? '/dashboard' : prefix;
    }
    return route;
  }

  /// Return user-friendly screen name for the navigable route.
  static String _toNavigableScreen(String rawRoute, String originalScreen) {
    if (!rawRoute.contains(':id')) return originalScreen;

    if (rawRoute == '/plants/:id/inverters/:id') return 'Inverters';
    if (rawRoute == '/plants/:id/mfm/:id') return 'Sensors (MFM)';
    if (rawRoute == '/plants/:id/temp/:id') return 'Sensors (Temperature)';
    if (rawRoute == '/plants/:id') return 'My Plants';
    if (rawRoute == '/slms/:id') return 'SLMS Devices';

    return originalScreen;
  }

  /// Normalize a dynamic route by replacing numeric/UUID IDs with :id
  /// e.g. /plants/123/inverters/456 → /plants/:id/inverters/:id
  static String _normalizeRoute(String route) {
    // Strip query parameters for normalization
    final base = route.split('?').first;
    return base.replaceAllMapped(
      RegExp(r'/(\d+|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'),
      (match) => '/:id',
    );
  }

  /// Ensure the route embedding table has an entry for this route
  static Future<void> _ensureRouteEmbedding(
      String route, String screen) async {
    try {
      final existing = await _supabase
          .from('route_embeddings')
          .select('id')
          .eq('route', route)
          .maybeSingle();

      if (existing != null) return;

      final embedding = _routeToEmbedding(route);
      await _supabase.from('route_embeddings').insert({
        'route': route,
        'screen': screen,
        'embedding': embedding.toString(),
      });
    } catch (e) {
      debugPrint('CrowdNav: Embedding insert warning: $e');
    }
  }

  /// Generate a feature vector from a route pattern.
  /// [dashboard, plant, inverter, sensor, alert, export, slms, depth]
  static List<double> _routeToEmbedding(String route) {
    final isDashboard = route == '/dashboard' ? 1.0 : 0.0;
    final isPlant =
        route.startsWith('/plants/') || route == '/my-plants' ? 1.0 : 0.0;
    final isInverter = route.contains('/inverters') ? 1.0 : 0.0;
    final isSensor = (route.contains('/sensors') ||
            route.contains('/mfm/') ||
            route.contains('/temp/'))
        ? 1.0
        : 0.0;
    final isAlert = route.contains('/alerts') ? 1.0 : 0.0;
    final isExport = route.contains('/exports') ? 1.0 : 0.0;
    final isSlms = route.contains('/slms') ? 1.0 : 0.0;

    final segments = route.split('/').where((s) => s.isNotEmpty).length;
    final depth = (segments / 4).clamp(0.0, 1.0);

    return [
      isDashboard,
      isPlant,
      isInverter,
      isSensor,
      isAlert,
      isExport,
      isSlms,
      depth,
    ];
  }
}
