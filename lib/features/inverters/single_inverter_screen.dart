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
  String _selectedChart = 'Total PV Current';

  static const _chartOptions = [
    'Total PV Current',
    'E-Total Power',
    'Total PV Voltage',
    'E-Today Power',
    'Active Power',
  ];

  static const _dcChannels = [1, 2, 3, 4, 5, 6, 7, 8];

  static const _channelColors = <Color>[
    AppColors.primary,
    AppColors.chartGreen,
    AppColors.chartOrange,
    AppColors.chartPurple,
    AppColors.chartBlue,
    AppColors.chartRed,
    AppColors.chartTeal,
    AppColors.chartPink,
  ];

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
        final plantName =
            inv['Plant']?['name'] ?? plantAsync.value?['name'] ?? 'Plant';

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

              // ── Charts Section ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Chart type selector chips ──
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
                                      setState(
                                          () => _selectedChart = opt);
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
                          TextButton(
                            onPressed: () => setState(() =>
                                _selectedDate = DateTime(2026, 3, 5)
                                    .subtract(const Duration(days: 1))),
                            child: const Text('Yesterday'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Legend for multi-line charts ──
                      if (_selectedChart == 'Total PV Current' ||
                          _selectedChart == 'Total PV Voltage')
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
                                          color:
                                              AppColors.textSecondary)));
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

  // ── Legend row for multi-channel charts ──
  Widget _buildLegend() {
    final prefix =
        _selectedChart == 'Total PV Current' ? 'DC Current' : 'DC Voltage';
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: _dcChannels.map((ch) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                  color: _channelColors[(ch - 1) % _channelColors.length],
                  borderRadius: BorderRadius.circular(2),
                )),
            const SizedBox(width: 4),
            Text('$prefix #$ch',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        );
      }).toList(),
    );
  }

  // ── Chart dispatcher ──
  Widget _buildChart(List<Map<String, dynamic>> records) {
    switch (_selectedChart) {
      case 'Total PV Current':
        return _buildMultiLineChart(records, 'dcCurrent', 'A');
      case 'Total PV Voltage':
        return _buildMultiLineChart(records, 'dcVoltage', 'V');
      case 'E-Total Power':
        return _buildSingleLineChart(
            records, _computeCumulativeEnergy, 'kWh', 'E-Total Power');
      case 'E-Today Power':
        return _buildSingleLineChart(
            records, _computeCumulativeEnergy, 'kWh', 'E-Today Power');
      case 'Active Power':
        return _buildSingleLineChart(
            records, _computeActivePower, 'W', 'Active Power');
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Multi-line chart (8 channels) ──
  Widget _buildMultiLineChart(
      List<Map<String, dynamic>> records, String prefix, String unit) {
    final channels = <int, List<FlSpot>>{};
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      for (final ch in _dcChannels) {
        final val = (r['$prefix$ch'] as num?)?.toDouble();
        if (val != null) {
          channels.putIfAbsent(ch, () => []);
          channels[ch]!.add(FlSpot(i.toDouble(), val));
        }
      }
    }
    if (channels.isEmpty) {
      return Center(
          child: Text('No ${prefix == 'dcCurrent' ? 'current' : 'voltage'} data',
              style: const TextStyle(color: AppColors.textSecondary)));
    }

    final channelList = channels.keys.toList()..sort();
    final series = <LineChartBarData>[];
    for (final ch in channelList) {
      series.add(LineChartBarData(
        spots: channels[ch]!,
        isCurved: true,
        color: _channelColors[(ch - 1) % _channelColors.length],
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    return LineChart(LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.white,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final ch = channelList[spot.barIndex];
              final label = prefix == 'dcCurrent'
                  ? 'DC Current #$ch'
                  : 'DC Voltage #$ch';
              return LineTooltipItem(
                '$label\n${spot.y.toStringAsFixed(2)} $unit',
                TextStyle(
                  color: _channelColors[(ch - 1) % _channelColors.length],
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
      titlesData: _buildTitlesData(records, unit),
      borderData: FlBorderData(show: false),
      lineBarsData: series,
    ));
  }

  // ── Single-line chart ──
  Widget _buildSingleLineChart(
    List<Map<String, dynamic>> records,
    List<FlSpot> Function(List<Map<String, dynamic>>) computeFn,
    String unit,
    String label,
  ) {
    final spots = computeFn(records);
    if (spots.isEmpty) {
      return Center(
          child: Text('No data',
              style: const TextStyle(color: AppColors.textSecondary)));
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
                '$label\n${spot.y.toStringAsFixed(2)} $unit',
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

  // ── Shared axis titles ──
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

  // ── Compute active power (W) at each timestamp ──
  List<FlSpot> _computeActivePower(List<Map<String, dynamic>> records) {
    final spots = <FlSpot>[];
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      double power = 0;
      for (final ch in _dcChannels) {
        final v = (r['dcVoltage$ch'] as num?)?.toDouble() ?? 0;
        final c = (r['dcCurrent$ch'] as num?)?.toDouble() ?? 0;
        power += v * c;
      }
      spots.add(FlSpot(i.toDouble(), power));
    }
    return spots;
  }

  // ── Compute cumulative energy (kWh) ──
  List<FlSpot> _computeCumulativeEnergy(
      List<Map<String, dynamic>> records) {
    final spots = <FlSpot>[];
    double cumulative = 0;
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      double power = 0;
      for (final ch in _dcChannels) {
        final v = (r['dcVoltage$ch'] as num?)?.toDouble() ?? 0;
        final c = (r['dcCurrent$ch'] as num?)?.toDouble() ?? 0;
        power += v * c;
      }
      // Approximate time step from adjacent records
      double dtHours = 5.0 / 60.0; // default 5 min
      if (i > 0) {
        final ts0 = DateTime.tryParse(
            records[i - 1]['timestamp']?.toString() ?? '');
        final ts1 =
            DateTime.tryParse(r['timestamp']?.toString() ?? '');
        if (ts0 != null && ts1 != null) {
          dtHours =
              ts1.difference(ts0).inSeconds.abs() / 3600.0;
        }
      }
      cumulative += (power / 1000.0) * dtHours;
      spots.add(FlSpot(i.toDouble(), cumulative));
    }
    return spots;
  }

  // ── CSV export with all 8 channels ──
  void _exportCsv(BuildContext context) {
    final dataAsync = ref.read(inverterDataByDateProvider(
        (inverterId: widget.inverterId, date: _selectedDate)));
    dataAsync.whenData((records) {
      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export')));
        return;
      }
      final header = ['timestamp'];
      for (final ch in _dcChannels) {
        header.addAll(['dcVoltage$ch', 'dcCurrent$ch']);
      }
      final buf = StringBuffer();
      buf.writeln(header.join(','));
      for (final r in records) {
        final row = [r['timestamp']];
        for (final ch in _dcChannels) {
          row.addAll([r['dcVoltage$ch'] ?? '', r['dcCurrent$ch'] ?? '']);
        }
        buf.writeln(row.join(','));
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
            const Text('Grid Measurements',
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
                  MapEntry(
                      'Grid Voltage AB', fmt(data['gridVoltageAB'], 'V')),
                  MapEntry(
                      'Grid Voltage BC', fmt(data['gridVoltageBC'], 'V')),
                  MapEntry(
                      'Grid Voltage AC', fmt(data['gridVoltageAC'], 'V')),
                  MapEntry(
                      'Grid Voltage A', fmt(data['gridVoltageA'], 'V')),
                  MapEntry(
                      'Grid Voltage B', fmt(data['gridVoltageB'], 'V')),
                  MapEntry(
                      'Grid Voltage C', fmt(data['gridVoltageC'], 'V')),
                  MapEntry(
                      'Grid Current A', fmt(data['gridCurrentA'], 'A')),
                  MapEntry(
                      'Grid Current B', fmt(data['gridCurrentB'], 'A')),
                  MapEntry(
                      'Grid Current C', fmt(data['gridCurrentC'], 'A')),
                  MapEntry(
                      'Grid Frequency', fmt(data['gridFrequency'], 'Hz')),
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (data) {
                if (data == null) {
                  return const Text('No data',
                      style:
                          TextStyle(color: AppColors.textSecondary));
                }
                // Calculate energy from all 8 DC channels
                double totalPower = 0;
                for (final ch in [1, 2, 3, 4, 5, 6, 7, 8]) {
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
                    _EnergyItem(
                        Icons.electric_meter_outlined,
                        'E-Total Active Production',
                        '${(totalPower / 1000).toStringAsFixed(2)} kW'),
                    const SizedBox(height: 16),
                    _EnergyItem(Icons.bolt, 'Active Power',
                        '${totalPower.toStringAsFixed(2)} W'),
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