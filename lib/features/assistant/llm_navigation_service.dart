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
    r'see|look|let|page|screen|tab|section)\b',
    caseSensitive: false,
  );

  // ── Tab / page keywords → route (no ID needed) ──
  static final List<_TabIntent> _tabIntents = [
    _TabIntent('/dashboard',  ['dashboard', 'home', 'main', 'overview', 'summary', 'start']),
    _TabIntent('/my-plants',  ['my plants', 'plants list', 'plant list', 'all plants', 'my plant']),
    _TabIntent('/inverters',  ['inverters list', 'all inverters', 'inverter list', 'inverters']),
    _TabIntent('/slms',       ['slms', 'string level', 'string monitoring', 'strings', 'slm']),
    _TabIntent('/sensors',    ['sensors', 'sensor list', 'sensor', 'all sensors', 'mfm', 'temperature sensor', 'temp sensor']),
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

  /// Main entry point — returns a route string or null.
  static Future<String?> getRouteFromText(String userInput) async {
    if (userInput.trim().isEmpty) return null;
    final text = userInput.toLowerCase().trim();

    // ────────────────────────────────────────────
    // 1. Exact tab / section matching (fastest)
    // ────────────────────────────────────────────
    final tabRoute = _matchTab(text);
    if (tabRoute != null) return tabRoute;

    // ────────────────────────────────────────────
    // 2. Device-specific navigation (needs DB)
    // ────────────────────────────────────────────
    final id = _extractIdentifier(text);

    // Inverter
    if (_inverterKw.hasMatch(text)) {
      return _resolveInverter(id, text);
    }

    // Plant
    if (_plantKw.hasMatch(text)) {
      return _resolvePlant(id, text);
    }

    // SLMS / String data
    if (_slmsKw.hasMatch(text)) {
      return _resolveSlms(id, text);
    }

    // MFM
    if (_mfmKw.hasMatch(text)) {
      return _resolveMfm(id, text);
    }

    // Temperature device
    if (_tempKw.hasMatch(text)) {
      return _resolveTemp(id, text);
    }

    // Generic sensor (could be MFM or temp)
    if (_sensorKw.hasMatch(text)) {
      return _resolveSensor(id, text);
    }

    // ────────────────────────────────────────────
    // 3. Fuzzy fallback — match against everything
    // ────────────────────────────────────────────
    return _fuzzyFallback(text);
  }

  // ══════════════════════════════════════════════
  //  Tab matching
  // ══════════════════════════════════════════════
  static String? _matchTab(String text) {
    // Strip filler to get the core intent
    final core = text.replaceAll(_filler, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

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
            return tab.route;
          }
        }
      }
    }
    return null;
  }

  // ══════════════════════════════════════════════
  //  Identifier extraction (number or remaining name)
  // ══════════════════════════════════════════════
  static String? _extractIdentifier(String text) {
    // Try to find a digit
    final digitMatch = RegExp(r'\b(\d+)\b').firstMatch(text);
    if (digitMatch != null) return digitMatch.group(1);

    // Try word numbers — scan every word
    final words = text.split(RegExp(r'\s+'));
    for (final w in words) {
      if (_wordToNumber.containsKey(w)) {
        // Make sure it's not a filler homophone in context
        // "go to inverter two" — "to" is filler, "two" is number
        // We pick the LAST matching number-word as the identifier
      }
    }
    // Pick the last number-word that appears after a device keyword
    for (int i = words.length - 1; i >= 0; i--) {
      if (_wordToNumber.containsKey(words[i])) {
        // Avoid picking filler homophones if they appear BEFORE a device keyword
        final num = _wordToNumber[words[i]]!;
        return num.toString();
      }
    }

    // Try extracting a name after stripping filler + device keywords
    final stripped = text
        .replaceAll(_filler, ' ')
        .replaceAll(_inverterKw, ' ')
        .replaceAll(_plantKw, ' ')
        .replaceAll(_slmsKw, ' ')
        .replaceAll(_mfmKw, ' ')
        .replaceAll(_tempKw, ' ')
        .replaceAll(_sensorKw, ' ')
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
      final mfms = await _supabase
          .from('MFM')
          .select('id, name, Sensors(plantId)');
      final match = _findBestMatch(mfms, id, text);
      if (match != null) {
        final plantId = match['Sensors']?['plantId']?.toString() ?? '';
        if (plantId.isNotEmpty) {
          return '/plants/$plantId/mfm/${match['id']}';
        }
      }
      return '/sensors';
    } catch (_) {
      return '/sensors';
    }
  }

  static Future<String?> _resolveTemp(String? id, String text) async {
    try {
      final temps = await _supabase
          .from('TemperatureDevice')
          .select('id, name, Sensors(plantId)');
      final match = _findBestMatch(temps, id, text);
      if (match != null) {
        final plantId = match['Sensors']?['plantId']?.toString() ?? '';
        if (plantId.isNotEmpty) {
          return '/plants/$plantId/temp/${match['id']}';
        }
      }
      return '/sensors';
    } catch (_) {
      return '/sensors';
    }
  }

  static Future<String?> _resolveSensor(String? id, String text) async {
    // Try MFM first, then temperature
    final mfmRoute = await _resolveMfm(id, text);
    if (mfmRoute != null && mfmRoute != '/sensors') return mfmRoute;
    final tempRoute = await _resolveTemp(id, text);
    if (tempRoute != null && tempRoute != '/sensors') return tempRoute;
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
      final mfms = await _supabase.from('MFM').select('id, name, Sensors(plantId)');
      for (final m in mfms) {
        final name = (m['name'] ?? '').toString().toLowerCase();
        if (_fuzzyScore(core, name) >= 0.5 || name.contains(core) || core.contains(name)) {
          final plantId = m['Sensors']?['plantId']?.toString() ?? '';
          if (plantId.isNotEmpty) {
            return '/plants/$plantId/mfm/${m['id']}';
          }
        }
      }

      // Search temp devices
      final temps = await _supabase.from('TemperatureDevice').select('id, name, Sensors(plantId)');
      for (final t in temps) {
        final name = (t['name'] ?? '').toString().toLowerCase();
        if (_fuzzyScore(core, name) >= 0.5 || name.contains(core) || core.contains(name)) {
          final plantId = t['Sensors']?['plantId']?.toString() ?? '';
          if (plantId.isNotEmpty) {
            return '/plants/$plantId/temp/${t['id']}';
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
      final idBoundary = RegExp(r'(^|\D)' + RegExp.escape(idLower) + r'($|\D)');
      for (final row in rows) {
        final name = (row['name'] ?? '').toString().toLowerCase();
        if (idBoundary.hasMatch(name)) {
          return Map<String, dynamic>.from(row);
        }
      }

      // Try by 1-based index
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