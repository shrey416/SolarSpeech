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

  /// Process a user message and return a bot response.
  static Future<ChatMessage> processMessage(String userInput) async {
    final text = userInput.toLowerCase().trim();
    if (text.isEmpty) {
      return ChatMessage(text: 'Please ask me something!', isUser: false);
    }

    try {
      // Detect intent
      if (_isCompareIntent(text)) return await _handleCompare(text);
      if (_isSummaryIntent(text)) return await _handleSummary(text);
      if (_isTopBottomIntent(text)) return await _handleTopBottom(text);
      if (_isStatusIntent(text)) return await _handleStatus(text);
      if (_isCountIntent(text)) return await _handleCount(text);
      if (_isEnergyIntent(text)) return await _handleEnergy(text);
      if (_isSensorIntent(text)) return await _handleSensorQuery(text);
      if (_isInverterIntent(text)) return await _handleInverterQuery(text);
      if (_isPlantIntent(text)) return await _handlePlantQuery(text);
      if (_isHelpIntent(text)) return _handleHelp();

      // Fallback: try a general search
      return await _handleGeneral(text);
    } catch (e) {
      return ChatMessage(
        text: 'Sorry, I ran into an issue fetching that data. Please try again.',
        isUser: false,
      );
    }
  }

  // ── Intent Detection ──

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

  // ── Intent Handlers ──

  static Future<ChatMessage> _handleCompare(String text) async {
    // Detect what's being compared
    if (text.contains('plant') || text.contains('site')) {
      return await _comparePlants(text);
    }
    if (text.contains('inverter')) {
      return await _compareInverters(text);
    }
    if (text.contains('sensor') || text.contains('mfm') || text.contains('temperature')) {
      return await _compareSensors(text);
    }
    // Default: compare plants
    return await _comparePlants(text);
  }

  static Future<ChatMessage> _comparePlants(String text) async {
    final plants = await _supabase.from('Plant').select('id, name');
    if (plants.isEmpty) {
      return ChatMessage(text: 'No plants found in the system.', isUser: false);
    }

    // Get energy data for each plant
    final buffer = StringBuffer();
    buffer.writeln('**Plant Comparison**\n');

    final inverters = await _supabase.from('Inverter').select('id, name, plantId');
    final plantInvCount = <String, int>{};
    for (final inv in inverters) {
      final pid = inv['plantId']?.toString() ?? '';
      plantInvCount[pid] = (plantInvCount[pid] ?? 0) + 1;
    }

    // Get latest data for each inverter per plant
    final plantEnergy = <String, double>{};
    final plantTodayEnergy = <String, double>{};
    for (final inv in inverters) {
      final invId = inv['id'] as String;
      final pid = inv['plantId']?.toString() ?? '';
      try {
        final latest = await _supabase
            .from('InverterData')
            .select('eTotalPower, eTodayPower, activePower')
            .eq('inverterId', invId)
            .order('timestamp', ascending: false)
            .limit(1);
        if (latest.isNotEmpty) {
          final eTotal = (latest[0]['eTotalPower'] as num?)?.toDouble() ?? 0;
          final eToday = (latest[0]['eTodayPower'] as num?)?.toDouble() ?? 0;
          plantEnergy[pid] = (plantEnergy[pid] ?? 0) + eTotal;
          plantTodayEnergy[pid] = (plantTodayEnergy[pid] ?? 0) + eToday;
        }
      } catch (_) {}
    }

    for (final plant in plants) {
      final pid = plant['id'] as String;
      final name = plant['name'] ?? 'Unknown';
      final invCount = plantInvCount[pid] ?? 0;
      final totalE = plantEnergy[pid] ?? 0;
      final todayE = plantTodayEnergy[pid] ?? 0;
      buffer.writeln('**$name**');
      buffer.writeln('  Inverters: $invCount');
      buffer.writeln('  Total Energy: ${totalE.toStringAsFixed(1)} kWh');
      buffer.writeln('  Today Energy: ${todayE.toStringAsFixed(1)} kWh');
      buffer.writeln('');
    }

    // Determine best performer
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

    // Extract specific inverter names/numbers from text
    final mentioned = _extractMentionedNames(text, inverters);
    final toCompare = mentioned.isNotEmpty ? mentioned : inverters.take(5).toList();

    final buffer = StringBuffer();
    buffer.writeln('**Inverter Comparison**\n');

    for (final inv in toCompare) {
      final invId = inv['id'] as String;
      final name = inv['name'] ?? 'Unknown';
      try {
        final latest = await _supabase
            .from('InverterData')
            .select('activePower, eTodayPower, eTotalPower, totalPvVoltage, totalPvCurrent')
            .eq('inverterId', invId)
            .order('timestamp', ascending: false)
            .limit(1);
        if (latest.isNotEmpty) {
          final d = latest[0];
          buffer.writeln('**$name**');
          buffer.writeln('  Active Power: ${_fmtNum(d['activePower'])} kW');
          buffer.writeln('  Today Energy: ${_fmtNum(d['eTodayPower'])} kWh');
          buffer.writeln('  Total Energy: ${_fmtNum(d['eTotalPower'])} kWh');
          buffer.writeln('  PV Voltage: ${_fmtNum(d['totalPvVoltage'])} V');
          buffer.writeln('  PV Current: ${_fmtNum(d['totalPvCurrent'])} A');
          buffer.writeln('');
        } else {
          buffer.writeln('**$name**: No data available\n');
        }
      } catch (_) {
        buffer.writeln('**$name**: Error fetching data\n');
      }
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _compareSensors(String text) async {
    final isMfm = text.contains('mfm') || text.contains('meter');
    final isTemp = text.contains('temperature') || text.contains('thermal');

    if (isMfm || (!isTemp)) {
      return await _compareMfms();
    }
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
      try {
        final latest = await _supabase
            .from('MFMData')
            .select('totalPower, l1nVoltage, l2nVoltage, l3nVoltage, frequency')
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
      } catch (_) {}
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
      try {
        final latest = await _supabase
            .from('TemperatureData')
            .select('value')
            .eq('deviceId', tempId)
            .order('timestamp', ascending: false)
            .limit(1);
        if (latest.isNotEmpty) {
          buffer.writeln('**$name**: ${_fmtNum(latest[0]['value'])} °C');
        }
      } catch (_) {}
    }

    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleSummary(String text) async {
    final buffer = StringBuffer();
    buffer.writeln('**System Overview**\n');

    // Plants
    final plants = await _supabase.from('Plant').select('id, name');
    buffer.writeln('**Plants:** ${plants.length}');

    // Inverters
    final inverters = await _supabase.from('Inverter').select('id');
    buffer.writeln('**Inverters:** ${inverters.length}');

    // Sensors
    final mfms = await _supabase.from('MFM').select('id');
    final temps = await _supabase.from('TemperatureDevice').select('id');
    final wfms = await _supabase.from('WFM').select('id');
    buffer.writeln('**Sensors:** ${mfms.length} MFM, ${temps.length} Temperature, ${wfms.length} WMS');

    // Energy totals
    double totalEnergy = 0, todayEnergy = 0, totalCapacity = 0;
    for (final inv in inverters) {
      try {
        final latest = await _supabase
            .from('InverterData')
            .select('eTotalPower, eTodayPower, activePower')
            .eq('inverterId', inv['id'] as String)
            .order('timestamp', ascending: false)
            .limit(1);
        if (latest.isNotEmpty) {
          totalEnergy += (latest[0]['eTotalPower'] as num?)?.toDouble() ?? 0;
          todayEnergy += (latest[0]['eTodayPower'] as num?)?.toDouble() ?? 0;
          totalCapacity += (latest[0]['activePower'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {}
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
        try {
          final latest = await _supabase
              .from('TemperatureData')
              .select('value')
              .eq('deviceId', t['id'] as String)
              .order('timestamp', ascending: false)
              .limit(1);
          if (latest.isNotEmpty) {
            readings[t['name'] ?? 'Unknown'] = (latest[0]['value'] as num?)?.toDouble() ?? 0;
          }
        } catch (_) {}
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
    final readings = <String, double>{};
    for (final inv in inverters) {
      try {
        final latest = await _supabase
            .from('InverterData')
            .select('activePower')
            .eq('inverterId', inv['id'] as String)
            .order('timestamp', ascending: false)
            .limit(1);
        if (latest.isNotEmpty) {
          readings[inv['name'] ?? 'Unknown'] = (latest[0]['activePower'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {}
    }
    if (readings.isEmpty) return ChatMessage(text: 'No inverter data available.', isUser: false);

    final sorted = readings.entries.toList()
      ..sort((a, b) => isTop ? b.value.compareTo(a.value) : a.value.compareTo(b.value));
    final label = isTop ? 'Highest' : 'Lowest';
    final top3 = sorted.take(3);
    final buffer = StringBuffer();
    buffer.writeln('**$label Active Power:**\n');
    int rank = 1;
    for (final entry in top3) {
      buffer.writeln('$rank. **${entry.key}**: ${entry.value.toStringAsFixed(1)} kW');
      rank++;
    }
    return ChatMessage(text: buffer.toString().trim(), isUser: false);
  }

  static Future<ChatMessage> _handleStatus(String text) async {
    final inverters = await _supabase.from('Inverter').select('id, name');
    int active = 0, inactive = 0;
    final inactiveNames = <String>[];

    for (final inv in inverters) {
      try {
        final latest = await _supabase
            .from('InverterData')
            .select('activePower, timestamp')
            .eq('inverterId', inv['id'] as String)
            .order('timestamp', ascending: false)
            .limit(1);
        if (latest.isNotEmpty) {
          final power = (latest[0]['activePower'] as num?)?.toDouble() ?? 0;
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
      } catch (_) {
        inactive++;
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

    // Count everything
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

    // Check if asking about specific inverter
    final mentioned = _extractMentionedNames(text, inverters);
    final targets = mentioned.isNotEmpty ? mentioned : inverters;

    for (final inv in targets) {
      try {
        final latest = await _supabase
            .from('InverterData')
            .select('eTotalPower, eTodayPower, activePower')
            .eq('inverterId', inv['id'] as String)
            .order('timestamp', ascending: false)
            .limit(1);
        if (latest.isNotEmpty) {
          final d = latest[0];
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
      } catch (_) {}
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
    if (text.contains('mfm') || text.contains('meter')) {
      return await _compareMfms();
    }
    if (text.contains('temperature') || text.contains('thermal')) {
      return await _compareTemps();
    }
    // General sensor overview
    final mfms = await _supabase.from('MFM').select('id');
    final temps = await _supabase.from('TemperatureDevice').select('id');
    final wfms = await _supabase.from('WFM').select('id');
    return ChatMessage(
      text: '**Sensors:** ${mfms.length} MFM, ${temps.length} Temperature, ${wfms.length} WMS devices.\n\nAsk me to compare specific sensors or show their latest readings!',
      isUser: false,
    );
  }

  static Future<ChatMessage> _handleInverterQuery(String text) async {
    return await _compareInverters(text);
  }

  static Future<ChatMessage> _handlePlantQuery(String text) async {
    return await _comparePlants(text);
  }

  static ChatMessage _handleHelp() {
    return ChatMessage(
      text: '''**Hi! I'm your Solar Dashboard Assistant.** Here's what I can do:

**Compare** — "Compare all plants", "Compare inverters", "Compare MFM sensors"

**Energy** — "Show energy production", "How much power today?", "Energy for inverter 1"

**Status** — "System status", "Which inverters are active?", "Are all devices working?"

**Rankings** — "Which inverter has the highest power?", "Lowest temperature sensor"

**Counts** — "How many inverters?", "Total number of sensors"

**Summary** — "Give me an overview", "Dashboard summary"

**Sensors** — "Show MFM readings", "Temperature sensor data"

Just ask naturally — I'll figure out what you need!''',
      isUser: false,
    );
  }

  static Future<ChatMessage> _handleGeneral(String text) async {
    // Try to find anything relevant
    // Check if it matches a device name
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

    return ChatMessage(
      text: "I'm not sure what you're looking for. Try asking about **plants**, **inverters**, **sensors**, **energy**, or say **help** to see what I can do!",
      isUser: false,
    );
  }

  // ── Helpers ──

  static String _fmtNum(dynamic value) {
    if (value == null) return '0';
    return (value as num).toDouble().toStringAsFixed(1);
  }

  static List<Map<String, dynamic>> _extractMentionedNames(
      String text, List<dynamic> items) {
    final results = <Map<String, dynamic>>[];
    for (final item in items) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      if (name.isNotEmpty && text.contains(name)) {
        results.add(Map<String, dynamic>.from(item));
      }
    }
    // Also check for numeric references like "inverter 1", "inverter 2"
    final numMatch = RegExp(r'\b(\d+)\b').allMatches(text);
    for (final m in numMatch) {
      final num = int.tryParse(m.group(1)!) ?? 0;
      if (num >= 1 && num <= items.length) {
        final item = Map<String, dynamic>.from(items[num - 1]);
        if (!results.any((r) => r['id'] == item['id'])) {
          results.add(item);
        }
      }
    }
    return results;
  }
}
