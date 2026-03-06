import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/csv_export.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';

class SingleInverterScreen extends ConsumerStatefulWidget {
  final String inverterId;
  final String plantId;
  const SingleInverterScreen(
      {super.key, required this.inverterId, required this.plantId});

  @override
  ConsumerState<SingleInverterScreen> createState() =>
      _SingleInverterScreenState();
}

class _SingleInverterScreenState extends ConsumerState<SingleInverterScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(2026, 3, 5);
  }

  @override
  Widget build(BuildContext context) {
    final invAsync = ref.watch(inverterByIdProvider(widget.inverterId));
    final dataAsync = ref.watch(inverterDataByDateProvider(
        (inverterId: widget.inverterId, date: _selectedDate)));
    final latestAsync =
        ref.watch(latestInverterDataProvider(widget.inverterId));
    final plantAsync = ref.watch(plantByIdProvider(widget.plantId));
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return invAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (inv) {
        if (inv == null) return const Center(child: Text('Inverter not found'));
        final invName = inv['name'] ?? 'Inverter';
        final plantName = inv['Plant']?['name'] ?? plantAsync.valueOrNull?['name'] ?? 'Plant';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Breadcrumb ──
              BreadcrumbBar(items: [
                const BreadcrumbItem('Dashboard', route: '/dashboard'),
                BreadcrumbItem('Plants',
                    route: '/plants/${widget.plantId}'),
                BreadcrumbItem(plantName,
                    route: '/plants/${widget.plantId}'),
                BreadcrumbItem(invName),
              ]),

              // ── Header ──
              Row(
                children: [
                  const Icon(Icons.circle,
                      color: AppColors.active, size: 10),
                  const SizedBox(width: 6),
                  const Text('Active',
                      style: TextStyle(
                          color: AppColors.active,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () {},
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: const Text('Alerts'),
                    onPressed: () => context.go('/alerts'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(invName,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // ── Export CSV ──
                  FilledButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export'),
                    onPressed: () => _exportCsv(context),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Grid Measurements + Energy Data ──
              isMobile
                  ? Column(children: [
                      _GridMeasurementsCard(latestAsync: latestAsync),
                      const SizedBox(height: 16),
                      _EnergyDataCard(latestAsync: latestAsync),
                    ])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 2,
                            child: _GridMeasurementsCard(
                                latestAsync: latestAsync)),
                        const SizedBox(width: 16),
                        Expanded(
                            flex: 1,
                            child:
                                _EnergyDataCard(latestAsync: latestAsync)),
                      ],
                    ),

              const SizedBox(height: 24),

              // ── String Current Chart ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('String Current',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          ActionChip(
                            avatar:
                                const Icon(Icons.calendar_today, size: 14),
                            label: Text(DateFormat('d/M/yyyy')
                                .format(_selectedDate)),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) {
                                setState(() => _selectedDate = d);
                              }
                            },
                          ),
                          TextButton(
                            onPressed: () => setState(() =>
                                _selectedDate = DateTime(2026, 3, 5)),
                            child: const Text('Today'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _selectedDate =
                                DateTime(2026, 3, 5)
                                    .subtract(const Duration(days: 1))),
                            child: const Text('Yesterday'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 280,
                        child: dataAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('$e')),
                          data: (records) {
                            if (records.isEmpty) {
                              return const Center(
                                  child: Text('No data for this date',
                                      style: TextStyle(
                                          color:
                                              AppColors.textSecondary)));
                            }
                            return _buildStringCurrentChart(records);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStringCurrentChart(List<Map<String, dynamic>> records) {
    // Build series for each dcCurrent channel
    final channels = <int, List<FlSpot>>{};
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      for (final ch in [1, 2, 3, 4, 8]) {
        final val = (r['dcCurrent$ch'] as num?)?.toDouble();
        if (val != null) {
          channels.putIfAbsent(ch, () => []);
          channels[ch]!.add(FlSpot(i.toDouble(), val));
        }
      }
    }
    if (channels.isEmpty) {
      return const Center(
          child: Text('No current data',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    final colors = [
      AppColors.primary,
      AppColors.chartGreen,
      AppColors.chartOrange,
      AppColors.chartPurple,
      AppColors.chartBlue,
    ];
    int ci = 0;
    final series = <LineChartBarData>[];
    for (final entry in channels.entries) {
      series.add(LineChartBarData(
        spots: entry.value,
        isCurved: true,
        color: colors[ci % colors.length],
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
      ci++;
    }
    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (v) =>
            FlLine(color: AppColors.border, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: (records.length / 6).ceilToDouble().clamp(1, 100),
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= records.length) {
                return const SizedBox.shrink();
              }
              final ts = records[idx]['timestamp']?.toString() ?? '';
              final dt = DateTime.tryParse(ts);
              if (dt == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(DateFormat('HH:mm').format(dt),
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(0)}A',
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary)),
          ),
        ),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: series,
    ));
  }

  void _exportCsv(BuildContext context) {
    final dataAsync = ref.read(inverterDataByDateProvider(
        (inverterId: widget.inverterId, date: _selectedDate)));
    dataAsync.whenData((records) {
      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export')));
        return;
      }
      final buf = StringBuffer();
      buf.writeln(
          'timestamp,dcVoltage1,dcCurrent1,dcVoltage2,dcCurrent2,dcVoltage3,dcCurrent3,dcVoltage4,dcCurrent4,dcVoltage8,dcCurrent8');
      for (final r in records) {
        buf.writeln([
          r['timestamp'],
          r['dcVoltage1'] ?? '',
          r['dcCurrent1'] ?? '',
          r['dcVoltage2'] ?? '',
          r['dcCurrent2'] ?? '',
          r['dcVoltage3'] ?? '',
          r['dcCurrent3'] ?? '',
          r['dcVoltage4'] ?? '',
          r['dcCurrent4'] ?? '',
          r['dcVoltage8'] ?? '',
          r['dcCurrent8'] ?? '',
        ].join(','));
      }
      final filename =
          'inverter_${widget.inverterId}_${DateFormat('yyyyMMdd').format(_selectedDate)}.csv';
      exportCsvFile(buf.toString(), filename, context);
    });
  }
}

// ── Grid Measurements Card ──
class _GridMeasurementsCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>?> latestAsync;
  const _GridMeasurementsCard({required this.latestAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Grid Measurements',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit'),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            latestAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (data) {
                if (data == null) {
                  return const Text('No data',
                      style: TextStyle(color: AppColors.textSecondary));
                }
                final measurements = <MapEntry<String, String>>[];
                for (final ch in [1, 2, 3, 4, 8]) {
                  final v = data['dcVoltage$ch'];
                  if (v != null) {
                    measurements.add(MapEntry(
                        'DC Voltage $ch', (v as num).toStringAsFixed(2)));
                  }
                }
                return Wrap(
                  spacing: 32,
                  runSpacing: 16,
                  children: measurements
                      .map((m) => SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.key,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(m.value,
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            latestAsync.whenData((d) {
              if (d == null) return const SizedBox.shrink();
              final ts = d['timestamp']?.toString();
              final dt = ts != null ? DateTime.tryParse(ts) : null;
              return Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                      dt != null
                          ? DateFormat('MMM d, h:mm a').format(dt)
                          : '-',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              );
            }).value ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

// ── Energy Data Card ──
class _EnergyDataCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>?> latestAsync;
  const _EnergyDataCard({required this.latestAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Energy Data',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            latestAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (data) {
                if (data == null) {
                  return const Text('No data',
                      style: TextStyle(color: AppColors.textSecondary));
                }
                // Calculate some energy metrics from DC data
                double totalPower = 0;
                for (final ch in [1, 2, 3, 4, 8]) {
                  final v =
                      (data['dcVoltage$ch'] as num?)?.toDouble() ?? 0;
                  final c =
                      (data['dcCurrent$ch'] as num?)?.toDouble() ?? 0;
                  totalPower += v * c;
                }
                return Column(
                  children: [
                    _EnergyItem(
                        Icons.solar_power_outlined,
                        'E-Today Active Production',
                        '${(totalPower / 1000).toStringAsFixed(2)} kW'),
                    const SizedBox(height: 16),
                    _EnergyItem(Icons.bolt, 'Active Power',
                        '${totalPower.toStringAsFixed(2)} W'),
                    const SizedBox(height: 16),
                    _EnergyItem(
                        Icons.electric_meter_outlined,
                        'E-Total Active Production',
                        '${(totalPower / 1000).toStringAsFixed(2)} kW'),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            latestAsync.whenData((d) {
              if (d == null) return const SizedBox.shrink();
              final ts = d['timestamp']?.toString();
              final dt = ts != null ? DateTime.tryParse(ts) : null;
              return Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                      dt != null
                          ? DateFormat('MMM d, h:mm a').format(dt)
                          : '-',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              );
            }).value ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _EnergyItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _EnergyItem(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}