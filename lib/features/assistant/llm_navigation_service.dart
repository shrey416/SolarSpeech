import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class LlmNavigationService {
  static final _supabase = Supabase.instance.client;

  // ── Word → number mapping (speech-to-text often returns words) ──
  static final Map<String, int> _wordToNumber = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
    'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
    'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
    'eighteen': 18, 'nineteen': 19, 'twenty': 20,
    'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5,
    'sixth': 6, 'seventh': 7, 'eighth': 8, 'ninth': 9, 'tenth': 10,
    'won': 1, 'to': 2, 'too': 2, 'for': 4, 'ate': 8,
  };

  // ── Filler words to strip ──
  static final RegExp _filler = RegExp(
    r'\b(go|take|bring|show|open|navigate|switch|move|display|view|visit|'
    r'me|us|to|the|a|an|at|on|of|in|up|please|can|you|i|want|need|'
    r'see|look|let|page|screen|tab|section|data|for|from|date)\b',
    caseSensitive: false,
  );

  // ── Tab / page keywords → route (no ID needed) ──
  // NOTE: More specific sensor sub-tabs MUST come before the generic /sensors entry
  static final List<_TabIntent> _tabIntents = [
    _TabIntent('/dashboard',  ['dashboard', 'home', 'main', 'overview', 'summary', 'start']),
    _TabIntent('/my-plants',  ['my plants', 'plants list', 'plant list', 'all plants', 'my plant']),
    _TabIntent('/inverters',  ['inverters list', 'all inverters', 'inverter list', 'inverters']),
    _TabIntent('/slms',       ['slms', 'string level', 'string monitoring', 'strings', 'slm']),
    // Sensor sub-tabs first (before generic /sensors)
    _TabIntent('/sensors?tab=mfm',  ['mfm', 'mfm tab', 'mfm sensors', 'energy meter', 'energy meters', 'multi function meter', 'multi function meters', 'mfm list', 'all mfm']),
    _TabIntent('/sensors?tab=wms',  ['wms', 'wms tab', 'wms sensors', 'weather monitoring', 'weather station', 'weather stations', 'wms list', 'all wms', 'wfm', 'weather']),
    _TabIntent('/sensors?tab=temperature',  ['temperature', 'temperature tab', 'temperature sensors', 'temp sensor', 'temp sensors', 'temp tab', 'thermal', 'thermal sensors', 'temp list', 'all temperature', 'all temp']),
    // Generic sensors last
    _TabIntent('/sensors',    ['sensors', 'sensor list', 'sensor', 'all sensors']),
    _TabIntent('/alerts',     ['alerts', 'alert', 'warnings', 'warning', 'alarm', 'alarms', 'notification', 'notifications']),
    _TabIntent('/exports',    ['exports', 'export', 'download', 'downloads', 'report', 'reports']),
  ];

  // ── Device type keywords ──
  static final RegExp _inverterKw = RegExp(
    r'\b(inverter|inv|converter|invertor)\b', caseSensitive: false);
  static final RegExp _plantKw = RegExp(
    r'\b(plant|site|station|farm|solar\s*plant|solar\s*farm)\b',
    caseSensitive: false);
  static final RegExp _slmsKw = RegExp(
    r'\b(slms|slm|string\s*level|string\s*data|string)\b',
    caseSensitive: false);
  static final RegExp _mfmKw = RegExp(
    r'\b(mfm|meter|multi\s*function\s*meter|energy\s*meter)\b',
    caseSensitive: false);
  static final RegExp _tempKw = RegExp(
    r'\b(temp|temperature|thermal|heat)\b', caseSensitive: false);
  static final RegExp _sensorKw = RegExp(
    r'\b(sensor)\b', caseSensitive: false);

  // ── Alert keywords ──
  static final RegExp _alertKw = RegExp(
    r'\b(alert|alerts|alarm|alarms|warning|warnings|fault|faults|issue|issues|notification|notifications)\b',
    caseSensitive: false);
  static final RegExp _alertDeviceKw = RegExp(
    r'\b(inverter|inv|converter|invertor|mfm|meter|temp|temperature|thermal|sensor|plant|site|station|farm)\b',
    caseSensitive: false);

  /// Check if text mentions both alert + device keywords
  static bool _hasAlertDeviceIntent(String text) {
    return _alertKw.hasMatch(text) && _alertDeviceKw.hasMatch(text);
  }

  static final RegExp _chartStripKw = RegExp(
    r'\b(graph|chart|voltage|current|power|energy|pv|dc|active|total|today|'
    r'e-total|e-today|cumulative|daily|live|real|watt|watts|with|of)\b',
    caseSensitive: false,
  );

  // ── Month name mapping ──
  static final Map<String, int> _monthNames = {
    'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3,
    'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6,
    'july': 7, 'jul': 7, 'august': 8, 'aug': 8, 'september': 9, 'sep': 9,
    'sept': 9, 'october': 10, 'oct': 10, 'november': 11, 'nov': 11,
    'december': 12, 'dec': 12,
  };

  // ── Date detection patterns ──
  static final RegExp _dateNumericSlash = RegExp(
    r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b');

  // ISO format: 2026-03-05 or 2026/03/05
  static final RegExp _dateIso = RegExp(
    r'\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b');

  static final RegExp _dateMonthName = RegExp(
    r'\b(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s*,?\s*(\d{4}))?\b',
    caseSensitive: false);

  static final RegExp _dateDayMonth = RegExp(
    r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)(?:\s+(\d{4}))?\b',
    caseSensitive: false);

  static final RegExp _dateRelative = RegExp(
    r'\b(today|yesterday|tomorrow|day before yesterday|day after tomorrow)\b(?!\s*(power|energy|data|chart|graph))',
    caseSensitive: false);

  // "N days ago", "N weeks ago", "N months ago"
  static final RegExp _dateNAgo = RegExp(
    r'\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+(days?|weeks?|months?)\s+ago\b',
    caseSensitive: false);

  // "last week", "last month", "this week", "this month"
  static final RegExp _dateLastThis = RegExp(
    r'\b(last|this|previous|current|past)\s+(week|month|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    caseSensitive: false);

  // "the 5th", "the fifth", standalone day of current month
  static final RegExp _dateStandaloneDay = RegExp(
    r'\b(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)\b',
    caseSensitive: false);

  // Ordinal word days: "the fifth", "the first"
  static final Map<String, int> _ordinalWords = {
    'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5,
    'sixth': 6, 'seventh': 7, 'eighth': 8, 'ninth': 9, 'tenth': 10,
    'eleventh': 11, 'twelfth': 12, 'thirteenth': 13, 'fourteenth': 14,
    'fifteenth': 15, 'sixteenth': 16, 'seventeenth': 17, 'eighteenth': 18,
    'nineteenth': 19, 'twentieth': 20, 'twenty first': 21, 'twenty second': 22,
    'twenty third': 23, 'twenty fourth': 24, 'twenty fifth': 25,
    'twenty sixth': 26, 'twenty seventh': 27, 'twenty eighth': 28,
    'twenty ninth': 29, 'thirtieth': 30, 'thirty first': 31,
  };

  // Day of week mapping
  static final Map<String, int> _dayOfWeek = {
    'monday': DateTime.monday, 'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday, 'thursday': DateTime.thursday,
    'friday': DateTime.friday, 'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  /// Convert ordinal words adjacent to month names into numeric form
  /// so date-detection regexes can match them.
  /// e.g. "first march" → "1 march", "march twenty first" → "march 21"
  static String _normalizeOrdinalWords(String text) {
    final monthPat = _monthNames.keys.join('|');
    // Sort by key length descending so "twenty first" is checked before "first"
    final sorted = _ordinalWords.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sorted) {
      // "first march" / "first of march" → "1 march" / "1 of march"
      final beforeMonth = RegExp(
        '\\b${RegExp.escape(entry.key)}\\b(\\s+(?:of\\s+)?)($monthPat)',
        caseSensitive: false,
      );
      text = text.replaceAllMapped(
          beforeMonth, (m) => '${entry.value}${m.group(1)}${m.group(2)}');

      // "march first" → "march 1"
      final afterMonth = RegExp(
        '($monthPat)(\\s+)${RegExp.escape(entry.key)}\\b',
        caseSensitive: false,
      );
      text = text.replaceAllMapped(
          afterMonth, (m) => '${m.group(1)}${m.group(2)}${entry.value}');
    }
    return text;
  }

  /// Detect a date from user text. Returns the date and the matched text span.
  static ({DateTime? date, String cleanedText}) _detectDate(String text) {
    final now = DateTime(2026, 3, 6);

    // Pre-process: convert ordinal words near month names to digits
    text = _normalizeOrdinalWords(text);

    // 1. Relative dates
    final relMatch = _dateRelative.firstMatch(text);
    if (relMatch != null) {
      final word = relMatch.group(1)!.toLowerCase();
      DateTime? d;
      if (word == 'today') d = now;
      if (word == 'yesterday') d = now.subtract(const Duration(days: 1));
      if (word == 'tomorrow') d = now.add(const Duration(days: 1));
      if (word == 'day before yesterday') d = now.subtract(const Duration(days: 2));
      if (word == 'day after tomorrow') d = now.add(const Duration(days: 2));
      if (d != null) {
        final cleaned = text.replaceFirst(relMatch.group(0)!, ' ').trim();
        return (date: d, cleanedText: cleaned);
      }
    }

    // 2. "N days/weeks/months ago"
    final agoMatch = _dateNAgo.firstMatch(text);
    if (agoMatch != null) {
      final numStr = agoMatch.group(1)!.toLowerCase();
      int n = int.tryParse(numStr) ?? _wordToNumber[numStr] ?? 1;
      final unit = agoMatch.group(2)!.toLowerCase();
      DateTime d;
      if (unit.startsWith('day')) {
        d = now.subtract(Duration(days: n));
      } else if (unit.startsWith('week')) {
        d = now.subtract(Duration(days: n * 7));
      } else {
        d = DateTime(now.year, now.month - n, now.day);
      }
      final cleaned = text.replaceFirst(agoMatch.group(0)!, ' ').trim();
      return (date: d, cleanedText: cleaned);
    }

    // 3. "last/this week/month/monday..."
    final ltMatch = _dateLastThis.firstMatch(text);
    if (ltMatch != null) {
      final prefix = ltMatch.group(1)!.toLowerCase();
      final target = ltMatch.group(2)!.toLowerCase();
      DateTime? d;
      if (target == 'week') {
        d = prefix == 'last' || prefix == 'previous' || prefix == 'past'
            ? now.subtract(Duration(days: now.weekday + 6)) // last Monday
            : now.subtract(Duration(days: now.weekday - 1)); // this Monday
      } else if (target == 'month') {
        d = prefix == 'last' || prefix == 'previous' || prefix == 'past'
            ? DateTime(now.year, now.month - 1, 1)
            : DateTime(now.year, now.month, 1);
      } else if (_dayOfWeek.containsKey(target)) {
        final targetDay = _dayOfWeek[target]!;
        int diff = now.weekday - targetDay;
        if (prefix == 'last' || prefix == 'previous' || prefix == 'past') {
          if (diff <= 0) diff += 7;
        } else {
          // "this" — same week or next occurrence
          if (diff < 0) diff += 7;
          if (diff == 0) diff = 0; // today
        }
        d = now.subtract(Duration(days: diff));
      }
      if (d != null) {
        final cleaned = text.replaceFirst(ltMatch.group(0)!, ' ').trim();
        return (date: d, cleanedText: cleaned);
      }
    }

    // 4. "March 5th, 2026" or "march 5"
    final mnMatch = _dateMonthName.firstMatch(text);
    if (mnMatch != null) {
      final month = _monthNames[mnMatch.group(1)!.toLowerCase()] ?? 1;
      final day = int.tryParse(mnMatch.group(2)!) ?? 1;
      final year = mnMatch.group(3) != null ? int.tryParse(mnMatch.group(3)!) ?? now.year : now.year;
      final cleaned = text.replaceFirst(mnMatch.group(0)!, ' ').trim();
      return (date: DateTime(year, month, day), cleanedText: cleaned);
    }

    // 5. "5th march 2026" or "5 march"
    final dmMatch = _dateDayMonth.firstMatch(text);
    if (dmMatch != null) {
      final day = int.tryParse(dmMatch.group(1)!) ?? 1;
      final month = _monthNames[dmMatch.group(2)!.toLowerCase()] ?? 1;
      final year = dmMatch.group(3) != null ? int.tryParse(dmMatch.group(3)!) ?? now.year : now.year;
      final cleaned = text.replaceFirst(dmMatch.group(0)!, ' ').trim();
      return (date: DateTime(year, month, day), cleanedText: cleaned);
    }

    // 6. ISO format: 2026-03-05
    final isoMatch = _dateIso.firstMatch(text);
    if (isoMatch != null) {
      final y = int.tryParse(isoMatch.group(1)!) ?? now.year;
      final m = int.tryParse(isoMatch.group(2)!) ?? 1;
      final d = int.tryParse(isoMatch.group(3)!) ?? 1;
      if (y >= 2000 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        final cleaned = text.replaceFirst(isoMatch.group(0)!, ' ').trim();
        return (date: DateTime(y, m, d), cleanedText: cleaned);
      }
    }

    // 7. Numeric: d/m/yyyy or d-m-yyyy (non-ISO)
    final numMatch = _dateNumericSlash.firstMatch(text);
    if (numMatch != null) {
      final a = int.tryParse(numMatch.group(1)!) ?? 1;
      final b = int.tryParse(numMatch.group(2)!) ?? 1;
      var y = int.tryParse(numMatch.group(3)!) ?? now.year;
      if (y < 100) y += 2000;
      // Smart format detection: if a > 12, it must be the day (d/m/y)
      // if b > 12, it must be the day (m/d/y)
      int day, month;
      if (a > 12) {
        day = a; month = b; // d/m/y
      } else if (b > 12) {
        day = b; month = a; // m/d/y
      } else {
        day = a; month = b; // default d/m/y
      }
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        final cleaned = text.replaceFirst(numMatch.group(0)!, ' ').trim();
        return (date: DateTime(y, month, day), cleanedText: cleaned);
      }
    }

    // 8. Ordinal words: "the fifth", "the twenty first"
    for (final entry in _ordinalWords.entries) {
      final pattern = RegExp(r'\b(?:the\s+)?' + entry.key + r'\b', caseSensitive: false);
      final match = pattern.firstMatch(text);
      if (match != null) {
        // Check that it's in a date context (near "on", "of", "for", "date", month)
        final surroundingText = text.toLowerCase();
        final hasDateContext = surroundingText.contains('on the') ||
            surroundingText.contains('for the') ||
            surroundingText.contains('date') ||
            _dateMonthName.hasMatch(surroundingText) ||
            _dateDayMonth.hasMatch(surroundingText);
        if (hasDateContext) {
          final cleaned = text.replaceFirst(match.group(0)!, ' ').trim();
          return (date: DateTime(now.year, now.month, entry.value), cleanedText: cleaned);
        }
      }
    }

    // 9. Standalone numeric day: "the 5th", "on 5th"
    final sdMatch = _dateStandaloneDay.firstMatch(text);
    if (sdMatch != null) {
      final day = int.tryParse(sdMatch.group(1)!) ?? 0;
      if (day >= 1 && day <= 31) {
        // Only treat as date if preceded by "on", "for", "date", "of" or similar context
        final before = text.substring(0, sdMatch.start).toLowerCase().trimRight();
        if (before.endsWith('on') || before.endsWith('for') || before.endsWith('of') ||
            before.endsWith('date') || before.endsWith('from')) {
          final cleaned = text.replaceFirst(sdMatch.group(0)!, ' ').trim();
          return (date: DateTime(now.year, now.month, day), cleanedText: cleaned);
        }
      }
    }

    return (date: null, cleanedText: text);
  }

  /// Append a query param to a route.
  static String _appendParam(String route, String key, String value) {
    final encoded = Uri.encodeComponent(value);
    return route.contains('?')
        ? '$route&$key=$encoded'
        : '$route?$key=$encoded';
  }

  // ── Chart / graph filter keywords ──
  // Inverter charts
  static final List<_ChartIntent> _chartIntents = [
    _ChartIntent('Total PV Current', [
      'pv current', 'dc current', 'total current', 'current graph',
      'current chart', 'total pv current',
    ]),
    _ChartIntent('Total PV Voltage', [
      'pv voltage', 'dc voltage', 'total voltage', 'voltage graph',
      'voltage chart', 'total pv voltage',
    ]),
    _ChartIntent('E-Total Power', [
      'e-total', 'e total', 'total power', 'total energy',
      'e-total power', 'cumulative power',
    ]),
    _ChartIntent('E-Today Power', [
      'e-today', 'e today', 'today power', 'today energy',
      'e-today power', 'daily power',
    ]),
    _ChartIntent('Active Power', [
      'active power', 'active', 'live power', 'real power',
      'current power', 'watt', 'watts',
    ]),
  ];

  // MFM charts (Voltage / Current / Total Power)
  static final List<_ChartIntent> _mfmChartIntents = [
    _ChartIntent('Voltage', [
      'voltage', 'voltage graph', 'voltage chart', 'l1 voltage', 'l2 voltage', 'l3 voltage',
    ]),
    _ChartIntent('Current', [
      'current', 'current graph', 'current chart', 'l1 current', 'l2 current', 'l3 current',
    ]),
    _ChartIntent('Total Power', [
      'total power', 'power', 'power graph', 'power chart',
    ]),
  ];

  /// Detect if the user mentioned a specific chart type (inverter charts).
  static String? _detectChart(String text) {
    for (final ci in _chartIntents) {
      for (final kw in ci.keywords) {
        if (text.contains(kw)) return ci.chartName;
      }
    }
    // Fuzzy: check individual words
    if (RegExp(r'\b(voltage)\b', caseSensitive: false).hasMatch(text)) {
      return 'Total PV Voltage';
    }
    if (RegExp(r'\b(current)\b', caseSensitive: false).hasMatch(text)) {
      return 'Total PV Current';
    }
    return null;
  }

  /// Detect MFM-specific chart type.
  static String? _detectMfmChart(String text) {
    for (final ci in _mfmChartIntents) {
      for (final kw in ci.keywords) {
        if (text.contains(kw)) return ci.chartName;
      }
    }
    return null;
  }

  /// Append chart query param to a route if a chart was detected.
  static String _appendChart(String route, String? chart) {
    if (chart == null) return route;
    return _appendParam(route, 'chart', chart);
  }

  /// Append date query param to a route if a date was detected.
  static String _appendDate(String route, DateTime? date) {
    if (date == null) return route;
    final str = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _appendParam(route, 'date', str);
  }

  /// Main entry point — returns a route string or null.
  static Future<String?> getRouteFromText(String userInput) async {
    if (userInput.trim().isEmpty) return null;
    final rawText = userInput.toLowerCase().trim();

    // Extract date first (before identifier extraction gets confused)
    final dateResult = _detectDate(rawText);
    final detectedDate = dateResult.date;
    final text = dateResult.cleanedText;

    // Detect chart filters
    final chart = _detectChart(text);
    final mfmChart = _detectMfmChart(text);

    // Helper to append both chart and date to a route
    String finalize(String route) {
      // Use MFM chart for MFM routes, inverter chart otherwise
      final useChart = route.contains('/mfm/') ? mfmChart : chart;
      var r = _appendChart(route, useChart);
      r = _appendDate(r, detectedDate);
      return r;
    }

    // ────────────────────────────────────────────
    // 0. Alert + device detection (before tab matching)
    // ────────────────────────────────────────────
    if (_hasAlertDeviceIntent(text)) {
      final alertRoute = await _resolveAlertForDevice(text);
      if (alertRoute != null) return alertRoute;
    }

    // ────────────────────────────────────────────
    // 1. Exact tab / section matching (fastest)
    // ────────────────────────────────────────────
    final tabRoute = _matchTab(text);
    if (tabRoute != null) return finalize(tabRoute);

    // ────────────────────────────────────────────
    // 2. Device-specific navigation (needs DB)
    // ────────────────────────────────────────────
    final id = _extractIdentifier(text);

    // Inverter
    if (_inverterKw.hasMatch(text)) {
      final route = await _resolveInverter(id, text);
      return route != null ? finalize(route) : route;
    }

    // Plant
    if (_plantKw.hasMatch(text)) {
      final route = await _resolvePlant(id, text);
      return route != null ? finalize(route) : route;
    }

    // SLMS / String data
    if (_slmsKw.hasMatch(text)) {
      final route = await _resolveSlms(id, text);
      return route != null ? finalize(route) : route;
    }

    // MFM
    if (_mfmKw.hasMatch(text)) {
      final route = await _resolveMfm(id, text);
      return route != null ? finalize(route) : route;
    }

    // Temperature device
    if (_tempKw.hasMatch(text)) {
      final route = await _resolveTemp(id, text);
      return route != null ? finalize(route) : route;
    }

    // Generic sensor (could be MFM or temp)
    if (_sensorKw.hasMatch(text)) {
      final route = await _resolveSensor(id, text);
      return route != null ? finalize(route) : route;
    }

    // ────────────────────────────────────────────
    // 3. Fuzzy fallback — match against everything
    // ────────────────────────────────────────────
    final fallback = await _fuzzyFallback(text);
    return fallback != null ? finalize(fallback) : null;
  }

  // ══════════════════════════════════════════════
  //  Alert + device resolution
  // ══════════════════════════════════════════════
  static Future<String?> _resolveAlertForDevice(String text) async {
    try {
      // Strip alert keywords to isolate device reference
      final deviceText = text
          .replaceAll(_alertKw, ' ')
          .replaceAll(_filler, ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final id = _extractIdentifier(deviceText.isNotEmpty ? deviceText : text);

      // Try inverter
      if (_inverterKw.hasMatch(text)) {
        final rows = await _supabase.from('Inverter').select('id, name');
        final match = _findBestMatch(rows, id, text);
        if (match != null) {
          return '/alerts?deviceId=${Uri.encodeComponent(match['id'])}&deviceName=${Uri.encodeComponent(match['name'] ?? '')}';
        }
      }

      // Try MFM
      if (_mfmKw.hasMatch(text)) {
        final rows = await _supabase.from('MFM').select('id, name');
        final match = _findBestMatch(rows, id, text);
        if (match != null) {
          return '/alerts?deviceId=${Uri.encodeComponent(match['id'])}&deviceName=${Uri.encodeComponent(match['name'] ?? '')}';
        }
      }

      // Try temperature
      if (_tempKw.hasMatch(text)) {
        final rows = await _supabase.from('TemperatureDevice').select('id, name');
        final match = _findBestMatch(rows, id, text);
        if (match != null) {
          return '/alerts?deviceId=${Uri.encodeComponent(match['id'])}&deviceName=${Uri.encodeComponent(match['name'] ?? '')}';
        }
      }

      // Try plant — filter alerts by plant
      if (_plantKw.hasMatch(text)) {
        final rows = await _supabase.from('Plant').select('id, name');
        final match = _findBestMatch(rows, id, text);
        if (match != null) {
          // Plant alerts: use plantId as deviceId (AlertsScreen will still show relevant alerts)
          return '/alerts?deviceId=${Uri.encodeComponent(match['id'])}&deviceName=${Uri.encodeComponent(match['name'] ?? '')}';
        }
      }

      // Try generic sensor
      if (_sensorKw.hasMatch(text)) {
        // Try MFM first, then temp
        final mfms = await _supabase.from('MFM').select('id, name');
        final mfmMatch = _findBestMatch(mfms, id, text);
        if (mfmMatch != null) {
          return '/alerts?deviceId=${Uri.encodeComponent(mfmMatch['id'])}&deviceName=${Uri.encodeComponent(mfmMatch['name'] ?? '')}';
        }
        final temps = await _supabase.from('TemperatureDevice').select('id, name');
        final tempMatch = _findBestMatch(temps, id, text);
        if (tempMatch != null) {
          return '/alerts?deviceId=${Uri.encodeComponent(tempMatch['id'])}&deviceName=${Uri.encodeComponent(tempMatch['name'] ?? '')}';
        }
      }

      // Fuzzy fallback: try matching against all device names
      final allDevices = <Map<String, dynamic>>[];
      final inverters = await _supabase.from('Inverter').select('id, name');
      allDevices.addAll(List<Map<String, dynamic>>.from(inverters));
      final mfms = await _supabase.from('MFM').select('id, name');
      allDevices.addAll(List<Map<String, dynamic>>.from(mfms));
      final temps = await _supabase.from('TemperatureDevice').select('id, name');
      allDevices.addAll(List<Map<String, dynamic>>.from(temps));

      final match = _findBestMatch(allDevices, id, text);
      if (match != null) {
        return '/alerts?deviceId=${Uri.encodeComponent(match['id'])}&deviceName=${Uri.encodeComponent(match['name'] ?? '')}';
      }
    } catch (_) {}
    return null;
  }

  // ══════════════════════════════════════════════
  //  Tab matching
  // ══════════════════════════════════════════════
  static String? _matchTab(String text) {
    // Strip filler to get the core intent
    final core = text.replaceAll(_filler, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    // Collect all matching tabs with a specificity score
    String? bestRoute;
    int bestScore = -1;

    for (final tab in _tabIntents) {
      for (final keyword in tab.keywords) {
        if (core == keyword || text.contains(keyword)) {
          // Make sure it's a tab-level request (no trailing number / name)
          // e.g. "inverters" → tab, "inverter 3" → device
          if (_extractIdentifier(text) == null ||
              tab.route == '/my-plants' ||
              tab.route == '/dashboard' ||
              tab.route == '/alerts' ||
              tab.route == '/exports') {
            // Prefer more specific matches (longer keyword = more specific)
            final score = keyword.length + (core == keyword ? 100 : 0);
            if (score > bestScore) {
              bestScore = score;
              bestRoute = tab.route;
            }
          }
        }
      }
    }
    return bestRoute;
  }

  // ══════════════════════════════════════════════
  //  Identifier extraction (number or remaining name)
  // ══════════════════════════════════════════════
  static String? _extractIdentifier(String text) {
    // Try to find a digit
    final digitMatch = RegExp(r'\b(\d+)\b').firstMatch(text);
    if (digitMatch != null) return digitMatch.group(1);

    // Try word numbers — scan every word
    // Only pick word-numbers that appear AFTER a device keyword to avoid homophones
    final words = text.split(RegExp(r'\s+'));
    final deviceKwPattern = RegExp(
      r'\b(inverter|inv|converter|invertor|plant|site|station|farm|slms|slm|string|mfm|meter|temp|temperature|thermal|sensor)\b',
      caseSensitive: false,
    );
    // Homophones that are only valid as numbers AFTER a device keyword
    const homophones = {'to', 'too', 'for', 'ate', 'won'};

    int deviceKwIndex = -1;
    for (int i = 0; i < words.length; i++) {
      if (deviceKwPattern.hasMatch(words[i])) {
        deviceKwIndex = i;
      }
    }

    // Pick the last number-word that appears after the last device keyword
    for (int i = words.length - 1; i >= 0; i--) {
      if (_wordToNumber.containsKey(words[i])) {
        // Skip homophones unless they appear right after a device keyword
        if (homophones.contains(words[i]) && (deviceKwIndex < 0 || i <= deviceKwIndex)) {
          continue;
        }
        final num = _wordToNumber[words[i]]!;
        return num.toString();
      }
    }

    // Try extracting a name after stripping filler + device + chart keywords
    final stripped = text
        .replaceAll(_filler, ' ')
        .replaceAll(_inverterKw, ' ')
        .replaceAll(_plantKw, ' ')
        .replaceAll(_slmsKw, ' ')
        .replaceAll(_mfmKw, ' ')
        .replaceAll(_tempKw, ' ')
        .replaceAll(_sensorKw, ' ')
        .replaceAll(_chartStripKw, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.isNotEmpty && stripped.length > 1) return stripped;

    return null;
  }

  // ══════════════════════════════════════════════
  //  Device resolvers (query Supabase)
  // ══════════════════════════════════════════════

  static Future<String?> _resolveInverter(String? id, String text) async {
    try {
      final inverters = await _supabase.from('Inverter').select('id, name, plantId');
      final match = _findBestMatch(inverters, id, text);
      if (match != null) {
        final plantId = match['plantId']?.toString() ?? '';
        final invId = match['id'].toString();
        if (plantId.isNotEmpty) {
          return '/plants/$plantId/inverters/$invId';
        }
      }
      // If all else fails, go to inverters list
      return '/inverters';
    } catch (_) {
      return '/inverters';
    }
  }

  static Future<String?> _resolvePlant(String? id, String text) async {
    try {
      final plants = await _supabase.from('Plant').select('id, name');
      final match = _findBestMatch(plants, id, text);
      if (match != null) {
        return '/plants/${match['id']}';
      }
      return '/my-plants';
    } catch (_) {
      return '/my-plants';
    }
  }

  static Future<String?> _resolveSlms(String? id, String text) async {
    try {
      final inverters = await _supabase.from('Inverter').select('id, name');
      final match = _findBestMatch(inverters, id, text);
      if (match != null) {
        return '/slms/${match['id']}';
      }
      return '/slms';
    } catch (_) {
      return '/slms';
    }
  }

  static Future<String?> _resolveMfm(String? id, String text) async {
    try {
      final mfms = await _supabase.from('MFM').select('id, name, sensorsId');
      final match = _findBestMatch(mfms, id, text);
      if (match != null) {
        final sensorsId = match['sensorsId']?.toString() ?? '';
        if (sensorsId.isNotEmpty) {
          final sensors = await _supabase
              .from('Sensors')
              .select('plantId')
              .eq('id', sensorsId)
              .limit(1);
          if (sensors.isNotEmpty) {
            final plantId = sensors[0]['plantId']?.toString() ?? '';
            if (plantId.isNotEmpty) {
              return '/plants/$plantId/mfm/${match['id']}';
            }
          }
        }
      }
      return '/sensors?tab=mfm';
    } catch (_) {
      return '/sensors?tab=mfm';
    }
  }

  static Future<String?> _resolveTemp(String? id, String text) async {
    try {
      final temps = await _supabase.from('TemperatureDevice').select('id, name, sensorsId');
      final match = _findBestMatch(temps, id, text);
      if (match != null) {
        final sensorsId = match['sensorsId']?.toString() ?? '';
        if (sensorsId.isNotEmpty) {
          final sensors = await _supabase
              .from('Sensors')
              .select('plantId')
              .eq('id', sensorsId)
              .limit(1);
          if (sensors.isNotEmpty) {
            final plantId = sensors[0]['plantId']?.toString() ?? '';
            if (plantId.isNotEmpty) {
              return '/plants/$plantId/temp/${match['id']}';
            }
          }
        }
      }
      return '/sensors?tab=temperature';
    } catch (_) {
      return '/sensors?tab=temperature';
    }
  }

  static Future<String?> _resolveSensor(String? id, String text) async {
    // Try MFM first, then temperature
    final mfmRoute = await _resolveMfm(id, text);
    if (mfmRoute != null && !mfmRoute.startsWith('/sensors')) return mfmRoute;
    final tempRoute = await _resolveTemp(id, text);
    if (tempRoute != null && !tempRoute.startsWith('/sensors')) return tempRoute;
    return '/sensors';
  }

  // ══════════════════════════════════════════════
  //  Fuzzy fallback — search ALL entities
  // ══════════════════════════════════════════════
  static Future<String?> _fuzzyFallback(String text) async {
    final core = text.replaceAll(_filler, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (core.isEmpty) return null;

    // Check tab names with fuzzy
    for (final tab in _tabIntents) {
      for (final kw in tab.keywords) {
        if (_fuzzyScore(core, kw) >= 0.6) return tab.route;
      }
    }

    try {
      // Search plants
      final plants = await _supabase.from('Plant').select('id, name');
      for (final p in plants) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        if (_fuzzyScore(core, name) >= 0.5 || name.contains(core) || core.contains(name)) {
          return '/plants/${p['id']}';
        }
      }

      // Search inverters
      final inverters = await _supabase.from('Inverter').select('id, name, plantId');
      for (final inv in inverters) {
        final name = (inv['name'] ?? '').toString().toLowerCase();
        if (_fuzzyScore(core, name) >= 0.5 || name.contains(core) || core.contains(name)) {
          final plantId = inv['plantId']?.toString() ?? '';
          if (plantId.isNotEmpty) {
            return '/plants/$plantId/inverters/${inv['id']}';
          }
        }
      }

      // Search MFMs
      final mfms = await _supabase.from('MFM').select('id, name, sensorsId');
      for (final m in mfms) {
        final name = (m['name'] ?? '').toString().toLowerCase();
        if (_fuzzyScore(core, name) >= 0.5 || name.contains(core) || core.contains(name)) {
          final sensorsId = m['sensorsId']?.toString() ?? '';
          if (sensorsId.isNotEmpty) {
            final sensors = await _supabase
                .from('Sensors').select('plantId').eq('id', sensorsId).limit(1);
            if (sensors.isNotEmpty) {
              final plantId = sensors[0]['plantId']?.toString() ?? '';
              if (plantId.isNotEmpty) {
                return '/plants/$plantId/mfm/${m['id']}';
              }
            }
          }
        }
      }

      // Search temp devices
      final temps = await _supabase.from('TemperatureDevice').select('id, name, sensorsId');
      for (final t in temps) {
        final name = (t['name'] ?? '').toString().toLowerCase();
        if (_fuzzyScore(core, name) >= 0.5 || name.contains(core) || core.contains(name)) {
          final sensorsId = t['sensorsId']?.toString() ?? '';
          if (sensorsId.isNotEmpty) {
            final sensors = await _supabase
                .from('Sensors').select('plantId').eq('id', sensorsId).limit(1);
            if (sensors.isNotEmpty) {
              final plantId = sensors[0]['plantId']?.toString() ?? '';
              if (plantId.isNotEmpty) {
                return '/plants/$plantId/temp/${t['id']}';
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  // ══════════════════════════════════════════════
  //  Best-match logic for a list of DB rows
  // ══════════════════════════════════════════════
  static Map<String, dynamic>? _findBestMatch(
      List<dynamic> rows, String? identifier, String fullText) {
    if (rows.isEmpty) return null;

    // 1. If we have a numeric identifier, try matching by name containing that number
    //    or by list index (1-based).
    if (identifier != null) {
      final num = int.tryParse(identifier);

      // Try exact name match first
      for (final row in rows) {
        final name = (row['name'] ?? '').toString().toLowerCase();
        if (name == identifier.toLowerCase()) {
          return Map<String, dynamic>.from(row);
        }
      }

      // Try name containing the identifier as a whole word/number
      final idLower = identifier.toLowerCase();
      final idBoundary = RegExp(r'(^|[\D_])' + RegExp.escape(idLower) + r'($|[\D_])');
      for (final row in rows) {
        final name = (row['name'] ?? '').toString().toLowerCase();
        if (idBoundary.hasMatch(name)) {
          return Map<String, dynamic>.from(row);
        }
      }

      // Try matching the number at the end of a name (e.g. "GRP_INNVERTER_1" → 1)
      if (num != null) {
        final trailingDigit = RegExp(r'(\d+)\s*$');
        for (final row in rows) {
          final name = (row['name'] ?? '').toString();
          final m = trailingDigit.firstMatch(name);
          if (m != null && int.tryParse(m.group(1)!) == num) {
            return Map<String, dynamic>.from(row);
          }
        }
      }

      // Last resort: try by 1-based index
      if (num != null && num >= 1 && num <= rows.length) {
        return Map<String, dynamic>.from(rows[num - 1]);
      }

      // Fuzzy match name against identifier
      Map<String, dynamic>? bestRow;
      double bestScore = 0;
      for (final row in rows) {
        final name = (row['name'] ?? '').toString().toLowerCase();
        final score = _fuzzyScore(identifier.toLowerCase(), name);
        if (score > bestScore && score >= 0.4) {
          bestScore = score;
          bestRow = Map<String, dynamic>.from(row);
        }
      }
      if (bestRow != null) return bestRow;
    }

    // 2. Fuzzy match against full text (stripped)
    final core = fullText
        .replaceAll(_filler, ' ')
        .replaceAll(_inverterKw, ' ')
        .replaceAll(_plantKw, ' ')
        .replaceAll(_slmsKw, ' ')
        .replaceAll(_mfmKw, ' ')
        .replaceAll(_tempKw, ' ')
        .replaceAll(_sensorKw, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (core.isNotEmpty) {
      Map<String, dynamic>? bestRow;
      double bestScore = 0;
      for (final row in rows) {
        final name = (row['name'] ?? '').toString().toLowerCase();
        final score = _fuzzyScore(core, name);
        if (score > bestScore && score >= 0.4) {
          bestScore = score;
          bestRow = Map<String, dynamic>.from(row);
        }
      }
      if (bestRow != null) return bestRow;
    }

    return null;
  }

  // ══════════════════════════════════════════════
  //  Fuzzy similarity (normalized Levenshtein)
  // ══════════════════════════════════════════════
  static double _fuzzyScore(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Also check substring containment
    if (a.contains(b) || b.contains(a)) return 0.85;

    final dist = _levenshtein(a, b);
    final maxLen = max(a.length, b.length);
    return 1.0 - (dist / maxLen);
  }

  static int _levenshtein(String s, String t) {
    final n = s.length, m = t.length;
    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (int i = 0; i <= n; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= m; j++) {
      dp[0][j] = j;
    }
    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    return dp[n][m];
  }
}

class _TabIntent {
  final String route;
  final List<String> keywords;
  const _TabIntent(this.route, this.keywords);
}

class _ChartIntent {
  final String chartName;
  final List<String> keywords;
  const _ChartIntent(this.chartName, this.keywords);
}