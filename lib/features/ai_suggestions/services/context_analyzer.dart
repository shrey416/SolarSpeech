import 'package:flutter/material.dart';
import '../models/suggestion.dart';
import 'behavior_tracker.dart';

/// Core rule engine that generates contextual suggestions based on the current
/// screen, data patterns, and user behavior history. The engine uses domain
/// knowledge about solar plant monitoring to produce relevant recommendations.
class ContextAnalyzer {
  /// Generate suggestions for the given screen context.
  /// Returns a list sorted by relevance (priority * learned score).
  static Future<List<AiSuggestion>> analyze(ScreenContext ctx) async {
    final candidates = <AiSuggestion>[];

    // Apply all rule sets
    candidates.addAll(_dashboardRules(ctx));
    candidates.addAll(_plantDetailRules(ctx));
    candidates.addAll(_inverterDetailRules(ctx));
    candidates.addAll(_inverterListRules(ctx));
    candidates.addAll(_sensorRules(ctx));
    candidates.addAll(_mfmDetailRules(ctx));
    candidates.addAll(_tempDetailRules(ctx));
    candidates.addAll(_slmsRules(ctx));
    candidates.addAll(_alertsPageRules(ctx));
    candidates.addAll(_exportsPageRules(ctx));
    candidates.addAll(await _behaviorBasedRules(ctx));

    // Score and sort using learned weights
    final scored = <(AiSuggestion, double)>[];
    final contextKey = _contextKey(ctx);
    for (final s in candidates) {
      final learned = await BehaviorTracker.getScore(contextKey, s.id);
      scored.add((s, s.priorityWeight * learned));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    // Return top 3 most relevant
    return scored.take(3).map((e) => e.$1).toList();
  }

  static String _contextKey(ScreenContext ctx) => ctx.route;

  // ─── Dashboard Rules ─────────────────────────────────────────────────

  static List<AiSuggestion> _dashboardRules(ScreenContext ctx) {
    if (ctx.route != '/dashboard') return [];
    return [
      const AiSuggestion(
        id: 'dash_check_underperforming',
        message:
            'Want to check which inverters are underperforming today? Tap to view all inverters.',
        route: '/inverters',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.medium,
        icon: Icons.trending_down,
      ),
      const AiSuggestion(
        id: 'dash_view_alerts',
        message:
            'No active alerts right now. Tap to review alert history and stay ahead of issues.',
        route: '/alerts',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.low,
        icon: Icons.notifications_none,
      ),
      const AiSuggestion(
        id: 'dash_visit_plants',
        message:
            'View detailed plant-by-plant energy breakdown to spot trends.',
        route: '/my-plants',
        type: SuggestionType.insight,
        priority: SuggestionPriority.medium,
        icon: Icons.park_outlined,
      ),
      const AiSuggestion(
        id: 'dash_sensor_health',
        message:
            'Check sensor health across all plants to ensure data accuracy.',
        route: '/sensors',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.low,
        icon: Icons.sensors,
      ),
    ];
  }

  // ─── Plant Detail Rules ──────────────────────────────────────────────

  static List<AiSuggestion> _plantDetailRules(ScreenContext ctx) {
    if (!ctx.route.startsWith('/plants/') ||
        ctx.route.contains('/inverters/') ||
        ctx.route.contains('/mfm/') ||
        ctx.route.contains('/temp/')) return [];

    final plantId = ctx.params['plantId'] ?? '';
    return [
      AiSuggestion(
        id: 'plant_check_inverters',
        message:
            'Review individual inverter performance for this plant to spot underperformers.',
        route: '/inverters',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.high,
        icon: Icons.electrical_services,
      ),
      AiSuggestion(
        id: 'plant_check_sensors',
        message:
            'Check sensor readings (MFM, temperature) for this plant to validate grid connection.',
        route: '/sensors',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.medium,
        icon: Icons.sensors,
      ),
      AiSuggestion(
        id: 'plant_file_report',
        message:
            'Noticed something off with this plant\'s output? File a report to flag it for maintenance.',
        type: SuggestionType.report,
        priority: SuggestionPriority.medium,
        icon: Icons.report_outlined,
        metadata: {'plantId': plantId},
      ),
      AiSuggestion(
        id: 'plant_export_data',
        message:
            'Export this plant\'s energy data for external analysis or reporting.',
        route: '/exports',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.low,
        icon: Icons.file_download_outlined,
      ),
    ];
  }

  // ─── Inverter Detail Rules ───────────────────────────────────────────

  static List<AiSuggestion> _inverterDetailRules(ScreenContext ctx) {
    if (!ctx.route.contains('/inverters/') ||
        !ctx.route.startsWith('/plants/')) return [];

    final inverterId = ctx.params['inverterId'] ?? '';
    final plantId = ctx.params['plantId'] ?? '';
    return [
      AiSuggestion(
        id: 'inv_check_alerts',
        message:
            'Concerned about this inverter\'s output? Check recent alerts for anomalies in the last week.',
        route: '/alerts',
        type: SuggestionType.anomaly,
        priority: SuggestionPriority.high,
        icon: Icons.warning_amber,
        metadata: {'inverterId': inverterId},
      ),
      AiSuggestion(
        id: 'inv_compare_plant',
        message:
            'Compare this inverter with others in the same plant to spot relative underperformance.',
        route: '/plants/$plantId',
        type: SuggestionType.comparison,
        priority: SuggestionPriority.high,
        icon: Icons.compare_arrows,
      ),
      AiSuggestion(
        id: 'inv_check_strings',
        message:
            'View string-level monitoring (SLMS) data to identify which strings may be degraded.',
        route: '/slms/$inverterId',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.medium,
        icon: Icons.monitor,
      ),
      AiSuggestion(
        id: 'inv_file_report',
        message:
            'Something doesn\'t look right? File a maintenance report for this inverter.',
        type: SuggestionType.report,
        priority: SuggestionPriority.high,
        icon: Icons.report_problem_outlined,
        metadata: {'inverterId': inverterId, 'plantId': plantId},
      ),
      AiSuggestion(
        id: 'inv_check_temp',
        message:
            'High inverter temperatures can reduce output. Check temperature sensors for this plant.',
        route: '/sensors',
        type: SuggestionType.insight,
        priority: SuggestionPriority.medium,
        icon: Icons.thermostat,
      ),
    ];
  }

  // ─── Inverter List Rules ─────────────────────────────────────────────

  static List<AiSuggestion> _inverterListRules(ScreenContext ctx) {
    if (ctx.route != '/inverters') return [];
    return [
      const AiSuggestion(
        id: 'invlist_check_dashboard',
        message:
            'Go to the dashboard for an aggregate view of all plant performance.',
        route: '/dashboard',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.low,
        icon: Icons.dashboard,
      ),
      const AiSuggestion(
        id: 'invlist_check_alerts',
        message:
            'Any inverter showing low output? Check alerts for system-wide anomalies.',
        route: '/alerts',
        type: SuggestionType.anomaly,
        priority: SuggestionPriority.medium,
        icon: Icons.warning_amber,
      ),
      const AiSuggestion(
        id: 'invlist_slms',
        message:
            'View string-level data across inverters for deeper diagnostics.',
        route: '/slms',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.medium,
        icon: Icons.monitor,
      ),
    ];
  }

  // ─── Sensor Page Rules ───────────────────────────────────────────────

  static List<AiSuggestion> _sensorRules(ScreenContext ctx) {
    if (ctx.route != '/sensors') return [];
    return [
      const AiSuggestion(
        id: 'sensor_check_inverters',
        message:
            'Abnormal sensor readings? Cross-check with inverter output to confirm issues.',
        route: '/inverters',
        type: SuggestionType.comparison,
        priority: SuggestionPriority.high,
        icon: Icons.electrical_services,
      ),
      const AiSuggestion(
        id: 'sensor_file_report',
        message:
            'Sensor reading out of range? File a report to schedule a site visit.',
        type: SuggestionType.report,
        priority: SuggestionPriority.medium,
        icon: Icons.report_outlined,
      ),
      const AiSuggestion(
        id: 'sensor_view_alerts',
        message:
            'See if any sensor-triggered alerts have been raised recently.',
        route: '/alerts',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.medium,
        icon: Icons.notifications_active_outlined,
      ),
    ];
  }

  // ─── MFM Detail Rules ───────────────────────────────────────────────

  static List<AiSuggestion> _mfmDetailRules(ScreenContext ctx) {
    if (!ctx.route.contains('/mfm/')) return [];
    final plantId = ctx.params['plantId'] ?? '';
    return [
      AiSuggestion(
        id: 'mfm_check_inverters',
        message:
            'MFM shows grid-level data. Check inverter output to see if generation matches grid feed.',
        route: '/plants/$plantId',
        type: SuggestionType.comparison,
        priority: SuggestionPriority.high,
        icon: Icons.compare_arrows,
      ),
      AiSuggestion(
        id: 'mfm_voltage_alert',
        message:
            'If voltage readings seem off, file a report for electrical inspection.',
        type: SuggestionType.report,
        priority: SuggestionPriority.medium,
        icon: Icons.report_problem_outlined,
        metadata: {'plantId': plantId},
      ),
      const AiSuggestion(
        id: 'mfm_export',
        message: 'Export MFM data for grid compliance reporting.',
        route: '/exports',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.low,
        icon: Icons.file_download_outlined,
      ),
    ];
  }

  // ─── Temperature Detail Rules ────────────────────────────────────────

  static List<AiSuggestion> _tempDetailRules(ScreenContext ctx) {
    if (!ctx.route.contains('/temp/')) return [];
    final plantId = ctx.params['plantId'] ?? '';
    return [
      AiSuggestion(
        id: 'temp_high_warning',
        message:
            'High ambient temperature reduces panel efficiency. Check inverter output for this plant.',
        route: '/plants/$plantId',
        type: SuggestionType.anomaly,
        priority: SuggestionPriority.high,
        icon: Icons.thermostat,
      ),
      AiSuggestion(
        id: 'temp_file_report',
        message:
            'Temperature consistently above threshold? File a report for cooling system check.',
        type: SuggestionType.report,
        priority: SuggestionPriority.medium,
        icon: Icons.report_outlined,
        metadata: {'plantId': plantId},
      ),
      const AiSuggestion(
        id: 'temp_check_alerts',
        message:
            'See if thermal alerts have been triggered for any devices.',
        route: '/alerts',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.medium,
        icon: Icons.warning_amber,
      ),
    ];
  }

  // ─── SLMS Rules ─────────────────────────────────────────────────────

  static List<AiSuggestion> _slmsRules(ScreenContext ctx) {
    if (!ctx.route.startsWith('/slms')) return [];
    final isDetail = ctx.route != '/slms';
    if (isDetail) {
      return [
        const AiSuggestion(
          id: 'slms_degraded_string',
          message:
              'If any string current is significantly lower, it may indicate panel degradation or shading. File a report.',
          type: SuggestionType.report,
          priority: SuggestionPriority.high,
          icon: Icons.report_problem_outlined,
        ),
        const AiSuggestion(
          id: 'slms_compare_inverter',
          message:
              'Compare string-level data with the inverter\'s total output for consistency.',
          route: '/inverters',
          type: SuggestionType.comparison,
          priority: SuggestionPriority.medium,
          icon: Icons.compare_arrows,
        ),
      ];
    }
    return [
      const AiSuggestion(
        id: 'slms_list_inverters',
        message:
            'View all inverters to pick one for string-level analysis.',
        route: '/inverters',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.medium,
        icon: Icons.electrical_services,
      ),
    ];
  }

  // ─── Alerts Page Rules ──────────────────────────────────────────────

  static List<AiSuggestion> _alertsPageRules(ScreenContext ctx) {
    if (ctx.route != '/alerts') return [];
    return [
      const AiSuggestion(
        id: 'alerts_check_inverters',
        message:
            'Investigate alerts by checking inverter performance data directly.',
        route: '/inverters',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.high,
        icon: Icons.electrical_services,
      ),
      const AiSuggestion(
        id: 'alerts_check_sensors',
        message:
            'Sensor data can help confirm if an alert is a real issue or a data glitch.',
        route: '/sensors',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.medium,
        icon: Icons.sensors,
      ),
      const AiSuggestion(
        id: 'alerts_file_report',
        message:
            'Multiple alerts on the same plant? File a consolidated maintenance report.',
        type: SuggestionType.report,
        priority: SuggestionPriority.high,
        icon: Icons.assignment_outlined,
      ),
    ];
  }

  // ─── Exports Page Rules ─────────────────────────────────────────────

  static List<AiSuggestion> _exportsPageRules(ScreenContext ctx) {
    if (ctx.route != '/exports') return [];
    return [
      const AiSuggestion(
        id: 'export_go_inverters',
        message:
            'Navigate to an inverter detail page to export its time-series data as CSV.',
        route: '/inverters',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.high,
        icon: Icons.electrical_services,
      ),
      const AiSuggestion(
        id: 'export_go_sensors',
        message:
            'Go to sensor detail pages to export MFM or temperature readings.',
        route: '/sensors',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.medium,
        icon: Icons.sensors,
      ),
    ];
  }

  // ─── Behavior-Based Rules (Self-Training) ───────────────────────────

  static Future<List<AiSuggestion>> _behaviorBasedRules(
      ScreenContext ctx) async {
    final suggestions = <AiSuggestion>[];

    // If user hasn't checked alerts in a while, nudge them
    final checkedAlerts = await BehaviorTracker.hasVisitedRecently(
        '/alerts', const Duration(hours: 2));
    if (!checkedAlerts && ctx.route != '/alerts') {
      suggestions.add(const AiSuggestion(
        id: 'behavior_check_alerts',
        message:
            'You haven\'t checked alerts recently. Tap to review any new issues.',
        route: '/alerts',
        type: SuggestionType.navigation,
        priority: SuggestionPriority.medium,
        icon: Icons.notifications_none,
      ));
    }

    // If user keeps visiting inverter pages, suggest SLMS for deeper analysis
    final history = await BehaviorTracker.getNavHistory();
    final recentInverterVisits = history
        .where((e) =>
            e.$2.contains('/inverters/') &&
            e.$1.isAfter(DateTime.now().subtract(const Duration(minutes: 30))))
        .length;
    if (recentInverterVisits >= 3 &&
        !ctx.route.startsWith('/slms')) {
      suggestions.add(const AiSuggestion(
        id: 'behavior_slms_deep_dive',
        message:
            'You\'ve been reviewing several inverters. Want to do a string-level deep dive?',
        route: '/slms',
        type: SuggestionType.insight,
        priority: SuggestionPriority.high,
        icon: Icons.analytics,
      ));
    }

    return suggestions;
  }
}
