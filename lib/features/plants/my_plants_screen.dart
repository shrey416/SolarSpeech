import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';

class MyPlantsScreen extends ConsumerWidget {
  const MyPlantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantsAsync = ref.watch(plantsProvider);
    final search = ref.watch(plantSearchProvider);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BreadcrumbBar(items: [
            BreadcrumbItem('Dashboard', route: '/dashboard'),
            BreadcrumbItem('My Plants'),
          ]),
          const SizedBox(height: 4),
          // Header
          Row(
            children: [
              plantsAsync.when(
                loading: () => const Text('Plants',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                error: (_, __) => const Text('Plants',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                data: (plants) => Text('Plants(${plants.length})',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                height: 38,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search Plants...',
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) =>
                      ref.read(plantSearchProvider.notifier).set(v),
                ),
              ),
              const SizedBox(width: 12),
              // View toggle (visual only)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.grid_view, size: 18),
                      onPressed: () {},
                      color: AppColors.primary,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    IconButton(
                      icon: const Icon(Icons.view_list, size: 18),
                      onPressed: () {},
                      color: AppColors.textSecondary,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Plant cards
          plantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (plants) {
              final filtered = search.isEmpty
                  ? plants
                  : plants
                      .where((p) => (p['name'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(search.toLowerCase()))
                      .toList();
              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                      child: Text('No plants found',
                          style:
                              TextStyle(color: AppColors.textSecondary))),
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: filtered
                    .map((p) => _PlantCard(plant: p))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlantCard extends ConsumerWidget {
  final Map<String, dynamic> plant;
  const _PlantCard({required this.plant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantId = plant['id'] as String;
    final name = plant['name']?.toString() ?? 'Unknown';
    final todayE =
        (plant['todayEnergy'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final totalE =
        (plant['totalEnergy'] as num?)?.toStringAsFixed(2) ?? '0.00';

    // Count devices: inverters + sensors devices
    final invertersAsync = ref.watch(invertersByPlantProvider(plantId));
    final sensorsAsync = ref.watch(sensorsByPlantProvider(plantId));

    int deviceCount = 0;
    invertersAsync.whenData((inv) => deviceCount += inv.length);
    sensorsAsync.whenData((s) {
      if (s != null) {
        final sid = s['id'] as String;
        ref.watch(mfmsBySensorsProvider(sid)).whenData((l) => deviceCount += l.length);
        ref.watch(wfmsBySensorsProvider(sid)).whenData((l) => deviceCount += l.length);
        ref.watch(tempDevicesBySensorsProvider(sid)).whenData((l) => deviceCount += l.length);
      }
    });

    // Last updated from latest inverter data
    final latestTs = plant['updatedAt'] ?? plant['createdAt'];
    final dt = latestTs != null ? DateTime.tryParse(latestTs.toString()) : null;
    final lastUpdated = dt != null
        ? 'Mar ${dt.day}, ${DateFormat('h:mm a').format(dt)} Last Updated'
        : 'Mar 6, 3:03 PM Last Updated';

    return SizedBox(
      width: 380,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/plants/$plantId'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Active badge
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                          const SizedBox(height: 2),
                          Text(lastUpdated,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.active.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle,
                              color: AppColors.active, size: 8),
                          const SizedBox(width: 4),
                          const Text('Active',
                              style: TextStyle(
                                  color: AppColors.active,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats row: Today | Total | Devices
                Row(
                  children: [
                    _StatColumn('Today', '$todayE KWH'),
                    const SizedBox(width: 24),
                    _StatColumn('Total', '$totalE KWH'),
                    const SizedBox(width: 24),
                    _StatColumn('Devices', '$deviceCount'),
                  ],
                ),
                const SizedBox(height: 16),

                // Mini chart
                SizedBox(
                  height: 100,
                  child: _MiniPlantChart(plantId: plantId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
      ],
    );
  }
}

/// Mini line chart showing aggregated inverter active power for the plant
class _MiniPlantChart extends ConsumerWidget {
  final String plantId;
  const _MiniPlantChart({required this.plantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invertersAsync = ref.watch(invertersByPlantProvider(plantId));
    return invertersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (inverters) {
        if (inverters.isEmpty) {
          return const Center(
              child: Text('No data',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)));
        }
        // Use first inverter's data as representative chart
        final firstId = inverters.first['id'] as String;
        final dataAsync = ref.watch(inverterDataByDateProvider(
            (inverterId: firstId, date: DateTime(2026, 3, 5))));
        return dataAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => const SizedBox.shrink(),
          data: (records) {
            if (records.isEmpty) {
              return const Center(
                  child: Text('No data',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)));
            }
            // Compute active power spots
            final spots = <FlSpot>[];
            for (int i = 0; i < records.length; i++) {
              final r = records[i];
              final ap = (r['activePower'] as num?)?.toDouble();
              if (ap != null) {
                spots.add(FlSpot(i.toDouble(), ap));
              } else {
                double power = 0;
                for (int ch = 1; ch <= 8; ch++) {
                  final v =
                      (r['dcVoltage$ch'] as num?)?.toDouble() ?? 0;
                  final c =
                      (r['dcCurrent$ch'] as num?)?.toDouble() ?? 0;
                  power += v * c;
                }
                spots.add(FlSpot(i.toDouble(), power));
              }
            }
            return LineChart(LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1000,
                getDrawingHorizontalLine: (v) =>
                    FlLine(color: AppColors.border, strokeWidth: 0.5),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval:
                        (records.length / 6).ceilToDouble().clamp(1, 100),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= records.length) {
                        return const SizedBox.shrink();
                      }
                      final ts =
                          records[idx]['timestamp']?.toString() ?? '';
                      final dt = DateTime.tryParse(ts);
                      if (dt == null) return const SizedBox.shrink();
                      return Text(DateFormat('HH:mm').format(dt),
                          style: const TextStyle(
                              fontSize: 8,
                              color: AppColors.textSecondary));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(
                        '${v.toInt()} A',
                        style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.textSecondary)),
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ));
          },
        );
      },
    );
  }
}
