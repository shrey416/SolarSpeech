import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// ── Date selection ──
final selectedDateProvider = StateProvider<DateTime>(
  (ref) => DateTime(2026, 3, 5),
);

// ── Search / filter state ──
final plantSearchProvider = StateProvider<String>((ref) => '');
final deviceSearchProvider = StateProvider<String>((ref) => '');
final slmsSearchProvider = StateProvider<String>((ref) => '');
final sensorSearchProvider = StateProvider<String>((ref) => '');

// ── Plants ──
final plantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await supabase.from('Plant').select();
  return List<Map<String, dynamic>>.from(res);
});

final plantByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final res = await supabase.from('Plant').select().eq('id', id).maybeSingle();
  return res;
});

// ── Inverters ──
final allInvertersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await supabase.from('Inverter').select('*, Plant(name)');
  return List<Map<String, dynamic>>.from(res);
});

final invertersByPlantProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, plantId) async {
  final res =
      await supabase.from('Inverter').select().eq('plantId', plantId);
  return List<Map<String, dynamic>>.from(res);
});

final inverterByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final res = await supabase
      .from('Inverter')
      .select('*, Plant(*)')
      .eq('id', id)
      .maybeSingle();
  return res;
});

// ── Inverter Data ──
final inverterDataByDateProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    ({String inverterId, DateTime date})>((ref, params) async {
  final start =
      DateTime(params.date.year, params.date.month, params.date.day);
  final end = start.add(const Duration(days: 1));
  final res = await supabase
      .from('InverterData')
      .select()
      .eq('inverterId', params.inverterId)
      .gte('timestamp', start.toIso8601String())
      .lt('timestamp', end.toIso8601String())
      .order('timestamp');
  return List<Map<String, dynamic>>.from(res);
});

final latestInverterDataProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, inverterId) async {
  final res = await supabase
      .from('InverterData')
      .select()
      .eq('inverterId', inverterId)
      .order('timestamp', ascending: false)
      .limit(1)
      .maybeSingle();
  return res;
});

// ── Sensors ──
final allSensorsWithPlantProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await supabase.from('Sensors').select('*, Plant(*)');
  return List<Map<String, dynamic>>.from(res);
});

final sensorsByPlantProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, plantId) async {
  final res = await supabase
      .from('Sensors')
      .select()
      .eq('plantId', plantId)
      .maybeSingle();
  return res;
});

// ── MFM ──
final allMfmsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res =
      await supabase.from('MFM').select('*, Sensors(plantId, Plant(name))');
  return List<Map<String, dynamic>>.from(res);
});

final mfmsBySensorsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, sensorsId) async {
  final res =
      await supabase.from('MFM').select().eq('sensorsId', sensorsId);
  return List<Map<String, dynamic>>.from(res);
});

final latestMfmDataProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, mfmId) async {
  final res = await supabase
      .from('MFMData')
      .select()
      .eq('mfmId', mfmId)
      .order('timestamp', ascending: false)
      .limit(1)
      .maybeSingle();
  return res;
});

// ── WFM ──
final allWfmsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res =
      await supabase.from('WFM').select('*, Sensors(plantId, Plant(name))');
  return List<Map<String, dynamic>>.from(res);
});

final wfmsBySensorsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, sensorsId) async {
  final res =
      await supabase.from('WFM').select().eq('sensorsId', sensorsId);
  return List<Map<String, dynamic>>.from(res);
});

// ── Temperature Devices ──
final allTempDevicesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await supabase
      .from('TemperatureDevice')
      .select('*, Sensors(plantId, Plant(name))');
  return List<Map<String, dynamic>>.from(res);
});

final tempDevicesBySensorsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, sensorsId) async {
  final res = await supabase
      .from('TemperatureDevice')
      .select()
      .eq('sensorsId', sensorsId);
  return List<Map<String, dynamic>>.from(res);
});

final latestTempDataProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, deviceId) async {
  final res = await supabase
      .from('TemperatureData')
      .select()
      .eq('deviceId', deviceId)
      .order('timestamp', ascending: false)
      .limit(1)
      .maybeSingle();
  return res;
});

// ── Dashboard aggregation ──
final dashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final plants = await ref.watch(plantsProvider.future);
  double totalEnergy = 0, todayEnergy = 0, totalCapacity = 0, co2 = 0;
  for (final p in plants) {
    totalEnergy += (p['totalEnergy'] as num?)?.toDouble() ?? 0;
    todayEnergy += (p['todayEnergy'] as num?)?.toDouble() ?? 0;
    totalCapacity += (p['capacityKWp'] as num?)?.toDouble() ?? 0;
    co2 += (p['co2Reduced'] as num?)?.toDouble() ?? 0;
  }
  return {
    'totalEnergy': totalEnergy,
    'todayEnergy': todayEnergy,
    'totalCapacity': totalCapacity,
    'co2Reduced': co2,
    'plantCount': plants.length,
  };
});

final inverterCountByPlantProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final inverters = await ref.watch(allInvertersProvider.future);
  final counts = <String, int>{};
  for (final inv in inverters) {
    final plantName =
        inv['Plant']?['name'] ?? inv['plantId'] ?? 'Unknown';
    counts[plantName] = (counts[plantName] ?? 0) + 1;
  }
  return counts;
});

// legacy alias so alert screen keeps compiling
final alertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return [];
});