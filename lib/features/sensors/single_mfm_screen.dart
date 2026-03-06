import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/csv_export.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';

class SingleMfmScreen extends ConsumerStatefulWidget {
  final String mfmId;
  final String plantId;
  final String? initialDate;
  const SingleMfmScreen(
      {super.key, required this.mfmId, required this.plantId, this.initialDate});

  @override
  ConsumerState<SingleMfmScreen> createState() => _SingleMfmScreenState();
}

class _SingleMfmScreenState extends ConsumerState<SingleMfmScreen> {
  late DateTime _selectedDate;
  String _selectedChart = 'Voltage';

  static const _chartOptions = [
    'Voltage',
    'Current',
    'Total Power',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      final parsed = DateTime.tryParse(widget.initialDate!);
      _selectedDate = parsed ?? DateTime(2026, 3, 5);
    } else {
      _selectedDate = DateTime(2026, 3, 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mfmAsync = ref.watch(mfmByIdProvider(widget.mfmId));
    final dataAsync = ref.watch(mfmDataByDateProvider(
        (mfmId: widget.mfmId, date: _selectedDate)));
    final latestAsync = ref.watch(latestMfmDataProvider(widget.mfmId));
    final plantAsync = ref.watch(plantByIdProvider(widget.plantId));
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return mfmAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (mfm) {
        if (mfm == null) return const Center(child: Text('MFM not found'));
        final mfmName = mfm['name'] ?? 'MFM';
        final plantName =
            mfm['Sensors']?['Plant']?['name'] ?? plantAsync.value?['name'] ?? 'Plant';

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
                BreadcrumbItem(mfmName),
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
                  Text(mfmName,
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

              // ── Measurement Cards ──
              isMobile
                  ? Column(children: [
                      _MfmMeasurementsCard(latestAsync: latestAsync),
                      const SizedBox(height: 16),
                      _MfmPowerCard(latestAsync: latestAsync),
                    ])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 2,
                            child: _MfmMeasurementsCard(
                                latestAsync: latestAsync)),
                        const SizedBox(width: 16),
                        Expanded(
                            flex: 1,
                            child: _MfmPowerCard(latestAsync: latestAsync)),
                      ],
                    ),

              const SizedBox(height: 24),

              // ── Charts Section ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _chartOptions
                            .map((opt) => ChoiceChip(
                                  label: Text(opt,
                                      style: const TextStyle(fontSize: 12)),
                                  selected: _selectedChart == opt,
                                  onSelected: (v) {
                                    if (v) {
                                      setState(() => _selectedChart = opt);
                                    }
                                  },
                                  selectedColor: AppColors.primaryLight,
                                  labelStyle: TextStyle(
                                    color: _selectedChart == opt
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontWeight: _selectedChart == opt
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ))
                            .toList(),
                      ),
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

                      // ── Legend ──
                      if (_selectedChart == 'Voltage' ||
                          _selectedChart == 'Current')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildLegend(),
                        ),

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
                            return _buildChart(records);
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

