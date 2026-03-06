import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../shared/kpi_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final plantsAsync = ref.watch(plantsProvider);
    final invCountAsync = ref.watch(inverterCountByPlantProvider);
    final search = ref.watch(plantSearchProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ──
          Text('Namaste, Dhruti!',
              style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: AppColors.primary)),
          const SizedBox(height: 2),
          Text('Solar Performance Overview',
              style: TextStyle(
                  fontSize: isMobile ? 20 : 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 20),

          // ── KPI Row ──
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading stats: $e'),
            data: (stats) {
              final todayE = (stats['todayEnergy'] as num).toStringAsFixed(1);
              final totalE = (stats['totalEnergy'] as num).toStringAsFixed(1);
              final cap = (stats['totalCapacity'] as num).toStringAsFixed(1);
              final co2 = (stats['co2Reduced'] as num).toStringAsFixed(2);
              final pCount = stats['plantCount'] as int;
              final kpis = [
                KpiCard(
                    title: 'Today Energy',
                    value: '$todayE kWh',
                    icon: Icons.bolt),
                KpiCard(
                    title: 'Total Energy',
                    value: '$totalE kWh',
                    icon: Icons.electric_meter_outlined),
                KpiCard(
                    title: 'Total Capacity',
                    value: '$cap kWp',
                    icon: Icons.battery_charging_full_outlined),
                KpiCard(
                    title: 'CO\u2082 Reduced',
                    value: '$co2 T',
                    icon: Icons.eco_outlined,
                    color: AppColors.active),
              ];
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: kpis
                    .map((k) => SizedBox(
                        width: isMobile
                            ? double.infinity
                            : (width - 300) / 4 - 12,
                        child: k))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Charts row ──
          isMobile
              ? Column(children: [
                  _DevicesPieChart(),
                  const SizedBox(height: 16),
                  _EnergyBarChart(),
                ])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 280, child: _DevicesPieChart()),
                    const SizedBox(width: 16),
                    Expanded(child: _EnergyBarChart()),
                  ],
                ),

          const SizedBox(height: 24),

          // ── Plants Details Table ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Plants Details',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      // Date picker
                      ActionChip(
                        avatar: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                            DateFormat('d MMM yyyy').format(selectedDate)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) {
                            ref.read(selectedDateProvider.notifier).state = d;
                          }
                        },
                      ),
                      SizedBox(
                        width: 220,
                        height: 38,
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search, size: 18),
                            hintText: 'Search Plants',
                            contentPadding: EdgeInsets.symmetric(vertical: 0),
                          ),
                          onChanged: (v) =>
                              ref.read(plantSearchProvider.notifier).state = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  plantsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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
                                  style: TextStyle(
                                      color: AppColors.textSecondary))),
                        );
                      }
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AppColors.primaryLighter),
                          columns: const [
                            DataColumn(label: Text('')),
                            DataColumn(label: Text('Plant Name')),
                            DataColumn(label: Text('Today')),
                            DataColumn(label: Text('Total')),
                            DataColumn(label: Text('Capacity')),
                            DataColumn(label: Text('Last Updated')),
                          ],
                          rows: filtered.map((p) {
                            final today =
                                (p['todayEnergy'] as num?)?.toStringAsFixed(0) ??
                                    '-';
                            final total =
                                (p['totalEnergy'] as num?)?.toStringAsFixed(0) ??
                                    '-';
                            final cap = (p['capacityKWp'] as num?)
                                    ?.toStringAsFixed(0) ??
                                '-';
                            final inst = p['installationDate'];
                            final lastUp = inst != null
                                ? DateFormat('MMM d, h:mm a')
                                    .format(DateTime.tryParse(inst.toString()) ??
                                        DateTime.now())
                                : '-';
                            final isActive =
                                ((p['todayEnergy'] as num?) ?? 0) > 0;
                            return DataRow(
                              cells: [
                                DataCell(_StatusDot(
                                    color: isActive
                                        ? AppColors.active
                                        : AppColors.warning,
                                    blink: isActive)),
                                DataCell(Text(p['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                                DataCell(Text('$today kWh')),
                                DataCell(Text('$total kWh')),
                                DataCell(Text('$cap kWp')),
                                DataCell(Text(lastUp)),
                              ],
                              onSelectChanged: (_) =>
                                  context.go('/plants/${p['id']}'),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Devices Pie Chart ──
class _DevicesPieChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(inverterCountByPlantProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total Devices',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            countAsync.when(
              loading: () => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e'),
              data: (counts) {
                if (counts.isEmpty) {
                  return const SizedBox(
                      height: 160,
                      child: Center(child: Text('No devices')));
                }
                final colors = [
                  AppColors.primary,
                  AppColors.chartGreen,
                  AppColors.chartOrange,
                  AppColors.chartPurple,
                  AppColors.chartBlue,
                ];
                final entries = counts.entries.toList();
                return Column(
                  children: [
                    SizedBox(
                      height: 160,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          sections: [
                            for (int i = 0; i < entries.length; i++)
                              PieChartSectionData(
                                value: entries[i].value.toDouble(),
                                color: colors[i % colors.length],
                                title: entries[i].value.toString(),
                                titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                                radius: 36,
                              ),
                          ],
                          pieTouchData: PieTouchData(
                            enabled: true,
                            touchCallback: (event, response) {
                              if (event is FlTapUpEvent &&
                                  response?.touchedSection != null) {
                                final idx = response!
                                    .touchedSection!.touchedSectionIndex;
                                if (idx >= 0 && idx < entries.length) {
                                  // Navigate to plant – resolve plant ID
                                  final plants = ref
                                      .read(plantsProvider)
                                      .valueOrNull;
                                  if (plants != null) {
                                    final match = plants.firstWhere(
                                        (p) =>
                                            p['name'] == entries[idx].key,
                                        orElse: () => {});
                                    if (match.containsKey('id')) {
                                      context.go('/plants/${match['id']}');
                                    }
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        for (int i = 0; i < entries.length; i++)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: colors[i % colors.length],
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(entries[i].key,
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Energy Bar Chart ──
class _EnergyBarChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantsAsync = ref.watch(plantsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('Energy Generation',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            plantsAsync.when(
              loading: () => const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e'),
              data: (plants) {
                if (plants.isEmpty) {
                  return const SizedBox(
                      height: 220, child: Center(child: Text('No data')));
                }
                final maxE = plants.fold<double>(
                    0.0,
                    (prev, p) =>
                        ((p['todayEnergy'] as num?)?.toDouble() ?? 0) > prev
                            ? ((p['todayEnergy'] as num?)?.toDouble() ?? 0)
                            : prev);
                return SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData()),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= plants.length) {
                                return const SizedBox.shrink();
                              }
                              final name =
                                  (plants[idx]['name'] ?? '').toString();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                    name.length > 8
                                        ? '${name.substring(0, 8)}…'
                                        : name,
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textSecondary)),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary)),
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(
                            color: AppColors.border, strokeWidth: 1),
                      ),
                      maxY: maxE * 1.2,
                      barGroups: [
                        for (int i = 0; i < plants.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: (plants[i]['todayEnergy'] as num?)
                                      ?.toDouble() ??
                                  0,
                              color: AppColors.primary,
                              width: 22,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ]),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status dot widget with optional pulse animation ──
class _StatusDot extends StatefulWidget {
  final Color color;
  final bool blink;
  const _StatusDot({required this.color, this.blink = false});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.blink) {
      return Icon(Icons.circle, color: widget.color, size: 10);
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.4 + 0.6 * _ctrl.value,
        child: Icon(Icons.circle, color: widget.color, size: 10),
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  const AnimatedBuilder(
      {super.key, required super.listenable, required this.builder});
  @override
  Widget build(BuildContext context) => builder(context, null);
}