import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/csv_export.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';

class SingleTempScreen extends ConsumerStatefulWidget {
  final String deviceId;
  final String plantId;
  const SingleTempScreen(
      {super.key, required this.deviceId, required this.plantId});

  @override
  ConsumerState<SingleTempScreen> createState() => _SingleTempScreenState();
}

class _SingleTempScreenState extends ConsumerState<SingleTempScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(2026, 3, 5);
  }

  @override
  Widget build(BuildContext context) {
    final deviceAsync = ref.watch(tempDeviceByIdProvider(widget.deviceId));
    final dataAsync = ref.watch(tempDataByDateProvider(
        (deviceId: widget.deviceId, date: _selectedDate)));
    final latestAsync = ref.watch(latestTempDataProvider(widget.deviceId));
    final plantAsync = ref.watch(plantByIdProvider(widget.plantId));

    return deviceAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (device) {
        if (device == null) {
          return const Center(child: Text('Device not found'));
        }
        final deviceName = device['name'] ?? 'Temperature Sensor';
        final plantName =
            device['Sensors']?['Plant']?['name'] ?? plantAsync.value?['name'] ?? 'Plant';

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
                BreadcrumbItem(deviceName),
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
                  Text(deviceName,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const Spacer(),
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

              // ── Latest Temperature Card ──
              _LatestTempCard(latestAsync: latestAsync),
              const SizedBox(height: 24),

              // ── Chart Section ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Temperature Over Time',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // ── Date controls ──
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.calendar_today,
                                size: 14),
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
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Chart ──
                      SizedBox(
                        height: 300,
                        child: dataAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('$e')),
                          data: (records) {
                            if (records.isEmpty) {
                              return const Center(
                                  child: Text('No data for this date',
                                      style: TextStyle(
                                          color: AppColors.textSecondary)));
                            }
                            return _buildTempChart(records);
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

  Widget _buildTempChart(List<Map<String, dynamic>> records) {
    final spots = <FlSpot>[];
    for (int i = 0; i < records.length; i++) {
      final val = (records[i]['value'] as num?)?.toDouble();
      if (val != null) {
        spots.add(FlSpot(i.toDouble(), val));
      }
    }
    if (spots.isEmpty) {
      return const Center(
          child: Text('No data',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return LineChart(LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.white,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (spots) {
            return spots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} °C',
                const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              );
            }).toList();
          },
        ),
      ),
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
            interval:
                (records.length / 6).ceilToDouble().clamp(1, 100),
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
            reservedSize: 44,
            getTitlesWidget: (v, _) => Text(
                '${v.toStringAsFixed(1)}°C',
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
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.chartOrange,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.chartOrange.withValues(alpha: 0.08),
          ),
        ),
      ],
    ));
  }

  void _exportCsv(BuildContext context) {
    final dataAsync = ref.read(tempDataByDateProvider(
        (deviceId: widget.deviceId, date: _selectedDate)));
    dataAsync.whenData((records) {
      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export')));
        return;
      }
      final buf = StringBuffer();
      buf.writeln('timestamp,value');
      for (final r in records) {
        buf.writeln('${r['timestamp'] ?? ''},${r['value'] ?? ''}');
      }
      final filename =
          'temp_${widget.deviceId}_${DateFormat('yyyyMMdd').format(_selectedDate)}.csv';
      exportCsvFile(buf.toString(), filename, context);
    });
  }
}

// ── Latest Temperature Card ──
class _LatestTempCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>?> latestAsync;
  const _LatestTempCard({required this.latestAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Latest Reading',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            latestAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (data) {
                if (data == null) {
                  return const Text('No data',
                      style:
                          TextStyle(color: AppColors.textSecondary));
                }
                final val =
                    (data['value'] as num?)?.toDouble() ?? 0;
                final ts = data['timestamp']?.toString();
                final dt = ts != null ? DateTime.tryParse(ts) : null;
                return Row(
                  children: [
                    const Icon(Icons.thermostat,
                        color: AppColors.chartOrange, size: 36),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Temperature',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('${val.toStringAsFixed(1)} °C',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                        if (dt != null) ...[
                          const SizedBox(height: 4),
                          Text(DateFormat('MMM d, h:mm a').format(dt),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
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