  Widget _buildLegend() {
    final phases = _selectedChart == 'Voltage'
        ? ['L1-N Voltage', 'L2-N Voltage', 'L3-N Voltage']
        : ['L1-N Current', 'L2-N Current', 'L3-N Current'];
    const colors = [AppColors.primary, AppColors.chartGreen, AppColors.chartOrange];
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: List.generate(3, (i) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(2),
                )),
            const SizedBox(width: 4),
            Text(phases[i],
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        );
      }),
    );
  }

  Widget _buildChart(List<Map<String, dynamic>> records) {
    switch (_selectedChart) {
      case 'Voltage':
        return _buildMultiLineChart(records,
            ['l1nVoltage', 'l2nVoltage', 'l3nVoltage'], 'V');
      case 'Current':
        return _buildMultiLineChart(records,
            ['l1nCurrent', 'l2nCurrent', 'l3nCurrent'], 'A');
      case 'Total Power':
        return _buildSingleLineChart(records, 'totalPower', 'kW');
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMultiLineChart(
      List<Map<String, dynamic>> records, List<String> fields, String unit) {
    const colors = [AppColors.primary, AppColors.chartGreen, AppColors.chartOrange];
    final series = <LineChartBarData>[];

    for (int f = 0; f < fields.length; f++) {
      final spots = <FlSpot>[];
      for (int i = 0; i < records.length; i++) {
        final val = (records[i][fields[f]] as num?)?.toDouble();
        if (val != null) {
          spots.add(FlSpot(i.toDouble(), val));
        }
      }
      if (spots.isNotEmpty) {
        series.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          color: colors[f % colors.length],
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ));
      }
    }

    if (series.isEmpty) {
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
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (v) =>
            FlLine(color: AppColors.border, strokeWidth: 1),
      ),
      titlesData: _buildTitlesData(records, unit),
      borderData: FlBorderData(show: false),
      lineBarsData: series,
    ));
  }

  Widget _buildSingleLineChart(
      List<Map<String, dynamic>> records, String field, String unit) {
    final spots = <FlSpot>[];
    for (int i = 0; i < records.length; i++) {
      final val = (records[i][field] as num?)?.toDouble();
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
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (v) =>
            FlLine(color: AppColors.border, strokeWidth: 1),
      ),
      titlesData: _buildTitlesData(records, unit),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primary,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primary.withValues(alpha: 0.08),
          ),
        ),
      ],
    ));
  }

  FlTitlesData _buildTitlesData(
      List<Map<String, dynamic>> records, String unit) {
    return FlTitlesData(
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
          reservedSize: 44,
          getTitlesWidget: (v, _) => Text(
              '${v.toStringAsFixed(v >= 1000 ? 0 : 1)}$unit',
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textSecondary)),
        ),
      ),
      topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  void _exportCsv(BuildContext context) {
    final dataAsync = ref.read(mfmDataByDateProvider(
        (mfmId: widget.mfmId, date: _selectedDate)));
    dataAsync.whenData((records) {
      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export')));
        return;
      }
      final header = [
        'timestamp',
        'l1nVoltage', 'l2nVoltage', 'l3nVoltage',
        'l1nCurrent', 'l2nCurrent', 'l3nCurrent',
        'totalPower',
      ];
      final buf = StringBuffer();
      buf.writeln(header.join(','));
      for (final r in records) {
        final row = header.map((h) => r[h] ?? '').toList();
        buf.writeln(row.join(','));
      }
      final filename =
          'mfm_${widget.mfmId}_${DateFormat('yyyyMMdd').format(_selectedDate)}.csv';
      exportCsvFile(buf.toString(), filename, context);
    });
  }
}

// ── MFM Measurements Card ──
class _MfmMeasurementsCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>?> latestAsync;
  const _MfmMeasurementsCard({required this.latestAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MFM Measurements',
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
                String fmt(dynamic v, String unit) {
                  if (v == null) return '--';
                  return '${(v as num).toStringAsFixed(2)} $unit';
                }

                final fields = <MapEntry<String, String>>[
                  MapEntry('L1-N Voltage', fmt(data['l1nVoltage'], 'V')),
                  MapEntry('L2-N Voltage', fmt(data['l2nVoltage'], 'V')),
                  MapEntry('L3-N Voltage', fmt(data['l3nVoltage'], 'V')),
                  MapEntry('L1-N Current', fmt(data['l1nCurrent'], 'A')),
                  MapEntry('L2-N Current', fmt(data['l2nCurrent'], 'A')),
                  MapEntry('L3-N Current', fmt(data['l3nCurrent'], 'A')),
                  MapEntry('Frequency', fmt(data['frequency'], 'Hz')),
                ];

                return Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: fields
                      .map((m) => SizedBox(
                            width: 150,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(m.key,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(m.value,
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 18,
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
                  const Icon(Icons.schedule,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                      dt != null
                          ? DateFormat('MMM d, h:mm a').format(dt)
                          : '-',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              );
            }).value ??
                const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

// ── MFM Power Card ──
class _MfmPowerCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>?> latestAsync;
  const _MfmPowerCard({required this.latestAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Power Data',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
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
                final totalPower =
                    (data['totalPower'] as num?)?.toDouble() ?? 0;
                return _PowerItem(Icons.electric_meter_outlined,
                    'Total Power', '${totalPower.toStringAsFixed(2)} kW');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PowerItem(this.icon, this.label, this.value);

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
