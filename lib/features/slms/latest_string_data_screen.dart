import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';

class LatestStringDataScreen extends ConsumerStatefulWidget {
  final String inverterId;
  const LatestStringDataScreen({super.key, required this.inverterId});

  @override
  ConsumerState<LatestStringDataScreen> createState() =>
      _LatestStringDataScreenState();
}

class _LatestStringDataScreenState
    extends ConsumerState<LatestStringDataScreen> {
  late DateTime _selectedDate;
  bool _gridView = true;

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

    return invAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (inv) {
        final invName = inv?['name'] ?? 'Inverter';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Breadcrumb ──
              BreadcrumbBar(items: [
                const BreadcrumbItem('Dashboard', route: '/dashboard'),
                const BreadcrumbItem('SLMS', route: '/slms'),
                BreadcrumbItem(invName),
              ]),

              // Header
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
                ],
              ),
              const SizedBox(height: 4),
              Text(invName,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // ── CT Data Chart ──
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
                          const Text('CT Data',
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
                            child: Text('Yesterday',
                                style: TextStyle(
                                    color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 260,
                        child: dataAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('$e')),
                          data: (records) {
                            if (records.isEmpty) {
                              return const Center(
                                  child: Text('No data for this date'));
                            }
                            return _buildCtChart(records);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Latest String Data Grid ──
              dataAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (records) {
                  // Count available CT channels from latest record
                  final channels = <int>[];
                  if (records.isNotEmpty) {
                    final latest = records.last;
                    for (final ch in [1, 2, 3, 4, 5, 6, 7, 8]) {
                      if (latest['dcCurrent$ch'] != null) {
                        channels.add(ch);
                      }
                    }
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                              'Latest String Data (Total String – ${channels.length})',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                          const Spacer(),
                          IconButton(
                            icon: Icon(_gridView
                                ? Icons.grid_view
                                : Icons.list),
                            onPressed: () =>
                                setState(() => _gridView = !_gridView),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (records.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No string data')),
                        )
                      else if (_gridView)
                        _buildStringGrid(records.last, channels)
                      else
                        _buildStringList(records.last, channels),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCtChart(List<Map<String, dynamic>> records) {
    final channelSpots = <int, List<FlSpot>>{};
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      for (final ch in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final v = (r['dcCurrent$ch'] as num?)?.toDouble();
        if (v != null) {
          channelSpots.putIfAbsent(ch, () => []);
          channelSpots[ch]!.add(FlSpot(i.toDouble(), v));
        }
      }
    }
    if (channelSpots.isEmpty) {
      return const Center(child: Text('No CT data'));
    }
    final colors = [
      AppColors.primary,
      AppColors.chartGreen,
      AppColors.chartOrange,
      AppColors.chartPurple,
      AppColors.chartBlue,
      AppColors.chartRed,
      AppColors.chartTeal,
      AppColors.chartPink,
    ];
    int ci = 0;
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
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    dt != null ? DateFormat('HH:mm').format(dt) : '',
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
      lineBarsData: channelSpots.entries.map((e) {
        final c = colors[ci++ % colors.length];
        return LineChartBarData(
          spots: e.value,
          isCurved: true,
          color: c,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        );
      }).toList(),
    ));
  }

  Widget _buildStringGrid(
      Map<String, dynamic> latest, List<int> channels) {
    final ts = latest['timestamp']?.toString();
    final dt = ts != null ? DateTime.tryParse(ts) : null;
    final timeStr = dt != null ? DateFormat('HH:mm:ss').format(dt) : '-';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: channels.map((ch) {
        final val =
            (latest['dcCurrent$ch'] as num?)?.toStringAsFixed(2) ?? '-';
        return Container(
          width: 130,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CT $ch',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  Text(timeStr,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
              const Spacer(),
              Text(val,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStringList(
      Map<String, dynamic> latest, List<int> channels) {
    return Column(
      children: channels.map((ch) {
        final val =
            (latest['dcCurrent$ch'] as num?)?.toStringAsFixed(2) ?? '-';
        return ListTile(
          leading: const Icon(Icons.electrical_services,
              color: AppColors.primary),
          title: Text('CT $ch'),
          trailing: Text('$val A',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
        );
      }).toList(),
    );
  }
}