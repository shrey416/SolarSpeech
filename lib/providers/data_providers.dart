import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../core/mock/synthetic_data.dart';

final supabase = Supabase.instance.client;

final plantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (AppConfig.useSyntheticData) return SyntheticData.plants;
  final res = await supabase.from('plants').select('*');
  return List<Map<String, dynamic>>.from(res);
});

final invertersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, plantId) async {
  if (AppConfig.useSyntheticData) {
    return SyntheticData.inverters.where((i) => i['plantId'] == plantId).toList();
  }
  final res = await supabase.from('devices').select('*').eq('type', 'INVERTER').eq('plantId', plantId);
  return List<Map<String, dynamic>>.from(res);
});

final slmsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (AppConfig.useSyntheticData) return SyntheticData.slmsDevices;
  final res = await supabase.from('devices').select('*').eq('type', 'SLMS');
  return List<Map<String, dynamic>>.from(res);
});

final alertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (AppConfig.useSyntheticData) return SyntheticData.alerts;
  final res = await supabase.from('alerts').select('*, plants(name), devices(name)');
  return List<Map<String, dynamic>>.from(res);
});