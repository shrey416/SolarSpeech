import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatbotService {
  static final _supabase = Supabase.instance.client;

  // Word → number mapping for speech-to-text
  static final Map<String, int> _wordToNumber = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
    'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
    'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
    'eighteen': 18, 'nineteen': 19, 'twenty': 20,
    'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5,
  };

  static final Map<String, int> _monthNames = {
    'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3,
    'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6,
    'july': 7, 'jul': 7, 'august': 8, 'aug': 8, 'september': 9, 'sep': 9,
    'october': 10, 'oct': 10, 'november': 11, 'nov': 11,
    'december': 12, 'dec': 12,
  };

  /// Process a user message and return a bot response.
  static Future<ChatMessage> processMessage(String userInput) async {
    final text = userInput.toLowerCase().trim();
    if (text.isEmpty) {
      return ChatMessage(text: 'Please ask me something!', isUser: false);
    }

    try {
      // Detect intent — order matters (more specific first)
      if (_isAlertIntent(text)) return await _handleAlertQuery(text);
      if (_isTrendIntent(text)) return await _handleTrend(text);
      if (_isHistoricalIntent(text)) return await _handleHistorical(text);
      if (_isCompareIntent(text)) return await _handleCompare(text);
      if (_isPercentageIntent(text)) return await _handlePercentage(text);
      if (_isSummaryIntent(text)) return await _handleSummary(text);
      if (_isTopBottomIntent(text)) return await _handleTopBottom(text);
      if (_isStatusIntent(text)) return await _handleStatus(text);
      if (_isCountIntent(text)) return await _handleCount(text);
      if (_isAverageIntent(text)) return await _handleAverage(text);
      if (_isEnergyIntent(text)) return await _handleEnergy(text);
      if (_isSensorIntent(text)) return await _handleSensorQuery(text);
      if (_isInverterIntent(text)) return await _handleInverterQuery(text);
      if (_isPlantIntent(text)) return await _handlePlantQuery(text);
      if (_isHelpIntent(text)) return _handleHelp();

      // Fallback
      return await _handleGeneral(text);
    } catch (e) {
      return ChatMessage(
        text: 'Sorry, I ran into an issue: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e}. Please try again.',
        isUser: false,
      );
    }
  }

  // ══════════════════════════════════════════════
  //  Intent Detection
  // ══════════════════════════════════════════════

  static bool _isAlertIntent(String t) =>
      t.contains('alert') || t.contains('alarm') || t.contains('fault') ||
      t.contains('issue') || t.contains('notification') ||
      (t.contains('warning') && !t.contains('warming'));

  static bool _isCompareIntent(String t) =>
      t.contains('compare') || t.contains('versus') || t.contains(' vs ') ||
      t.contains('difference between') || t.contains('better') ||
      t.contains('which one') || t.contains('which is');

  static bool _isSummaryIntent(String t) =>
      t.contains('summary') || t.contains('summarize') || t.contains('overview') ||
      t.contains('how is everything') || t.contains('system status') ||
      t.contains('overall') || t.contains('dashboard');

  static bool _isTopBottomIntent(String t) =>
      t.contains('highest') || t.contains('lowest') || t.contains('best') ||
      t.contains('worst') || t.contains('top') || t.contains('bottom') ||
      t.contains('maximum') || t.contains('minimum') || t.contains('most') ||
      t.contains('least');

  static bool _isStatusIntent(String t) =>
      t.contains('status') || t.contains('health') || t.contains('working') ||
      t.contains('active') || t.contains('offline') || t.contains('online');

  static bool _isCountIntent(String t) =>
      t.contains('how many') || t.contains('count') || t.contains('total number') ||
      t.contains('number of');

  static bool _isEnergyIntent(String t) =>
      t.contains('energy') || t.contains('power') || t.contains('generation') ||
      t.contains('production') || t.contains('kwh') || t.contains('kw') ||
      t.contains('watt');

  static bool _isSensorIntent(String t) =>
      t.contains('sensor') || t.contains('mfm') || t.contains('temperature') ||
      t.contains('wms') || t.contains('weather') || t.contains('thermal') ||
      t.contains('meter');

  static bool _isInverterIntent(String t) =>
      t.contains('inverter') || t.contains('converter');

  static bool _isPlantIntent(String t) =>
      t.contains('plant') || t.contains('site') || t.contains('farm') ||
      t.contains('station');

  static bool _isHelpIntent(String t) =>
      t.contains('help') || t.contains('what can you') || t.contains('capabilities') ||
      t == 'hi' || t == 'hello' || t == 'hey';

  static bool _isPercentageIntent(String t) =>
      t.contains('percentage') || t.contains('percent') || t.contains('%') ||
      t.contains('contribution') || t.contains('share of') ||
      t.contains('fraction') || t.contains('proportion') ||
      t.contains('how much of');

  static bool _isAverageIntent(String t) =>
      t.contains('average') || t.contains('mean ') || t.contains('avg');

  static bool _isTrendIntent(String t) =>
      t.contains('trend') || t.contains('improving') || t.contains('declining') ||
      t.contains('going up') || t.contains('going down') ||
      t.contains('increasing') || t.contains('decreasing') ||
      t.contains('performance over');

  static bool _isHistoricalIntent(String t) {
    // Matches queries about specific time periods
    if (t.contains('last') && (t.contains('day') || t.contains('week') ||
        t.contains('month') || t.contains('hour'))) {
      return true;
    }
    if (t.contains('past') && (t.contains('day') || t.contains('week') ||
        t.contains('month') || t.contains('hour'))) {
      return true;
    }
    if (t.contains('yesterday') || t.contains('this week') ||
        t.contains('this month') || t.contains('today\'s')) {
      return true;
    }
    if (RegExp(r'\b\d+\s*(days?|weeks?|months?|hours?)\b').hasMatch(t)) {
      return true;
    }
    // Check for date patterns
    if (_monthNames.keys.any((m) => t.contains(m))) {
      // Only if it also has a device reference
      if (t.contains('inverter') || t.contains('plant') || t.contains('mfm') ||
          t.contains('sensor') || t.contains('temperature')) {
        return true;
      }
    }
    if (t.contains('show') && (t.contains('for') || t.contains('from') ||
        t.contains('since') || t.contains('between'))) {
      return true;
    }
    return false;
  }

  // ══════════════════════════════════════════════
  //  Date / Time Range Extraction
  // ══════════════════════════════════════════════

  static ({DateTime start, DateTime end, String label})? _extractDateRange(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // "last N days/weeks/months/hours"
    final lastN = RegExp(r'(?:last|past)\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+(days?|weeks?|months?|hours?)');
    final lastNMatch = lastN.firstMatch(text);
    if (lastNMatch != null) {
      final numStr = lastNMatch.group(1)!;
      final n = int.tryParse(numStr) ?? _wordToNumber[numStr] ?? 1;
      final unit = lastNMatch.group(2)!;
      if (unit.startsWith('day')) {
        return (start: today.subtract(Duration(days: n)), end: now, label: 'last $n day${n > 1 ? 's' : ''}');
      } else if (unit.startsWith('week')) {
        return (start: today.subtract(Duration(days: n * 7)), end: now, label: 'last $n week${n > 1 ? 's' : ''}');
      } else if (unit.startsWith('month')) {
        return (start: DateTime(now.year, now.month - n, now.day), end: now, label: 'last $n month${n > 1 ? 's' : ''}');
      } else if (unit.startsWith('hour')) {
        return (start: now.subtract(Duration(hours: n)), end: now, label: 'last $n hour${n > 1 ? 's' : ''}');
      }
    }

    // "yesterday"
    if (text.contains('yesterday')) {
      final yd = today.subtract(const Duration(days: 1));
      return (start: yd, end: today, label: 'yesterday');
    }

    // "today"
    if (text.contains('today')) {
      return (start: today, end: now, label: 'today');
    }

    // "this week"
    if (text.contains('this week')) {
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      return (start: weekStart, end: now, label: 'this week');
    }

    // "last week"
    if (text.contains('last week')) {
      final lastWeekEnd = today.subtract(Duration(days: today.weekday));
      final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
      return (start: lastWeekStart, end: lastWeekEnd, label: 'last week');
    }

    // "this month"
    if (text.contains('this month')) {
      return (start: DateTime(now.year, now.month, 1), end: now, label: 'this month');
    }

    // "last month"
    if (text.contains('last month')) {
      final lmStart = DateTime(now.year, now.month - 1, 1);
      final lmEnd = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
      return (start: lmStart, end: lmEnd, label: 'last month');
    }

    // Specific month name: "in march", "for february"
    for (final entry in _monthNames.entries) {
      if (text.contains(entry.key)) {
        final year = now.year;
        final monthStart = DateTime(year, entry.value, 1);
        final monthEnd = DateTime(year, entry.value + 1, 1).subtract(const Duration(days: 1));
        return (start: monthStart, end: monthEnd.isAfter(now) ? now : monthEnd, label: entry.key);
      }
    }

    return null;
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ══════════════════════════════════════════════
  //  Metric Detection
  // ══════════════════════════════════════════════

  static ({String field, String label}) _detectMetric(String text) {
    if (text.contains('today') || text.contains('daily') || text.contains('e-today')) {
      return (field: 'eTodayPower', label: 'Today Energy');
    }
    if (text.contains('total energy') || text.contains('e-total') || text.contains('cumulative')) {
      return (field: 'eTotalPower', label: 'Total Energy');
    }
    if (text.contains('voltage') || text.contains('grid voltage')) {
      return (field: 'activePower', label: 'Active Power (Voltage)');
    }
    if (text.contains('current') || text.contains('grid current')) {
      return (field: 'activePower', label: 'Active Power (Current)');
    }
    // Default: active power
    return (field: 'activePower', label: 'Active Power');
  }

  // ══════════════════════════════════════════════
  //  Entity Resolution (robust)
  // ══════════════════════════════════════════════

  /// Robustly resolve device references from user text.
  /// Handles: "inverter 1", "inverter one", "inv 3", full names, fuzzy matching.
  static List<Map<String, dynamic>> _resolveDevices(String text, List<dynamic> items) {
    final results = <Map<String, dynamic>>[];
    final resolvedIds = <String>{};

    // Step 1: Exact name match
    for (final item in items) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      if (name.isNotEmpty && text.contains(name)) {
        final mapped = Map<String, dynamic>.from(item);
        if (resolvedIds.add(mapped['id'].toString())) {
          results.add(mapped);
        }
      }
    }

    // Step 2: Numeric references ("inverter 1", "sensor 3", etc.)
    final allNums = RegExp(r'\b(\d+)\b').allMatches(text).toList();
    // Also extract word-numbers
    for (final entry in _wordToNumber.entries) {
      final pat = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b');
      if (pat.hasMatch(text) && entry.value > 0) {
        allNums.add(pat.firstMatch(text)!);
      }
    }

    for (final m in allNums) {
      int num;
      final raw = m.group(0)!.toLowerCase();
      num = int.tryParse(raw) ?? _wordToNumber[raw] ?? 0;
      if (num < 1) continue;

      Map<String, dynamic>? matched;

      // Strategy A: Name contains this number with word boundary
      final boundary = RegExp(r'(^|[\D_])' + num.toString() + r'($|[\D_])');
      for (final item in items) {
        final name = (item['name'] ?? '').toString();
        if (boundary.hasMatch(name)) {
          matched = Map<String, dynamic>.from(item);
          break;
        }
      }

      // Strategy B: Trailing number in name
      if (matched == null) {
        final trailingDigit = RegExp(r'(\d+)\s*$');
        for (final item in items) {
          final name = (item['name'] ?? '').toString();
          final tm = trailingDigit.firstMatch(name);
          if (tm != null && int.tryParse(tm.group(1)!) == num) {
            matched = Map<String, dynamic>.from(item);
            break;
          }
        }
      }

      // Strategy C: Use as 1-based list index
      if (matched == null && num >= 1 && num <= items.length) {
        matched = Map<String, dynamic>.from(items[num - 1]);
      }

      if (matched != null && resolvedIds.add(matched['id'].toString())) {
        results.add(matched);
      }
    }

    // Step 3: Fuzzy word overlap for remaining unmatched text
    if (results.isEmpty) {
      final textWords = text.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
      Map<String, dynamic>? best;
      int bestOverlap = 0;
      for (final item in items) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final nameWords = name.split(RegExp(r'[\s./,_\-]+')).where((w) => w.length > 2).toSet();
        final overlap = textWords.intersection(nameWords).length;
        if (overlap > bestOverlap) {
          bestOverlap = overlap;
          best = Map<String, dynamic>.from(item);
        }
      }
      if (best != null) results.add(best);
    }

    return results;
  }

  /// Find a single entity by fuzzy name match
  static Map<String, dynamic>? _findEntityByFuzzyName(String text, List<dynamic> items) {
    final resolved = _resolveDevices(text, items);
    return resolved.isNotEmpty ? resolved.first : null;
  }

  // ══════════════════════════════════════════════
  //  Historical / Time-range Data Fetching
  // ══════════════════════════════════════════════

  /// Fetch inverter data points within a date range
  static Future<List<Map<String, dynamic>>> _fetchInverterDataRange(
      String inverterId, DateTime start, DateTime end) async {
    final data = await _supabase
        .from('InverterData')
        .select()
        .eq('inverterId', inverterId)
        .gte('timestamp', start.toIso8601String())
        .lte('timestamp', end.toIso8601String())
        .order('timestamp', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetch MFM data points within a date range
  static Future<List<Map<String, dynamic>>> _fetchMfmDataRange(
      String mfmId, DateTime start, DateTime end) async {
    final data = await _supabase
        .from('MFMData')
        .select()
        .eq('mfmId', mfmId)
        .gte('timestamp', start.toIso8601String())
        .lte('timestamp', end.toIso8601String())
        .order('timestamp', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetch temperature data within a date range
  static Future<List<Map<String, dynamic>>> _fetchTempDataRange(
      String deviceId, DateTime start, DateTime end) async {
    final data = await _supabase
        .from('TemperatureData')
        .select()
        .eq('deviceId', deviceId)
        .gte('timestamp', start.toIso8601String())
        .lte('timestamp', end.toIso8601String())
        .order('timestamp', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Get the latest data for an inverter
  static Future<Map<String, dynamic>?> _getLatestInverterData(String inverterId) async {
    final latest = await _supabase
        .from('InverterData')
        .select()
        .eq('inverterId', inverterId)
        .order('timestamp', ascending: false)
        .limit(1);
    return latest.isNotEmpty ? Map<String, dynamic>.from(latest[0]) : null;
  }

  /// Get daily summary (aggregate) for an inverter over a date range
  static Future<List<_DailySummary>> _getDailyInverterSummary(
      String inverterId, DateTime start, DateTime end) async {
    final data = await _fetchInverterDataRange(inverterId, start, end);
    if (data.isEmpty) return [];

    // Group by date
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final row in data) {
      final ts = DateTime.tryParse(row['timestamp']?.toString() ?? '');
      if (ts == null) continue;
      final dateKey = _fmtDate(ts);
      byDate.putIfAbsent(dateKey, () => []).add(row);
    }

    final summaries = <_DailySummary>[];
    for (final entry in byDate.entries) {
      final rows = entry.value;
      double maxPower = 0, sumPower = 0, maxToday = 0;
      for (final r in rows) {
        final ap = (r['activePower'] as num?)?.toDouble() ?? 0;
        final et = (r['eTodayPower'] as num?)?.toDouble() ?? 0;
        if (ap > maxPower) maxPower = ap;
        sumPower += ap;
        if (et > maxToday) maxToday = et;
      }
      summaries.add(_DailySummary(
        date: entry.key,
        maxPower: maxPower,
        avgPower: rows.isNotEmpty ? sumPower / rows.length : 0,
        todayEnergy: maxToday,
        dataPoints: rows.length,
      ));
    }
    summaries.sort((a, b) => a.date.compareTo(b.date));
    return summaries;
  }

  // ══════════════════════════════════════════════
  //  Intent Handlers
  // ══════════════════════════════════════════════

  static Future<ChatMessage> _handleHistorical(String text) async {
    final dateRange = _extractDateRange(text);

    // Detect device type
    if (text.contains('inverter') || text.contains('converter')) {
      return await _handleInverterHistorical(text, dateRange);
    }
    if (text.contains('mfm') || text.contains('meter')) {
      return await _handleMfmHistorical(text, dateRange);
    }
    if (text.contains('temperature') || text.contains('temp')) {
      return await _handleTempHistorical(text, dateRange);
    }
    if (text.contains('plant') || text.contains('site')) {
      return await _handlePlantHistorical(text, dateRange);
    }
    // Default: try inverter data
    return await _handleInverterHistorical(text, dateRange);
  }

  static Future<ChatMessage> _handleInverterHistorical(
      String text, ({DateTime start, DateTime end, String label})? dateRange) async {
    final inverters = await _supabase.from('Inverter').select('id, name, plantId');
    if (inverters.isEmpty) {
      return ChatMessage(text: 'No inverters found in the system.', isUser: false);
    }

    final mentioned = _resolveDevices(text, inverters);
    final targets = mentioned.isNotEmpty ? mentioned : inverters;
    final metric = _detectMetric(text);

    if (dateRange == null) {
      // Default to last 7 days
      final now = DateTime.now();
      dateRange = (
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
        end: now,
        label: 'last 7 days',
      );
    }

    final buffer = StringBuffer();
    if (mentioned.isNotEmpty) {
      buffer.writeln('**${metric.label} Data — ${dateRange.label}**\n');
    } else {
      buffer.writeln('**System ${metric.label} — ${dateRange.label}**\n');
    }

    for (final inv in targets) {
      final invId = inv['id'] as String;
      final name = inv['name'] ?? 'Unknown';

      final dailySummary = await _getDailyInverterSummary(invId, dateRange.start, dateRange.end);

      if (dailySummary.isEmpty) {
        buffer.writeln('**$name**: No data available for ${dateRange.label}\n');
        continue;
      }

      buffer.writeln('**$name**');
      for (final day in dailySummary) {
        buffer.writeln('  ${day.date}: Peak ${day.maxPower.toStringAsFixed(1)} kW | '
            'Avg ${day.avgPower.toStringAsFixed(1)} kW | '
            'Energy ${day.todayEnergy.toStringAsFixed(1)} kWh');
      }

      // Summary stats
      final totalEnergy = dailySummary.fold<double>(0, (s, d) => s + d.todayEnergy);
      final peakPower = dailySummary.fold<double>(0, (s, d) => d.maxPower > s ? d.maxPower : s);
      final avgPower = dailySummary.fold<double>(0, (s, d) => s + d.avgPower) / dailySummary.length;
      buffer.writeln('  **Total Energy: ${totalEnergy.toStringAsFixed(1)} kWh**');
      buffer.writeln('  **Peak Power: ${peakPower.toStringAsFixed(1)} kW**');
      buffer.writeln('  **Avg Power: ${avgPower.toStringAsFixed(1)} kW**');
      buffer.writeln('');
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleMfmHistorical(
      String text, ({DateTime start, DateTime end, String label})? dateRange) async {
    final mfms = await _supabase.from('MFM').select('id, name');
    if (mfms.isEmpty) return ChatMessage(text: 'No MFM sensors found.', isUser: false);

    final mentioned = _resolveDevices(text, mfms);
    final targets = mentioned.isNotEmpty ? mentioned : mfms;

    if (dateRange == null) {
      final now = DateTime.now();
      dateRange = (
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
        end: now,
        label: 'last 7 days',
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('**MFM Data — ${dateRange.label}**\n');

    for (final mfm in targets) {
      final mfmId = mfm['id'] as String;
      final name = mfm['name'] ?? 'Unknown';
      final data = await _fetchMfmDataRange(mfmId, dateRange.start, dateRange.end);

      if (data.isEmpty) {
        buffer.writeln('**$name**: No data for ${dateRange.label}\n');
        continue;
      }

      double maxPower = 0, sumPower = 0;
      for (final r in data) {
        final p = (r['totalPower'] as num?)?.toDouble() ?? 0;
        if (p > maxPower) maxPower = p;
        sumPower += p;
      }

      buffer.writeln('**$name** (${data.length} readings)');
      buffer.writeln('  Peak Power: ${maxPower.toStringAsFixed(1)} kW');
      buffer.writeln('  Avg Power: ${(sumPower / data.length).toStringAsFixed(1)} kW');
      buffer.writeln('');
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleTempHistorical(
      String text, ({DateTime start, DateTime end, String label})? dateRange) async {
    final temps = await _supabase.from('TemperatureDevice').select('id, name');
    if (temps.isEmpty) return ChatMessage(text: 'No temperature sensors found.', isUser: false);

    final mentioned = _resolveDevices(text, temps);
    final targets = mentioned.isNotEmpty ? mentioned : temps;

    if (dateRange == null) {
      final now = DateTime.now();
      dateRange = (
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
        end: now,
        label: 'last 7 days',
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('**Temperature Data — ${dateRange.label}**\n');

    for (final temp in targets) {
      final tempId = temp['id'] as String;
      final name = temp['name'] ?? 'Unknown';
      final data = await _fetchTempDataRange(tempId, dateRange.start, dateRange.end);

      if (data.isEmpty) {
        buffer.writeln('**$name**: No data for ${dateRange.label}\n');
        continue;
      }

      double maxT = -999, minT = 999, sumT = 0;
      for (final r in data) {
        final v = (r['value'] as num?)?.toDouble() ?? 0;
        if (v > maxT) maxT = v;
        if (v < minT) minT = v;
        sumT += v;
      }

      buffer.writeln('**$name** (${data.length} readings)');
      buffer.writeln('  Max: ${maxT.toStringAsFixed(1)} °C');
      buffer.writeln('  Min: ${minT.toStringAsFixed(1)} °C');
      buffer.writeln('  Avg: ${(sumT / data.length).toStringAsFixed(1)} °C');
      buffer.writeln('');
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handlePlantHistorical(
      String text, ({DateTime start, DateTime end, String label})? dateRange) async {
    final plants = await _supabase.from('Plant').select('id, name');
    final inverters = await _supabase.from('Inverter').select('id, name, plantId');

    final mentioned = _resolveDevices(text, plants);
    final targets = mentioned.isNotEmpty ? mentioned : plants;

    if (dateRange == null) {
      final now = DateTime.now();
      dateRange = (
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
        end: now,
        label: 'last 7 days',
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('**Plant Data — ${dateRange.label}**\n');

    for (final plant in targets) {
      final pid = plant['id'] as String;
      final name = plant['name'] ?? 'Unknown';
      final plantInvs = inverters.where((i) => i['plantId'] == pid).toList();

      double totalEnergy = 0, peakPower = 0;
      int totalPoints = 0;

      for (final inv in plantInvs) {
        final summary = await _getDailyInverterSummary(
            inv['id'] as String, dateRange.start, dateRange.end);
        for (final day in summary) {
          totalEnergy += day.todayEnergy;
          if (day.maxPower > peakPower) peakPower = day.maxPower;
          totalPoints += day.dataPoints;
        }
      }

      buffer.writeln('**$name** (${plantInvs.length} inverters)');
      buffer.writeln('  Total Energy: ${totalEnergy.toStringAsFixed(1)} kWh');
      buffer.writeln('  Peak Power: ${peakPower.toStringAsFixed(1)} kW');
      buffer.writeln('  Data Points: $totalPoints');
      buffer.writeln('');
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  // ── Trend Handler ──

  static Future<ChatMessage> _handleTrend(String text) async {
    final now = DateTime.now();
    final dateRange = _extractDateRange(text) ?? (
      start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
      end: now,
      label: 'last 7 days',
    );

    if (text.contains('temperature') || text.contains('temp')) {
      return await _handleTempTrend(text, dateRange);
    }

    // Default: inverter power trend
    final inverters = await _supabase.from('Inverter').select('id, name, plantId');
    final mentioned = _resolveDevices(text, inverters);
    final targets = mentioned.isNotEmpty ? mentioned : inverters;

    final buffer = StringBuffer();
    buffer.writeln('**Power Trend — ${dateRange.label}**\n');

    for (final inv in targets) {
      final invId = inv['id'] as String;
      final name = inv['name'] ?? 'Unknown';
      final summary = await _getDailyInverterSummary(invId, dateRange.start, dateRange.end);

      if (summary.length < 2) {
        buffer.writeln('**$name**: Not enough data to show trend\n');
        continue;
      }

      buffer.writeln('**$name**');
      for (final day in summary) {
        final bar = '█' * (day.avgPower / 5).clamp(1, 20).round();
        buffer.writeln('  ${day.date}: $bar ${day.avgPower.toStringAsFixed(1)} kW');
      }

      // Calculate trend direction
      final firstHalf = summary.sublist(0, summary.length ~/ 2);
      final secondHalf = summary.sublist(summary.length ~/ 2);
      final avgFirst = firstHalf.fold<double>(0, (s, d) => s + d.avgPower) / firstHalf.length;
      final avgSecond = secondHalf.fold<double>(0, (s, d) => s + d.avgPower) / secondHalf.length;
      final change = avgSecond - avgFirst;
      final pctChange = avgFirst > 0 ? (change / avgFirst * 100) : 0.0;

      if (change > 0) {
        buffer.writeln('  📈 **Increasing** by ${pctChange.toStringAsFixed(1)}%');
      } else if (change < 0) {
        buffer.writeln('  📉 **Decreasing** by ${pctChange.abs().toStringAsFixed(1)}%');
      } else {
        buffer.writeln('  ➡ **Stable**');
      }
      buffer.writeln('');
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleTempTrend(
      String text, ({DateTime start, DateTime end, String label}) dateRange) async {
    final temps = await _supabase.from('TemperatureDevice').select('id, name');
    final mentioned = _resolveDevices(text, temps);
    final targets = mentioned.isNotEmpty ? mentioned : temps;

    final buffer = StringBuffer();
    buffer.writeln('**Temperature Trend — ${dateRange.label}**\n');

    for (final temp in targets) {
      final tempId = temp['id'] as String;
      final name = temp['name'] ?? 'Unknown';
      final data = await _fetchTempDataRange(tempId, dateRange.start, dateRange.end);

      if (data.length < 2) {
        buffer.writeln('**$name**: Not enough data for trend\n');
        continue;
      }

      // Group by date
      final byDate = <String, List<double>>{};
      for (final r in data) {
        final ts = DateTime.tryParse(r['timestamp']?.toString() ?? '');
        if (ts == null) continue;
        final key = _fmtDate(ts);
        byDate.putIfAbsent(key, () => []).add((r['value'] as num?)?.toDouble() ?? 0);
      }

      buffer.writeln('**$name**');
      final sortedDates = byDate.keys.toList()..sort();
      for (final date in sortedDates) {
        final vals = byDate[date]!;
        final avg = vals.fold<double>(0, (s, v) => s + v) / vals.length;
        buffer.writeln('  $date: ${avg.toStringAsFixed(1)} °C');
      }
      buffer.writeln('');
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  // ── Compare Handler ──

  static Future<ChatMessage> _handleCompare(String text) async {
    // Check for time-range comparison
    final dateRange = _extractDateRange(text);

    if (text.contains('plant') || text.contains('site')) {
      return dateRange != null
          ? await _handlePlantHistorical(text, dateRange)
          : await _comparePlants(text);
    }
    if (text.contains('inverter')) {
      return dateRange != null
          ? await _compareInvertersOverTime(text, dateRange)
          : await _compareInverters(text);
    }
    if (text.contains('sensor') || text.contains('mfm') || text.contains('temperature')) {
      return await _compareSensors(text);
    }

    // Auto-detect from numbers + context
    final inverters = await _supabase.from('Inverter').select('id, name, plantId');
    final mentionedInv = _resolveDevices(text, inverters);
    if (mentionedInv.length >= 2) {
      return dateRange != null
          ? await _compareInvertersOverTime(text, dateRange)
          : await _compareInverters(text);
    }

    return await _comparePlants(text);
  }

  static Future<ChatMessage> _comparePlants(String text) async {
    final plants = await _supabase.from('Plant').select('id, name');
    if (plants.isEmpty) {
      return ChatMessage(text: 'No plants found in the system.', isUser: false);
    }

    final buffer = StringBuffer();
    buffer.writeln('**Plant Comparison**\n');

    final inverters = await _supabase.from('Inverter').select('id, name, plantId');
    final plantInvCount = <String, int>{};
    for (final inv in inverters) {
      final pid = inv['plantId']?.toString() ?? '';
      plantInvCount[pid] = (plantInvCount[pid] ?? 0) + 1;
    }

    final plantEnergy = <String, double>{};
    final plantTodayEnergy = <String, double>{};
    final plantActivePower = <String, double>{};
    for (final inv in inverters) {
      final invId = inv['id'] as String;
      final pid = inv['plantId']?.toString() ?? '';
      final d = await _getLatestInverterData(invId);
      if (d != null) {
        final eTotal = (d['eTotalPower'] as num?)?.toDouble() ?? 0;
        final eToday = (d['eTodayPower'] as num?)?.toDouble() ?? 0;
        final active = (d['activePower'] as num?)?.toDouble() ?? 0;
        plantEnergy[pid] = (plantEnergy[pid] ?? 0) + eTotal;
        plantTodayEnergy[pid] = (plantTodayEnergy[pid] ?? 0) + eToday;
        plantActivePower[pid] = (plantActivePower[pid] ?? 0) + active;
      }
    }

    for (final plant in plants) {
      final pid = plant['id'] as String;
      final name = plant['name'] ?? 'Unknown';
      final invCount = plantInvCount[pid] ?? 0;
      final totalE = plantEnergy[pid] ?? 0;
      final todayE = plantTodayEnergy[pid] ?? 0;
      final activeP = plantActivePower[pid] ?? 0;
      buffer.writeln('**$name**');
      buffer.writeln('  Inverters: $invCount');
      buffer.writeln('  Active Power: ${activeP.toStringAsFixed(1)} kW');
      buffer.writeln('  Today Energy: ${todayE.toStringAsFixed(1)} kWh');
      buffer.writeln('  Total Energy: ${totalE.toStringAsFixed(1)} kWh');
      buffer.writeln('');
    }

    if (plantTodayEnergy.isNotEmpty) {
      final bestPid = plantTodayEnergy.entries
          .reduce((a, b) => a.value > b.value ? a : b).key;
      final bestName = plants.firstWhere((p) => p['id'] == bestPid)['name'];
      buffer.writeln('**Best Today:** $bestName with ${plantTodayEnergy[bestPid]!.toStringAsFixed(1)} kWh');
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _compareInverters(String text) async {
    final inverters = await _supabase.from('Inverter').select('id, name, plantId');
    if (inverters.isEmpty) {
      return ChatMessage(text: 'No inverters found.', isUser: false);
    }

    final mentioned = _resolveDevices(text, inverters);
    final toCompare = mentioned.isNotEmpty ? mentioned : inverters.take(5).toList();

    final buffer = StringBuffer();
    buffer.writeln('**Inverter Comparison**\n');

    final dataMap = <String, Map<String, dynamic>>{};

    for (final inv in toCompare) {
      final invId = inv['id'] as String;
      final name = inv['name'] ?? 'Unknown';
      final d = await _getLatestInverterData(invId);
      if (d != null) {
        dataMap[name] = d;
        buffer.writeln('**$name**');
        buffer.writeln('  Active Power: ${_fmtNum(d['activePower'])} kW');
        buffer.writeln('  Today Energy: ${_fmtNum(d['eTodayPower'])} kWh');
        buffer.writeln('  Total Energy: ${_fmtNum(d['eTotalPower'])} kWh');
        buffer.writeln('');
      } else {
        buffer.writeln('**$name**: No data available\n');
      }
    }

    // Add winner summary if comparing 2+ with data
    if (dataMap.length >= 2) {
      buffer.writeln('---');
      final bestByPower = dataMap.entries.reduce((a, b) =>
          ((a.value['activePower'] as num?)?.toDouble() ?? 0) >=
          ((b.value['activePower'] as num?)?.toDouble() ?? 0) ? a : b);
      final bestByToday = dataMap.entries.reduce((a, b) =>
          ((a.value['eTodayPower'] as num?)?.toDouble() ?? 0) >=
          ((b.value['eTodayPower'] as num?)?.toDouble() ?? 0) ? a : b);
      buffer.writeln('**Best Active Power:** ${bestByPower.key} (${_fmtNum(bestByPower.value['activePower'])} kW)');
      buffer.writeln('**Best Today Energy:** ${bestByToday.key} (${_fmtNum(bestByToday.value['eTodayPower'])} kWh)');
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _compareInvertersOverTime(
      String text, ({DateTime start, DateTime end, String label}) dateRange) async {
    final inverters = await _supabase.from('Inverter').select('id, name, plantId');
    if (inverters.isEmpty) {
      return ChatMessage(text: 'No inverters found.', isUser: false);
    }

    final mentioned = _resolveDevices(text, inverters);
    final toCompare = mentioned.isNotEmpty ? mentioned : inverters.take(5).toList();

    final buffer = StringBuffer();
    buffer.writeln('**Inverter Comparison — ${dateRange.label}**\n');

    final invSummaries = <String, List<_DailySummary>>{};

    for (final inv in toCompare) {
      final invId = inv['id'] as String;
      final name = inv['name'] ?? 'Unknown';
      final summary = await _getDailyInverterSummary(invId, dateRange.start, dateRange.end);
      invSummaries[name] = summary;

      if (summary.isEmpty) {
        buffer.writeln('**$name**: No data for ${dateRange.label}\n');
        continue;
      }

      final totalEnergy = summary.fold<double>(0, (s, d) => s + d.todayEnergy);
      final peakPower = summary.fold<double>(0, (s, d) => d.maxPower > s ? d.maxPower : s);
      final avgPower = summary.fold<double>(0, (s, d) => s + d.avgPower) / summary.length;

      buffer.writeln('**$name**');
      buffer.writeln('  Total Energy: ${totalEnergy.toStringAsFixed(1)} kWh');
      buffer.writeln('  Peak Power: ${peakPower.toStringAsFixed(1)} kW');
      buffer.writeln('  Avg Power: ${avgPower.toStringAsFixed(1)} kW');
      buffer.writeln('  Days with data: ${summary.length}');
      buffer.writeln('');
    }

    // Winner summary
    final withData = invSummaries.entries.where((e) => e.value.isNotEmpty).toList();
    if (withData.length >= 2) {
      buffer.writeln('---');
      final bestEnergy = withData.reduce((a, b) {
        final aTotal = a.value.fold<double>(0, (s, d) => s + d.todayEnergy);
        final bTotal = b.value.fold<double>(0, (s, d) => s + d.todayEnergy);
        return aTotal >= bTotal ? a : b;
      });
      final totalE = bestEnergy.value.fold<double>(0, (s, d) => s + d.todayEnergy);
      buffer.writeln('**Best Overall:** ${bestEnergy.key} with ${totalE.toStringAsFixed(1)} kWh total');
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _compareSensors(String text) async {
    final isMfm = text.contains('mfm') || text.contains('meter');
    final isTemp = text.contains('temperature') || text.contains('thermal');
    if (isMfm || (!isTemp)) return await _compareMfms();
    return await _compareTemps();
  }

  static Future<ChatMessage> _compareMfms() async {
    final mfms = await _supabase.from('MFM').select('id, name');
    if (mfms.isEmpty) return ChatMessage(text: 'No MFM sensors found.', isUser: false);

    final buffer = StringBuffer();
    buffer.writeln('**MFM Sensor Comparison**\n');

    for (final mfm in mfms) {
      final mfmId = mfm['id'] as String;
      final name = mfm['name'] ?? 'Unknown';
      final latest = await _supabase
          .from('MFMData')
          .select()
          .eq('mfmId', mfmId)
          .order('timestamp', ascending: false)
          .limit(1);
      if (latest.isNotEmpty) {
        final d = latest[0];
        buffer.writeln('**$name**');
        buffer.writeln('  Total Power: ${_fmtNum(d['totalPower'])} kW');
        buffer.writeln('  L1 Voltage: ${_fmtNum(d['l1nVoltage'])} V');
        buffer.writeln('  L2 Voltage: ${_fmtNum(d['l2nVoltage'])} V');
        buffer.writeln('  L3 Voltage: ${_fmtNum(d['l3nVoltage'])} V');
        buffer.writeln('  Frequency: ${_fmtNum(d['frequency'])} Hz');
        buffer.writeln('');
      }
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _compareTemps() async {
    final temps = await _supabase.from('TemperatureDevice').select('id, name');
    if (temps.isEmpty) return ChatMessage(text: 'No temperature sensors found.', isUser: false);

    final buffer = StringBuffer();
    buffer.writeln('**Temperature Sensor Comparison**\n');

    for (final temp in temps) {
      final tempId = temp['id'] as String;
      final name = temp['name'] ?? 'Unknown';
      final latest = await _supabase
          .from('TemperatureData')
          .select()
          .eq('deviceId', tempId)
          .order('timestamp', ascending: false)
          .limit(1);
      if (latest.isNotEmpty) {
        buffer.writeln('**$name**: ${_fmtNum(latest[0]['value'])} °C');
      }
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleSummary(String text) async {
    final buffer = StringBuffer();
    buffer.writeln('**System Overview**\n');

    final plants = await _supabase.from('Plant').select('id, name');
    buffer.writeln('**Plants:** ${plants.length}');

    final inverters = await _supabase.from('Inverter').select('id');
    buffer.writeln('**Inverters:** ${inverters.length}');

    final mfms = await _supabase.from('MFM').select('id');
    final temps = await _supabase.from('TemperatureDevice').select('id');
    final wfms = await _supabase.from('WFM').select('id');
    buffer.writeln('**Sensors:** ${mfms.length} MFM, ${temps.length} Temperature, ${wfms.length} WMS');

    double totalEnergy = 0, todayEnergy = 0, totalCapacity = 0;
    for (final inv in inverters) {
      final d = await _getLatestInverterData(inv['id'] as String);
      if (d != null) {
        totalEnergy += (d['eTotalPower'] as num?)?.toDouble() ?? 0;
        todayEnergy += (d['eTodayPower'] as num?)?.toDouble() ?? 0;
        totalCapacity += (d['activePower'] as num?)?.toDouble() ?? 0;
      }
    }

    buffer.writeln('');
    buffer.writeln('**Total Energy:** ${totalEnergy.toStringAsFixed(1)} kWh');
    buffer.writeln('**Today Energy:** ${todayEnergy.toStringAsFixed(1)} kWh');
    buffer.writeln('**Active Power:** ${totalCapacity.toStringAsFixed(1)} kW');
    buffer.writeln('**CO₂ Reduced:** ${(totalEnergy * 0.7).toStringAsFixed(0)} kg');

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleTopBottom(String text) async {
    final isTop = text.contains('highest') || text.contains('best') ||
        text.contains('top') || text.contains('maximum') || text.contains('most');

    if (text.contains('temperature') || text.contains('temp')) {
      final temps = await _supabase.from('TemperatureDevice').select('id, name');
      final readings = <String, double>{};
      for (final t in temps) {
        final latest = await _supabase
            .from('TemperatureData')
            .select()
            .eq('deviceId', t['id'] as String)
            .order('timestamp', ascending: false)
            .limit(1);
        if (latest.isNotEmpty) {
          readings[t['name'] ?? 'Unknown'] = (latest[0]['value'] as num?)?.toDouble() ?? 0;
        }
      }
      if (readings.isEmpty) return ChatMessage(text: 'No temperature data available.', isUser: false);

      final sorted = readings.entries.toList()
        ..sort((a, b) => isTop ? b.value.compareTo(a.value) : a.value.compareTo(b.value));
      final label = isTop ? 'Highest' : 'Lowest';
      final top = sorted.first;
      return ChatMessage(
        text: '**$label Temperature:** ${top.key} at ${top.value.toStringAsFixed(1)} °C',
        isUser: false,
      );
    }

    // Default: energy/power comparison across inverters
    final inverters = await _supabase.from('Inverter').select('id, name');
    final metric = _detectMetric(text);
    final readings = <String, double>{};
    for (final inv in inverters) {
      final d = await _getLatestInverterData(inv['id'] as String);
      if (d != null) {
        readings[inv['name'] ?? 'Unknown'] = (d[metric.field] as num?)?.toDouble() ?? 0;
      }
    }
    if (readings.isEmpty) return ChatMessage(text: 'No inverter data available.', isUser: false);

    final sorted = readings.entries.toList()
      ..sort((a, b) => isTop ? b.value.compareTo(a.value) : a.value.compareTo(b.value));
    final label = isTop ? 'Highest' : 'Lowest';
    final top3 = sorted.take(3);
    final buffer = StringBuffer();
    buffer.writeln('**$label ${metric.label}:**\n');
    int rank = 1;
    for (final entry in top3) {
      buffer.writeln('$rank. **${entry.key}**: ${entry.value.toStringAsFixed(1)}');
      rank++;
    }
    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleStatus(String text) async {
    final inverters = await _supabase.from('Inverter').select('id, name');
    int active = 0, inactive = 0;
    final inactiveNames = <String>[];

    for (final inv in inverters) {
      final d = await _getLatestInverterData(inv['id'] as String);
      if (d != null) {
        final power = (d['activePower'] as num?)?.toDouble() ?? 0;
        if (power > 0) {
          active++;
        } else {
          inactive++;
          inactiveNames.add(inv['name'] ?? 'Unknown');
        }
      } else {
        inactive++;
        inactiveNames.add(inv['name'] ?? 'Unknown');
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('**System Status**\n');
    buffer.writeln('Active Inverters: **$active** / ${inverters.length}');
    if (inactiveNames.isNotEmpty) {
      buffer.writeln('Inactive: ${inactiveNames.join(', ')}');
    }
    buffer.writeln('');
    buffer.writeln('All systems ${inactive == 0 ? "operational ✓" : "have $inactive inactive device(s)"}');

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleCount(String text) async {
    final buffer = StringBuffer();

    if (text.contains('inverter')) {
      final data = await _supabase.from('Inverter').select('id');
      return ChatMessage(text: 'There are **${data.length}** inverters in the system.', isUser: false);
    }
    if (text.contains('plant') || text.contains('site')) {
      final data = await _supabase.from('Plant').select('id');
      return ChatMessage(text: 'There are **${data.length}** plants in the system.', isUser: false);
    }
    if (text.contains('sensor') || text.contains('mfm') || text.contains('temperature')) {
      final mfms = await _supabase.from('MFM').select('id');
      final temps = await _supabase.from('TemperatureDevice').select('id');
      final wfms = await _supabase.from('WFM').select('id');
      buffer.writeln('**Sensor Count:**');
      buffer.writeln('  MFM: ${mfms.length}');
      buffer.writeln('  Temperature: ${temps.length}');
      buffer.writeln('  WMS: ${wfms.length}');
      buffer.writeln('  **Total: ${mfms.length + temps.length + wfms.length}**');
      return ChatMessage(text: buffer.toString().trim(), isUser: false);
    }

    final plants = await _supabase.from('Plant').select('id');
    final inverters = await _supabase.from('Inverter').select('id');
    final mfms = await _supabase.from('MFM').select('id');
    final temps = await _supabase.from('TemperatureDevice').select('id');
    buffer.writeln('**Device Count:**');
    buffer.writeln('  Plants: ${plants.length}');
    buffer.writeln('  Inverters: ${inverters.length}');
    buffer.writeln('  MFM Sensors: ${mfms.length}');
    buffer.writeln('  Temperature Sensors: ${temps.length}');
    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleEnergy(String text) async {
    final inverters = await _supabase.from('Inverter').select('id, name');
    double totalToday = 0, totalAll = 0, totalActive = 0;

    final buffer = StringBuffer();
    final dateRange = _extractDateRange(text);

    // If there's a date range, use historical handler
    if (dateRange != null) {
      return await _handleInverterHistorical(text, dateRange);
    }

    final mentioned = _resolveDevices(text, inverters);
    final targets = mentioned.isNotEmpty ? mentioned : inverters;

    for (final inv in targets) {
      final d = await _getLatestInverterData(inv['id'] as String);
      if (d != null) {
        final eTotal = (d['eTotalPower'] as num?)?.toDouble() ?? 0;
        final eToday = (d['eTodayPower'] as num?)?.toDouble() ?? 0;
        final active = (d['activePower'] as num?)?.toDouble() ?? 0;
        totalAll += eTotal;
        totalToday += eToday;
        totalActive += active;

        if (mentioned.isNotEmpty) {
          buffer.writeln('**${inv['name']}**');
          buffer.writeln('  Active Power: ${active.toStringAsFixed(1)} kW');
          buffer.writeln('  Today Energy: ${eToday.toStringAsFixed(1)} kWh');
          buffer.writeln('  Total Energy: ${eTotal.toStringAsFixed(1)} kWh');
        }
      }
    }

    if (mentioned.isEmpty) {
      buffer.writeln('**Energy Summary**\n');
      buffer.writeln('Active Power: **${totalActive.toStringAsFixed(1)} kW**');
      buffer.writeln('Today Energy: **${totalToday.toStringAsFixed(1)} kWh**');
      buffer.writeln('Total Energy: **${totalAll.toStringAsFixed(1)} kWh**');
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleSensorQuery(String text) async {
    final dateRange = _extractDateRange(text);
    if (dateRange != null) {
      if (text.contains('mfm') || text.contains('meter')) {
        return await _handleMfmHistorical(text, dateRange);
      }
      if (text.contains('temperature') || text.contains('thermal')) {
        return await _handleTempHistorical(text, dateRange);
      }
    }

    if (text.contains('mfm') || text.contains('meter')) return await _compareMfms();
    if (text.contains('temperature') || text.contains('thermal')) return await _compareTemps();

    final mfms = await _supabase.from('MFM').select('id');
    final temps = await _supabase.from('TemperatureDevice').select('id');
    final wfms = await _supabase.from('WFM').select('id');
    return ChatMessage(
      text: '**Sensors:** ${mfms.length} MFM, ${temps.length} Temperature, ${wfms.length} WMS devices.\n\nAsk me to compare specific sensors or show their latest readings!',
      isUser: false,
    );
  }

  static Future<ChatMessage> _handleInverterQuery(String text) async {
    final dateRange = _extractDateRange(text);
    if (dateRange != null) {
      return await _handleInverterHistorical(text, dateRange);
    }
    return await _compareInverters(text);
  }

  static Future<ChatMessage> _handlePlantQuery(String text) async {
    final dateRange = _extractDateRange(text);
    if (dateRange != null) {
      return await _handlePlantHistorical(text, dateRange);
    }
    return await _comparePlants(text);
  }

  static Future<ChatMessage> _handleAlertQuery(String text) async {
    try {
      // Try to find a specific device
      List<Map<String, dynamic>> alerts;
      String context = 'all devices';

      // Check inverters
      if (text.contains('inverter') || text.contains('converter') || text.contains('inv ')) {
        final inverters = await _supabase.from('Inverter').select('id, name');
        final match = _findEntityByFuzzyName(text, inverters);
        if (match != null) {
          alerts = List<Map<String, dynamic>>.from(
            await _supabase.from('Alert').select('*').eq('deviceId', match['id']).order('triggeredAt', ascending: false));
          context = match['name'] ?? 'inverter';
        } else {
          alerts = List<Map<String, dynamic>>.from(
            await _supabase.from('Alert').select('*').eq('deviceType', 'Inverter').order('triggeredAt', ascending: false));
          context = 'all inverters';
        }
      } else if (text.contains('mfm') || text.contains('meter') || text.contains('energy meter')) {
        final mfms = await _supabase.from('MFM').select('id, name');
        final match = _findEntityByFuzzyName(text, mfms);
        if (match != null) {
          alerts = List<Map<String, dynamic>>.from(
            await _supabase.from('Alert').select('*').eq('deviceId', match['id']).order('triggeredAt', ascending: false));
          context = match['name'] ?? 'MFM';
        } else {
          alerts = List<Map<String, dynamic>>.from(
            await _supabase.from('Alert').select('*').eq('deviceType', 'MFM').order('triggeredAt', ascending: false));
          context = 'all MFM sensors';
        }
      } else if (text.contains('temp') || text.contains('thermal') || text.contains('heat')) {
        final temps = await _supabase.from('TemperatureDevice').select('id, name');
        final match = _findEntityByFuzzyName(text, temps);
        if (match != null) {
          alerts = List<Map<String, dynamic>>.from(
            await _supabase.from('Alert').select('*').eq('deviceId', match['id']).order('triggeredAt', ascending: false));
          context = match['name'] ?? 'temperature device';
        } else {
          alerts = List<Map<String, dynamic>>.from(
            await _supabase.from('Alert').select('*').eq('deviceType', 'TemperatureDevice').order('triggeredAt', ascending: false));
          context = 'all temperature sensors';
        }
      } else if (text.contains('plant') || text.contains('site') || text.contains('farm')) {
        final plants = await _supabase.from('Plant').select('id, name');
        final match = _findEntityByFuzzyName(text, plants);
        if (match != null) {
          alerts = List<Map<String, dynamic>>.from(
            await _supabase.from('Alert').select('*').eq('plantId', match['id']).order('triggeredAt', ascending: false));
          context = match['name'] ?? 'plant';
        } else {
          alerts = List<Map<String, dynamic>>.from(
            await _supabase.from('Alert').select('*').order('triggeredAt', ascending: false));
        }
      } else {
        // Try fuzzy match against all devices
        final allDevices = <Map<String, dynamic>>[];
        allDevices.addAll(List<Map<String, dynamic>>.from(await _supabase.from('Inverter').select('id, name')));
        allDevices.addAll(List<Map<String, dynamic>>.from(await _supabase.from('MFM').select('id, name')));
        allDevices.addAll(List<Map<String, dynamic>>.from(await _supabase.from('TemperatureDevice').select('id, name')));
        final match = _findEntityByFuzzyName(text, allDevices);
        if (match != null) {
          alerts = List<Map<String, dynamic>>.from(
            await _supabase.from('Alert').select('*').eq('deviceId', match['id']).order('triggeredAt', ascending: false));
          context = match['name'] ?? 'device';
        } else {
          alerts = List<Map<String, dynamic>>.from(
            await _supabase.from('Alert').select('*').order('triggeredAt', ascending: false));
        }
      }

      if (alerts.isEmpty) {
        return ChatMessage(text: 'No alerts found for **$context**.', isUser: false);
      }

      final active = alerts.where((a) => a['isActive'] == true).toList();
      final resolved = alerts.where((a) => a['isActive'] == false).toList();
      final critical = active.where((a) => a['severity'] == 'critical').length;
      final warning = active.where((a) => a['severity'] == 'warning').length;
      final info = active.where((a) => a['severity'] == 'info').length;

      final buf = StringBuffer();
      buf.writeln('**Alerts for $context**\n');
      buf.writeln('Active: **${active.length}** | Resolved: **${resolved.length}**');
      if (active.isNotEmpty) {
        buf.writeln('\u{1F534} Critical: **$critical** | \u{1F7E1} Warning: **$warning** | \u{1F535} Info: **$info**');
        buf.writeln('');
        for (final a in active.take(5)) {
          final sev = a['severity'] ?? 'info';
          final icon = sev == 'critical' ? '\u{1F534}' : sev == 'warning' ? '\u{1F7E1}' : '\u{1F535}';
          buf.writeln('$icon **${a['title']}**');
          buf.writeln('  ${a['deviceName']} \u2022 ${a['category']}');
        }
        if (active.length > 5) {
          buf.writeln('\n...and ${active.length - 5} more active alerts');
        }
      }

      return ChatMessage(text: buf.toString().trim(), isUser: false);
    } catch (e) {
      return ChatMessage(text: 'Could not fetch alerts: $e', isUser: false);
    }
  }

  static ChatMessage _handleHelp() {
    return ChatMessage(
      text: '''**Hi! I'm your Solar Dashboard Assistant.** Here's what I can do:

**Compare** — "Compare inverter 1 and inverter 3", "Compare all plants", "Compare MFM sensors"

**Historical Data** — "Show power for inverter 2 last 5 days", "Inverter 1 data for last week", "Plant energy this month"

**Trends** — "Power trend for inverter 1 last 10 days", "Temperature trend this week", "Is inverter 3 improving?"

**Percentage** — "What percentage of Goa plant power is from inverter 1?", "Show contribution of each plant"

**Averages** — "Average temperature", "Average power across inverters"

**Energy** — "Show energy production", "How much power today?", "Energy for inverter 1"

**Status** — "System status", "Which inverters are active?", "Are all devices working?"

**Rankings** — "Which inverter has the highest power?", "Lowest temperature sensor"

**Counts** — "How many inverters?", "Total number of sensors"

**Summary** — "Give me an overview", "Dashboard summary"

**Sensors** — "Show MFM readings last 3 days", "Temperature sensor data"

**Time Ranges** — "last 5 days", "this week", "last month", "yesterday", "past 2 weeks"

**Alerts** — "Show alerts for inverter 1", "Any alarms on MFM 2?", "Temperature sensor alerts", "Plant alerts for Goa"

**Navigate** — "Open inverter 1", "Go to Goa plant", "Show MFM 1 chart"

Just ask naturally — I'll figure out what you need!''',
      isUser: false,
    );
  }

  static Future<ChatMessage> _handleGeneral(String text) async {
    // Check for date range — might be a historical query without explicit device type
    final dateRange = _extractDateRange(text);
    if (dateRange != null) {
      return await _handleHistorical(text);
    }

    // Try to find anything relevant by name
    final plants = await _supabase.from('Plant').select('id, name');
    for (final p in plants) {
      if (text.contains((p['name'] ?? '').toString().toLowerCase())) {
        return await _comparePlants(text);
      }
    }

    final inverters = await _supabase.from('Inverter').select('id, name');
    for (final inv in inverters) {
      if (text.contains((inv['name'] ?? '').toString().toLowerCase())) {
        return await _compareInverters(text);
      }
    }

    // Check if there are number references that could be inverters
    final nums = RegExp(r'\b\d+\b').allMatches(text);
    if (nums.isNotEmpty && inverters.isNotEmpty) {
      final resolved = _resolveDevices(text, inverters);
      if (resolved.isNotEmpty) {
        return await _compareInverters(text);
      }
    }

    return ChatMessage(
      text: "I'm not sure what you're looking for. Try asking about **plants**, **inverters**, **sensors**, **energy**, or say **help** to see what I can do!\n\nYou can also ask about **historical data** (e.g., \"show inverter 1 data last 5 days\") or **compare** devices.",
      isUser: false,
    );
  }

  // ── Percentage Handler ──

  static Future<ChatMessage> _handlePercentage(String text) async {
    final plants = await _supabase.from('Plant').select('id, name');
    final inverters = await _supabase.from('Inverter').select('id, name, plantId');

    final mentionedPlant = _findEntityByFuzzyName(text, plants);
    final mentionedInverters = _resolveDevices(text, inverters);

    final metric = _detectMetric(text);
    final metricField = metric.field;
    final metricLabel = metric.label;

    // Case 1: Percentage of a plant's total by specific inverter(s)
    if (mentionedPlant != null && mentionedInverters.isNotEmpty) {
      final plantId = mentionedPlant['id'] as String;
      final plantInvs = inverters.where((i) => i['plantId'] == plantId).toList();
      double plantTotal = 0;
      final invValues = <String, double>{};
      for (final inv in plantInvs) {
        final latest = await _supabase
            .from('InverterData')
            .select()
            .eq('inverterId', inv['id'] as String)
            .order('timestamp', ascending: false)
            .limit(1);
        if (latest.isNotEmpty) {
          final val = (latest[0][metricField] as num?)?.toDouble() ?? 0;
          plantTotal += val;
          if (mentionedInverters.any((m) => m['id'] == inv['id'])) {
            invValues[inv['name'] ?? 'Unknown'] = val;
          }
        }
      }
      if (plantTotal > 0 && invValues.isNotEmpty) {
        final buf = StringBuffer();
        buf.writeln('**$metricLabel Contribution to ${mentionedPlant['name']}**\n');
        double invSum = 0;
        for (final e in invValues.entries) {
          final pct = (e.value / plantTotal * 100);
          invSum += e.value;
          buf.writeln('**${e.key}**: ${e.value.toStringAsFixed(1)} kWh — **${pct.toStringAsFixed(1)}%**');
        }
        buf.writeln('\nPlant Total: ${plantTotal.toStringAsFixed(1)} kWh');
        if (invValues.length == 1) {
          final pct = (invSum / plantTotal * 100).toStringAsFixed(1);
          buf.writeln('\n**${invValues.keys.first}** contributes **$pct%** of ${mentionedPlant['name']}\'s $metricLabel.');
        }
        return ChatMessage(text: buf.toString().trim(), isUser: false);
      }
    }

    // Case 2: Percentage of total system by mentioned inverter(s)
    if (mentionedInverters.isNotEmpty) {
      double systemTotal = 0;
      final invValues = <String, double>{};
      for (final inv in inverters) {
        final latest = await _supabase
            .from('InverterData')
            .select()
            .eq('inverterId', inv['id'] as String)
            .order('timestamp', ascending: false)
            .limit(1);
        if (latest.isNotEmpty) {
          final val = (latest[0][metricField] as num?)?.toDouble() ?? 0;
          systemTotal += val;
          if (mentionedInverters.any((m) => m['id'] == inv['id'])) {
            invValues[inv['name'] ?? 'Unknown'] = val;
          }
        }
      }
      if (systemTotal > 0 && invValues.isNotEmpty) {
        final buf = StringBuffer();
        buf.writeln('**$metricLabel Contribution (System-wide)**\n');
        for (final e in invValues.entries) {
          final pct = (e.value / systemTotal * 100);
          buf.writeln('**${e.key}**: ${e.value.toStringAsFixed(1)} kWh — **${pct.toStringAsFixed(1)}%** of system total');
        }
        buf.writeln('\nSystem Total: ${systemTotal.toStringAsFixed(1)} kWh');
        return ChatMessage(text: buf.toString().trim(), isUser: false);
      }
    }

    // Case 3: Each plant's contribution to total
    {
      double systemTotal = 0;
      final plantEnergy = <String, double>{};
      for (final plant in plants) {
        final pid = plant['id'] as String;
        final plantInvs = inverters.where((i) => i['plantId'] == pid).toList();
        double pTotal = 0;
        for (final inv in plantInvs) {
          final latest = await _supabase
              .from('InverterData')
              .select()
              .eq('inverterId', inv['id'] as String)
              .order('timestamp', ascending: false)
              .limit(1);
          if (latest.isNotEmpty) {
            pTotal += (latest[0][metricField] as num?)?.toDouble() ?? 0;
          }
        }
        plantEnergy[plant['name'] ?? 'Unknown'] = pTotal;
        systemTotal += pTotal;
      }
      if (systemTotal > 0) {
        final buf = StringBuffer();
        buf.writeln('**Plant $metricLabel Breakdown**\n');
        for (final e in plantEnergy.entries) {
          final pct = (e.value / systemTotal * 100);
          buf.writeln('**${e.key}**: ${e.value.toStringAsFixed(1)} kWh — **${pct.toStringAsFixed(1)}%**');
        }
        buf.writeln('\nSystem Total: ${systemTotal.toStringAsFixed(1)} kWh');
        return ChatMessage(text: buf.toString().trim(), isUser: false);
      }
    }

    return ChatMessage(
      text: 'I couldn\'t find enough data to calculate percentages. Try specifying a plant and inverter, e.g. "What percentage of Goa plant power is from inverter 1?"',
      isUser: false,
    );
  }

  // ── Average Handler ──

  static Future<ChatMessage> _handleAverage(String text) async {
    final dateRange = _extractDateRange(text);

    if (text.contains('temperature') || text.contains('temp')) {
      final temps = await _supabase.from('TemperatureDevice').select('id, name');
      double sum = 0;
      int count = 0;
      final buf = StringBuffer();
      buf.writeln('**Average Temperature Readings**\n');

      for (final t in temps) {
        if (dateRange != null) {
          final data = await _fetchTempDataRange(t['id'] as String, dateRange.start, dateRange.end);
          if (data.isNotEmpty) {
            final avg = data.fold<double>(0, (s, r) => s + ((r['value'] as num?)?.toDouble() ?? 0)) / data.length;
            sum += avg;
            count++;
            buf.writeln('**${t['name']}**: ${avg.toStringAsFixed(1)} °C (avg over ${dateRange.label})');
          }
        } else {
          final latest = await _supabase
              .from('TemperatureData')
              .select()
              .eq('deviceId', t['id'] as String)
              .order('timestamp', ascending: false)
              .limit(1);
          if (latest.isNotEmpty) {
            final val = (latest[0]['value'] as num?)?.toDouble() ?? 0;
            sum += val;
            count++;
            buf.writeln('**${t['name']}**: ${val.toStringAsFixed(1)} °C');
          }
        }
      }
      if (count > 0) {
        buf.writeln('\n**Average: ${(sum / count).toStringAsFixed(1)} °C** across $count sensors');
      }
      return ChatMessage(text: buf.toString().trim(), isUser: false);
    }

    // Default: average power across inverters
    final inverters = await _supabase.from('Inverter').select('id, name');
    final metric = _detectMetric(text);

    double sum = 0;
    int count = 0;
    for (final inv in inverters) {
      if (dateRange != null) {
        final data = await _fetchInverterDataRange(inv['id'] as String, dateRange.start, dateRange.end);
        if (data.isNotEmpty) {
          final avg = data.fold<double>(0, (s, r) => s + ((r[metric.field] as num?)?.toDouble() ?? 0)) / data.length;
          sum += avg;
          count++;
        }
      } else {
        final d = await _getLatestInverterData(inv['id'] as String);
        if (d != null) {
          sum += (d[metric.field] as num?)?.toDouble() ?? 0;
          count++;
        }
      }
    }

    if (count > 0) {
      final periodLabel = dateRange != null ? ' (${dateRange.label})' : '';
      return ChatMessage(
        text: '**Average ${metric.label}$periodLabel** across $count inverters: **${(sum / count).toStringAsFixed(1)}**\n\nTotal: ${sum.toStringAsFixed(1)}',
        isUser: false,
      );
    }
    return ChatMessage(text: 'No inverter data available to calculate average.', isUser: false);
  }

  // ── Helpers ──

  static String _fmtNum(dynamic value) {
    if (value == null) return '0';
    return (value as num).toDouble().toStringAsFixed(1);
  }
}

class _DailySummary {
  final String date;
  final double maxPower;
  final double avgPower;
  final double todayEnergy;
  final int dataPoints;

  _DailySummary({
    required this.date,
    required this.maxPower,
    required this.avgPower,
    required this.todayEnergy,
    required this.dataPoints,
  });
}
